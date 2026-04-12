# uvm - UV 环境管理器

<div align="center">

**一个以 Bash 为核心、类 Conda 体验的 `uv` 环境管理工具**

[English Docs](README.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20Git%20Bash-blue.svg)](https://github.com/Tendo33/uvm)

</div>

`uvm` 保留了熟悉的 `create / activate / deactivate / list / delete` 工作流，同时把环境创建与包管理交给 `uv`。`1.1.0` 版本的重点不是堆新功能，而是把底层做稳：统一配置解析、改进元数据存储、把 shell 与镜像配置改成受管 block、让自动激活支持向上继承，并提供 `doctor` / `repair` 作为一线诊断入口。

## 功能概览

- 类 Conda 命令体验，保持 Bash 小而稳的实现方式
- 支持默认共享环境目录，也支持 `--path` 自定义路径环境并纳入管理
- `.venv` 与 `.uvmrc` 都支持向上查找和自动激活
- 元数据改为 `envs.d/` 单文件记录，不再依赖脆弱的字符串拼接 JSON
- shell 配置与镜像配置通过起止标记进行幂等更新
- 新增诊断与修复命令：`uvm doctor`、`uvm repair`
- 支持 Linux、macOS、Windows Git Bash

## 运行要求

- Bash 或 Zsh
- 已安装 `uv`
- Linux、macOS，或 Windows + Git Bash

说明：

- 当前版本不支持 PowerShell / CMD。
- Windows 用户请先在 PowerShell 中安装 `uv`，再在 Git Bash 中使用 `uvm`。

## 安装

### 推荐方式：先下载，再执行

交互式安装需要真实脚本文件，因此推荐先下载 `install.sh`，不要直接把远程脚本管道给 `bash`。

Linux / macOS：

```bash
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh
```

Windows（Git Bash）：

```bash
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh
```

安装器会：

- 把 `uvm` 安装到 `~/.local/bin/uvm`
- 把库文件安装到 `~/.local/lib/uvm`
- 初始化 `UVM_HOME`，默认位置为 `~/.config/uvm`
- 初始化 `UVM_ENVS_DIR`，默认位置为 `~/uv_envs`
- 扫描默认环境目录并注册已有环境
- 通过受管 block 写入 PATH 与 shell hook，而不是粗暴追加零散行
- 通过受管 block 更新 `uv` 镜像配置

### 非交互安装

```bash
bash install.sh -y
```

注意：

- 非交互模式下，如果系统没有 `uv`，安装会直接失败。
- 这个模式适合 CI、自动化脚本和重复部署场景。

### 自定义受管环境目录

```bash
bash install.sh --envs-dir /path/to/envs
```

该目录会被写入 `UVM_HOME/config`，并在 `uvm config show` 中体现为当前有效配置。

### 本地开发安装

```bash
git clone https://github.com/Tendo33/uvm.git
cd uvm
bash install.sh
```

## 快速开始

```bash
uvm create myenv --python 3.11
source ~/.bashrc   # 或 ~/.zshrc
uvm activate myenv
uvm list
uvm deactivate
uvm delete myenv
```

## 命令说明

### `uvm create`

```bash
uvm create myenv
uvm create myenv --python 3.12
uvm create myenv --path /work/envs/myenv
```

行为说明：

- 在真正写入文件系统前会先校验环境名
- `--path` 允许把环境建到自定义位置
- 使用 `--path` 创建的环境仍会写入元数据，因此 `uvm list` / `uvm activate` / `uvm delete` 都能正确识别

### `uvm activate`

```bash
uvm activate myenv
```

`activate` 必须运行在 shell 集成环境中，因为它需要把目标环境 `source` 到当前 shell 会话。

如果提示需要 shell integration，请确认 shell rc 中存在：

```bash
eval "$(uvm shell-hook)"
```

安装器与 `uvm repair` 都可以自动修复这段受管 block。

### `uvm deactivate`

```bash
uvm deactivate
```

和 `activate` 一样，它依赖 shell 集成。

### `uvm list`

```bash
uvm list
uvm list --all
```

行为说明：

- 优先列出 `envs.d/` 中的受管记录
- 同时补充扫描默认 `UVM_ENVS_DIR` 下可识别的有效环境
- 当前活动环境前会显示 `*`
- `--all` 会额外显示来源列，区分 `managed` 与 `discovered`

### `uvm delete`

```bash
uvm delete myenv
uvm delete myenv --force
```

安全规则：

- 拒绝非法环境名
- 拒绝删除当前正处于激活状态的环境
- 拒绝删除非受管或越界路径
- 删除环境目录后会同步删除对应元数据记录

### `uvm scan`

```bash
uvm scan
uvm scan /path/to/envs
```

扫描指定目录并注册其中的有效环境。

### `uvm init`

```bash
uvm init
```

初始化 `UVM_HOME`、默认环境目录、镜像配置，并扫描默认环境目录。

### `uvm doctor`

```bash
uvm doctor
```

输出内容包括：

- 当前平台与 shell 类型
- 实际使用的 shell rc 文件
- shell hook 是否已配置
- `UVM_HOME`
- `UVM_ENVS_DIR`
- 元数据记录数量
- `~/.local/bin` 是否在 `PATH`
- 当前检测到的 `uv` 版本
- mirror block 是否存在
- 当前活动环境
- 当前环境是否来自自动激活

当 `activate`、自动激活、PATH 或元数据状态异常时，优先先跑这个命令。

### `uvm repair`

```bash
uvm repair
```

它会做安全的、可恢复的修复：

- 清理无效元数据记录
- 重新扫描默认 `UVM_ENVS_DIR`
- 重写 shell hook 受管 block
- 重写镜像配置受管 block

它不会自动删除有效环境。

### `uvm config`

```bash
uvm config show
uvm config mirror
```

- `config show`：输出当前生效的配置路径
- `config mirror`：刷新 `~/.config/uv/uv.toml` 中的受管镜像 block
- 如果检测到会冲突的非 `uvm` 镜像配置，`uvm` 会给出警告并保持原文件不变

### `uvm shell-hook`

```bash
eval "$(uvm shell-hook)"
```

这个命令会生成当前 shell 所需的运行时代码，用于：

- `uvm activate`
- `uvm deactivate`
- 基于 prompt / `chpwd` 的自动激活检查

当前版本不再通过覆写 `cd` 来做自动激活，而是改成 hook 机制。

## 自动激活

`uvm` 会从当前目录开始向上查找激活目标。

优先级如下：

1. 最近的父级 `.venv`
2. 最近的父级 `.uvmrc`

这意味着：

- 进入项目子目录时，不会因为离开项目根目录就丢失环境
- 离开整个项目树后，会自动失活由自动激活带起的环境
- 如果同一范围内同时存在 `.venv` 和 `.uvmrc`，优先使用 `.venv`

### 本地 `.venv`

```bash
cd ~/project
uv venv
cd ~/project/src/module
```

如果 `~/project/.venv` 是有效环境，那么进入 `src/module` 这样的子目录时也会自动激活。

### 共享环境 `.uvmrc`

```bash
uvm create shared-311 --python 3.11
echo "shared-311" > .uvmrc
```

项目子目录会继承最近父目录中的 `.uvmrc` 绑定。

## 配置与元数据模型

### 生效路径

- `UVM_HOME`：默认 `~/.config/uvm`
- `UVM_ENVS_DIR`：默认 `~/uv_envs`
- 元数据目录：`~/.config/uvm/envs.d`

### 元数据格式

当前版本会为每个环境写一个独立记录文件：

```text
~/.config/uvm/envs.d/
  myenv.env
  py311.env
```

这样做的好处：

- 不再依赖手工拼接 JSON 字符串
- 通过临时文件 + `mv` 实现更稳定的原子写入
- 纯 Bash 下更容易做增删改查
- 为并发写预留了锁目录

旧版 `envs.json` 只用于一次性迁移，且仅在 record 文件尚不存在时才会参与。

### shell 受管 block

安装器与 `uvm repair` 会维护稳定的起止标记，例如：

```bash
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<

# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
```

这种方式让重复安装、升级、修复、卸载都具备幂等性。

### mirror 受管 block

`uvm config mirror` 与 `uvm repair` 只会更新 `~/.config/uv/uv.toml` 中由 `uvm` 管理的 block：

```toml
# >>> uvm mirror >>>
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true

[python-downloads]
url = "https://mirrors.tuna.tsinghua.edu.cn/python-releases/"
# <<< uvm mirror <<<
```

如果目标文件原本已经存在，`uvm` 会保留一次性备份 `uv.toml.backup`。
如果文件里已经存在非 `uvm` 管理的 `[[index]]` 或 `[python-downloads]` 段，`uvm` 会跳过写入受管镜像 block，避免生成无效或语义冲突的 TOML 配置。

## 常见问题与排障

### `uvm: command not found`

先执行：

```bash
source ~/.bashrc   # 或 ~/.zshrc
uvm doctor
```

如果看到 `PATH ~/.local/bin : missing`，请补上：

```bash
export PATH="${HOME}/.local/bin:$PATH"
```

或者重新执行：

```bash
bash install.sh -y
```

### `uvm activate` 提示必须在 shell integration 中运行

执行：

```bash
uvm repair
source ~/.bashrc   # 或 ~/.zshrc
uvm doctor
```

### `uvm list` 没看到环境

排查顺序：

- 如果环境是用 `uvm create --path` 创建的，先确认实际路径仍然存在
- 运行 `uvm repair`，清理失效记录并重新扫描默认目录
- 运行 `uvm list --all`，查看条目的来源信息

### 自动激活不工作

检查项：

- shell rc 中是否存在受管的 `uvm shell` block
- 当前 shell 是否已经重新加载
- `.venv` 是否为有效 `uv` 环境，且含有激活脚本
- `.uvmrc` 中是否写的是合法环境名
- `.uvmrc` 指向的共享环境是否仍存在

建议先运行：

```bash
uvm doctor
uvm repair
```

### 系统没有 `uv`

`uvm` 本身不会内置 `uv`。

- Linux / macOS 交互式安装时可选择安装
- 非交互安装在缺少 `uv` 时会直接失败
- Windows 用户应先在 PowerShell 中安装 `uv`

## 卸载

```bash
bash uninstall.sh
bash uninstall.sh --force
bash uninstall.sh --keep-shell-config
```

卸载会删除：

- `~/.local/bin/uvm`
- `~/.local/lib/uvm`
- `~/.config/uvm`
- shell 中由 `uvm` 写入的受管 block，除非使用 `--keep-shell-config`

卸载会保留：

- 你的虚拟环境目录
- `uv`
- `~/.config/uv/uv.toml`

详细说明见：[project_document/UNINSTALL.md](project_document/UNINSTALL.md)

## 平台支持范围

- Linux：支持
- macOS：支持
- Windows Git Bash：支持
- PowerShell / CMD：当前版本不支持

## 当前验证覆盖

仓库当前已经覆盖：

- BATS 测试：元数据、环境名校验、受管 block、`doctor`、`repair`、`--path`、父级 `.uvmrc` 继承
- CI：语法检查、BATS、Windows Git Bash smoke 测试

## 后续方向

- 环境导出 / 导入
- shell completion
- 更丰富的环境说明信息
- 在 Bash 核心稳定的前提下，为更多 shell 预留扩展空间

## License

MIT，详见 [LICENSE](LICENSE)。
