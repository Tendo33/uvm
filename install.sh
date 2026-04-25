#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

UVM_INSTALL_VERSION="1.1.1"
UVM_PATH_BLOCK_START="# >>> uvm path >>>"
UVM_PATH_BLOCK_END="# <<< uvm path <<<"
UVM_REPOSITORY="Tendo33/uvm"

print_info() {
    echo -e "${BLUE}i${NC} $1"
}

print_success() {
    echo -e "${GREEN}OK${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARN${NC} $1"
}

print_error() {
    echo -e "${RED}ERR${NC} $1"
}

detect_os() {
    case "$(uname -s)" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

check_uv() {
    if command -v uv >/dev/null 2>&1; then
        print_success "UV is already installed: $(uv --version 2>&1 | head -n 1)"
        return 0
    fi

    print_warning "UV is not installed"
    return 1
}

install_uv() {
    print_info "Installing UV..."

    case "$(detect_os)" in
        linux|macos)
            if command -v curl >/dev/null 2>&1; then
                curl -LsSf https://astral.sh/uv/install.sh | sh
            elif command -v wget >/dev/null 2>&1; then
                wget -qO- https://astral.sh/uv/install.sh | sh
            else
                print_error "Neither curl nor wget is available."
                return 1
            fi
            ;;
        windows)
            print_error "Install UV manually in PowerShell first:"
            print_error '  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"'
            return 1
            ;;
        *)
            print_error "Unsupported operating system"
            return 1
            ;;
    esac

    command -v uv >/dev/null 2>&1
}

uvm_get_effective_home() {
    printf '%s\n' "${UVM_HOME:-${HOME}/.config/uvm}"
}

uvm_get_download_ref() {
    printf '%s\n' "${UVM_DOWNLOAD_REF:-v${UVM_INSTALL_VERSION}}"
}

uvm_get_download_base_url() {
    printf 'https://raw.githubusercontent.com/%s/%s\n' \
        "${UVM_REPOSITORY}" \
        "$(uvm_get_download_ref)"
}

download_uvm_files() {
    local dest="$1"
    local base_url
    local file_path

    base_url="$(uvm_get_download_base_url)"
    mkdir -p "$dest/bin" "$dest/lib" "$dest/templates"

    for file_path in \
        bin/uvm \
        lib/uvm-config.sh \
        lib/uvm-core.sh \
        lib/uvm-shell-hooks.sh \
        templates/uv.toml.template
    do
        local url="${base_url}/${file_path}"
        local output="${dest}/${file_path}"

        print_info "Downloading ${file_path}..."
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$url" -o "$output" || return 1
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$output" "$url" || return 1
        else
            print_error "Neither curl nor wget is available."
            return 1
        fi
    done
}

install_uvm() {
    local source_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    local install_dir="${HOME}/.local/bin"
    local uvm_lib_dir="${HOME}/.local/lib/uvm"
    local uvm_home

    uvm_home="$(uvm_get_effective_home)"
    print_info "Installing uvm files..."
    mkdir -p "$install_dir" "$uvm_lib_dir" "${uvm_home}/templates"

    cp "${source_dir}/bin/uvm" "${install_dir}/uvm"
    chmod +x "${install_dir}/uvm"
    cp -r "${source_dir}/lib/." "$uvm_lib_dir/"
    cp -r "${source_dir}/templates/." "${uvm_home}/templates/"

    sed -i.bak "s|SCRIPT_DIR=\".*\"|SCRIPT_DIR=\"${uvm_lib_dir}\"|g" "${install_dir}/uvm" 2>/dev/null || \
        sed -i '' "s|SCRIPT_DIR=\".*\"|SCRIPT_DIR=\"${uvm_lib_dir}\"|g" "${install_dir}/uvm" 2>/dev/null || true
    sed -i.bak "s|LIB_DIR=\".*\"|LIB_DIR=\"${uvm_lib_dir}\"|g" "${install_dir}/uvm" 2>/dev/null || \
        sed -i '' "s|LIB_DIR=\".*\"|LIB_DIR=\"${uvm_lib_dir}\"|g" "${install_dir}/uvm" 2>/dev/null || true
    rm -f "${install_dir}/uvm.bak"

    print_success "Installed binary to ${install_dir}/uvm"
    print_success "Installed library to ${uvm_lib_dir}"
}

source_installed_config_lib() {
    local config_lib="${HOME}/.local/lib/uvm/uvm-config.sh"
    if [ ! -f "$config_lib" ]; then
        print_error "Installed configuration library not found: $config_lib"
        return 1
    fi

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

configure_path() {
    local install_dir="${HOME}/.local/bin"
    local shell_rc

    if [[ ":$PATH:" == *":${install_dir}:"* ]]; then
        print_success "Installation directory already in PATH"
        return 0
    fi

    shell_rc=$(detect_shell_rc)
    print_info "Adding PATH block to ${shell_rc}"

    source_installed_config_lib
    uvm_upsert_managed_block \
        "$shell_rc" \
        "$UVM_PATH_BLOCK_START" \
        "$UVM_PATH_BLOCK_END" \
        'export PATH="${HOME}/.local/bin:$PATH"'

    print_success "PATH configuration updated"
}

configure_shell_integration() {
    local shell_rc

    shell_rc=$(detect_shell_rc)
    source_installed_config_lib
    uvm_ensure_shell_hook_configured "$shell_rc"
    print_success "Shell hook configured in ${shell_rc}"
}

initialize_config() {
    local envs_dir="${1:-${HOME}/uv_envs}"
    local mirror_url="${2:-}"
    local registered_count

    print_info "Initializing uvm configuration..."
    mkdir -p "$envs_dir"

    source_installed_config_lib
    export UVM_HOME
    UVM_HOME="$(uvm_get_effective_home)"
    export UVM_ENVS_DIR="$envs_dir"

    init_uvm_config
    printf 'UVM_ENVS_DIR=%q\n' "$envs_dir" > "$(uvm_get_config_file)"
    registered_count=$(scan_and_register_envs "$envs_dir")

    if [ -n "$mirror_url" ]; then
        setup_uv_mirror "$mirror_url"
        print_success "Mirror configured: ${mirror_url}"
    fi

    print_success "Environment directory configured: $envs_dir"
    print_success "Registered ${registered_count} existing environment(s)"
}

show_post_install() {
    local enable_auto_activation="$1"
    local shell_rc
    local uvm_home

    shell_rc=$(detect_shell_rc)
    uvm_home="$(uvm_get_effective_home)"

    echo ""
    print_success "uvm ${UVM_INSTALL_VERSION} installed successfully"
    echo "  Binary        : ${HOME}/.local/bin/uvm"
    echo "  Library       : ${HOME}/.local/lib/uvm"
    echo "  Config        : ${uvm_home}"
    echo "  Shell RC      : ${shell_rc}"
    echo ""
    echo "Next steps:"
    echo "  1. Reload your shell: source ${shell_rc}"
    echo "  2. Create an environment: uvm create myenv --python 3.11"
    if [[ "$enable_auto_activation" =~ ^[Yy]$ ]]; then
        echo "  3. Auto-activation is enabled"
    else
        echo "  3. Enable auto-activation later with: eval \"\$(uvm shell-hook)\""
    fi
}

interactive_setup() {
    local envs_dir="${HOME}/uv_envs"
    local install_uv_choice="n"
    local enable_auto_activation="y"
    local mirror_url=""
    local choice

    echo ""
    echo "UVM installation wizard"
    echo "-----------------------"
    printf "Environment directory [%s]: " "$envs_dir"
    read -r choice
    if [ -n "$choice" ]; then
        envs_dir="${choice/#\~/$HOME}"
    fi

    if ! check_uv >/dev/null 2>&1; then
        if [ "$(detect_os)" = "windows" ]; then
            print_warning "Install UV in PowerShell, then rerun this installer."
        else
            printf "Install UV now? (Y/n): "
            read -r install_uv_choice
            install_uv_choice="${install_uv_choice:-y}"
        fi
    fi

    printf "Enable auto-activation? (Y/n): "
    read -r enable_auto_activation
    enable_auto_activation="${enable_auto_activation:-y}"

    printf "Configure a PyPI mirror URL? (press Enter to skip): "
    read -r mirror_url

    echo "$envs_dir"
    echo "$install_uv_choice"
    echo "$enable_auto_activation"
    echo "$mirror_url"
}

main() {
    local script_dir
    local temp_dir=""
    local custom_envs_dir=""
    local custom_mirror_url=""
    local non_interactive=false
    local install_uv_choice="n"
    local enable_auto_activation="y"

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

    if [ ! -d "${script_dir}/bin" ]; then
        print_info "Remote installation mode detected"
        temp_dir=$(mktemp -d)
        trap 'rm -rf "$temp_dir"' EXIT
        download_uvm_files "$temp_dir" || {
            print_error "Failed to download uvm files"
            exit 1
        }
        script_dir="$temp_dir"
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --envs-dir)
                custom_envs_dir="$2"
                non_interactive=true
                shift 2
                ;;
            --mirror)
                custom_mirror_url="$2"
                shift 2
                ;;
            --no-mirror)
                custom_mirror_url=""
                shift
                ;;
            -y|--non-interactive)
                non_interactive=true
                shift
                ;;
            -h|--help)
                cat <<EOF
UVM Installer v${UVM_INSTALL_VERSION}

Usage: ./install.sh [OPTIONS]

  --envs-dir <path>    Custom directory for virtual environments
  --mirror <url>       Configure a PyPI mirror (e.g. https://pypi.tuna.tsinghua.edu.cn/simple)
  --no-mirror          Skip mirror configuration (default in non-interactive mode)
  -y, --non-interactive
                       Use defaults and fail if UV is missing
  -h, --help           Show this help message
EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    print_info "Detected OS: $(detect_os)"

    if [ "$non_interactive" = false ] && [ -z "$custom_envs_dir" ]; then
        local config_result
        config_result=$(interactive_setup)
        custom_envs_dir=$(printf '%s\n' "$config_result" | sed -n '1p')
        install_uv_choice=$(printf '%s\n' "$config_result" | sed -n '2p')
        enable_auto_activation=$(printf '%s\n' "$config_result" | sed -n '3p')
        custom_mirror_url=$(printf '%s\n' "$config_result" | sed -n '4p')
    else
        custom_envs_dir="${custom_envs_dir:-${HOME}/uv_envs}"
        print_info "Running in non-interactive mode"
    fi

    if [[ "$install_uv_choice" =~ ^[Yy]$ ]]; then
        install_uv || {
            print_error "Failed to install UV"
            exit 1
        }
    elif ! check_uv; then
        if [ "$non_interactive" = true ]; then
            print_error "UV is required in non-interactive mode. Install UV first or rerun interactively."
            exit 1
        fi
        print_warning "Skipping UV installation. You can install it later from https://github.com/astral-sh/uv"
    fi

    install_uvm "$script_dir"
    configure_path
    initialize_config "$custom_envs_dir" "$custom_mirror_url"

    if [[ "$enable_auto_activation" =~ ^[Yy]$ ]]; then
        configure_shell_integration
    fi

    show_post_install "$enable_auto_activation"
}

if [ "${UVM_INSTALL_SKIP_MAIN:-0}" != "1" ]; then
    main "$@"
fi
