#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

UVM_PATH_BLOCK_START="# >>> uvm path >>>"
UVM_PATH_BLOCK_END="# <<< uvm path <<<"

print_error() {
    echo -e "${RED}ERR${NC} $1"
}

print_success() {
    echo -e "${GREEN}OK${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARN${NC} $1"
}

print_info() {
    echo -e "${BLUE}i${NC} $1"
}

uvm_get_effective_home() {
    printf '%s\n' "${UVM_HOME:-${HOME}/.config/uvm}"
}

source_installed_config_lib() {
    local config_lib="${HOME}/.local/lib/uvm/uvm-config.sh"
    [ -f "$config_lib" ] || return 1
    # shellcheck source=/dev/null
    source "$config_lib"
}

detect_shell_rc() {
    if source_installed_config_lib >/dev/null 2>&1; then
        get_shell_rc_file
        return 0
    fi

    if [ -n "${ZSH_VERSION:-}" ]; then
        echo "${HOME}/.zshrc"
    elif [ -f "${HOME}/.bashrc" ]; then
        echo "${HOME}/.bashrc"
    else
        echo "${HOME}/.bash_profile"
    fi
}

resolve_managed_envs_dir() {
    if source_installed_config_lib >/dev/null 2>&1; then
        uvm_load_user_config
        uvm_get_default_envs_dir
        return 0
    fi

    printf '%s\n' "${HOME}/uv_envs"
}

show_removal_plan() {
    local shell_rc
    local uvm_home

    uvm_home="$(uvm_get_effective_home)"

    echo "The following will be removed:"
    [ -f "${HOME}/.local/bin/uvm" ] && echo "  - ${HOME}/.local/bin/uvm"
    [ -d "${HOME}/.local/lib/uvm" ] && echo "  - ${HOME}/.local/lib/uvm"
    [ -d "${uvm_home}" ] && echo "  - ${uvm_home}"

    shell_rc=$(detect_shell_rc)
    if [ -f "$shell_rc" ]; then
        echo "  - managed shell blocks in ${shell_rc}"
    fi

    echo ""
    echo "Virtual environments themselves are kept."
    echo ""
}

backup_shell_rc() {
    local shell_rc="$1"
    local backup_file

    [ -f "$shell_rc" ] || return 0

    backup_file="${shell_rc}.uvm-backup-$(date +%Y%m%d-%H%M%S)"
    cp "$shell_rc" "$backup_file"
    print_success "Backed up shell config to: $backup_file" >&2
    printf '%s\n' "$backup_file"
}

remove_from_shell_rc() {
    local shell_rc="$1"

    [ -f "$shell_rc" ] || return 0

    if source_installed_config_lib >/dev/null 2>&1; then
        uvm_remove_managed_block \
            "$shell_rc" \
            "$(uvm_get_shell_hook_start_marker)" \
            "$(uvm_get_shell_hook_end_marker)"
        uvm_remove_managed_block \
            "$shell_rc" \
            "$UVM_PATH_BLOCK_START" \
            "$UVM_PATH_BLOCK_END"
    else
        local temp_file
        temp_file=$(mktemp "${TMPDIR:-/tmp}/uvm-uninstall.XXXXXX") || return 1
        awk -v path_start="$UVM_PATH_BLOCK_START" -v path_end="$UVM_PATH_BLOCK_END" \
            -v shell_start="# >>> uvm shell >>>" -v shell_end="# <<< uvm shell <<<" '
            $0 == path_start || $0 == shell_start { skip = 1; next }
            $0 == path_end || $0 == shell_end { skip = 0; next }
            skip != 1 { print }
        ' "$shell_rc" > "$temp_file"
        mv "$temp_file" "$shell_rc"
    fi

    print_success "Removed managed shell configuration from ${shell_rc}"
}

remove_files() {
    local uvm_home

    uvm_home="$(uvm_get_effective_home)"

    if [ -f "${HOME}/.local/bin/uvm" ]; then
        rm -f "${HOME}/.local/bin/uvm"
        print_success "Removed ${HOME}/.local/bin/uvm"
    fi

    if [ -d "${HOME}/.local/lib/uvm" ]; then
        rm -rf "${HOME}/.local/lib/uvm"
        print_success "Removed ${HOME}/.local/lib/uvm"
    fi

    # Remove bash completion file
    local bash_completion="${HOME}/.local/share/bash-completion/completions/uvm"
    if [ -f "$bash_completion" ]; then
        rm -f "$bash_completion"
        print_success "Removed bash completion: ${bash_completion}"
    fi

    # Remove zsh completion file
    local zsh_completion="${HOME}/.zfunc/_uvm"
    if [ -f "$zsh_completion" ]; then
        rm -f "$zsh_completion"
        print_success "Removed zsh completion: ${zsh_completion}"
    fi

    if [ -d "${uvm_home}" ]; then
        rm -rf "${uvm_home}"
        print_success "Removed ${uvm_home}"
    fi

    return 0
}

show_post_uninstall() {
    local backup_file="$1"
    local envs_dir="$2"

    echo ""
    print_success "uvm has been uninstalled successfully"
    echo "Next steps:"
    echo "  1. Reload your shell configuration"
    [ -n "$backup_file" ] && echo "  2. Shell backup: $backup_file"

    if [ -d "$envs_dir" ]; then
        echo "  3. Your environments remain at: $envs_dir"
    fi
}

main() {
    local force_mode=false
    local keep_shell_config=false
    local shell_rc
    local backup_file=""
    local envs_dir

    while [ $# -gt 0 ]; do
        case "$1" in
            -f|--force)
                force_mode=true
                shift
                ;;
            --keep-shell-config)
                keep_shell_config=true
                shift
                ;;
            -h|--help)
                cat <<'EOF'
UVM Uninstaller

Usage: ./uninstall.sh [OPTIONS]

  -f, --force             Skip confirmation
  --keep-shell-config     Leave shell integration blocks untouched
  -h, --help              Show this help message
EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    show_removal_plan
    envs_dir="$(resolve_managed_envs_dir)"

    if [ "$force_mode" = false ]; then
        printf "Do you want to continue? (y/N): "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Uninstallation cancelled"
            exit 0
        fi
    fi

    shell_rc=$(detect_shell_rc)
    if [ "$keep_shell_config" = false ]; then
        backup_file=$(backup_shell_rc "$shell_rc")
        remove_from_shell_rc "$shell_rc"
    else
        print_info "Keeping shell configuration"
    fi

    remove_files
    show_post_uninstall "$backup_file" "$envs_dir"
}

main "$@"
