#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/uvm-config.sh
source "${SCRIPT_DIR}/uvm-config.sh"

# Color output — only when stdout is a real terminal.
if [ -t 1 ]; then
    _UVM_RESET='\033[0m'
    _UVM_BOLD='\033[1m'
    _UVM_GREEN='\033[0;32m'
    _UVM_YELLOW='\033[1;33m'
    _UVM_BLUE='\033[0;34m'
    _UVM_CYAN='\033[0;36m'
    _UVM_DIM='\033[2m'
else
    _UVM_RESET=''
    _UVM_BOLD=''
    _UVM_GREEN=''
    _UVM_YELLOW=''
    _UVM_BLUE=''
    _UVM_CYAN=''
    _UVM_DIM=''
fi

uvm_cleanup_created_env() {
    local env_name="$1"
    local env_path="$2"
    local default_root

    remove_env_record "$env_name" >/dev/null 2>&1 || true
    [ -e "$env_path" ] || return 0
    default_root=$(uvm_get_default_envs_dir)
    [ -d "$default_root" ] || return 1
    if uvm_path_is_within "$default_root" "$env_path" && [ "$(basename "$env_path")" = "$env_name" ]; then
        rm -rf "$env_path"
        return $?
    fi
    echo "Warning: Partial environment was not removed because it is outside the managed root: ${env_path}" >&2
    return 1
}

uvm_env_is_safe_delete_target() {
    local env_name="$1"
    local env_path="$2"
    local default_root
    local resolved_default
    local resolved_path

    if uvm_load_env_record "$env_name" && [ "${UVM_RECORD_PATH}" = "$env_path" ]; then
        return 0
    fi

    default_root=$(uvm_get_default_envs_dir)
    resolved_default=$(uvm_resolve_existing_path "$default_root") || return 1
    resolved_path=$(uvm_resolve_existing_path "$env_path") || return 1

    case "${resolved_path}/" in
        "${resolved_default}/"*)
            [ "$(basename "$resolved_path")" = "$env_name" ]
            return $?
            ;;
        *)
            return 1
            ;;
    esac
}

uvm_create() {
    local env_name=""
    local python_version=""
    local custom_path=""
    local env_path=""
    local actual_python_version=""
    local existing_env_path=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --python)
                if [ $# -lt 2 ] || [ -z "$2" ]; then
                    echo "Error: --python requires a value"
                    return 1
                fi
                python_version="$2"
                shift 2
                ;;
            --path)
                if [ $# -lt 2 ] || [ -z "$2" ]; then
                    echo "Error: --path requires a value"
                    return 1
                fi
                custom_path="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option: $1"
                return 1
                ;;
            *)
                if [ -z "$env_name" ]; then
                    env_name="$1"
                else
                    echo "Error: Too many arguments"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required"
        echo "Usage: uvm create <env_name> [--python VERSION] [--path PATH]"
        return 1
    fi

    if ! uvm_is_valid_env_name "$env_name"; then
        echo "Error: Invalid environment name"
        echo "Allowed characters: letters, numbers, dot, underscore, hyphen"
        return 1
    fi

    if ! command -v uv >/dev/null 2>&1; then
        echo "Error: 'uv' is not installed."
        echo "Run 'uvm repair' after installing uv to refresh the setup."
        return 1
    fi

    init_uvm_config || return 1
    existing_env_path=$(get_env_path "$env_name" 2>/dev/null || true)
    if [ -n "$existing_env_path" ]; then
        echo "Error: Environment '${env_name}' is already managed at: ${existing_env_path}"
        return 1
    fi

    if [ -n "$custom_path" ]; then
        if uvm_value_has_line_break "$custom_path"; then
            echo "Error: Environment paths cannot contain line breaks"
            return 1
        fi
        mkdir -p "$(dirname "$custom_path")" || return 1
        env_path=$(uvm_resolve_target_path "$custom_path") || {
            echo "Error: Could not resolve environment path: ${custom_path}"
            return 1
        }
    else
        mkdir -p "$(uvm_get_default_envs_dir)" || return 1
        env_path=$(uvm_resolve_target_path "$(uvm_get_default_envs_dir)/${env_name}") || return 1
    fi

    if [ -e "$env_path" ]; then
        echo "Error: Environment '${env_name}' already exists at: ${env_path}"
        return 1
    fi

    echo "Creating environment '${env_name}'..."
    if [ -n "$python_version" ]; then
        echo "  Python version: ${python_version}"
        uv venv "$env_path" --python "$python_version" || return 1
    else
        uv venv "$env_path" || return 1
    fi

    actual_python_version=$(get_env_python_version "$env_path")
    if ! add_env_record "$env_name" "$env_path" "$actual_python_version"; then
        echo "Error: Failed to register environment; removing the newly created directory" >&2
        rm -rf "$env_path"
        return 1
    fi

    echo "Environment '${env_name}' created successfully"
    echo "  Location: ${env_path}"
    echo "  Python: ${actual_python_version}"
    echo ""

    local shell_rc
    shell_rc=$(get_shell_rc_file)

    if [ -n "${VIRTUAL_ENV:-}${UVM_ACTIVE_ENV:-}" ]; then
        # Shell integration is active in this session
        echo "To activate: uvm activate ${env_name}"
    elif uvm_is_shell_hook_configured "$shell_rc"; then
        # Hook is written but this session predates it; user needs to reload
        echo "Shell integration is installed. To activate:"
        echo "  source ${shell_rc}"
        echo "  uvm activate ${env_name}"
    else
        # Hook not configured yet
        echo "Shell integration is not set up yet. To activate:"
        echo "  uvm repair"
        echo "  source ${shell_rc}"
        echo "  uvm activate ${env_name}"
    fi
}

uvm_run() {
    local env_name="$1"
    shift


    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required"
        echo "Usage: uvm run <env_name> <command> [args...]"
        return 1
    fi

    if [ $# -eq 0 ]; then
        echo "Error: Command is required"
        echo "Usage: uvm run <env_name> <command> [args...]"
        return 1
    fi

    local env_path
    env_path=$(get_env_path "$env_name") || {
        echo "Error: Environment '${env_name}' not found"
        echo "Run 'uvm list' to see available environments."
        return 1
    }

    local activate_script
    activate_script=$(uvm_env_activate_script "$env_path") || {
        echo "Error: Activate script not found in: ${env_path}"
        return 1
    }

    # Execute in a subshell so the caller's environment is never modified.
    (
        # shellcheck source=/dev/null
        source "$activate_script"
        exec "$@"
    )
}

uvm_rename() {
    if [ "$#" -ne 2 ]; then
        echo "Error: Exactly two environment names are required"
        echo "Usage: uvm rename <old_name> <new_name>"
        return 1
    fi
    local old_name="$1"
    local new_name="$2"

    if [ -z "$old_name" ] || [ -z "$new_name" ]; then
        echo "Error: Both old and new names are required"
        echo "Usage: uvm rename <old_name> <new_name>"
        return 1
    fi

    if ! uvm_is_valid_env_name "$old_name" || ! uvm_is_valid_env_name "$new_name"; then
        echo "Error: Invalid environment name"
        echo "Allowed characters: letters, numbers, dot, underscore, hyphen"
        return 1
    fi

    local old_path
    old_path=$(get_env_path "$old_name") || {
        echo "Error: Environment '${old_name}' not found"
        return 1
    }

    if [ "${VIRTUAL_ENV:-}" = "$old_path" ]; then
        echo "Error: Cannot rename the active environment. Run 'uvm deactivate' first."
        return 1
    fi

    # Check the target name is not already taken
    if get_env_path "$new_name" >/dev/null 2>&1; then
        echo "Error: Environment '${new_name}' already exists"
        return 1
    fi

    rename_env_record "$old_name" "$new_name" || {
        echo "Error: Failed to rename environment metadata"
        return 1
    }

    echo "Environment '${old_name}' renamed to '${new_name}'"
    echo "  Location unchanged: ${old_path}"

    # Warn the user about any .uvmrc files that still reference the old name,
    # since those will now silently fail to activate.
    local uvmrc_hits
    uvmrc_hits=$(grep -rIl --exclude-dir=.git --exclude-dir=node_modules \
        -F "${old_name}" . 2>/dev/null | grep -F '.uvmrc' || true)
    if [ -n "$uvmrc_hits" ]; then
        echo ""
        # shellcheck disable=SC2059
        printf "${_UVM_YELLOW}Warning: .uvmrc files still reference '${old_name}':${_UVM_RESET}\n" >&2
        printf '%s\n' "$uvmrc_hits" | sed 's/^/  /' >&2
        echo "  Update them to '${new_name}' to keep auto-activation working." >&2
    fi
    return 0
}

uvm_clone() {
    if [ "$#" -ne 2 ]; then
        echo "Error: Exactly two environment names are required"
        echo "Usage: uvm clone <src_name> <dst_name>"
        return 1
    fi
    local src_name="$1"
    local dst_name="$2"

    if [ -z "$src_name" ] || [ -z "$dst_name" ]; then
        echo "Error: Source and destination names are required"
        echo "Usage: uvm clone <src_name> <dst_name>"
        return 1
    fi

    if ! uvm_is_valid_env_name "$src_name" || ! uvm_is_valid_env_name "$dst_name"; then
        echo "Error: Invalid environment name"
        echo "Allowed characters: letters, numbers, dot, underscore, hyphen"
        return 1
    fi

    local src_path
    src_path=$(get_env_path "$src_name") || {
        echo "Error: Source environment '${src_name}' not found"
        return 1
    }

    if get_env_path "$dst_name" >/dev/null 2>&1; then
        echo "Error: Environment '${dst_name}' already exists"
        return 1
    fi

    local python_version
    python_version=$(get_env_python_version "$src_path")

    local src_python
    src_python=$(uvm_env_python_binary "$src_path") || {
        echo "Error: Python binary not found in source environment"
        return 1
    }

    local requirements_file
    requirements_file=$(mktemp "${TMPDIR:-/tmp}/uvm-clone.XXXXXX.txt") || return 1
    if ! uv pip freeze --python "$src_python" > "$requirements_file"; then
        rm -f "$requirements_file"
        echo "Error: Failed to inspect packages in '${src_name}'"
        return 1
    fi

    local dst_path
    mkdir -p "$(uvm_get_default_envs_dir)" || return 1
    dst_path=$(uvm_resolve_target_path "$(uvm_get_default_envs_dir)/${dst_name}") || {
        rm -f "$requirements_file"
        return 1
    }
    if [ -e "$dst_path" ]; then
        rm -f "$requirements_file"
        echo "Error: Destination path already exists: ${dst_path}"
        return 1
    fi

    echo "Cloning '${src_name}' -> '${dst_name}'..."
    echo "  Python: ${python_version}"

    if [ -n "$python_version" ] && [ "$python_version" != "unknown" ]; then
        uv venv "$dst_path" --python "$python_version" || {
            rm -f "$requirements_file"
            return 1
        }
    else
        uv venv "$dst_path" || {
            rm -f "$requirements_file"
            return 1
        }
    fi

    if [ -s "$requirements_file" ]; then
        local dst_python
        dst_python=$(uvm_env_python_binary "$dst_path") || {
            rm -f "$requirements_file"
            uvm_cleanup_created_env "$dst_name" "$dst_path" || true
            return 1
        }
        echo "  Copying installed packages..."
        if ! uv pip install --python "$dst_python" -r "$requirements_file"; then
            rm -f "$requirements_file"
            uvm_cleanup_created_env "$dst_name" "$dst_path" || true
            echo "Error: Failed to install cloned packages"
            return 1
        fi
    fi
    rm -f "$requirements_file"

    local actual_python
    actual_python=$(get_env_python_version "$dst_path")
    if ! add_env_record "$dst_name" "$dst_path" "$actual_python"; then
        uvm_cleanup_created_env "$dst_name" "$dst_path" || true
        echo "Error: Failed to register cloned environment" >&2
        return 1
    fi

    echo "Environment '${dst_name}' cloned from '${src_name}'"
    echo "  Location: ${dst_path}"
    echo "  Python: ${actual_python}"
}

uvm_export() {
    if [ "$#" -ne 1 ]; then
        echo "Error: Exactly one environment name is required" >&2
        echo "Usage: uvm export <env_name>" >&2
        return 1
    fi
    local env_name="$1"

    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required" >&2
        echo "Usage: uvm export <env_name>" >&2
        return 1
    fi

    local env_path
    env_path=$(get_env_path "$env_name") || {
        echo "Error: Environment '${env_name}' not found" >&2
        return 1
    }

    local python_bin
    python_bin=$(uvm_env_python_binary "$env_path") || {
        echo "Error: Python binary not found in: ${env_path}" >&2
        uvm_cleanup_created_env "$env_name" "$env_path" || true
        return 1
    }

    uv pip freeze --python "$python_bin"
}

uvm_import() {
    local env_name=""
    local from_file=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --from)
                if [ $# -lt 2 ] || [ -z "$2" ]; then
                    echo "Error: --from requires a value"
                    return 1
                fi
                from_file="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option: $1"
                return 1
                ;;
            *)
                if [ -z "$env_name" ]; then
                    env_name="$1"
                else
                    echo "Error: Too many arguments"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$env_name" ] || [ -z "$from_file" ]; then
        echo "Error: Usage: uvm import <env_name> --from <requirements.txt>"
        return 1
    fi

    if [ ! -f "$from_file" ]; then
        echo "Error: Requirements file not found: ${from_file}"
        return 1
    fi

    uvm_create "$env_name" || return 1

    local env_path
    env_path=$(get_env_path "$env_name") || return 1

    local python_bin
    python_bin=$(uvm_env_python_binary "$env_path") || {
        echo "Error: Python binary not found in: ${env_path}" >&2
        return 1
    }

    echo "Installing packages from ${from_file}..."
    if ! uv pip install --python "$python_bin" -r "$from_file"; then
        echo "Error: Import failed; removing the newly created environment" >&2
        uvm_cleanup_created_env "$env_name" "$env_path" || true
        return 1
    fi
    echo "Import complete"
}

uvm_activate() {
    local env_name="$1"
    local env_path
    local activate_script

    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required"
        echo "Usage: uvm activate <env_name>"
        return 1
    fi

    env_path=$(get_env_path "$env_name") || {
        echo "Error: Environment '${env_name}' not found"
        echo "Run 'uvm list' to inspect known environments or 'uvm repair' to rebuild metadata."
        return 1
    }

    activate_script=$(uvm_env_activate_script "$env_path") || {
        echo "Error: Activate script not found in: ${env_path}"
        return 1
    }

    # shellcheck source=/dev/null
    source "$activate_script"
    export UVM_ACTIVE_ENV="$env_name"
    echo "Environment '${env_name}' activated"
}

uvm_deactivate() {
    if [ -z "${VIRTUAL_ENV:-}" ]; then
        echo "No active environment to deactivate"
        return 0
    fi

    if command -v deactivate >/dev/null 2>&1; then
        deactivate
        unset UVM_ACTIVE_ENV
        unset UVM_AUTO_ACTIVATED
        unset UVM_AUTO_ACTIVATED_PATH
        unset UVM_AUTO_PROJECT_ROOT
        echo "Environment deactivated"
        return 0
    fi

    echo "Error: deactivate command not found"
    return 1
}

uvm_delete() {
    local env_name=""
    local force=false
    local env_path
    local response

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|--force)
                force=true
                shift
                ;;
            -*)
                echo "Error: Unknown option: $1"
                return 1
                ;;
            *)
                if [ -z "$env_name" ]; then
                    env_name="$1"
                else
                    echo "Error: Too many arguments"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required"
        echo "Usage: uvm delete <env_name> [-f|--force]"
        return 1
    fi

    if ! uvm_is_valid_env_name "$env_name"; then
        echo "Error: Invalid environment name"
        return 1
    fi

    env_path=$(get_env_path "$env_name") || {
        echo "Error: Environment '${env_name}' not found"
        echo "Run 'uvm list' or 'uvm repair' to refresh managed environments."
        return 1
    }

    if [ "${VIRTUAL_ENV:-}" = "$env_path" ]; then
        echo "Error: Cannot delete the active environment. Run 'uvm deactivate' first."
        return 1
    fi

    if ! uvm_env_is_safe_delete_target "$env_name" "$env_path"; then
        echo "Error: Refusing to delete unmanaged path: ${env_path}"
        return 1
    fi

    if [ "$force" = false ]; then
        printf "Delete '%s' at '%s'? (y/N): " "$env_name" "$env_path"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Deletion cancelled"
            return 0
        fi
    fi

    rm -rf "$env_path" || {
        echo "Error: Failed to delete environment directory"
        return 1
    }
    remove_env_record "$env_name" || return 1
    # Remove any trust entry for this path so a future venv at the same location
    # is not silently auto-activated without explicit re-trust.
    uvm_untrust_local_env "$env_path" 2>/dev/null || true

    echo "Environment '${env_name}' deleted successfully"
}

uvm_self_update() {
    local channel="latest"
    local target_given=false
    local check_only=false
    local install_url
    local current_version="${UVM_VERSION#v}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --check)
                check_only=true
                ;;
            -*)
                echo "Error: Unknown option: $1"
                echo "Usage: uvm update [--check] [v<version>]"
                return 1
                ;;
            *)
                if [ "$target_given" = true ]; then
                    echo "Error: Usage: uvm update [--check] [v<version>]"
                    return 1
                fi
                channel="$1"
                target_given=true
                ;;
        esac
        shift
    done

    if [ "$channel" != "latest" ] && [[ ! "$channel" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
        echo "Error: Update target must be 'latest' or a version tag such as v1.2.3"
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        echo "Error: curl or wget is required for uvm update"
        return 1
    fi

    if [ "$channel" = "latest" ]; then
        install_url="https://github.com/Tendo33/uvm/releases/latest/download/install.sh"
    else
        install_url="https://raw.githubusercontent.com/Tendo33/uvm/${channel}/install.sh"
    fi

    if [ "$check_only" = true ]; then
        # For latest channel use the GitHub releases API — much lighter than
        # downloading the full installer just to read one version string.
        local downloaded_version
        if [ "$channel" = "latest" ]; then
            local api_url="https://api.github.com/repos/Tendo33/uvm/releases/latest"
            local api_response
            if command -v curl >/dev/null 2>&1; then
                api_response=$(curl -fsSL "$api_url" 2>/dev/null) || {
                    echo "Error: Failed to reach GitHub API"
                    return 1
                }
            else
                api_response=$(wget -qO- "$api_url" 2>/dev/null) || {
                    echo "Error: Failed to reach GitHub API"
                    return 1
                }
            fi
            downloaded_version=$(printf '%s' "$api_response" \
                | grep '"tag_name"' \
                | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/')
            if [ -z "$downloaded_version" ]; then
                echo "Error: Could not parse version from GitHub API response"
                return 1
            fi
        else
            # Specific version target: download installer to confirm it exists.
            local tmp_install
            tmp_install=$(mktemp "${TMPDIR:-/tmp}/uvm-check.XXXXXX.sh") || return 1
            local check_url="https://raw.githubusercontent.com/Tendo33/uvm/${channel}/install.sh"
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$check_url" -o "$tmp_install" 2>/dev/null || {
                    rm -f "$tmp_install"
                    echo "Error: Version '${channel}' not found"
                    return 1
                }
            else
                wget -qO "$tmp_install" "$check_url" 2>/dev/null || {
                    rm -f "$tmp_install"
                    echo "Error: Version '${channel}' not found"
                    return 1
                }
            fi
            downloaded_version=$(sed -n 's/^UVM_INSTALL_VERSION="\([^"]*\)"/\1/p' "$tmp_install" | head -n 1)
            rm -f "$tmp_install"
            if [ -z "$downloaded_version" ]; then
                echo "Error: Could not parse version from installer"
                return 1
            fi
        fi

        echo "Installed : ${current_version:-unknown}"
        echo "Available : ${downloaded_version}"
        if [ "$downloaded_version" = "$current_version" ]; then
            echo "uvm is up to date"
        elif [ -z "$current_version" ] || uvm_version_is_at_least "$downloaded_version" "$current_version"; then
            echo "Update available. Run: uvm update"
        else
            echo "The available release is older than the installed version"
        fi
        return 0
    fi

    if [ "$channel" = "latest" ]; then
        install_url="https://github.com/Tendo33/uvm/releases/latest/download/install.sh"
    else
        install_url="https://raw.githubusercontent.com/Tendo33/uvm/${channel}/install.sh"
    fi

    echo "Updating uvm from ${install_url}..."
    local tmp_install
    tmp_install=$(mktemp "${TMPDIR:-/tmp}/uvm-update.XXXXXX.sh") || return 1

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$install_url" -o "$tmp_install" || {
            rm -f "$tmp_install"
            echo "Error: Failed to download installer"
            return 1
        }
    else
        wget -qO "$tmp_install" "$install_url" || {
            rm -f "$tmp_install"
            echo "Error: Failed to download installer"
            return 1
        }
    fi

    local downloaded_version
    downloaded_version=$(sed -n 's/^UVM_INSTALL_VERSION="\([^"]*\)"/\1/p' "$tmp_install" | head -n 1)
    if [ -z "$downloaded_version" ]; then
        rm -f "$tmp_install"
        echo "Error: Downloaded installer does not declare a version"
        return 1
    fi
    if [[ ! "$downloaded_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
        rm -f "$tmp_install"
        echo "Error: Downloaded installer declares an invalid version"
        return 1
    fi
    if [ "$check_only" = true ]; then
        rm -f "$tmp_install"
        echo "Installed: ${current_version:-unknown}"
        echo "Available: ${downloaded_version}"
        if [ "$downloaded_version" = "$current_version" ]; then
            echo "uvm is up to date"
        elif [ -z "$current_version" ] || uvm_version_is_at_least "$downloaded_version" "$current_version"; then
            echo "Update available. Run: uvm update"
        else
            echo "The available release is older than the installed version"
        fi
        return 0
    fi

    if [ -n "$current_version" ] && ! uvm_version_is_at_least "$downloaded_version" "$current_version"; then
        rm -f "$tmp_install"
        echo "Error: Refusing to downgrade uvm ${current_version} to ${downloaded_version}"
        return 1
    fi

    if [ "$target_given" = false ] && [ "$downloaded_version" = "$current_version" ]; then
        rm -f "$tmp_install"
        echo "uvm ${current_version} is already up to date"
        echo "  To reinstall it anyway, run: uvm update v${current_version}"
        return 0
    fi

    local -a installer_args=(-y --envs-dir "$(uvm_get_default_envs_dir)")
    # Respect users who installed without auto-activation.
    if ! uvm_is_shell_hook_configured "$(get_shell_rc_file)"; then
        installer_args+=(--no-shell-hook)
    fi

    UVM_HOME="$(uvm_get_home)" UVM_ENVS_DIR="$(uvm_get_default_envs_dir)" \
        bash "$tmp_install" "${installer_args[@]}"
    local update_status=$?
    rm -f "$tmp_install"
    if [ "$update_status" -eq 0 ]; then
        echo ""
        echo "uvm updated to ${downloaded_version}"
        echo "  Restart your shell to load it: exec \"\$SHELL\""
    fi
    return "$update_status"
}

uvm_config_usage() {
    cat <<'EOF'
Usage:
  uvm config show
  uvm config get envs-dir
  uvm config set envs-dir <path>
  uvm config mirror        <show | set <url> | remove>    PyPI package index
  uvm config python-mirror <show | set <url> | remove>    Python interpreter downloads
EOF
}

uvm_config_set_envs_dir() {
    local envs_dir="$1"
    local registered_count

    if [ -z "$envs_dir" ]; then
        uvm_config_usage
        return 1
    fi
    mkdir -p "$envs_dir" || return 1
    envs_dir=$(uvm_resolve_existing_path "$envs_dir") || return 1

    uvm_write_config_value UVM_ENVS_DIR "$envs_dir" || return 1
    export UVM_ENVS_DIR="$envs_dir"
    init_uvm_config || return 1
    registered_count=$(scan_and_register_envs "$envs_dir")

    echo "Environment directory set to: ${envs_dir}"
    echo "  Registered ${registered_count} environment(s) found there"
    echo "  Existing environments stay where they are and remain registered."
}

uvm_config_show() {
    local pypi_mirror
    local python_mirror

    pypi_mirror=$(uvm_get_pypi_mirror_url) || pypi_mirror="not set"
    python_mirror=$(uvm_get_python_mirror_url) || python_mirror="not set"

    echo "uvm configuration"
    echo "  uvm version       : ${UVM_VERSION:-unknown}"
    echo "  UVM_HOME          : $(uvm_get_home)"
    echo "  Config file       : $(uvm_get_config_file)"
    echo "  envs-dir          : $(uvm_get_default_envs_dir)"
    echo "  Metadata directory: $(uvm_get_env_records_dir)"
    echo "  Shell             : $(detect_shell)"
    echo "  Shell RC          : $(get_shell_rc_file)"
    echo "  uv config file    : $(uvm_get_uv_config_file)"
    echo "  PyPI mirror       : ${pypi_mirror}"
    echo "  Python mirror     : ${python_mirror}"
    if [ -n "${UV_DEFAULT_INDEX:-}${UV_INDEX_URL:-}" ]; then
        echo "  Note: UV_DEFAULT_INDEX / UV_INDEX_URL is set and overrides the PyPI mirror"
    fi
    if [ -n "${UV_PYTHON_INSTALL_MIRROR:-}" ]; then
        echo "  Note: UV_PYTHON_INSTALL_MIRROR is set and overrides the Python mirror"
    fi
}

# kind: "pypi" or "python"
uvm_config_mirror_command() {
    local kind="$1"
    local action="${2:-show}"
    local label="mirror"
    local title="PyPI mirror"
    local example="https://pypi.tuna.tsinghua.edu.cn/simple"
    local start_marker
    local end_marker
    local url

    shift
    [ $# -gt 0 ] && shift
    if [ "$kind" = "python" ]; then
        label="python-mirror"
        title="Python mirror"
        example="https://mirror.nju.edu.cn/github-release/astral-sh/python-build-standalone"
        start_marker=$(uvm_get_python_mirror_start_marker)
        end_marker=$(uvm_get_python_mirror_end_marker)
    else
        start_marker=$(uvm_get_mirror_start_marker)
        end_marker=$(uvm_get_mirror_end_marker)
    fi

    case "$action" in
        set)
            if [ $# -ne 1 ] || [ -z "$1" ]; then
                echo "Usage: uvm config ${label} set <url>"
                echo "Example: uvm config ${label} set ${example}"
                return 1
            fi
            if [ "$kind" = "python" ]; then
                setup_uv_python_mirror "$1" || return 1
            else
                setup_uv_mirror "$1" || return 1
            fi
            echo "${title} set to: $1"
            echo "  Written to: $(uvm_get_uv_config_file)"
            ;;
        remove)
            if [ $# -ne 0 ]; then
                echo "Usage: uvm config ${label} remove"
                return 1
            fi
            uvm_remove_managed_block "$(uvm_get_uv_config_file)" "$start_marker" "$end_marker" || return 1
            if [ "$kind" = "pypi" ]; then
                uvm_remove_stale_mirror_config || return 1
            fi
            echo "${title} removed from $(uvm_get_uv_config_file)"
            ;;
        show)
            if [ $# -ne 0 ]; then
                echo "Usage: uvm config ${label} show"
                return 1
            fi
            if [ "$kind" = "python" ]; then
                url=$(uvm_get_python_mirror_url)
            else
                url=$(uvm_get_pypi_mirror_url)
            fi
            if [ -n "$url" ]; then
                echo "${title}: ${url}"
                echo "  Configured in: $(uvm_get_uv_config_file)"
            else
                echo "No managed ${title} configured"
                echo "  To add: uvm config ${label} set <url>"
                echo "  Example: uvm config ${label} set ${example}"
            fi
            ;;
        *)
            echo "Usage: uvm config ${label} <show | set <url> | remove>"
            return 1
            ;;
    esac
}

uvm_config_command() {
    local subcommand="${1:-show}"
    shift || true

    case "$subcommand" in
        show)
            uvm_config_show
            ;;
        get)
            case "${1:-}" in
                envs-dir)
                    [ $# -eq 1 ] || { uvm_config_usage; return 1; }
                    uvm_get_default_envs_dir
                    ;;
                *)
                    echo "Error: Unknown config key: ${1:-}. Supported keys: envs-dir"
                    return 1
                    ;;
            esac
            ;;
        set)
            case "${1:-}" in
                envs-dir)
                    [ $# -eq 2 ] || { uvm_config_usage; return 1; }
                    uvm_config_set_envs_dir "$2"
                    ;;
                *)
                    echo "Error: Unknown config key: ${1:-}. Supported keys: envs-dir"
                    return 1
                    ;;
            esac
            ;;
        mirror|mirrors)
            uvm_config_mirror_command pypi "$@"
            ;;
        python-mirror)
            uvm_config_mirror_command python "$@"
            ;;
        *)
            uvm_config_usage
            return 1
            ;;
    esac
}

uvm_print_env_entry() {
    local env_name="$1"
    local env_path="$2"
    local python_version="$3"
    local source_label="$4"
    # col_width is optional (5th arg); defaults to 20 for callers that don't pass it
    local col_width="${5:-20}"
    local marker="  "
    local name_fmt

    name_fmt="%-${col_width}s"

    if [ "${VIRTUAL_ENV:-}" = "$env_path" ]; then
        # Green bold name + arrow marker for active environment
        # shellcheck disable=SC2059
        printf "${_UVM_GREEN}${_UVM_BOLD}* ${name_fmt}${_UVM_RESET}" "$env_name"
    else
        # shellcheck disable=SC2059
        printf "${_UVM_DIM}${marker}${_UVM_RESET}${name_fmt}" "$env_name"
    fi

    # shellcheck disable=SC2059
    printf "  ${_UVM_CYAN}Python %-9s${_UVM_RESET}" "${python_version:-unknown}"

    if [ "${UVM_LIST_SHOW_ALL:-false}" = true ]; then
        # shellcheck disable=SC2059
        printf "  ${_UVM_DIM}%-11s${_UVM_RESET}" "$source_label"
    fi

    # shellcheck disable=SC2059
    printf "  ${_UVM_DIM}%s${_UVM_RESET}\n" "$env_path"
}

uvm_list() {
    local seen_names=""
    local env_name
    local env_path
    local env_dir
    local json_mode=false
    # Collect entries for two-pass column-width calculation
    local -a _entry_names=()
    local -a _entry_paths=()
    local -a _entry_pythons=()
    local -a _entry_sources=()
    local col_width=0
    local name_len

    UVM_LIST_SHOW_ALL=false
    while [ $# -gt 0 ]; do
        case "$1" in
            -a|--all)
                UVM_LIST_SHOW_ALL=true
                shift
                ;;
            --json)
                json_mode=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1"
                return 1
                ;;
        esac
    done

    init_uvm_config || return 1

    if [ "$json_mode" = true ]; then
        _uvm_list_json
        return $?
    fi

    # --- Pass 1: collect all valid entries ---
    for env_name in $(uvm_list_record_names); do
        if uvm_load_env_record "$env_name" && uvm_is_valid_uv_env "$UVM_RECORD_PATH"; then
            _entry_names+=("$env_name")
            _entry_paths+=("$UVM_RECORD_PATH")
            _entry_pythons+=("${UVM_RECORD_PYTHON:-unknown}")
            _entry_sources+=("managed")
            seen_names="${seen_names}
${env_name}"
        fi
    done

    if [ -d "$(uvm_get_default_envs_dir)" ]; then
        for env_dir in "$(uvm_get_default_envs_dir)"/*; do
            [ -d "$env_dir" ] || continue
            env_name=$(basename "$env_dir")
            if printf '%s\n' "$seen_names" | grep -Fxq "$env_name"; then
                continue
            fi
            if ! uvm_is_valid_env_name "$env_name"; then
                continue
            fi
            if uvm_is_valid_uv_env "$env_dir"; then
                _entry_names+=("$env_name")
                _entry_paths+=("$env_dir")
                _entry_pythons+=("$(get_env_python_version "$env_dir")")
                _entry_sources+=("discovered")
                seen_names="${seen_names}
${env_name}"
            fi
        done
    fi

    # --- Pass 2: compute column width from longest name ---
    local i=0
    while [ "$i" -lt "${#_entry_names[@]}" ]; do
        name_len="${#_entry_names[$i]}"
        [ "$name_len" -gt "$col_width" ] && col_width="$name_len"
        i=$((i + 1))
    done
    # Minimum width of 16; add 2 for padding
    [ "$col_width" -lt 16 ] && col_width=16
    col_width=$((col_width + 2))

    # --- Output ---
    # shellcheck disable=SC2059
    printf "${_UVM_BOLD}Available environments:${_UVM_RESET}\n\n"

    if [ "${#_entry_names[@]}" -eq 0 ]; then
        echo "  No environments found"
        echo ""
        echo "Create one with: uvm create <env_name>"
    else
        i=0
        while [ "$i" -lt "${#_entry_names[@]}" ]; do
            uvm_print_env_entry \
                "${_entry_names[$i]}" \
                "${_entry_paths[$i]}" \
                "${_entry_pythons[$i]}" \
                "${_entry_sources[$i]}" \
                "$col_width"
            i=$((i + 1))
        done
    fi

    echo ""
}

_uvm_list_json() {
    local first=true
    local env_name
    local env_path
    local env_dir
    local seen_names=""
    local active

    printf '[\n'

    for env_name in $(uvm_list_record_names); do
        if uvm_load_env_record "$env_name" && uvm_is_valid_uv_env "$UVM_RECORD_PATH"; then
            env_path="$UVM_RECORD_PATH"
            active="false"
            [ "${VIRTUAL_ENV:-}" = "$env_path" ] && active="true"
            [ "$first" = true ] || printf ',\n'
            first=false
            printf '  {"name":"%s","path":"%s","python":"%s","active":%s,"source":"managed"}' \
                "$(uvm_json_escape "$env_name")" \
                "$(uvm_json_escape "$env_path")" \
                "$(uvm_json_escape "${UVM_RECORD_PYTHON:-unknown}")" \
                "$active"
            seen_names="${seen_names}
${env_name}"
        fi
    done

    if [ -d "$(uvm_get_default_envs_dir)" ]; then
        for env_dir in "$(uvm_get_default_envs_dir)"/*; do
            [ -d "$env_dir" ] || continue
            env_name=$(basename "$env_dir")
            if printf '%s\n' "$seen_names" | grep -Fxq "$env_name"; then
                continue
            fi
            if ! uvm_is_valid_env_name "$env_name"; then
                continue
            fi
            if uvm_is_valid_uv_env "$env_dir"; then
                local py_ver
                py_ver=$(get_env_python_version "$env_dir")
                active="false"
                [ "${VIRTUAL_ENV:-}" = "$env_dir" ] && active="true"
                [ "$first" = true ] || printf ',\n'
                first=false
                printf '  {"name":"%s","path":"%s","python":"%s","active":%s,"source":"discovered"}' \
                    "$(uvm_json_escape "$env_name")" \
                    "$(uvm_json_escape "$env_dir")" \
                    "$(uvm_json_escape "$py_ver")" \
                    "$active"
                seen_names="${seen_names}
${env_name}"
            fi
        done
    fi

    printf '\n]\n'
}

uvm_doctor() {
    local shell_rc
    local hook_status="missing"
    local uv_status="missing"
    local path_status="missing"
    local mirror_status="missing"
    local stale_mirror_file

    init_uvm_config || return 1
    shell_rc=$(get_shell_rc_file)

    if uvm_is_shell_hook_configured "$shell_rc"; then
        hook_status="configured"
    fi

    if command -v uv >/dev/null 2>&1; then
        uv_status="$(uv --version 2>&1 | head -n 1)"
    fi

    case ":${PATH}:" in
        *":${HOME}/.local/bin:"*)
            path_status="present"
            ;;
        *)
            path_status="missing"
            ;;
    esac

    if uvm_file_contains_managed_block \
        "$(uvm_get_uv_config_file)" \
        "$(uvm_get_mirror_start_marker)" \
        "$(uvm_get_mirror_end_marker)"; then
        mirror_status="configured"
    fi

    local ok="${_UVM_GREEN}OK${_UVM_RESET}"
    local warn="${_UVM_YELLOW}WARN${_UVM_RESET}"
    local info="${_UVM_BLUE}--${_UVM_RESET}"

    # shellcheck disable=SC2059
    printf "\n${_UVM_BOLD}UVM doctor${_UVM_RESET}\n"
    printf '%0.s─' {1..40}; echo

    # --- Installation ---
    # shellcheck disable=SC2059
    printf "\n${_UVM_BOLD}Installation${_UVM_RESET}\n"
    printf "  Platform          : %s\n" "$(uvm_detect_platform)"
    printf "  Shell             : %s\n" "$(detect_shell)"
    if [ "$path_status" = "present" ]; then
        # shellcheck disable=SC2059
        printf "  PATH ~/.local/bin : [${ok}] present\n"
    else
        # shellcheck disable=SC2059
        printf "  PATH ~/.local/bin : [${warn}] MISSING\n"
        printf "    Fix: add 'export PATH=\"\${HOME}/.local/bin:\$PATH\"' to %s\n" "$shell_rc"
        printf "         or rerun: bash install.sh -y\n"
    fi
    if [ "$uv_status" = "missing" ]; then
        # shellcheck disable=SC2059
        printf "  uv                : [${warn}] NOT FOUND\n"
        printf "    Fix: https://docs.astral.sh/uv/getting-started/installation/\n"
    else
        # shellcheck disable=SC2059
        printf "  uv                : [${ok}] %s\n" "$uv_status"
    fi

    # --- Configuration ---
    # shellcheck disable=SC2059
    printf "\n${_UVM_BOLD}Configuration${_UVM_RESET}\n"
    printf "  UVM_HOME          : %s\n" "$(uvm_get_home)"
    printf "  envs dir          : %s\n" "$(uvm_get_default_envs_dir)"
    printf "  UV config file    : %s\n" "$(uvm_get_uv_config_file)"
    if [ "$mirror_status" = "configured" ]; then
        # shellcheck disable=SC2059
        printf "  Mirror block      : [${ok}] configured\n"
    else
        # shellcheck disable=SC2059
        printf "  Mirror block      : [${info}] not configured (optional)\n"
        printf "    To add: uvm config mirror set <url>\n"
    fi
    if stale_mirror_file=$(uvm_get_stale_mirror_config_file); then
        # shellcheck disable=SC2059
        printf "  Stale mirror      : [${warn}] %s (ignored by uv)\n" "$stale_mirror_file"
        printf "    Fix: uvm config mirror set <url>  (or: uvm config mirror remove)\n"
    fi

    # --- Shell integration ---
    # shellcheck disable=SC2059
    printf "\n${_UVM_BOLD}Shell integration${_UVM_RESET}\n"
    printf "  Shell RC          : %s\n" "$shell_rc"
    if [ "$hook_status" = "configured" ]; then
        # shellcheck disable=SC2059
        printf "  Shell hook        : [${ok}] configured\n"
    else
        # shellcheck disable=SC2059
        printf "  Shell hook        : [${warn}] MISSING\n"
        printf "    Fix: uvm repair && source %s\n" "$shell_rc"
    fi
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        # shellcheck disable=SC2059
        printf "  Active env        : ${_UVM_GREEN}%s${_UVM_RESET}\n" "$VIRTUAL_ENV"
    else
        printf "  Active env        : none\n"
    fi
    if [ -n "${UVM_AUTO_ACTIVATED:-}" ]; then
        printf "  Auto activated    : %s (from %s)\n" "$UVM_AUTO_ACTIVATED" "${UVM_AUTO_PROJECT_ROOT:-unknown}"
    else
        printf "  Auto activated    : no\n"
    fi
    if [ -n "${UVM_UNTRUSTED_LOCAL_ENV:-}" ]; then
        # shellcheck disable=SC2059
        printf "  Local .venv trust : [${warn}] REQUIRED (%s)\n" "$UVM_UNTRUSTED_LOCAL_ENV"
        printf "    Fix: review first, then run: uvm trust '%s'\n" "$UVM_UNTRUSTED_LOCAL_ENV"
    else
        printf "  Local .venv trust : no pending environment\n"
    fi

    # --- Metadata ---
    # shellcheck disable=SC2059
    printf "\n${_UVM_BOLD}Metadata${_UVM_RESET}\n"
    printf "  Records           : %s\n" "$(uvm_count_metadata_records)"
    echo
}

uvm_repair() {
    local shell_rc
    local registered_count

    init_uvm_config || return 1
    uvm_prune_invalid_records || return 1
    registered_count=$(scan_and_register_envs "$(uvm_get_default_envs_dir)") || return 1

    shell_rc=$(get_shell_rc_file)
    uvm_ensure_shell_hook_configured "$shell_rc" || return 1

    # Only re-apply mirror if a managed block already exists (do not silently
    # overwrite user config for those who never opted in to a mirror).
    if uvm_file_contains_managed_block \
        "$(uvm_get_uv_config_file)" \
        "$(uvm_get_mirror_start_marker)" \
        "$(uvm_get_mirror_end_marker)"; then
        echo "  Mirror block already configured; skipping rewrite"
    fi

    echo "Repair complete"
    echo "  Shell hook file : ${shell_rc}"
    echo "  Managed records : $(uvm_count_metadata_records)"
    echo "  Re-registered   : ${registered_count}"
}

uvm_status() {
    local json_mode=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) json_mode=true; shift ;;
            *)
                echo "Error: Unknown option: $1"
                return 1
                ;;
        esac
    done

    init_uvm_config || return 1

    if [ "$json_mode" = true ]; then
        local active_env="${UVM_ACTIVE_ENV:-${UVM_AUTO_ACTIVATED:-}}"
        local active_path="${VIRTUAL_ENV:-}"
        printf '{"active_env":%s,"active_path":%s,"envs_dir":"%s","records":%s}\n' \
            "$([ -n "$active_env" ] && printf '"%s"' "$(uvm_json_escape "$active_env")" || printf 'null')" \
            "$([ -n "$active_path" ] && printf '"%s"' "$(uvm_json_escape "$active_path")" || printf 'null')" \
            "$(uvm_json_escape "$(uvm_get_default_envs_dir)")" \
            "$(uvm_count_metadata_records)"
        return 0
    fi

    # shellcheck disable=SC2059
    printf "${_UVM_BOLD}uvm status${_UVM_RESET}\n\n"

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        local active_name="${UVM_ACTIVE_ENV:-${UVM_AUTO_ACTIVATED:-}}"
        if [ -n "$active_name" ]; then
            # shellcheck disable=SC2059
            printf "  Active env  : ${_UVM_GREEN}${_UVM_BOLD}%s${_UVM_RESET}${_UVM_DIM} (%s)${_UVM_RESET}\n" \
                "$active_name" "$VIRTUAL_ENV"
        else
            # shellcheck disable=SC2059
            printf "  Active env  : ${_UVM_GREEN}%s${_UVM_RESET}\n" "$VIRTUAL_ENV"
        fi
        if [ -n "${UVM_AUTO_ACTIVATED:-}" ]; then
            # shellcheck disable=SC2059
            printf "  Source      : ${_UVM_DIM}auto (%s)${_UVM_RESET}\n" "${UVM_AUTO_PROJECT_ROOT:-unknown}"
        fi
    else
        # shellcheck disable=SC2059
        printf "  Active env  : ${_UVM_DIM}none${_UVM_RESET}\n"
    fi

    # shellcheck disable=SC2059
    printf "  Envs dir    : ${_UVM_DIM}%s${_UVM_RESET}\n" "$(uvm_get_default_envs_dir)"
    # shellcheck disable=SC2059
    printf "  Records     : ${_UVM_DIM}%s environment(s)${_UVM_RESET}\n" "$(uvm_count_metadata_records)"
    echo
}

uvm_help() {
    cat <<'EOF'
uvm - UV Manager

A Conda-like environment manager for UV.

USAGE:
    uvm <command> [options]

COMMANDS:
    create <name>              Create a new virtual environment
        --python <version>     Specify Python version (for example 3.11)
        --path <path>          Create the environment in a custom location

    activate <name>            Activate an environment
    deactivate                 Deactivate the current environment

    delete <name>              Delete an environment
        -f, --force            Skip the confirmation prompt

    run <name> <cmd> [args]    Run a command inside an environment without activating
    rename <old> <new>         Rename an environment
    clone <src> <dst>          Clone an environment
    export <name>              Print installed packages (pip freeze) to stdout
    import <name> --from <f>   Create environment and install packages from a requirements file

    list                       List known environments
        -a, --all              Show the source of each environment
        --json                 Output as JSON array

    scan [directory]           Scan a directory and register valid environments
    repair                     Rebuild metadata and shell hook
    doctor                     Diagnose shell integration and metadata health
    status                     Show the active environment and key config at a glance
    update [v<version>]        Update uvm to the latest (or given) release
        --check                Only report whether an update is available
    trust [path]               Trust a local .venv for auto-activation
    trust list                 List trusted local environments
    untrust [path]             Revoke local .venv auto-activation trust
    help                       Show this help message

CONFIG:
    config show                Show all effective settings
    config get envs-dir        Print the environment directory
    config set envs-dir <dir>  Change the directory for new environments
    config mirror show|set <url>|remove
                               PyPI package index mirror
    config python-mirror show|set <url>|remove
                               Mirror for uv's Python interpreter downloads

AUTO-ACTIVATION:
    Enable shell integration by adding:
        eval "$(uvm shell-hook)"

    Priority:
      1. Nearest trusted parent .venv
      2. Nearest parent .uvmrc

CONFIGURATION:
    UVM_HOME defaults to ~/.config/uvm
    envs-dir defaults to ~/uv_envs (change with: uvm config set envs-dir <dir>)

EOF
}
