#!/bin/bash

# {{RIPER-7 Action}}
# Role: LD | Task_ID: fix-shell-hook | Time: 2025-12-26T15:35:00+08:00
# Logic: 快速修复脚本，自动检测 shell 类型并添加 shell-hook
# Principle: SOLID-S (单一职责)

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== UVM Shell Hook Fix Script ===${NC}"
echo ""

# 检测当前 shell
detect_current_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        # 从 $SHELL 环境变量判断
        case "$SHELL" in
            */zsh)
                echo "zsh"
                ;;
            */bash)
                echo "bash"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    fi
}

# 获取 shell 配置文件
get_shell_rc() {
    local shell_type="$1"
    
    case "$shell_type" in
        bash)
            if [ -f "${HOME}/.bashrc" ]; then
                echo "${HOME}/.bashrc"
            else
                echo "${HOME}/.bash_profile"
            fi
            ;;
        zsh)
            echo "${HOME}/.zshrc"
            ;;
        *)
            echo "${HOME}/.profile"
            ;;
    esac
}

# 主逻辑
main() {
    # 检测 shell
    local current_shell=$(detect_current_shell)
    echo -e "${BLUE}Detected shell: ${current_shell}${NC}"
    
    if [ "$current_shell" = "unknown" ]; then
        echo -e "${YELLOW}Warning: Could not detect shell type${NC}"
        echo "Please manually add the following line to your shell config:"
        echo '  eval "$(uvm shell-hook)"'
        exit 1
    fi
    
    # 获取配置文件
    local shell_rc=$(get_shell_rc "$current_shell")
    echo -e "${BLUE}Shell config file: ${shell_rc}${NC}"
    echo ""
    
    # 检查是否已存在
    if grep -q "uvm shell-hook" "$shell_rc" 2>/dev/null; then
        echo -e "${GREEN}✓ Shell hook already configured in ${shell_rc}${NC}"
    else
        echo -e "${BLUE}Adding shell hook to ${shell_rc}...${NC}"
        
        # 添加 shell-hook
        cat >> "$shell_rc" << 'EOF'

# UVM (UV Manager) - Shell Integration
eval "$(uvm shell-hook)"
EOF
        
        echo -e "${GREEN}✓ Shell hook added${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Scanning for existing environments...${NC}"
    
    # 加载配置
    if [ -f "${HOME}/.config/uvm/config" ]; then
        source "${HOME}/.config/uvm/config"
    fi
    
    local envs_dir="${UVM_ENVS_DIR:-${HOME}/uv_envs}"
    
    if [ -d "$envs_dir" ]; then
        # 扫描环境
        uvm scan "$envs_dir"
    else
        echo -e "${YELLOW}Environment directory not found: ${envs_dir}${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}=== Fix Complete ===${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Reload your shell configuration:"
    echo -e "     ${YELLOW}source ${shell_rc}${NC}"
    echo ""
    echo "  2. Verify the fix:"
    echo -e "     ${YELLOW}type uvm${NC}  # Should show 'uvm is a function'"
    echo -e "     ${YELLOW}uvm list${NC}"
    echo -e "     ${YELLOW}uvm activate <env_name>${NC}"
    echo ""
}

main "$@"

