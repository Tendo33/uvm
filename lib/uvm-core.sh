#!/bin/bash

# 加载配置模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/uvm-config.sh"

# 创建虚拟环境
uvm_create() {
    local env_name=""
    local python_version=""
    local custom_path=""
    
    # 解析参数
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
    
    # 检查环境名称
    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required"
        echo "Usage: uvm create <env_name> [--python VERSION] [--path PATH]"
        return 1
    fi
    
    # 检查 uv 是否安装
    if ! command -v uv &> /dev/null; then
        echo "Error: 'uv' is not installed. Please install it first."
        echo "Visit: https://github.com/astral-sh/uv"
        return 1
    fi
    
    # 确定环境路径
    local uvm_envs_dir="${UVM_ENVS_DIR:-${HOME}/uv_envs}"
    local env_path="${custom_path:-${uvm_envs_dir}/${env_name}}"
    
    # 检查环境是否已存在
    if [ -d "$env_path" ]; then
        echo "Error: Environment '${env_name}' already exists at: ${env_path}"
        return 1
    fi
    
    # 创建环境目录（如果使用默认路径）
    if [ -z "$custom_path" ]; then
        mkdir -p "$uvm_envs_dir"
    fi
    
    # 调用 uv venv 创建环境
    echo "Creating environment '${env_name}'..."
    if [ -n "$python_version" ]; then
        echo "  Python version: ${python_version}"
        uv venv "$env_path" --python "$python_version"
    else
        uv venv "$env_path"
    fi
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create environment"
        return 1
    fi
    
    # 获取 Python 版本
    local actual_python_version=""
    if [ -f "${env_path}/bin/python" ]; then
        actual_python_version=$("${env_path}/bin/python" --version 2>&1 | cut -d' ' -f2)
    elif [ -f "${env_path}/Scripts/python.exe" ]; then
        # Windows Git Bash
        actual_python_version=$("${env_path}/Scripts/python.exe" --version 2>&1 | cut -d' ' -f2)
    fi
    
    # 记录环境元数据
    add_env_record "$env_name" "$env_path" "$actual_python_version"
    
    echo "✓ Environment '${env_name}' created successfully"
    echo "  Location: ${env_path}"
    echo "  Python: ${actual_python_version}"
    echo ""
    echo "To activate: uvm activate ${env_name}"
}

# 激活虚拟环境
uvm_activate() {
    local env_name="$1"
    
    if [ -z "$env_name" ]; then
        echo "Error: Environment name is required"
        echo "Usage: uvm activate <env_name>"
        return 1
    fi
    
    # 查找环境路径
    local env_path=$(get_env_path "$env_name")
    
    if [ -z "$env_path" ]; then
        echo "Error: Environment '${env_name}' not found"
        echo "Run 'uvm list' to see available environments"
        return 1
    fi
    
    # 检查激活脚本
    local activate_script=""
    if [ -f "${env_path}/bin/activate" ]; then
        activate_script="${env_path}/bin/activate"
    elif [ -f "${env_path}/Scripts/activate" ]; then
        # Windows Git Bash
        activate_script="${env_path}/Scripts/activate"
    else
        echo "Error: Activate script not found in: ${env_path}"
        return 1
    fi
    
    # 激活环境
    echo "Activating environment '${env_name}'..."
    source "$activate_script"
    
    if [ $? -eq 0 ]; then
        export UVM_ACTIVE_ENV="$env_name"
        echo "✓ Environment '${env_name}' activated"
    else
        echo "Error: Failed to activate environment"
        return 1
    fi
}

# 停用虚拟环境
uvm_deactivate() {
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "No active environment to deactivate"
        return 0
    fi
    
    if command -v deactivate &> /dev/null; then
        deactivate
        unset UVM_ACTIVE_ENV
        unset UVM_AUTO_ACTIVATED
        echo "✓ Environment deactivated"
    else
        echo "Error: deactivate command not found"
        return 1
    fi
}

# 删除虚拟环境
uvm_delete() {
    local env_name="$1"
    local force=false
    
    # 解析参数
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
    
    # 查找环境路径
    local env_path=$(get_env_path "$env_name")
    
    if [ -z "$env_path" ]; then
        echo "Error: Environment '${env_name}' not found"
        return 1
    fi
    
    # 检查是否正在使用
    if [ "$VIRTUAL_ENV" = "$env_path" ]; then
        echo "Error: Cannot delete active environment. Deactivate it first."
        return 1
    fi
    
    # 确认删除
    if [ "$force" = false ]; then
        echo "Are you sure you want to delete '${env_name}'? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Deletion cancelled"
            return 0
        fi
    fi
    
    # 删除环境目录
    echo "Deleting environment '${env_name}'..."
    rm -rf "$env_path"
    
    if [ $? -eq 0 ]; then
        # 删除元数据记录
        remove_env_record "$env_name"
        echo "✓ Environment '${env_name}' deleted successfully"
    else
        echo "Error: Failed to delete environment"
        return 1
    fi
}

# 列出所有虚拟环境
uvm_list() {
    local uvm_envs_dir="${UVM_ENVS_DIR:-${HOME}/uv_envs}"
    local show_all=false
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -a|--all)
                show_all=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo "Available environments:"
    echo ""
    
    local found_any=false
    
    # 列出默认目录中的环境
    if [ -d "$uvm_envs_dir" ]; then
        for env_dir in "$uvm_envs_dir"/*; do
            if [ -d "$env_dir" ]; then
                local env_name=$(basename "$env_dir")
                
                # 检查是否是有效的虚拟环境
                local activate_script=""
                if [ -f "${env_dir}/bin/activate" ]; then
                    activate_script="${env_dir}/bin/activate"
                elif [ -f "${env_dir}/Scripts/activate" ]; then
                    activate_script="${env_dir}/Scripts/activate"
                fi
                
                if [ -n "$activate_script" ]; then
                    found_any=true
                    
                    # 获取 Python 版本
                    local python_version="unknown"
                    if [ -f "${env_dir}/bin/python" ]; then
                        python_version=$("${env_dir}/bin/python" --version 2>&1 | cut -d' ' -f2)
                    elif [ -f "${env_dir}/Scripts/python.exe" ]; then
                        python_version=$("${env_dir}/Scripts/python.exe" --version 2>&1 | cut -d' ' -f2)
                    fi
                    
                    # 标记当前激活的环境
                    local marker="  "
                    if [ "$VIRTUAL_ENV" = "$env_dir" ]; then
                        marker="* "
                    fi
                    
                    printf "${marker}%-25s Python %-10s %s\n" "$env_name" "$python_version" "$env_dir"
                fi
            fi
        done
    fi
    
    if [ "$found_any" = false ]; then
        echo "  No environments found"
        echo ""
        echo "Create one with: uvm create <env_name>"
    fi
    
    echo ""
}

# 显示帮助信息
uvm_help() {
    cat <<'EOF'
uvm - UV Manager

A Conda-like environment manager for UV (Python package manager)

USAGE:
    uvm <command> [options]

COMMANDS:
    create <name>              Create a new virtual environment
        --python <version>     Specify Python version (e.g., 3.11)
        --path <path>          Custom environment location
    
    activate <name>            Activate an environment
    
    deactivate                 Deactivate current environment
    
    delete <name>              Delete an environment
        -f, --force            Skip confirmation prompt
    
    list                       List all environments
        -a, --all              Show all details
    
    scan [directory]           Scan and register existing UV environments
                               (default: scans UVM_ENVS_DIR)
    
    help                       Show this help message

EXAMPLES:
    # Create environment with Python 3.11
    uvm create myenv --python 3.11
    
    # Activate environment
    uvm activate myenv
    
    # List all environments
    uvm list
    
    # Delete environment
    uvm delete myenv

AUTO-ACTIVATION:
    uvm supports automatic environment activation:
    
    1. Local .venv (highest priority)
       - Automatically detects .venv in current or parent directories
       - No configuration needed
    
    2. Shared environment via .uvmrc
       - Create .uvmrc file with environment name
       - Environment auto-activates when entering directory
    
    To enable auto-activation, add to ~/.bashrc or ~/.zshrc:
        eval "$(uvm shell-hook)"

CONFIGURATION:
    Default environment directory: ~/uv_envs/
    Config directory: ~/.config/uvm/
    UV config: ~/.config/uv/uv.toml

For more information, visit: https://github.com/Tendo33/uvm
EOF
}

