# UVM 卸载指南

本文档说明当前版本 `uninstall.sh` 的真实行为、保留项、可选参数以及手动清理方法。以下内容已对齐 `1.1.0` 的卸载实现。

---

## 1. 快速卸载

推荐先下载脚本，再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/uninstall.sh -o uninstall.sh
bash uninstall.sh
rm uninstall.sh
```

如果你是在仓库本地执行：

```bash
cd /path/to/uvm
bash uninstall.sh
```

---

## 2. 可选参数

### `--force`

跳过确认提示：

```bash
bash uninstall.sh --force
```

适用场景：

- 自动化脚本
- CI 清理
- 已确认要卸载，不需要交互确认

### `--keep-shell-config`

保留 shell 配置中的 `uvm` 受管 block：

```bash
bash uninstall.sh --keep-shell-config
```

适用场景：

- 只想移除二进制和库文件
- 准备稍后重新安装
- 想暂时保留 shell hook 与 PATH 配置

---

## 3. 卸载时会删除什么

默认会删除以下内容：

- `~/.local/bin/uvm`
- `~/.local/lib/uvm`
- `~/.config/uvm`
- shell rc 中由 `uvm` 管理的受管 block

shell block 是按起止标记精确删除的，而不是删除所有包含 `uvm` 的行。

受管标记示例：

```bash
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<

# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
```

---

## 4. 卸载时会保留什么

默认会保留以下内容：

- 你的虚拟环境目录
- `uv`
- `~/.config/uv/uv.toml`

说明：

- `uvm` 不会主动删除你创建的环境目录
- `uvm` 也不会删除 `uv` 本体
- `uv` 的配置文件不会被卸载脚本清理

---

## 5. 卸载流程说明

当前版本的卸载流程大致如下：

1. 检测并展示待删除项
2. 解析当前 shell 对应的 rc 文件
3. 若未使用 `--keep-shell-config`，先备份 shell rc
4. 按受管 block 起止标记删除 `uvm` 写入内容
5. 删除二进制、库目录和 `~/.config/uvm`
6. 输出保留项与后续建议

这一流程已经修复了旧版在 `set -e` 下可能提前中断的问题。

---

## 6. shell 配置备份

如果 shell rc 文件存在，卸载前会自动创建备份，文件名类似：

```text
~/.bashrc.uvm-backup-20260412-101530
```

如果卸载后你想恢复原文件，可以手动执行：

```bash
cp ~/.bashrc.uvm-backup-20260412-101530 ~/.bashrc
source ~/.bashrc
```

---

## 7. 卸载后的建议动作

卸载完成后，建议：

1. 重新加载 shell 配置
2. 确认 `uvm` 命令已不可用
3. 如无需要，再手动清理虚拟环境目录

示例：

```bash
source ~/.bashrc   # 或 ~/.zshrc
which uvm
```

---

## 8. 手动清理方法

如果你不想使用脚本，也可以手动清理：

```bash
rm -f ~/.local/bin/uvm
rm -rf ~/.local/lib/uvm
rm -rf ~/.config/uvm
```

然后编辑对应 shell rc 文件，删除以下受管 block：

```bash
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<

# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
```

注意：

- 只删除这两个 block，不要粗暴删除所有包含 `uvm` 的行
- 如果你还在其他地方手写过 `uvm` 相关配置，需要自行判断是否保留

---

## 9. 如果还想删除虚拟环境

卸载 `uvm` 后，环境目录仍然会保留。确认不再需要时，你可以手动删除：

```bash
rm -rf ~/uv_envs
```

如果你安装时使用了自定义 `UVM_ENVS_DIR`，请删除对应目录，而不是默认写死删除 `~/uv_envs`。

---

## 10. 如果还想删除 `uv`

`uvm` 不会卸载 `uv`。如需删除，请按你自己的 `uv` 安装方式处理。

例如：

```bash
uv --version
```

确认不需要后，再按照 `uv` 官方安装方式对应的卸载方法执行。

---

## 11. 常见问题

### 卸载会删除我的虚拟环境吗？

不会。`uninstall.sh` 只删除 `uvm` 本身及其受管配置，不删除你的环境目录。

### 卸载会删除 `uv.toml` 吗？

不会。`~/.config/uv/uv.toml` 会被保留。

### 卸载会破坏我的 shell rc 吗？

当前版本会先备份，再删除受管 block。它不再使用旧版那种按关键字粗暴过滤的方式，因此风险明显更低。

### `--keep-shell-config` 是做什么的？

它会保留 shell rc 中由 `uvm` 写入的 PATH 与 shell hook block，仅删除 `uvm` 二进制、库与配置目录。

### 卸载后还能继续手动使用已有环境吗？

可以。只要环境目录还在，你依然可以用标准方式手动激活：

```bash
source /path/to/env/bin/activate
```

---

## 12. 卸载检查清单

卸载完成后，可按下面清单检查：

- `which uvm` 不再返回可执行路径
- `~/.local/bin/uvm` 已不存在
- `~/.local/lib/uvm` 已不存在
- `~/.config/uvm` 已不存在
- shell rc 中的 `uvm` 受管 block 已按预期移除
- 你的环境目录仍保留
- `uv` 仍可独立工作

---

## 13. 与旧版行为的区别

相较旧版，当前卸载实现有几个关键变化：

- 不再通过 `grep -v "uvm"` 这类方式删除 shell 配置
- 不再因为“删除了文件就返回非零值”而在 `set -e` 下提前退出
- 受管 block 可重复安装、修复、升级、卸载，行为更稳定
- 会明确保留环境目录与 `uv` 配置，减少误删风险
