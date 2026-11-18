#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/uvm-config.sh
source "${SCRIPT_DIR}/uvm-config.sh"

uvm_shell_load_runtime_config() {
    local configured_envs_dir

    export UVM_HOME="${UVM_HOME:-${HOME}/.config/uvm}"
    if configured_envs_dir=$(uvm_read_config_value UVM_ENVS_DIR); then
        UVM_ENVS_DIR="$configured_envs_dir"
    fi
    export UVM_ENVS_DIR="${UVM_ENVS_DIR:-${HOME}/uv_envs}"
}

_uvm_hook_record_file_path() {
    local env_name="$1"
    printf '%s/%s.env\n' "$(uvm_get_env_records_dir)" "$env_name"
}

_uvm_hook_get_env_path() {
    local env_name="$1"
    local default_path
    local record_file
    local line key value

    uvm_shell_load_runtime_config
    uvm_is_valid_env_name "$env_name" || return 1

    record_file=$(_uvm_hook_record_file_path "$env_name")
    if [ -f "$record_file" ]; then
        unset UVM_RECORD_NAME UVM_RECORD_PATH UVM_RECORD_PYTHON UVM_RECORD_CREATED
        # Safe key=value parser — never sources the file
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%$'\r'}"
            case "$line" in
                UVM_RECORD_NAME=*|UVM_RECORD_PATH=*|UVM_RECORD_PYTHON=*|UVM_RECORD_CREATED=*)
                    key="${line%%=*}"
                    value="${line#*=}"
                    value="${value#\'}" ; value="${value%\'}"
                    value="${value#\"}" ; value="${value%\"}"
                    printf -v "$key" '%s' "$value"
                    export "${key?}"
                    ;;
            esac
        done < "$record_file"
        if [ -n "${UVM_RECORD_PATH:-}" ] && uvm_is_valid_uv_env "$UVM_RECORD_PATH"; then
            echo "$UVM_RECORD_PATH"
            return 0
        fi
    fi

    default_path="$(uvm_get_default_envs_dir)/${env_name}"
    if uvm_is_valid_uv_env "$default_path"; then
        echo "$default_path"
        return 0
    fi

    return 1
}

# Parent directory without forking `dirname`. Runs in the caller's shell on a
# real string, so it beats a command substitution even for one level.
uvm_parent_dir() {
    local path="$1"

    while [ "${path%/}" != "$path" ]; do
        path="${path%/}"
    done
    case "$path" in
        */*) printf '%s' "${path%/*}" ;;
        *) printf '%s' "" ;;
    esac
}

uvm_find_upward_file() {
    local file_name="$1"
    local current_dir="${2:-$PWD}"
    local depth=0
    local parent

    while [ -n "$current_dir" ] && [ "$current_dir" != "/" ] && [ "$depth" -lt 25 ]; do
        if [ -f "${current_dir}/${file_name}" ]; then
            printf '%s/%s\n' "$current_dir" "$file_name"
            return 0
        fi
        parent=$(uvm_parent_dir "$current_dir")
        [ "$parent" = "$current_dir" ] && break
        current_dir="$parent"
        depth=$((depth + 1))
    done

    return 1
}

uvm_find_upward_local_env() {
    local current_dir="${1:-$PWD}"
    local depth=0
    local local_env
    local parent

    while [ -n "$current_dir" ] && [ "$current_dir" != "/" ] && [ "$depth" -lt 25 ]; do
        local_env="${current_dir}/.venv"
        if uvm_is_valid_uv_env "$local_env"; then
            echo "$local_env"
            return 0
        fi
        parent=$(uvm_parent_dir "$current_dir")
        [ "$parent" = "$current_dir" ] && break
        current_dir="$parent"
        depth=$((depth + 1))
    done

    return 1
}

# One upward walk that reports both matches, because the auto-activation hook
# needs both on every `cd` and two separate walks cost twice the stat calls.
# Sets UVM_UPWARD_LOCAL_ENV and UVM_UPWARD_FILE (empty when not found).
uvm_find_upward_targets() {
    local file_name="$1"
    local current_dir="${2:-$PWD}"
    local depth=0
    local local_env
    local parent
    local found_file=""

    UVM_UPWARD_LOCAL_ENV=""
    UVM_UPWARD_FILE=""
    while [ -n "$current_dir" ] && [ "$current_dir" != "/" ] && [ "$depth" -lt 25 ]; do
        if [ -z "$UVM_UPWARD_LOCAL_ENV" ]; then
            local_env="${current_dir}/.venv"
            if uvm_is_valid_uv_env "$local_env"; then
                UVM_UPWARD_LOCAL_ENV="$local_env"
            fi
        fi
        if [ -z "$found_file" ] && [ -f "${current_dir}/${file_name}" ]; then
            found_file="${current_dir}/${file_name}"
        fi
        # Both answers found, or reached the top: nothing left to look at.
        if [ -n "$UVM_UPWARD_LOCAL_ENV" ] && [ -n "$found_file" ]; then
            break
        fi
        parent=$(uvm_parent_dir "$current_dir")
        [ "$parent" = "$current_dir" ] && break
        current_dir="$parent"
        depth=$((depth + 1))
    done

    UVM_UPWARD_FILE="$found_file"
    [ -n "$UVM_UPWARD_LOCAL_ENV" ] || [ -n "$UVM_UPWARD_FILE" ]
}

uvm_detect_auto_activation_target() {
    local local_env
    local uvmrc_file
    local env_name
    local env_path

    unset UVM_AUTO_TARGET_PATH UVM_AUTO_TARGET_SOURCE UVM_AUTO_TARGET_ROOT UVM_UNTRUSTED_LOCAL_ENV
    uvm_shell_load_runtime_config

    if uvm_find_upward_targets ".uvmrc"; then
        local_env="$UVM_UPWARD_LOCAL_ENV"
        uvmrc_file="$UVM_UPWARD_FILE"
    fi
    if [ -n "$local_env" ]; then
        if uvm_is_local_env_trusted "$local_env"; then
            UVM_AUTO_TARGET_PATH="$local_env"
            UVM_AUTO_TARGET_SOURCE="local"
            UVM_AUTO_TARGET_ROOT="$(uvm_parent_dir "$UVM_AUTO_TARGET_PATH")"
            export UVM_AUTO_TARGET_PATH UVM_AUTO_TARGET_SOURCE UVM_AUTO_TARGET_ROOT
            return 0
        fi
        UVM_UNTRUSTED_LOCAL_ENV=$(uvm_resolve_existing_path "$local_env" || printf '%s' "$local_env")
        export UVM_UNTRUSTED_LOCAL_ENV
    fi

    if [ -n "$uvmrc_file" ]; then
        env_name=$(head -n 1 "$uvmrc_file" | tr -d '[:space:]')
        if ! uvm_is_valid_env_name "$env_name"; then
            echo "Warning: Invalid environment name in ${uvmrc_file}" >&2
            return 0
        fi

        env_path=$(_uvm_hook_get_env_path "$env_name") || {
            echo "Warning: Environment '${env_name}' referenced by ${uvmrc_file} was not found" >&2
            return 0
        }

        UVM_AUTO_TARGET_PATH="$env_path"
        UVM_AUTO_TARGET_SOURCE="uvm:${env_name}"
        UVM_AUTO_TARGET_ROOT="$(dirname "$uvmrc_file")"
        export UVM_AUTO_TARGET_PATH UVM_AUTO_TARGET_SOURCE UVM_AUTO_TARGET_ROOT
    fi
}

uvm_auto_activate() {
    local previous_status=$?
    local activate_script

    # Warn once per shell session when the loaded hook version doesn't match
    # the installed binary (happens after `uvm update` before re-sourcing RC).
    if [ -z "${_UVM_HOOK_DRIFT_WARNED:-}" ]; then
        local binary_version
        binary_version=$(command uvm version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -n 1)
        if [ -n "${_UVM_HOOK_VERSION:-}" ] && [ -n "$binary_version" ] \
            && [ "${_UVM_HOOK_VERSION}" != "$binary_version" ]; then
            printf 'uvm: shell hook %s is out of sync with binary %s — run: source %s\n' \
                "$_UVM_HOOK_VERSION" "$binary_version" "$(get_shell_rc_file 2>/dev/null || echo "$HOME/.zshrc")" >&2
        fi
        _UVM_HOOK_DRIFT_WARNED=1
        export _UVM_HOOK_DRIFT_WARNED
    fi

    # Re-detect only when the directory changed since the last run; auto-activation
    # only depends on the current $PWD, so re-scanning on every prompt is wasted
    # filesystem traversal that can stall the prompt on slow filesystems (NFS,
    # remote mounts) or in deep trees.
    if [ "${_UVM_LAST_PWD:-}" != "$PWD" ]; then
        _UVM_LAST_PWD="$PWD"
        uvm_detect_auto_activation_target
    fi

    if [ -n "${UVM_AUTO_TARGET_PATH:-}" ]; then
        if [ "${VIRTUAL_ENV:-}" != "$UVM_AUTO_TARGET_PATH" ]; then
            if [ -n "${VIRTUAL_ENV:-}" ] && command -v deactivate >/dev/null 2>&1; then
                deactivate >/dev/null 2>&1 || true
            fi

            activate_script=$(uvm_env_activate_script "$UVM_AUTO_TARGET_PATH") || return "$previous_status"
            # shellcheck source=/dev/null
            source "$activate_script" || return "$previous_status"
            export UVM_AUTO_ACTIVATED="${UVM_AUTO_TARGET_SOURCE}"
            export UVM_AUTO_ACTIVATED_PATH="$UVM_AUTO_TARGET_PATH"
            export UVM_AUTO_PROJECT_ROOT="$UVM_AUTO_TARGET_ROOT"
        fi
        return "$previous_status"
    fi

    if [ -n "${UVM_AUTO_ACTIVATED:-}" ] && [ -n "${VIRTUAL_ENV:-}" ]; then
        if command -v deactivate >/dev/null 2>&1; then
            deactivate >/dev/null 2>&1 || true
        fi
        unset UVM_AUTO_ACTIVATED
        unset UVM_AUTO_ACTIVATED_PATH
        unset UVM_AUTO_PROJECT_ROOT
    fi

    return "$previous_status"
}

uvm_shell_activate() {
    local env_name="$1"
    local env_path
    local activate_script

    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required"
        echo "Usage: uvm activate <env_name>"
        return 1
    fi

    env_path=$(_uvm_hook_get_env_path "$env_name") || {
        echo "Error: Environment '$env_name' not found"
        echo "Run 'uvm list' or 'uvm repair' to refresh metadata."
        return 1
    }

    activate_script=$(uvm_env_activate_script "$env_path") || {
        echo "Error: Activate script not found"
        return 1
    }

    # shellcheck source=/dev/null
    source "$activate_script"
    export UVM_ACTIVE_ENV="$env_name"
    unset UVM_AUTO_ACTIVATED
    unset UVM_AUTO_ACTIVATED_PATH
    unset UVM_AUTO_PROJECT_ROOT
    echo "Environment '$env_name' activated"
}

uvm_shell_deactivate() {
    if [ -n "${VIRTUAL_ENV:-}" ] && command -v deactivate >/dev/null 2>&1; then
        deactivate
        unset UVM_ACTIVE_ENV
        unset UVM_AUTO_ACTIVATED
        unset UVM_AUTO_ACTIVATED_PATH
        unset UVM_AUTO_PROJECT_ROOT
        echo "Environment deactivated"
        return 0
    fi

    echo "No active environment to deactivate"
}

uvm_setup_prompt_hook() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        if autoload -U add-zsh-hook >/dev/null 2>&1; then
            add-zsh-hook chpwd uvm_auto_activate
            add-zsh-hook precmd uvm_auto_activate
        else
            chpwd_functions+=("uvm_auto_activate")
            precmd_functions+=("uvm_auto_activate")
        fi
        return 0
    fi

    if [ -n "${BASH_VERSION:-}" ]; then
        if declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare -a'; then
            local hook
            for hook in "${PROMPT_COMMAND[@]}"; do
                [ "$hook" = "uvm_auto_activate" ] && return 0
            done
            PROMPT_COMMAND=("uvm_auto_activate" "${PROMPT_COMMAND[@]}")
            return 0
        fi
        case ";${PROMPT_COMMAND:-};" in
            *";uvm_auto_activate;"*)
                ;;
            *)
                # shellcheck disable=SC2128,SC2178 # This branch is only for scalar PROMPT_COMMAND.
                PROMPT_COMMAND="uvm_auto_activate${PROMPT_COMMAND:+;${PROMPT_COMMAND}}"
                ;;
        esac
    fi
}

uvm_generate_shell_hook() {
    cat <<EOF
# UVM shell hook
_UVM_HOOK_VERSION="$(command uvm version 2>/dev/null | grep -o '[0-9][^ ]*' | head -n 1)"
$(declare -f uvm_get_home)
$(declare -f uvm_get_config_file)
$(declare -f uvm_read_config_value)
$(declare -f uvm_get_default_envs_dir)
$(declare -f uvm_get_env_records_dir)
$(declare -f uvm_get_trusted_envs_file)
$(declare -f uvm_resolve_dir_path)
$(declare -f uvm_resolve_existing_path)
$(declare -f uvm_is_valid_env_name)
$(declare -f uvm_env_activate_script)
$(declare -f uvm_is_valid_uv_env)
$(declare -f uvm_is_local_env_trusted)
$(declare -f uvm_shell_load_runtime_config)
$(declare -f _uvm_hook_record_file_path)
$(declare -f _uvm_hook_get_env_path)
$(declare -f uvm_parent_dir)
$(declare -f uvm_find_upward_file)
$(declare -f uvm_find_upward_local_env)
$(declare -f uvm_find_upward_targets)
$(declare -f uvm_detect_auto_activation_target)
$(declare -f uvm_auto_activate)
$(declare -f uvm_shell_activate)
$(declare -f uvm_shell_deactivate)
$(declare -f uvm_setup_prompt_hook)

uvm() {
    if [ "\$1" = "activate" ]; then
        shift
        uvm_shell_activate "\$@"
    elif [ "\$1" = "deactivate" ]; then
        shift
        uvm_shell_deactivate "\$@"
    else
        command uvm "\$@"
    fi
}

uvm_setup_prompt_hook
uvm_auto_activate
EOF
}
