#!/usr/bin/env bash
# UVM Uninstaller
# Safely removes uvm from your system

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# 检测 Shell RC 文件
detect_shell_rc() {
    if [ -n "$BASH_VERSION" ]; then
        echo "$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "$HOME/.zshrc"
    else
        echo "$HOME/.bashrc"
    fi
}

# 显示标题
show_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  UVM Uninstaller v1.0.1                    ║"
    echo "║          UV Manager - Conda-like Environment Manager       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

# 显示将要删除的内容
show_removal_plan() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 The following will be removed:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local items_to_remove=()
    
    # 检查各个组件
    if [ -f "$HOME/.local/bin/uvm" ]; then
        items_to_remove+=("  ✓ Binary: $HOME/.local/bin/uvm")
    fi
    
    if [ -d "$HOME/.local/lib/uvm" ]; then
        items_to_remove+=("  ✓ Library: $HOME/.local/lib/uvm")
    fi
    
    if [ -d "$HOME/.config/uvm" ]; then
        items_to_remove+=("  ✓ Config: $HOME/.config/uvm")
    fi
    
    local shell_rc=$(detect_shell_rc)
    if [ -f "$shell_rc" ] && grep -q "uvm" "$shell_rc" 2>/dev/null; then
        items_to_remove+=("  ✓ Shell integration from: $shell_rc")
    fi
    
    if [ ${#items_to_remove[@]} -eq 0 ]; then
        print_warning "No uvm installation found"
        echo ""
        echo "Nothing to uninstall."
        exit 0
    fi
    
    for item in "${items_to_remove[@]}"; do
        echo "$item"
    done
    
    echo ""
    print_warning "Your virtual environments will NOT be removed"
    
    # 显示环境目录位置
    local envs_dir="$HOME/uv_envs"
    if [ -f "$HOME/.config/uvm/config" ]; then
        local configured_dir=$(grep "UVM_ENVS_DIR=" "$HOME/.config/uvm/config" 2>/dev/null | cut -d'"' -f2)
        if [ -n "$configured_dir" ]; then
            envs_dir="$configured_dir"
        fi
    fi
    
    if [ -d "$envs_dir" ]; then
        print_info "Environments location: $envs_dir"
        echo "  (You can manually delete this directory if needed)"
    fi
    
    echo ""
}

# 备份 Shell RC 文件
backup_shell_rc() {
    local shell_rc="$1"
    local backup_file="${shell_rc}.uvm-backup-$(date +%Y%m%d-%H%M%S)"
    
    if [ -f "$shell_rc" ]; then
        cp "$shell_rc" "$backup_file"
        print_success "Backed up shell config to: $backup_file"
        echo "$backup_file"
    fi
}

# 从 Shell RC 文件中移除 uvm 相关配置
remove_from_shell_rc() {
    local shell_rc="$1"
    
    if [ ! -f "$shell_rc" ]; then
        return 0
    fi
    
    # 检查是否有 uvm 相关内容
    if ! grep -q "uvm" "$shell_rc" 2>/dev/null; then
        return 0
    fi
    
    print_info "Removing uvm from: $shell_rc"
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 移除包含 uvm 的行
    grep -v "uvm" "$shell_rc" > "$temp_file" || true
    
    # 替换原文件
    mv "$temp_file" "$shell_rc"
    
    print_success "Removed uvm configuration from shell RC file"
}

# 删除文件和目录
remove_files() {
    local removed_count=0
    
    # 删除二进制文件
    if [ -f "$HOME/.local/bin/uvm" ]; then
        rm -f "$HOME/.local/bin/uvm"
        print_success "Removed: $HOME/.local/bin/uvm"
        ((removed_count++))
    fi
    
    # 删除库文件
    if [ -d "$HOME/.local/lib/uvm" ]; then
        rm -rf "$HOME/.local/lib/uvm"
        print_success "Removed: $HOME/.local/lib/uvm"
        ((removed_count++))
    fi
    
    # 删除配置目录
    if [ -d "$HOME/.config/uvm" ]; then
        rm -rf "$HOME/.config/uvm"
        print_success "Removed: $HOME/.config/uvm"
        ((removed_count++))
    fi
    
    return $removed_count
}

# 显示卸载后说明
show_post_uninstall() {
    local backup_file="$1"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "uvm has been uninstalled successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "📝 Next Steps:"
    echo ""
    echo "   1. Reload your shell configuration:"
    echo "      source ~/.bashrc  # or ~/.zshrc"
    echo ""
    
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        echo "   2. Your shell config backup is saved at:"
        echo "      $backup_file"
        echo ""
    fi
    
    # 显示环境目录信息
    local envs_dir="$HOME/uv_envs"
    if [ -d "$envs_dir" ]; then
        echo "   3. Your virtual environments are still at:"
        echo "      $envs_dir"
        echo ""
        echo "      To remove them (optional):"
        echo "      rm -rf $envs_dir"
        echo ""
    fi
    
    echo "💡 To reinstall uvm later:"
    echo "   git clone https://github.com/Tendo33/uvm.git"
    echo "   cd uvm && ./install.sh"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 主卸载流程
main() {
    local force_mode=false
    local keep_shell_config=false
    
    # 解析命令行参数
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
                cat <<EOF
UVM Uninstaller v1.0.0

Usage: ./uninstall.sh [OPTIONS]

OPTIONS:
    -f, --force              Skip confirmation prompt
    --keep-shell-config      Keep uvm configuration in shell RC file
    -h, --help               Show this help message

EXAMPLES:
    # Interactive uninstall (recommended)
    ./uninstall.sh
    
    # Force uninstall without confirmation
    ./uninstall.sh --force
    
    # Uninstall but keep shell configuration
    ./uninstall.sh --keep-shell-config

WHAT GETS REMOVED:
    • Binary: ~/.local/bin/uvm
    • Library: ~/.local/lib/uvm
    • Config: ~/.config/uvm
    • Shell integration (unless --keep-shell-config is used)

WHAT STAYS:
    • Your virtual environments (~/uv_envs or custom location)
    • UV itself (the underlying tool)

EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run './uninstall.sh --help' for usage information"
                exit 1
                ;;
        esac
    done
    
    show_header
    show_removal_plan
    
    # 确认卸载
    if [ "$force_mode" = false ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        read -p "Do you want to continue? (y/N): " confirm
        echo ""
        
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Uninstallation cancelled"
            exit 0
        fi
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🗑️  Uninstalling uvm..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 备份并移除 Shell 配置
    local backup_file=""
    if [ "$keep_shell_config" = false ]; then
        local shell_rc=$(detect_shell_rc)
        backup_file=$(backup_shell_rc "$shell_rc")
        remove_from_shell_rc "$shell_rc"
        echo ""
    else
        print_info "Keeping shell configuration (--keep-shell-config)"
        echo ""
    fi
    
    # 删除文件
    remove_files
    echo ""
    
    # 显示完成信息
    show_post_uninstall "$backup_file"
}

# 运行主函数
main "$@"

