#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/uvm-config.sh
source "${SCRIPT_DIR}/uvm-config.sh"

uvm_shell_load_runtime_config() {
    export UVM_HOME="${UVM_HOME:-${HOME}/.config/uvm}"
    if [ -f "$(uvm_get_config_file)" ]; then
        # shellcheck source=/dev/null
        source "$(uvm_get_config_file)"
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

uvm_find_upward_file() {
    local file_name="$1"
    local current_dir="$PWD"
    local depth=0

    while [ -n "$current_dir" ] && [ "$current_dir" != "/" ] && [ "$depth" -lt 25 ]; do
        if [ -f "${current_dir}/${file_name}" ]; then
            printf '%s/%s\n' "$current_dir" "$file_name"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
        depth=$((depth + 1))
    done

    return 1
}

uvm_find_upward_local_env() {
    local current_dir="$PWD"
    local depth=0
    local local_env

    while [ -n "$current_dir" ] && [ "$current_dir" != "/" ] && [ "$depth" -lt 25 ]; do
        local_env="${current_dir}/.venv"
        if uvm_is_valid_uv_env "$local_env"; then
            echo "$local_env"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
        depth=$((depth + 1))
    done

    return 1
}

uvm_detect_auto_activation_target() {
    local local_env
    local uvmrc_file
    local env_name
    local env_path

    unset UVM_AUTO_TARGET_PATH UVM_AUTO_TARGET_SOURCE UVM_AUTO_TARGET_ROOT
    uvm_shell_load_runtime_config

    local_env=$(uvm_find_upward_local_env || true)
    if [ -n "$local_env" ]; then
        UVM_AUTO_TARGET_PATH="$local_env"
        UVM_AUTO_TARGET_SOURCE="local"
        UVM_AUTO_TARGET_ROOT="$(dirname "$local_env")"
        export UVM_AUTO_TARGET_PATH UVM_AUTO_TARGET_SOURCE UVM_AUTO_TARGET_ROOT
        return 0
    fi

    uvmrc_file=$(uvm_find_upward_file ".uvmrc" || true)
    if [ -n "$uvmrc_file" ]; then
        env_name=$(tr -d '[:space:]' < "$uvmrc_file" | head -n 1)
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
    local activate_script

    uvm_detect_auto_activation_target

    if [ -n "${UVM_AUTO_TARGET_PATH:-}" ]; then
        if [ "${VIRTUAL_ENV:-}" != "$UVM_AUTO_TARGET_PATH" ]; then
            if [ -n "${VIRTUAL_ENV:-}" ] && command -v deactivate >/dev/null 2>&1; then
                deactivate >/dev/null 2>&1 || true
            fi

            activate_script=$(uvm_env_activate_script "$UVM_AUTO_TARGET_PATH") || return 0
            # shellcheck source=/dev/null
            source "$activate_script"
            export UVM_AUTO_ACTIVATED="${UVM_AUTO_TARGET_SOURCE}"
            export UVM_AUTO_ACTIVATED_PATH="$UVM_AUTO_TARGET_PATH"
            export UVM_AUTO_PROJECT_ROOT="$UVM_AUTO_TARGET_ROOT"
        fi
        return 0
    fi

    if [ -n "${UVM_AUTO_ACTIVATED:-}" ] && [ -n "${VIRTUAL_ENV:-}" ]; then
        if command -v deactivate >/dev/null 2>&1; then
            deactivate >/dev/null 2>&1 || true
        fi
        unset UVM_AUTO_ACTIVATED
        unset UVM_AUTO_ACTIVATED_PATH
        unset UVM_AUTO_PROJECT_ROOT
    fi
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
        case ";${PROMPT_COMMAND:-};" in
            *";uvm_auto_activate;"*)
                ;;
            *)
                PROMPT_COMMAND="uvm_auto_activate${PROMPT_COMMAND:+;${PROMPT_COMMAND}}"
                ;;
        esac
    fi
}

uvm_generate_shell_hook() {
    cat <<EOF
# UVM shell hook
$(declare -f uvm_get_home)
$(declare -f uvm_get_config_file)
$(declare -f uvm_get_default_envs_dir)
$(declare -f uvm_get_env_records_dir)
$(declare -f uvm_is_valid_env_name)
$(declare -f uvm_env_activate_script)
$(declare -f uvm_is_valid_uv_env)
$(declare -f uvm_shell_load_runtime_config)
$(declare -f _uvm_hook_record_file_path)
$(declare -f _uvm_hook_get_env_path)
$(declare -f uvm_find_upward_file)
$(declare -f uvm_find_upward_local_env)
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
