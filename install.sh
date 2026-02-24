#!/bin/bash


set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*)    echo "windows";;
        *)          echo "unknown";;
    esac
}

# 检查 UV 是否已安装
check_uv() {
    if command -v uv &> /dev/null; then
        local uv_version
        uv_version=$(uv --version 2>&1 | head -n 1)
        print_success "UV is already installed: $uv_version"
        return 0
    else
        print_warning "UV is not installed"
        return 1
    fi
}

# 安装 UV
install_uv() {
    print_info "Installing UV..."
    
    local os
    os=$(detect_os)
    
    case "$os" in
        linux|macos)
            # 使用官方安装脚本
            if command -v curl &> /dev/null; then
                curl -LsSf https://astral.sh/uv/install.sh | sh
            elif command -v wget &> /dev/null; then
                wget -qO- https://astral.sh/uv/install.sh | sh
            else
                print_error "Neither curl nor wget is available. Please install one of them first."
                return 1
            fi
            ;;
        windows)
            print_info "For Windows, please install UV manually:"
            print_info "  PowerShell: powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\""
            print_info "  Or download from: https://github.com/astral-sh/uv/releases"
            return 1
            ;;
        *)
            print_error "Unsupported operating system"
            return 1
            ;;
    esac
    
    # 验证安装
    if command -v uv &> /dev/null; then
        print_success "UV installed successfully"
        return 0
    else
        print_error "UV installation failed"
        return 1
    fi
}

# 安装 UVM
install_uvm() {
    local source_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    
    print_info "Installing uvm..."
    
    # 确定安装目录
    local install_dir="${HOME}/.local/bin"
    local uvm_lib_dir="${HOME}/.local/lib/uvm"
    
    # 创建目录
    mkdir -p "$install_dir"
    mkdir -p "$uvm_lib_dir"
    
    # 使用传入的源目录
    local script_dir="$source_dir"
    
    # 复制文件
    print_info "Copying files..."
    
    # 复制主脚本
    if [ -f "$script_dir/bin/uvm" ]; then
        cp "$script_dir/bin/uvm" "$install_dir/uvm"
        chmod +x "$install_dir/uvm"
        print_success "Installed uvm binary to: $install_dir/uvm"
    else
        print_error "Source file not found: $script_dir/bin/uvm"
        return 1
    fi
    
    # 复制库文件
    if [ -d "$script_dir/lib" ]; then
        cp -r "$script_dir/lib"/* "$uvm_lib_dir/"
        print_success "Installed library files to: $uvm_lib_dir"
    else
        print_error "Library directory not found: $script_dir/lib"
        return 1
    fi
    
    # 复制模板文件
    if [ -d "$script_dir/templates" ]; then
        mkdir -p "${HOME}/.config/uvm/templates"
        cp -r "$script_dir/templates"/* "${HOME}/.config/uvm/templates/"
        print_success "Installed templates to: ${HOME}/.config/uvm/templates"
    fi
    
    # 更新库文件中的路径引用
    sed -i.bak "s|SCRIPT_DIR=\".*\"|SCRIPT_DIR=\"${uvm_lib_dir}\"|g" "$install_dir/uvm" 2>/dev/null || \
    sed -i '' "s|SCRIPT_DIR=\".*\"|SCRIPT_DIR=\"${uvm_lib_dir}\"|g" "$install_dir/uvm" 2>/dev/null || true
    
    # 修正 LIB_DIR 路径
    sed -i.bak "s|LIB_DIR=\".*\"|LIB_DIR=\"${uvm_lib_dir}\"|g" "$install_dir/uvm" 2>/dev/null || \
    sed -i '' "s|LIB_DIR=\".*\"|LIB_DIR=\"${uvm_lib_dir}\"|g" "$install_dir/uvm" 2>/dev/null || true
    
    rm -f "$install_dir/uvm.bak"
    
    return 0
}

# 配置 PATH
configure_path() {
    local install_dir="${HOME}/.local/bin"
    
    # 检查是否已在 PATH 中
    if echo "$PATH" | grep -q "$install_dir"; then
        print_success "Installation directory already in PATH"
        return 0
    fi
    
    print_warning "Installation directory not in PATH"
    
    # 检测 Shell 类型
    local shell_rc=""
    if [ -n "$BASH_VERSION" ]; then
        if [ -f "${HOME}/.bashrc" ]; then
            shell_rc="${HOME}/.bashrc"
        else
            shell_rc="${HOME}/.bash_profile"
        fi
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="${HOME}/.zshrc"
    else
        shell_rc="${HOME}/.profile"
    fi
    
    print_info "Adding to PATH in: $shell_rc"
    
    # 添加 PATH 配置
    echo "" >> "$shell_rc"
    echo "# Added by uvm installer" >> "$shell_rc"
    echo "export PATH=\"\${HOME}/.local/bin:\$PATH\"" >> "$shell_rc"
    
    print_success "PATH configuration added to: $shell_rc"
    print_warning "Please run: source $shell_rc"
}

# 初始化配置
initialize_config() {
    local envs_dir="${1:-${HOME}/uv_envs}"
    
    print_info "Initializing uvm configuration..."
    
    # 创建配置目录
    mkdir -p "${HOME}/.config/uvm"
    
    # 创建环境目录
    if [ ! -d "$envs_dir" ]; then
        print_info "Creating environments directory: $envs_dir"
        mkdir -p "$envs_dir"
    else
        print_success "Environments directory already exists: $envs_dir"
    fi
    
    # 保存环境目录配置
    local uvm_config="${HOME}/.config/uvm/config"
    echo "UVM_ENVS_DIR=\"$envs_dir\"" > "$uvm_config"
    print_success "Environment directory configured: $envs_dir"
    
    # 初始化环境列表
    if [ ! -f "${HOME}/.config/uvm/envs.json" ]; then
        echo "[]" > "${HOME}/.config/uvm/envs.json"
    fi
    
    # 扫描并注册已存在的环境
    if [ -d "$envs_dir" ]; then
        print_info "Scanning for existing UV environments..."
        
        # 加载 uvm-config.sh 以使用扫描函数
        local lib_dir="${HOME}/.local/lib/uvm"
        if [ -f "${lib_dir}/uvm-config.sh" ]; then
            source "${lib_dir}/uvm-config.sh"
            
            # 临时设置环境变量
            export UVM_ENVS_DIR="$envs_dir"
            
            # 扫描环境
            local registered_count=0
            for env_dir in "${envs_dir}"/*; do
                if [ -d "$env_dir" ]; then
                    local env_name
                    env_name=$(basename "$env_dir")
                    
                    # 跳过隐藏目录和特殊文件
                    if [[ "$env_name" == .* ]] || [[ "$env_name" == "desktop.ini" ]] || [[ "$env_name" == *.ico ]]; then
                        continue
                    fi
                    
                    # 检查是否是有效的虚拟环境
                    if [ -f "${env_dir}/bin/activate" ] || [ -f "${env_dir}/Scripts/activate" ]; then
                        if [ -f "${env_dir}/pyvenv.cfg" ]; then
                            # 获取 Python 版本
                            local python_version="unknown"
                            if [ -f "${env_dir}/bin/python" ]; then
                                python_version=$("${env_dir}/bin/python" --version 2>&1 | cut -d' ' -f2)
                            elif [ -f "${env_dir}/Scripts/python.exe" ]; then
                                python_version=$("${env_dir}/Scripts/python.exe" --version 2>&1 | cut -d' ' -f2)
                            fi
                            
                            # 生成时间戳
                            local timestamp
                            if date --version >/dev/null 2>&1; then
                                timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
                            else
                                timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
                            fi
                            
                            # 添加到 envs.json
                            local record="{\"name\":\"${env_name}\",\"path\":\"${env_dir}\",\"python\":\"${python_version}\",\"created\":\"${timestamp}\"}"
                            local envs_file="${HOME}/.config/uvm/envs.json"
                            local content
                            content=$(cat "${envs_file}")
                            
                            if [ "$content" = "[]" ]; then
                                echo "[${record}]" > "${envs_file}"
                            else
                                echo "${content%]},${record}]" > "${envs_file}"
                            fi
                            
                            print_success "  Registered: ${env_name} (Python ${python_version})"
                            registered_count=$((registered_count + 1))
                        fi
                    fi
                fi
            done
            
            if [ $registered_count -gt 0 ]; then
                print_success "Registered ${registered_count} existing environment(s)"
            fi
        fi
    fi
    
    # 配置 UV 镜像
    print_info "Configuring UV mirrors (China mirrors)..."
    
    local uv_config_dir="${HOME}/.config/uv"
    local uv_config_file="${uv_config_dir}/uv.toml"
    
    mkdir -p "$uv_config_dir"
    
    if [ -f "$uv_config_file" ]; then
        if grep -q "pypi.tuna.tsinghua.edu.cn" "$uv_config_file" 2>/dev/null; then
            print_success "UV mirror already configured"
        else
            print_warning "Backing up existing uv.toml"
            cp "$uv_config_file" "${uv_config_file}.backup"
            
            cat > "$uv_config_file" <<'EOF'
# UV 镜像配置 - 由 uvm 自动生成
# PyPI 镜像源（清华大学镜像）
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true

# Python 解释器下载镜像
[python-downloads]
url = "https://mirrors.tuna.tsinghua.edu.cn/python-releases/"
EOF
            print_success "UV mirror configured"
        fi
    else
        cat > "$uv_config_file" <<'EOF'
# UV 镜像配置 - 由 uvm 自动生成
# PyPI 镜像源（清华大学镜像）
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true

# Python 解释器下载镜像
[python-downloads]
url = "https://mirrors.tuna.tsinghua.edu.cn/python-releases/"
EOF
        print_success "UV mirror configured"
    fi
    
    print_success "Configuration initialized"
}

# {{RIPER-7 Action}}
# Role: LD | Task_ID: remote-install | Time: 2025-12-26T16:15:00+08:00
# Logic: 添加远程下载功能,支持 curl/wget 直接执行安装
# Principle: SOLID-S (单一职责)

# 下载 UVM 文件从 GitHub
download_uvm_files() {
    local dest="$1"
    local base_url="https://raw.githubusercontent.com/Tendo33/uvm/main"
    
    print_info "Downloading uvm files from GitHub..."
    
    # 创建目录结构
    mkdir -p "$dest/bin" "$dest/lib" "$dest/templates"
    
    # 下载文件列表
    local files=(
        "bin/uvm"
        "lib/uvm-config.sh"
        "lib/uvm-core.sh"
        "lib/uvm-shell-hooks.sh"
        "templates/uv.toml.template"
    )
    
    # 检测可用的下载工具
    local download_cmd=""
    if command -v curl &> /dev/null; then
        download_cmd="curl"
    elif command -v wget &> /dev/null; then
        download_cmd="wget"
    else
        print_error "Neither curl nor wget is available. Please install one of them first."
        return 1
    fi
    
    # 下载每个文件
    for file in "${files[@]}"; do
        local url="${base_url}/${file}"
        local output="${dest}/${file}"
        
        print_info "  Downloading ${file}..."
        
        if [ "$download_cmd" = "curl" ]; then
            if ! curl -fsSL "$url" -o "$output"; then
                print_error "Failed to download ${file}"
                return 1
            fi
        else
            if ! wget -qO "$output" "$url"; then
                print_error "Failed to download ${file}"
                return 1
            fi
        fi
    done
    
    print_success "All files downloaded successfully"
    return 0
}

# 显示安装后说明
show_post_install() {
    local enable_auto_activation="${1:-y}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "uvm installed successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    # 读取配置的环境目录
    local configured_envs_dir="${HOME}/uv_envs"
    if [ -f "${HOME}/.config/uvm/config" ]; then
        configured_envs_dir=$(grep "UVM_ENVS_DIR=" "${HOME}/.config/uvm/config" | cut -d'"' -f2)
    fi
    
    echo "📦 Installation Details:"
    echo "   Binary: ${HOME}/.local/bin/uvm"
    echo "   Library: ${HOME}/.local/lib/uvm"
    echo "   Config: ${HOME}/.config/uvm"
    echo "   Environments: ${configured_envs_dir}"
    echo ""
    echo "🚀 Next Steps:"
    echo ""
    echo "   1. Reload your shell configuration:"
    echo "      source ~/.bashrc  # or ~/.zshrc"
    echo ""
    
    if [[ "$enable_auto_activation" =~ ^[Yy]$ ]]; then
        echo "   2. Enable auto-activation (you chose YES):"
        echo "      echo 'eval \"\$(uvm shell-hook)\"' >> ~/.bashrc"
        echo "      source ~/.bashrc"
        echo ""
        echo "      After this, environments will auto-activate when you:"
        echo "      • Enter a directory with .venv folder"
        echo "      • Enter a directory with .uvmrc file"
        echo ""
    else
        echo "   2. Auto-activation is disabled (you chose NO)"
        echo "      You can enable it later by adding to ~/.bashrc:"
        echo "      echo 'eval \"\$(uvm shell-hook)\"' >> ~/.bashrc"
        echo ""
    fi
    
    echo "   3. Create your first environment:"
    echo "      uvm create myenv --python 3.11"
    echo ""
    echo "   4. Activate the environment:"
    echo "      uvm activate myenv"
    echo ""
    echo "📚 Documentation:"
    echo "   Run 'uvm help' for more information"
    echo ""
    echo "🔧 Configuration:"
    echo "   UV mirrors configured for faster downloads in China"
    echo "   PyPI: https://pypi.tuna.tsinghua.edu.cn/simple"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 交互式配置向导
interactive_setup() {
    echo "" >&2
    echo "╔════════════════════════════════════════════════════════════╗" >&2
    echo "║            UVM Installation Configuration Wizard           ║" >&2
    echo "╚════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    
    # 步骤 1: 环境目录配置
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "📁 Step 1/3: Environment Directory" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Virtual environments will be stored in:" >&2
    echo "  ${HOME}/uv_envs" >&2
    echo "" >&2
    
    local envs_dir="${HOME}/uv_envs"
    read -p "Use this directory? (Y/n) or enter custom path: " choice
    
    # 如果用户输入了内容
    if [ -n "$choice" ]; then
        # 如果是 n/N，询问自定义路径
        if [[ "$choice" =~ ^[Nn]$ ]]; then
            read -p "Enter custom path: " custom_path
            if [ -n "$custom_path" ]; then
                # 安全展开 ~ 符号（使用 Bash 参数替换，避免 eval 命令注入）
                envs_dir="${custom_path/#\~/$HOME}"
            fi
        # 如果不是 y/Y/n/N，当作路径处理
        elif [[ ! "$choice" =~ ^[Yy]$ ]]; then
            envs_dir="${choice/#\~/$HOME}"
        fi
        # 如果是 y/Y，使用默认值（已设置）
    fi
    
    print_success "Environment directory: $envs_dir" >&2
    echo "" >&2
    
    # 步骤 2: UV 安装检查
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "🔧 Step 2/3: UV Installation Check" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    
    local install_uv_choice="n"
    # 检查 UV 是否安装（重定向输出到 stderr）
    if ! check_uv >&2; then
        echo "" >&2
        local os
        os=$(detect_os)
        if [ "$os" = "windows" ]; then
            print_warning "On Windows, UV must be installed manually in PowerShell:" >&2
            print_info "  powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\"" >&2
            echo "" >&2
            read -p "Have you already installed UV? (y/n) [n]: " uv_installed
            if [[ ! "$uv_installed" =~ ^[Yy]$ ]]; then
                print_error "Please install UV first, then run this installer again." >&2
                exit 1
            fi
        else
            read -p "Would you like to install UV now? (y/n) [y]: " install_uv_choice
            install_uv_choice=${install_uv_choice:-y}
        fi
    fi
    echo "" >&2
    
    # 步骤 3: Shell 集成配置
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "🐚 Step 3/3: Auto-Activation" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Auto-activation will automatically activate environments when you:" >&2
    echo "  • Enter a directory with .venv folder" >&2
    echo "  • Enter a directory with .uvmrc file" >&2
    echo "" >&2
    
    local enable_auto_activation="y"
    read -p "Enable auto-activation? (Y/n): " enable_auto_activation
    enable_auto_activation=${enable_auto_activation:-y}
    echo "" >&2
    
    # 返回配置结果
    echo "$envs_dir"
    echo "$install_uv_choice"
    echo "$enable_auto_activation"
}

# 主安装流程
main() {
    # 检测执行模式 (本地 vs 远程)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    local temp_dir=""
    
    # 如果 bin 目录不存在,说明是远程执行
    if [ ! -d "${script_dir}/bin" ]; then
        is_remote_install=true
        print_info "Remote installation mode detected"
        echo ""
        
        # 创建临时目录
        temp_dir=$(mktemp -d)
        
        # 设置清理陷阱
        trap 'rm -rf "$temp_dir"' EXIT
        
        # 下载文件
        if ! download_uvm_files "$temp_dir"; then
            print_error "Failed to download uvm files from GitHub"
            print_info "Please check your internet connection and try again"
            exit 1
        fi
        
        # 更新 script_dir 指向临时目录
        script_dir="$temp_dir"
        echo ""
    fi
    
    # 解析命令行参数
    local custom_envs_dir=""
    local non_interactive=false
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --envs-dir)
                custom_envs_dir="$2"
                non_interactive=true
                shift 2
                ;;
            --non-interactive|-y)
                non_interactive=true
                shift
                ;;
            --help|-h)
                cat <<EOF
UVM Installer v1.0.3

Usage: ./install.sh [OPTIONS]

OPTIONS:
    --envs-dir <path>    Custom directory for virtual environments
                         (default: ~/uv_envs)
    -y, --non-interactive
                         Non-interactive mode (use defaults)
    -h, --help           Show this help message

MODES:
    Interactive (default):
        ./install.sh
        
        Launches a step-by-step wizard to configure:
        - Environment directory location
        - UV installation (if needed)
        - Shell integration preferences
    
    Non-interactive:
        ./install.sh -y
        ./install.sh --envs-dir /custom/path

EXAMPLES:
    # Interactive installation (recommended for first-time users)
    ./install.sh
    
    # Quick install with defaults
    ./install.sh -y
    
    # Install with custom environment directory
    ./install.sh --envs-dir /mnt/data/python-envs
    
    # Install with custom directory on external drive
    ./install.sh --envs-dir /media/external/uvm-envs

EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_info "Run './install.sh --help' for usage information"
                exit 1
                ;;
        esac
    done
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  UVM Installer v1.0.3                      ║"
    echo "║          UV Manager - Conda-like Environment Manager       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 检测操作系统
    local os
    os=$(detect_os)
    print_info "Detected OS: $os"
    echo ""
    
    # 交互式配置或使用默认值
    local install_uv_choice="n"
    local enable_auto_activation="y"
    
    if [ "$non_interactive" = false ] && [ -z "$custom_envs_dir" ]; then
        # 运行交互式向导
        local config_result
        config_result=$(interactive_setup)
        custom_envs_dir=$(echo "$config_result" | sed -n '1p')
        install_uv_choice=$(echo "$config_result" | sed -n '2p')
        enable_auto_activation=$(echo "$config_result" | sed -n '3p')
    else
        print_info "Running in non-interactive mode..."
        echo ""
    fi
    
    # 检查 UV（如果在交互模式中已经处理，则跳过）
    if [ "$install_uv_choice" = "y" ] || [ "$install_uv_choice" = "Y" ]; then
        install_uv || {
            print_error "Failed to install UV"
            exit 1
        }
    elif ! check_uv && [ "$non_interactive" = false ]; then
        print_warning "Skipping UV installation. You can install it later from:"
        print_warning "  https://github.com/astral-sh/uv"
    fi
    
    echo ""
    
    # 安装 UVM (传入 script_dir)
    install_uvm "$script_dir" || {
        print_error "Failed to install uvm"
        exit 1
    }
    
    echo ""
    
    # 配置 PATH
    configure_path
    
    echo ""
    
    # 初始化配置
    initialize_config "$custom_envs_dir"
    
    # 显示安装后说明
    show_post_install "$enable_auto_activation"
}

# 执行安装
main "$@"

