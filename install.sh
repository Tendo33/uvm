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
        local uv_version=$(uv --version 2>&1 | head -n 1)
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
    
    local os=$(detect_os)
    
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
    print_info "Installing uvm..."
    
    # 确定安装目录
    local install_dir="${HOME}/.local/bin"
    local uvm_lib_dir="${HOME}/.local/lib/uvm"
    
    # 创建目录
    mkdir -p "$install_dir"
    mkdir -p "$uvm_lib_dir"
    
    # 获取脚本所在目录
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
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
    print_info "Initializing uvm configuration..."
    
    # 创建配置目录
    mkdir -p "${HOME}/.config/uvm"
    mkdir -p "${HOME}/uv_envs"
    
    # 初始化环境列表
    if [ ! -f "${HOME}/.config/uvm/envs.json" ]; then
        echo "[]" > "${HOME}/.config/uvm/envs.json"
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

# 显示安装后说明
show_post_install() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "uvm installed successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 Installation Details:"
    echo "   Binary: ${HOME}/.local/bin/uvm"
    echo "   Library: ${HOME}/.local/lib/uvm"
    echo "   Config: ${HOME}/.config/uvm"
    echo "   Environments: ${HOME}/uv_envs"
    echo ""
    echo "🚀 Quick Start:"
    echo "   1. Reload your shell configuration:"
    echo "      source ~/.bashrc  # or ~/.zshrc"
    echo ""
    echo "   2. Enable auto-activation (optional but recommended):"
    echo "      echo 'eval \"\$(uvm shell-hook)\"' >> ~/.bashrc"
    echo "      source ~/.bashrc"
    echo ""
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

# 主安装流程
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  UVM Installer v1.0.0                      ║"
    echo "║          UV Manager - Conda-like Environment Manager       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 检测操作系统
    local os=$(detect_os)
    print_info "Detected OS: $os"
    echo ""
    
    # 检查 UV
    if ! check_uv; then
        echo ""
        read -p "UV is not installed. Do you want to install it now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_uv || {
                print_error "Failed to install UV"
                exit 1
            }
        else
            print_warning "Skipping UV installation. You can install it later from:"
            print_warning "  https://github.com/astral-sh/uv"
        fi
    fi
    
    echo ""
    
    # 安装 UVM
    install_uvm || {
        print_error "Failed to install uvm"
        exit 1
    }
    
    echo ""
    
    # 配置 PATH
    configure_path
    
    echo ""
    
    # 初始化配置
    initialize_config
    
    # 显示安装后说明
    show_post_install
}

# 执行安装
main "$@"

