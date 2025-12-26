# 🗑️ UVM 卸载指南

本文档提供了完整的 UVM 卸载说明和常见问题解答。

---

## 📋 目录

- [快速卸载](#快速卸载)
- [卸载选项](#卸载选项)
- [卸载内容](#卸载内容)
- [保留内容](#保留内容)
- [手动卸载](#手动卸载)
- [常见问题](#常见问题)

---

## 🚀 快速卸载

### 交互式卸载（推荐）

```bash
cd /path/to/uvm
./uninstall.sh
```

**卸载过程：**

```
╔════════════════════════════════════════════════════════════╗
║                  UVM Uninstaller v1.0.0                    ║
║          UV Manager - Conda-like Environment Manager       ║
╚════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 The following will be removed:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ Binary: /home/user/.local/bin/uvm
  ✓ Library: /home/user/.local/lib/uvm
  ✓ Config: /home/user/.config/uvm
  ✓ Shell integration from: /home/user/.bashrc

⚠ Your virtual environments will NOT be removed
ℹ Environments location: /home/user/uv_envs
  (You can manually delete this directory if needed)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Do you want to continue? (y/N): y

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗑️  Uninstalling uvm...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Backed up shell config to: /home/user/.bashrc.uvm-backup-20231226-143022
✓ Removed uvm configuration from shell RC file

✓ Removed: /home/user/.local/bin/uvm
✓ Removed: /home/user/.local/lib/uvm
✓ Removed: /home/user/.config/uvm

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ uvm has been uninstalled successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 Next Steps:

   1. Reload your shell configuration:
      source ~/.bashrc  # or ~/.zshrc

   2. Your shell config backup is saved at:
      /home/user/.bashrc.uvm-backup-20231226-143022

   3. Your virtual environments are still at:
      /home/user/uv_envs

      To remove them (optional):
      rm -rf /home/user/uv_envs

💡 To reinstall uvm later:
   git clone https://github.com/yourusername/uvm.git
   cd uvm && ./install.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## ⚙️ 卸载选项

### 强制卸载（跳过确认）

```bash
./uninstall.sh --force
# 或
./uninstall.sh -f
```

适用场景：
- 自动化脚本
- 确定要卸载，不需要确认提示

### 保留 Shell 配置

```bash
./uninstall.sh --keep-shell-config
```

适用场景：
- 临时卸载，稍后会重新安装
- 想保留 `eval "$(uvm shell-hook)"` 配置

### 查看帮助

```bash
./uninstall.sh --help
```

---

## 📦 卸载内容

卸载脚本会删除以下内容：

| 项目 | 路径 | 说明 |
|------|------|------|
| **UVM 二进制文件** | `~/.local/bin/uvm` | 主执行文件 |
| **UVM 库文件** | `~/.local/lib/uvm/` | 核心功能库 |
| **UVM 配置** | `~/.config/uvm/` | 配置文件和元数据 |
| **Shell 集成** | `~/.bashrc` 或 `~/.zshrc` | `eval "$(uvm shell-hook)"` 相关行 |

### 🔒 自动备份

卸载前会自动备份您的 Shell 配置文件：

```
~/.bashrc.uvm-backup-20231226-143022
```

如果卸载后发现问题，可以恢复：

```bash
cp ~/.bashrc.uvm-backup-20231226-143022 ~/.bashrc
source ~/.bashrc
```

---

## 💾 保留内容

以下内容**不会**被删除：

### ✅ 虚拟环境目录

```
~/uv_envs/  （或您自定义的目录）
```

**原因：** 您的项目环境和已安装的包都在这里，删除可能导致数据丢失。

**如需删除：**

```bash
# 查看环境目录位置
ls -lh ~/uv_envs

# 确认后删除
rm -rf ~/uv_envs
```

### ✅ UV 本身

UV 是独立的工具，不会被卸载。

**如需卸载 UV：**

```bash
# Linux/macOS
rm -rf ~/.cargo/bin/uv ~/.local/bin/uv

# 或者使用 rustup（如果通过 cargo 安装）
cargo uninstall uv
```

### ✅ UV 配置文件

```
~/.config/uv/uv.toml
```

这是 UV 的镜像配置，不属于 UVM。

**如需删除：**

```bash
rm ~/.config/uv/uv.toml
```

---

## 🔧 手动卸载

如果卸载脚本不可用，可以手动删除：

### Linux / macOS

```bash
# 1. 删除 UVM 文件
rm -f ~/.local/bin/uvm
rm -rf ~/.local/lib/uvm
rm -rf ~/.config/uvm

# 2. 编辑 Shell 配置文件
nano ~/.bashrc  # 或 ~/.zshrc

# 删除包含 "uvm" 的行，例如：
# eval "$(uvm shell-hook)"
# export PATH="$HOME/.local/bin:$PATH"  # 如果只用于 uvm

# 3. 重新加载 Shell
source ~/.bashrc

# 4. 验证卸载
which uvm  # 应该显示 "not found"
```

### Windows (Git Bash)

```bash
# 1. 删除 UVM 文件
rm -f ~/.local/bin/uvm
rm -rf ~/.local/lib/uvm
rm -rf ~/.config/uvm

# 2. 编辑 .bashrc
nano ~/.bashrc

# 删除包含 "uvm" 的行

# 3. 重新加载
source ~/.bashrc

# 4. 验证
which uvm
```

---

## ❓ 常见问题

### Q1: 卸载后还能使用 `uv` 命令吗？

**A:** 可以！`uv` 是独立的工具，卸载 UVM 不影响 `uv` 的使用。

```bash
uv --version  # 仍然可用
```

### Q2: 卸载后我的虚拟环境还在吗？

**A:** 是的，虚拟环境不会被删除。您可以继续使用标准方式激活：

```bash
source ~/uv_envs/myenv/bin/activate
```

### Q3: 如何完全清理所有相关文件？

**A:** 运行卸载脚本后，手动删除环境目录和 UV 配置：

```bash
# 卸载 UVM
./uninstall.sh --force

# 删除虚拟环境
rm -rf ~/uv_envs

# 删除 UV 配置（可选）
rm -rf ~/.config/uv

# 卸载 UV（可选）
rm -rf ~/.cargo/bin/uv ~/.local/bin/uv
```

### Q4: 卸载后如何重新安装？

**A:** 重新运行安装脚本：

```bash
cd /path/to/uvm
./install.sh
```

如果您保留了环境目录，重新安装后可以继续使用原有环境。

### Q5: 卸载时提示 "No uvm installation found"？

**A:** 这表示 UVM 已经被卸载或从未安装。您可以：

```bash
# 检查是否有残留文件
ls -la ~/.local/bin/uvm
ls -la ~/.local/lib/uvm
ls -la ~/.config/uvm

# 如果有，手动删除
rm -rf ~/.local/bin/uvm ~/.local/lib/uvm ~/.config/uvm
```

### Q6: 卸载后 Shell 配置文件损坏了怎么办？

**A:** 使用自动备份恢复：

```bash
# 查找备份文件
ls -la ~/.bashrc.uvm-backup-*

# 恢复最新的备份
cp ~/.bashrc.uvm-backup-20231226-143022 ~/.bashrc

# 重新加载
source ~/.bashrc
```

### Q7: 可以只删除 Shell 集成，保留 UVM 吗？

**A:** 可以，手动编辑 Shell 配置文件：

```bash
nano ~/.bashrc

# 删除或注释这一行：
# eval "$(uvm shell-hook)"

# 保存后重新加载
source ~/.bashrc
```

这样 `uvm` 命令仍然可用，但不会自动激活环境。

### Q8: 卸载脚本会删除我的项目代码吗？

**A:** 不会！卸载脚本只删除 UVM 自身的文件，不会触及：
- 您的项目代码
- 虚拟环境目录
- 任何用户数据

---

## 🔄 卸载后重新安装

如果您改变主意，随时可以重新安装：

```bash
# 1. 进入 UVM 源码目录
cd /path/to/uvm

# 2. 运行安装脚本
./install.sh

# 3. 如果您保留了环境目录，原有环境会自动识别
uvm list
```

---

## 📞 需要帮助？

如果卸载过程中遇到问题：

1. **查看日志：** 卸载脚本会显示详细的操作信息
2. **检查备份：** Shell 配置文件会自动备份
3. **手动清理：** 参考 [手动卸载](#手动卸载) 章节
4. **提交 Issue：** 在 GitHub 上报告问题

---

## 📝 卸载检查清单

完成卸载后，验证以下项目：

- [ ] `which uvm` 返回 "not found"
- [ ] `~/.local/bin/uvm` 不存在
- [ ] `~/.local/lib/uvm` 不存在
- [ ] `~/.config/uvm` 不存在
- [ ] Shell 配置文件中没有 `uvm` 相关行
- [ ] 新开终端不会加载 UVM
- [ ] （可选）虚拟环境目录已删除
- [ ] （可选）UV 配置已删除

---

## 💡 提示

- **卸载前备份：** 如果不确定，先备份重要的虚拟环境
- **保留环境：** 卸载 UVM 不会影响虚拟环境的使用
- **清理空间：** 如果磁盘空间紧张，记得删除不需要的环境目录
- **重新安装：** 卸载后可以随时重新安装，不会丢失数据

---

**感谢使用 UVM！** 🙏

如果您有任何反馈或建议，欢迎在 GitHub 上提交 Issue 或 Pull Request。

