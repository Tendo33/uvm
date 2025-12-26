# UVM Fixes - 2025-12-26

## 问题总结

用户报告在 Windows + Git Bash + Oh My Zsh 环境下，`uvm list` 能看到环境，但 `uvm activate` 提示环境不存在。

## 根本原因

### 1. Shell Hook 未正确加载配置
**问题**: `uvm_generate_shell_hook()` 生成的代码中没有读取 `~/.config/uvm/config` 文件，导致 `UVM_ENVS_DIR` 环境变量未被正确设置。

**影响**: 当用户的环境目录不是默认的 `~/uv_envs` 时（如 `/d/envs`），shell hook 无法找到环境。

### 2. Activate 函数未使用 envs.json
**问题**: Shell hook 中的 `uvm()` 函数在激活环境时，只检查默认路径 `$UVM_ENVS_DIR/$env_name`，没有查询 `envs.json` 中注册的环境路径。

**影响**: 即使环境已注册在 `envs.json` 中，activate 命令仍然找不到。

### 3. 已存在的环境未被注册
**问题**: 用户在安装 uvm 之前创建的环境（如 `base`、`llm`）没有被自动注册到 `envs.json`。

**影响**: 这些环境无法被 uvm 管理。

## 解决方案

### 修复 1: Shell Hook 加载配置

**文件**: `lib/uvm-shell-hooks.sh`

**修改**: 在 `uvm_generate_shell_hook()` 函数开头添加配置加载逻辑

```bash
# Load UVM configuration
export UVM_HOME="${UVM_HOME:-${HOME}/.config/uvm}"
if [ -f "${UVM_HOME}/config" ]; then
    source "${UVM_HOME}/config"
fi
```

### 修复 2: Activate 函数查询 envs.json

**文件**: `lib/uvm-shell-hooks.sh`

**修改**: 
1. 添加 `_uvm_get_env_path()` 辅助函数，实现与 `uvm-config.sh` 中 `get_env_path()` 相同的逻辑
2. 修改 `uvm()` 函数的 activate 分支，使用 `_uvm_get_env_path()` 查找环境

```bash
# Helper function to get environment path
_uvm_get_env_path() {
    local env_name="$1"
    local uvm_envs_dir="${UVM_ENVS_DIR:-${HOME}/uv_envs}"
    local uvm_envs_file="${HOME}/.config/uvm/envs.json"
    
    # Try default path first
    local default_path="${uvm_envs_dir}/${env_name}"
    if [ -d "${default_path}" ]; then
        echo "${default_path}"
        return 0
    fi
    
    # Try to find in envs.json
    if [ -f "${uvm_envs_file}" ]; then
        local path=$(grep -o "\"name\":\"${env_name}\"[^}]*\"path\":\"[^\"]*\"" "${uvm_envs_file}" | grep -o "\"path\":\"[^\"]*\"" | cut -d'"' -f4)
        if [ -n "$path" ] && [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    fi
    
    return 1
}
```

### 修复 3: 自动扫描和注册已存在的环境

**新增功能**:

1. **在 `lib/uvm-config.sh` 中添加扫描函数**:
   - `is_valid_uv_env()`: 检查目录是否是有效的 UV 环境
   - `get_env_python_version()`: 获取环境的 Python 版本
   - `scan_and_register_envs()`: 扫描目录并注册所有 UV 环境

2. **在 `install.sh` 中添加自动扫描**:
   - 安装时自动扫描用户指定的环境目录
   - 注册所有已存在的 UV 环境

3. **在 `bin/uvm` 中添加 `scan` 命令**:
   - 用户可以手动运行 `uvm scan [directory]` 来注册环境
   - `uvm init` 命令也会自动执行扫描

## 使用方法

### 对于新安装用户
安装时会自动扫描并注册已存在的环境，无需额外操作。

### 对于已安装用户
运行以下命令修复：

```bash
# 方法 1: 使用快速修复脚本
./fix-shell-hook.sh

# 方法 2: 手动修复
# 1. 重新加载 shell 配置
source ~/.bashrc  # 或 ~/.zshrc

# 2. 扫描并注册环境
uvm scan /path/to/your/envs

# 3. 验证
uvm list
uvm activate <env_name>
```

## 测试验证

```bash
# 1. 清空 envs.json
echo "[]" > ~/.config/uvm/envs.json

# 2. 扫描环境
uvm scan /d/envs

# 输出:
# Scanning for existing UV environments in: /d/envs
#   ✓ Registered: base (Python 3.11.11)
#   ✓ Registered: bert (Python 3.11.11)
#   ✓ Registered: llm (Python 3.12.9)
# ✓ Registered 3 environment(s)

# 3. 验证注册
cat ~/.config/uvm/envs.json | python -m json.tool

# 4. 测试激活
uvm activate llm
# ✓ Environment 'llm' activated
```

## 文件变更清单

1. **lib/uvm-shell-hooks.sh**
   - 添加配置加载逻辑
   - 添加 `_uvm_get_env_path()` 函数
   - 修改 `uvm()` 函数的 activate 逻辑

2. **lib/uvm-config.sh**
   - 添加 `is_valid_uv_env()` 函数
   - 添加 `get_env_python_version()` 函数
   - 添加 `scan_and_register_envs()` 函数

3. **bin/uvm**
   - 在 `init` 命令中添加自动扫描
   - 添加 `scan` 命令

4. **install.sh**
   - 在 `initialize_config()` 中添加自动扫描逻辑

5. **lib/uvm-core.sh**
   - 更新帮助信息，添加 `scan` 命令说明

6. **新增文件**:
   - `TROUBLESHOOTING.md`: 详细的故障排查指南
   - `fix-shell-hook.sh`: 快速修复脚本
   - `FIXES.md`: 本文档

7. **README.md**
   - 添加故障排查章节
   - 添加 TROUBLESHOOTING.md 链接

## 兼容性

- ✅ Linux
- ✅ macOS
- ✅ Windows (Git Bash)
- ✅ Bash
- ✅ Zsh
- ✅ Oh My Zsh

## 注意事项

1. **Shell 类型检测**: 修复脚本会自动检测当前使用的 shell（bash 或 zsh），并添加 hook 到正确的配置文件。

2. **配置文件位置**: 
   - Bash: `~/.bashrc` (Linux/Git Bash) 或 `~/.bash_profile` (macOS)
   - Zsh: `~/.zshrc`

3. **环境目录**: 如果使用非默认目录，确保 `~/.config/uvm/config` 中正确设置了 `UVM_ENVS_DIR`。

4. **重新加载**: 修改配置文件后，必须重新加载才能生效：
   ```bash
   source ~/.bashrc  # 或 ~/.zshrc
   ```


