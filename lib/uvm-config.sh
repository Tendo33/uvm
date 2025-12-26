#!/bin/bash

# 设置 UV 镜像源（清华大学镜像）
setup_uv_mirror() {
    local uv_config_dir="${HOME}/.config/uv"
    local uv_config_file="${uv_config_dir}/uv.toml"
    
    # 创建配置目录
    mkdir -p "${uv_config_dir}"
    
    # 检查是否已配置
    if [ -f "${uv_config_file}" ]; then
        if grep -q "pypi.tuna.tsinghua.edu.cn" "${uv_config_file}" 2>/dev/null; then
            echo "✓ UV mirror already configured"
            return 0
        fi
        echo "⚠️  Backing up existing uv.toml to uv.toml.backup"
        cp "${uv_config_file}" "${uv_config_file}.backup"
    fi
    
    # 写入镜像配置
    cat > "${uv_config_file}" <<'EOF'
# UV 镜像配置 - 由 uvm 自动生成
# PyPI 镜像源（清华大学镜像）
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true

# Python 解释器下载镜像
[python-downloads]
url = "https://mirrors.tuna.tsinghua.edu.cn/python-releases/"
EOF
    
    if [ $? -eq 0 ]; then
        echo "✓ UV mirror configured successfully"
        echo "  PyPI: https://pypi.tuna.tsinghua.edu.cn/simple"
        echo "  Python: https://mirrors.tuna.tsinghua.edu.cn/python-releases/"
        return 0
    else
        echo "✗ Failed to configure UV mirror"
        return 1
    fi
}

# 初始化 UVM 配置目录
init_uvm_config() {
    local uvm_config_dir="${HOME}/.config/uvm"
    local uvm_envs_file="${uvm_config_dir}/envs.json"
    
    # 创建配置目录
    mkdir -p "${uvm_config_dir}"
    
    # 初始化环境列表文件
    if [ ! -f "${uvm_envs_file}" ]; then
        echo "[]" > "${uvm_envs_file}"
        echo "✓ Initialized uvm config directory: ${uvm_config_dir}"
    fi
    
    return 0
}

# 检查是否是有效的 UV 虚拟环境
is_valid_uv_env() {
    local env_path="$1"
    
    # 检查是否存在激活脚本
    if [ -f "${env_path}/bin/activate" ] || [ -f "${env_path}/Scripts/activate" ]; then
        # 检查是否有 pyvenv.cfg（UV 和 venv 都会创建）
        if [ -f "${env_path}/pyvenv.cfg" ]; then
            return 0
        fi
    fi
    
    return 1
}

# 获取环境的 Python 版本
get_env_python_version() {
    local env_path="$1"
    local python_version="unknown"
    
    # 尝试从 Python 可执行文件获取版本
    if [ -f "${env_path}/bin/python" ]; then
        python_version=$("${env_path}/bin/python" --version 2>&1 | cut -d' ' -f2)
    elif [ -f "${env_path}/Scripts/python.exe" ]; then
        python_version=$("${env_path}/Scripts/python.exe" --version 2>&1 | cut -d' ' -f2)
    fi
    
    echo "$python_version"
}

# 扫描并注册指定目录下的所有 UV 环境
scan_and_register_envs() {
    local scan_dir="$1"
    local uvm_envs_file="${HOME}/.config/uvm/envs.json"
    local registered_count=0
    
    # 确保配置已初始化
    init_uvm_config
    
    # 检查目录是否存在
    if [ ! -d "$scan_dir" ]; then
        return 0
    fi
    
    echo "Scanning for existing UV environments in: ${scan_dir}"
    
    # 读取已注册的环境名称
    local existing_envs=""
    if [ -f "${uvm_envs_file}" ]; then
        existing_envs=$(grep -o "\"name\":\"[^\"]*\"" "${uvm_envs_file}" 2>/dev/null | cut -d'"' -f4 || true)
    fi
    
    # 扫描目录
    for env_dir in "${scan_dir}"/*; do
        if [ -d "$env_dir" ]; then
            local env_name=$(basename "$env_dir")
            
            # 跳过隐藏目录和特殊目录
            if [[ "$env_name" == .* ]] || [[ "$env_name" == "desktop.ini" ]]; then
                continue
            fi
            
            # 检查是否已注册
            if echo "$existing_envs" | grep -q "^${env_name}$"; then
                continue
            fi
            
            # 检查是否是有效的 UV 环境
            if is_valid_uv_env "$env_dir"; then
                local python_version=$(get_env_python_version "$env_dir")
                
                # 注册环境
                add_env_record "$env_name" "$env_dir" "$python_version"
                echo "  ✓ Registered: ${env_name} (Python ${python_version})"
                registered_count=$((registered_count + 1))
            fi
        fi
    done
    
    if [ $registered_count -eq 0 ]; then
        echo "  No new environments found"
    else
        echo "✓ Registered ${registered_count} environment(s)"
    fi
    
    return 0
}

# 添加环境记录到元数据
add_env_record() {
    local env_name="$1"
    local env_path="$2"
    local python_version="$3"
    local uvm_envs_file="${HOME}/.config/uvm/envs.json"
    
    # 确保配置目录存在
    init_uvm_config
    
    # 生成时间戳（跨平台兼容）
    local timestamp
    if date --version >/dev/null 2>&1; then
        # GNU date
        timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
    else
        # BSD date (macOS)
        timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
    fi
    
    # 创建 JSON 记录
    local record="{\"name\":\"${env_name}\",\"path\":\"${env_path}\",\"python\":\"${python_version}\",\"created\":\"${timestamp}\"}"
    
    # 追加到文件（简单实现，不做去重）
    if [ -f "${uvm_envs_file}" ]; then
        # 读取现有内容，去除结尾的 ]，添加新记录
        local content=$(cat "${uvm_envs_file}")
        if [ "$content" = "[]" ]; then
            echo "[${record}]" > "${uvm_envs_file}"
        else
            # 移除最后的 ]，添加逗号和新记录
            echo "${content%]},${record}]" > "${uvm_envs_file}"
        fi
    fi
}

# 删除环境记录
remove_env_record() {
    local env_name="$1"
    local uvm_envs_file="${HOME}/.config/uvm/envs.json"
    
    if [ ! -f "${uvm_envs_file}" ]; then
        return 0
    fi
    
    # 使用临时文件过滤（简单实现）
    local temp_file=$(mktemp)
    grep -v "\"name\":\"${env_name}\"" "${uvm_envs_file}" > "${temp_file}" || true
    mv "${temp_file}" "${uvm_envs_file}"
}

# 获取环境路径
get_env_path() {
    local env_name="$1"
    local uvm_envs_dir="${UVM_ENVS_DIR:-${HOME}/uv_envs}"
    
    # 默认路径
    local default_path="${uvm_envs_dir}/${env_name}"
    
    if [ -d "${default_path}" ]; then
        echo "${default_path}"
        return 0
    fi
    
    # 从元数据中查找
    local uvm_envs_file="${HOME}/.config/uvm/envs.json"
    if [ -f "${uvm_envs_file}" ]; then
        # 简单的 grep 提取（生产环境应使用 jq）
        local path=$(grep -o "\"name\":\"${env_name}\"[^}]*\"path\":\"[^\"]*\"" "${uvm_envs_file}" | grep -o "\"path\":\"[^\"]*\"" | cut -d'"' -f4)
        if [ -n "$path" ] && [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    fi
    
    return 1
}

# 检测 Shell 类型
detect_shell() {
    if [ -n "$BASH_VERSION" ]; then
        echo "bash"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    else
        echo "unknown"
    fi
}

# 获取 Shell 配置文件路径
get_shell_rc_file() {
    local shell_type=$(detect_shell)
    
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

