# uvm 快速入门指南

5 分钟快速上手 uvm！

## 🚀 安装（2 分钟）

### 推荐方式：先下载后执行

**Linux / macOS：**

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh

# 执行安装（交互式向导）
bash install.sh

# 按照向导进行：
# - 第 1/3 步：环境目录（默认：~/uv_envs，按回车或输入自定义路径）
# - 第 2/3 步：安装 UV（如未安装会自动检测）
# - 第 3/3 步：启用自动激活？（默认：是）

# 重新加载 Shell
source ~/.bashrc  # 或 ~/.zshrc
```

### Windows（Git Bash）

```bash
# 1. 首先在 PowerShell 中安装 UV
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# 2. 在 Git Bash 中下载并执行安装脚本
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh

# 3. 重新加载 Shell
source ~/.bashrc
```

### 快速安装（跳过向导）

```bash
# 使用默认配置
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh -y
```

## 🎯 启用自动激活（30 秒）

```bash
# 将 Shell 集成添加到 ~/.bashrc 或 ~/.zshrc
echo 'eval "$(uvm shell-hook)"' >> ~/.bashrc
source ~/.bashrc
```

## 📦 创建第一个环境（1 分钟）

```bash
# 创建 Python 3.11 环境
uvm create myenv --python 3.11

# 激活环境
uvm activate myenv

# 安装一些包
pip install requests numpy pandas

# 验证
python -c "import pandas; print('✓ pandas 已安装')"
```

## 🔄 体验自动激活（2 分钟）

### 方式 1：本地项目环境

```bash
# 创建新项目
mkdir ~/my-project
cd ~/my-project

# 创建本地 .venv
uv venv
uv pip install requests

# 离开并重新进入 - 观察自动激活！
cd ~
cd ~/my-project
# 🔄 Auto-activating local .venv
```

### 方式 2：共享环境

```bash
# 创建共享环境
uvm create shared-env --python 3.11

# 创建使用它的项目
mkdir ~/another-project
cd ~/another-project
echo "shared-env" > .uvmrc

# 进入目录 - 自动激活！
cd ~/another-project
# 🔄 Auto-activating uvm environment: shared-env
```

## 🎉 准备就绪！

常用命令：

```bash
uvm list          # 列出所有环境
uvm activate env  # 激活环境
uvm deactivate    # 停用当前环境
uvm delete env    # 删除环境
uvm help          # 显示帮助
```

## 📚 下一步

- 阅读完整的 [README.md](../README.md) 获取详细文档
- 查看 [EXAMPLES.md](../EXAMPLES.md) 了解真实使用场景
- 使用 `uvm config` 配置自定义设置

## 🗑️ 卸载

如需移除 UVM：

```bash
# 下载并执行卸载脚本
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/uninstall.sh -o uninstall.sh
bash uninstall.sh
```

**卸载过程：**
- ✅ 移除 UVM 文件
- ✅ 清理 Shell 集成
- ✅ 保留您的环境

📖 **完整指南：** [UNINSTALL.md](UNINSTALL.md)

---

## ❓ 需要帮助？

- 运行 `uvm help` 查看命令参考
- 查看 [README.md#故障排除](../README.md#-故障排除) 解决常见问题
- 在 GitHub 上提交 Issue

---

**使用 uvm 愉快编码！🎉**
