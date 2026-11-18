# uvm — UV 环境管理器（1.3.4）

<div align="center">

**为 `uv` 加上命名、共享环境层 —— 不用 conda 也能有 conda 的工作流**

[English Docs](README.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20Git%20Bash-blue.svg)](https://github.com/Tendo33/uvm)
[![CI](https://github.com/Tendo33/uvm/actions/workflows/ci.yml/badge.svg)](https://github.com/Tendo33/uvm/actions/workflows/ci.yml)

</div>

`uv` 很快，但它没有"按名字从任意目录激活一个共享环境"的概念。`uvm` 补上这一层 —— `create`、`activate`、`deactivate`、`list`、`delete` —— 同时把所有 Python、虚拟环境和包操作都交给 `uv`。你保留速度，获得工作流。

## 为什么用 uvm？

| 任务 | 不用 uvm | 用 uvm |
|------|----------|--------|
| 创建命名环境 | `uv venv ~/uv_envs/myenv --python 3.11` | `uvm create myenv --python 3.11` |
| 按名字激活 | `source ~/uv_envs/myenv/bin/activate` | `uvm activate myenv` |
| 按项目自动激活 | 手动 | `.uvmrc` 或受信任的 `.venv` |
| 列出所有环境 | `ls ~/uv_envs` | `uvm list` |
| 跨机器迁移环境 | 手动 | `uvm export` / `uvm import` |

uvm 不替换 `uv`。它是一层很薄的 shell 封装（约 1200 行 Bash），管理环境元数据并提供 `uv` 刻意省略的激活机制。

## 快速开始

```bash
# 1. 安装
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y
source ~/.zshrc          # 或 ~/.bashrc

# 2. 创建并激活
uvm create myenv --python 3.11
uvm activate myenv

# 3. 使用
python -m pip install requests
python my_script.py

# 4. 完成
uvm deactivate
```

## 运行要求

- Bash ≥ 3.2 或 Zsh
- [`uv`](https://docs.astral.sh/uv/)（安装器可在 Linux/macOS 上帮你装）
- Linux、macOS 或 Windows Git Bash

不支持 PowerShell 和 CMD。

## 安装

### 交互式（首次安装推荐）

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh

# Windows（Git Bash）—— 先在 PowerShell 里装 uv
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh
```

安装向导会询问环境目录、是否安装 `uv`、是否启用自动激活。

### 非交互式（CI / 脚本）

```bash
# 直接 pipe，无需临时文件
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y

# 指定环境目录
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y --envs-dir /path/to/envs

# 配置 PyPI 镜像（国内推荐）
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y \
  --mirror https://pypi.tuna.tsinghua.edu.cn/simple
```

非交互模式下，缺少 `uv` 是硬错误。镜像配置默认跳过，需显式用 `--mirror` 开启。

安装器会把 `uvm` 放到 `~/.local/bin`，库文件放到 `~/.local/lib/uvm`，配置放到 `~/.config/uvm`，并在 shell RC 文件里写入受管 PATH 和 shell hook 块，重装和卸载都是幂等的。

### 自定义环境目录

```bash
bash install.sh --envs-dir /path/to/envs
```

### 本地开发安装

```bash
git clone https://github.com/Tendo33/uvm.git
cd uvm
bash install.sh
```

### 升级

```bash
uvm update           # 最新版
uvm update --check   # 检查版本，不安装（使用 GitHub API）
uvm update v1.2.3    # 指定版本
```

更新后重启 shell：`exec "$SHELL"`

---

## 常用命令

这几个命令覆盖 90% 的日常使用：

```bash
uvm create myenv --python 3.11   # 创建命名环境
uvm activate myenv               # 激活（需要 shell 集成）
uvm deactivate                   # 退出当前环境
uvm list                         # 列出所有环境
uvm status                       # 显示活跃环境和配置概览
uvm delete myenv                 # 删除环境
uvm run myenv python -V          # 不激活，直接在环境里运行命令
```

---

## 完整命令参考

### create

```bash
uvm create myenv
uvm create myenv --python 3.12
uvm create myenv --path /work/envs/myenv
```

在写文件系统之前先验证名称。`--path` 环境会被元数据追踪，出现在 `uvm list` 里。

### activate / deactivate

```bash
uvm activate myenv
uvm deactivate
```

需要 shell 集成（`eval "$(uvm shell-hook)"` 写入 RC 文件 —— 安装器自动完成）。

### list

```bash
uvm list
uvm list --all    # 显示来源列（managed / discovered）
uvm list --json   # 机器可读 JSON 数组
```

活跃环境用绿色 `*` 标记。

### status

```bash
uvm status           # 活跃环境、环境目录、记录数
uvm status --json    # {"active_env":"myenv","active_path":"...","envs_dir":"...","records":3}
```

### delete

```bash
uvm delete myenv
uvm delete myenv --force   # 跳过确认
```

拒绝删除活跃环境。同时清理该路径的 trust 记录，避免同路径新建的 venv 被静默信任。

### run

```bash
uvm run myenv python my_script.py
uvm run myenv pytest tests/
```

在环境内运行命令，不修改调用方的 shell。

### rename

```bash
uvm rename myenv myenv-v2
```

只改管理名称，不移动目录。如果当前目录树里有 `.uvmrc` 还引用旧名，会给出警告。

### clone

```bash
uvm clone myenv myenv-copy
```

复制源环境并通过 `uv pip` 迁移包。

### export / import

```bash
uvm export myenv > requirements.txt
uvm import restored --from requirements.txt
```

使用 `uv pip freeze` 和 `uv pip install`，不需要 seeded pip。

### trust / untrust

```bash
uvm trust            # 信任 ./.venv（先检查激活脚本内容）
uvm trust /path      # 信任指定路径
uvm trust list       # 列出已信任路径
uvm untrust          # 撤销 ./.venv 的信任
```

本地 `.venv` 的激活脚本是可执行 shell 代码，uvm 在你显式信任其规范路径之前不会自动 source 它。受管 `.uvmrc` 环境不需要这一步。

### update

```bash
uvm update            # 最新版
uvm update --check    # 对比已安装版本和可用版本（GitHub API，不下载安装器）
uvm update v1.2.3     # 指定版本
```

拒绝降级。保留 `UVM_HOME`、`UVM_ENVS_DIR` 和自动激活偏好。

### doctor

```bash
uvm doctor
```

分组显示安装健康状态、shell hook 状态、活跃环境、镜像配置、待处理的 trust 警告，带颜色。出问题先跑这个。

### repair

```bash
uvm repair
```

清除无效元数据记录，重新扫描默认环境目录，重写受管 shell hook 块。不会自动删除有效环境。

### config

```bash
uvm config show
uvm config get envs-dir
uvm config set envs-dir ~/my-envs

uvm config mirror set https://pypi.tuna.tsinghua.edu.cn/simple
uvm config mirror show
uvm config mirror remove

uvm config python-mirror set https://mirror.nju.edu.cn/github-release/astral-sh/python-build-standalone
uvm config python-mirror show
uvm config python-mirror remove
```

`config mirror` 管理 `uv pip install` 使用的 PyPI 包索引。`config python-mirror` 管理 uv 下载 Python 解释器时使用的 URL。两者都写到 uv 的用户级 `uv.toml`。如果该类型的配置已有未受管的设置，uvm 不会修改文件。

---

## 自动激活

在 shell RC 里加入（安装器自动完成）：

```bash
eval "$(uvm shell-hook)"
```

启用后，每次切换目录，uvm 会按以下优先级查找激活目标：

1. 最近的已信任父级 `.venv`
2. 最近的父级 `.uvmrc`

离开项目目录树时，自动激活的环境会自动退出。

### 自动激活本地 .venv

```bash
cd ~/project
uv venv                # 用 uv 创建 .venv
uvm trust              # 显式信任（先看一眼激活脚本）
cd ~/project/src       # 自动激活
```

### 自动激活共享命名环境

```bash
uvm create shared-311 --python 3.11
echo "shared-311" > ~/project/.uvmrc
cd ~/project/src       # 自动激活 shared-311
```

---

## 配置说明

| 项目 | 默认值 | 修改方式 |
|------|--------|----------|
| `UVM_HOME` | `~/.config/uvm` | 安装前 export |
| `UVM_ENVS_DIR` | `~/uv_envs` | `uvm config set envs-dir` |
| 配置文件 | `~/.config/uvm/config` | — |
| 元数据 | `~/.config/uvm/envs.d/*.env` | — |
| uv 配置 | `~/.config/uv/uv.toml` | `XDG_CONFIG_HOME` |

配置文件使用 `KEY="value"` 格式，uvm 只解析，不执行。

元数据是 `envs.d/` 下每个环境一个文件，通过 `mktemp` + `mv` 原子写入。旧版 `envs.json` 仅做一次性迁移，之后不再写入。

安装器在 shell RC 里写入稳定的受管块：

```bash
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<

# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
```

这些标记让安装、修复、重装、卸载都是幂等的。

`uv.toml` 里的镜像块遵循同样的模式：

```toml
# >>> uvm mirror >>>
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
# <<< uvm mirror <<<
```

`uvm doctor` 会打印解析后的 `uv.toml` 路径。`UV_DEFAULT_INDEX` 和 `UV_PYTHON_INSTALL_MIRROR` 环境变量会覆盖受管块；`uvm config show` 在它们被设置时会给出提示。

---

## 故障排查

**`uvm: command not found`**
```bash
source ~/.zshrc    # 或 ~/.bashrc
uvm doctor
```
若 `PATH ~/.local/bin` 显示 MISSING，重新运行 `bash install.sh -y`。

**`uvm activate` 提示需要 shell 集成**
```bash
uvm repair && source ~/.zshrc
```

**`uvm list` 里缺少某个环境**
```bash
uvm repair            # 清理无效记录并重新扫描
uvm list --all        # 检查来源标签
```

**自动激活不工作**
```bash
uvm doctor            # 检查 hook 状态和待处理 trust 警告
uvm repair
```

**`uvm update` 后 shell 还显示旧版本**
```bash
exec "$SHELL"         # 重载 shell 以加载新 hook
```

---

## 卸载

```bash
bash uninstall.sh
bash uninstall.sh --force             # 跳过确认
bash uninstall.sh --keep-shell-config # 保留 shell RC 里的块
```

会删除 `~/.local/bin/uvm`、`~/.local/lib/uvm`、`UVM_HOME` 和受管 shell 块。虚拟环境和 uv 本身保留不动。

如果使用了自定义 `UVM_HOME`：
```bash
UVM_HOME=/custom/path bash uninstall.sh --force
```

---

## 平台支持

| 平台 | 状态 |
|------|------|
| Linux | 支持 |
| macOS | 支持 |
| Windows Git Bash | 支持（先在 PowerShell 里安装 uv） |
| PowerShell / CMD | 不支持 |

---

## 许可证

MIT。详见 [LICENSE](LICENSE)。

