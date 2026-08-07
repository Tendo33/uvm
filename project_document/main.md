# UVM 项目技术文档

**项目名称**：uvm - UV Environment Manager
**当前版本**：1.2.1
**文档更新时间**：2026-08-07
**状态**：与当前实现及发布检查对齐

## 1. 项目定位

`uvm` 是一层面向 Bash/Zsh/Git Bash 的轻量 `uv` 环境管理界面。它负责命名环境、元数据、shell 集成和项目切换；Python 下载、虚拟环境创建和包操作仍由 `uv` 负责。

核心边界：

- `uvm` 不假设 `uv venv` 内存在 `pip`，包操作统一使用 `uv pip --python <env>`。
- 受管环境由 `envs.d/*.env` 记录；`rename` 只改名称映射，不移动普通虚拟环境目录。
- `.uvmrc` 引用受管环境；本地 `.venv` 包含可执行激活脚本，必须先显式信任才会自动加载。
- mirror 只写 `uv` 支持的 `[[index]]` 配置，并在落盘前由当前 `uv` 校验。

## 2. 目录与职责

```text
uvm/
├── bin/uvm                    # CLI 路由与版本
├── lib/
│   ├── uvm-config.sh          # 配置、记录、锁、路径、mirror、信任库
│   ├── uvm-core.sh            # 生命周期、包操作、诊断、自更新
│   └── uvm-shell-hooks.sh     # shell hook 与自动激活
├── completions/               # Bash/Zsh 补全
├── templates/uv.toml.template
├── tests/uvm.bats
├── .github/workflows/
│   ├── ci.yml
│   └── release.yml
├── install.sh
└── uninstall.sh
```

### 配置层

- `UVM_HOME` 默认 `~/.config/uvm`。
- `UVM_ENVS_DIR` 默认 `~/uv_envs`，写入配置时保存为规范化绝对路径。
- 环境记录位于 `$(uvm_get_home)/envs.d`；写入和重命名在 metadata lock 下完成。
- 本地环境信任清单位于 `$(uvm_get_home)/trusted-local-envs`，比较时使用规范路径。
- 旧 `envs.json` 仅作为一次性迁移输入，不再是事实来源。

### 生命周期层

- `create`：校验参数和名称，以 `uv venv` 创建后写入记录。
- `delete`：拒绝删除活动环境或不满足安全边界的路径。
- `rename`：原子更新元数据名称，环境目录保持不变，避免破坏激活脚本中的绝对路径。
- `clone` / `export` / `import`：通过 `uv pip --python` 操作，不依赖环境内的 `pip`。
- `list --json`：对所有字符串字段进行 JSON 转义，可直接交给标准 JSON 解析器。
- `update`：读取正式 release 安装器版本，拒绝降级，并保留现有 `UVM_HOME` 与 `UVM_ENVS_DIR`。

## 3. 自动激活与信任边界

目录切换时从当前目录向上查找，优先级如下：

1. 已信任的本地 `.venv`
2. 指向受管环境的 `.uvmrc`

发现未信任 `.venv` 时，uvm 只设置待确认状态并由 `doctor` 报告，不会执行其中的 `activate`。用户确认项目来源后可运行：

```bash
uvm trust .venv
uvm untrust .venv
uvm trust --list
```

shell hook 不覆盖 `cd`：Zsh 使用 `chpwd`，Bash 使用 `PROMPT_COMMAND`。自动激活函数保留上一条用户命令的退出状态，避免 prompt hook 改写 `$?`。

## 4. Mirror 配置

受管配置写入 `~/.config/uv/uv.toml`：

```toml
# >>> uvm mirror >>>
[[index]]
url = "https://example.invalid/simple"
default = true
# <<< uvm mirror <<<
```

`uvm config mirror set <url>` 会拒绝无效协议、换行和引号；若检测到用户自行维护的 `[[index]]` 或 `python-install-mirror`，则停止并提示冲突，不抢占配置所有权。候选文件必须通过 `uv --config-file <file> python list --only-installed` 后才替换正式文件。

## 5. 安装与修复

```bash
./install.sh
./install.sh --envs-dir /absolute/path --no-mirror
uvm init
uvm doctor
uvm repair
```

交互安装的提示与结果通道分离，避免命令替换吞掉用户输入。更新或重装时，如果未显式传入新目录，则保留当前环境根目录。所有需要值的选项都在移动参数前验证。

`doctor` 是只读诊断；`repair` 只重建可恢复的记录和受管配置块，不删除环境。

## 6. CI 与发布

CI 是发布工作流的必需依赖，覆盖：

- ShellCheck 与 Bash 语法检查
- Ubuntu、macOS 上的 BATS
- 最低支持 uv 0.10.0 与当前验证 uv 0.12.2
- Windows Git Bash 生命周期 smoke test
- 版本、文档和已退役实现的一致性检查

发布仅由 `v*` tag 触发。release workflow 先运行同一套 CI，再校验 tag、`bin/uvm`、`install.sh`、下载 ref 和 changelog 一致，最后才创建 GitHub Release。失败不得被当成已发布版本。

## 7. 验证基线

本地改动至少运行：

```bash
bash -n bin/uvm install.sh uninstall.sh lib/*.sh
bats tests/uvm.bats
```

涉及版本发布时，还需等待 GitHub Actions 的 CI 与 release job 成功，并检查 release 资产中的安装器版本；本地测试成功不等同于远端发布成功。
