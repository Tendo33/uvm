#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/uvm-config.sh
source "${SCRIPT_DIR}/uvm-config.sh"

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
                python_version="$2"
                shift 2
                ;;
            --path)
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
        env_path="$custom_path"
        mkdir -p "$(dirname "$env_path")" || return 1
    else
        env_path="$(uvm_get_default_envs_dir)/${env_name}"
        mkdir -p "$(uvm_get_default_envs_dir)" || return 1
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
    add_env_record "$env_name" "$env_path" "$actual_python_version" || return 1

    echo "Environment '${env_name}' created successfully"
    echo "  Location: ${env_path}"
    echo "  Python: ${actual_python_version}"
    echo ""
    echo "Next step:"
    echo "  Run 'uvm activate ${env_name}' after enabling shell integration."
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

    local new_path="$old_path"
    local default_root
    default_root=$(uvm_get_default_envs_dir)

    # If env lives under UVM_ENVS_DIR, rename the directory too
    if uvm_path_is_within "$default_root" "$old_path" 2>/dev/null; then
        new_path="${default_root}/${new_name}"
        mv "$old_path" "$new_path" || {
            echo "Error: Failed to move environment directory"
            return 1
        }
    fi

    # Reload python version from old record before removing it
    local python_version="unknown"
    if uvm_load_env_record "$old_name"; then
        python_version="${UVM_RECORD_PYTHON:-unknown}"
    fi

    remove_env_record "$old_name" || return 1
    add_env_record "$new_name" "$new_path" "$python_version" || return 1

    echo "Environment '${old_name}' renamed to '${new_name}'"
    [ "$new_path" != "$old_path" ] && echo "  New location: ${new_path}"
    return 0
}

uvm_clone() {
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

    local dst_path
    dst_path="$(uvm_get_default_envs_dir)/${dst_name}"
    mkdir -p "$(uvm_get_default_envs_dir)" || return 1

    echo "Cloning '${src_name}' -> '${dst_name}'..."
    echo "  Python: ${python_version}"

    if [ -n "$python_version" ] && [ "$python_version" != "unknown" ]; then
        uv venv "$dst_path" --python "$python_version" || return 1
    else
        uv venv "$dst_path" || return 1
    fi

    # Copy installed packages from source to destination
    local src_python
    src_python=$(uvm_env_python_binary "$src_path" || true)
    if [ -n "$src_python" ] && [ -f "$src_python" ]; then
        echo "  Copying installed packages..."
        local requirements
        requirements=$(VIRTUAL_ENV="$src_path" "$src_python" -m pip freeze 2>/dev/null || true)
        if [ -n "$requirements" ]; then
            local dst_python
            dst_python=$(uvm_env_python_binary "$dst_path" || true)
            if [ -n "$dst_python" ] && [ -f "$dst_python" ]; then
                echo "$requirements" | VIRTUAL_ENV="$dst_path" "$dst_python" -m pip install -q -r /dev/stdin || true
            fi
        fi
    fi

    local actual_python
    actual_python=$(get_env_python_version "$dst_path")
    add_env_record "$dst_name" "$dst_path" "$actual_python" || return 1

    echo "Environment '${dst_name}' cloned from '${src_name}'"
    echo "  Location: ${dst_path}"
    echo "  Python: ${actual_python}"
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

    echo "Environment '${env_name}' deleted successfully"
}

uvm_print_env_entry() {
    local env_name="$1"
    local env_path="$2"
    local python_version="$3"
    local source_label="$4"
    local marker="  "

    if [ "${VIRTUAL_ENV:-}" = "$env_path" ]; then
        marker="* "
    fi

    if [ "${UVM_LIST_SHOW_ALL:-false}" = true ]; then
        printf "%s%-20s Python %-10s %-10s %s\n" "$marker" "$env_name" "${python_version:-unknown}" "$source_label" "$env_path"
    else
        printf "%s%-20s Python %-10s %s\n" "$marker" "$env_name" "${python_version:-unknown}" "$env_path"
    fi
}

uvm_list() {
    local seen_names=""
    local env_name
    local env_path
    local env_dir

    UVM_LIST_SHOW_ALL=false
    while [ $# -gt 0 ]; do
        case "$1" in
            -a|--all)
                UVM_LIST_SHOW_ALL=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1"
                return 1
                ;;
        esac
    done

    init_uvm_config || return 1
    echo "Available environments:"
    echo ""

    for env_name in $(uvm_list_record_names); do
        if uvm_load_env_record "$env_name" && uvm_is_valid_uv_env "$UVM_RECORD_PATH"; then
            uvm_print_env_entry "$env_name" "$UVM_RECORD_PATH" "${UVM_RECORD_PYTHON}" "managed"
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
                uvm_print_env_entry "$env_name" "$env_dir" "$(get_env_python_version "$env_dir")" "discovered"
                seen_names="${seen_names}
${env_name}"
            fi
        done
    fi

    if [ -z "${seen_names#?}" ]; then
        echo "  No environments found"
        echo ""
        echo "Create one with: uvm create <env_name>"
    fi

    echo ""
}

uvm_doctor() {
    local shell_rc
    local hook_status="missing"
    local uv_status="missing"
    local path_status="missing"
    local mirror_status="missing"

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

    echo "UVM doctor"
    echo "----------"
    echo "Platform          : $(uvm_detect_platform)"
    echo "Shell             : $(detect_shell)"
    echo "Shell RC          : ${shell_rc}"
    echo "Shell hook        : ${hook_status}"
    echo "UVM_HOME          : $(uvm_get_home)"
    echo "UVM_ENVS_DIR      : $(uvm_get_default_envs_dir)"
    echo "Metadata records  : $(uvm_count_metadata_records)"
    echo "PATH ~/.local/bin : ${path_status}"
    echo "UV                : ${uv_status}"
    echo "Mirror block      : ${mirror_status}"
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        echo "Active environment: ${VIRTUAL_ENV}"
    else
        echo "Active environment: none"
    fi
    if [ -n "${UVM_AUTO_ACTIVATED:-}" ]; then
        echo "Auto activated    : ${UVM_AUTO_ACTIVATED}"
    else
        echo "Auto activated    : no"
    fi
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
    update                     Update uvm to the latest release
    help                       Show this help message

CONFIG:
    config show                Show effective configuration paths
    config mirror show         Show mirror configuration status
    config mirror set <url>    Configure a custom PyPI mirror
    config mirror remove       Remove the managed mirror block

AUTO-ACTIVATION:
    Enable shell integration by adding:
        eval "$(uvm shell-hook)"

    Priority:
      1. Nearest parent .venv
      2. Nearest parent .uvmrc

CONFIGURATION:
    UVM_HOME defaults to ~/.config/uvm
    UVM_ENVS_DIR defaults to ~/uv_envs

EOF
}
