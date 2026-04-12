# UVM 项目技术文档

**项目名称**：uvm - UV Environment Manager  
**当前版本**：1.1.0  
**文档更新时间**：2026-04-12  
**状态**：已对齐当前实现

---

## 1. 项目定位

`uvm` 是一个以 Bash 为核心、类 Conda 体验的 `uv` 环境管理工具。它的目标不是替代 `uv`，而是为共享环境管理、自动激活、镜像配置和常见排障提供一层轻量而稳定的工作流。

当前版本重点：

- 统一 `UVM_HOME` / `UVM_ENVS_DIR` 解析逻辑
- 用 `envs.d/*.env` 重构元数据存储
- 用受管 block 管理 shell 配置和 mirror 配置
- 让 `.venv` / `.uvmrc` 自动激活支持向上查找
- 提供 `uvm doctor` 与 `uvm repair`

---

## 2. 目录结构

```text
uvm/
├── bin/
│   └── uvm
├── lib/
│   ├── uvm-config.sh
│   ├── uvm-core.sh
│   └── uvm-shell-hooks.sh
├── templates/
│   └── uv.toml.template
├── tests/
│   └── uvm.bats
├── .github/workflows/
│   └── ci.yml
├── install.sh
├── uninstall.sh
├── fix-shell-hook.sh
├── README.md
├── README_CN.md
└── project_document/
    ├── main.md
    └── UNINSTALL.md
```

---

## 3. 模块职责

### 3.1 `bin/uvm`

CLI 入口，负责：

- 加载配置层与核心逻辑
- 解析命令行参数
- 路由命令到对应模块
- 暴露版本号与帮助信息

当前支持命令：

- `create`
- `activate`
- `deactivate`
- `delete`
- `list`
- `scan`
- `init`
- `doctor`
- `repair`
- `config`
- `shell-hook`
- `help`
- `version`

### 3.2 `lib/uvm-config.sh`

配置与底层工具层，负责：

- 解析 `UVM_HOME`
- 解析 `UVM_ENVS_DIR`
- 初始化配置目录
- 管理环境记录文件
- 提供 metadata lock
- 提供路径安全检查辅助函数
- 管理 shell block / mirror block
- 管理 legacy `envs.json` 迁移

关键事实：

- 元数据目录固定为 `$(uvm_get_home)/envs.d`
- 每个环境一条记录，记录文件后缀为 `.env`
- 旧版 `envs.json` 不再作为主存储，仅用于迁移

### 3.3 `lib/uvm-core.sh`

核心命令实现层，负责：

- 创建环境
- 删除环境
- 列出环境
- 元数据修复与扫描
- 诊断输出

关键能力：

- `uvm create --path` 创建的环境会被纳入元数据管理
- 删除前会验证目标路径是否属于安全删除范围
- `uvm doctor` 输出当前配置、PATH、shell hook、mirror、活动环境状态
- `uvm repair` 做可恢复修复，不做破坏性清理

### 3.4 `lib/uvm-shell-hooks.sh`

shell 集成与自动激活层，负责：

- 生成 `uvm shell-hook`
- 在 shell 内拦截 `uvm activate` / `uvm deactivate`
- 实现自动激活
- 基于 prompt / `chpwd` hook 执行目录检查

关键变化：

- 不再通过覆盖 `cd` 实现自动激活
- `.venv` 和 `.uvmrc` 都支持向上查找
- 进入项目子目录时仍可保持激活

---

## 4. 配置模型

### 4.1 生效路径

- `UVM_HOME` 默认值：`~/.config/uvm`
- `UVM_ENVS_DIR` 默认值：`~/uv_envs`
- 主配置文件：`~/.config/uvm/config`
- 元数据目录：`~/.config/uvm/envs.d`
- 锁目录：`~/.config/uvm/locks`
- `uv` 配置文件：`~/.config/uv/uv.toml`

### 4.2 元数据布局

当前版本使用如下结构：

```text
~/.config/uvm/
├── config
├── envs.d/
│   ├── myenv.env
│   └── shared-311.env
└── locks/
```

单条记录示意：

```bash
UVM_RECORD_NAME=myenv
UVM_RECORD_PATH=/home/user/uv_envs/myenv
UVM_RECORD_PYTHON=3.12.1
UVM_RECORD_CREATED=2026-04-12T10:00:00+0800
```

设计目的：

- 纯 Bash 下易维护
- 单条记录可原子更新
- 易于去重、删除、重建
- 为并发写预留锁机制

### 4.3 legacy 迁移策略

如果旧版 `envs.json` 存在，且 `envs.d/` 下还没有记录文件，则会进行一次迁移。迁移完成后，主逻辑始终以 `envs.d/` 为准。

---

## 5. 命令行为说明

### 5.1 `create`

- 校验环境名合法性
- 支持 `--python`
- 支持 `--path`
- 创建成功后写入元数据

### 5.2 `list`

- 先列受管记录
- 再补默认目录下已存在但尚未写入记录的有效环境
- `--all` 显示来源列

### 5.3 `delete`

- 禁止删除当前激活环境
- 禁止删除越界路径
- 删除目录后同步清理元数据

### 5.4 `doctor`

输出以下诊断维度：

- 平台
- shell
- shell rc 文件
- shell hook 状态
- `UVM_HOME`
- `UVM_ENVS_DIR`
- 元数据数量
- `~/.local/bin` 是否进入 PATH
- `uv` 版本
- mirror block 状态
- 当前活动环境
- 当前环境是否来自自动激活

### 5.5 `repair`

执行内容：

- 清理无效记录
- 重新扫描默认环境目录
- 修复 shell hook 受管 block
- 修复 mirror 受管 block

适用场景：

- shell 集成丢失
- 元数据损坏或不完整
- PATH / shell / 自动激活行为异常后的恢复

---

## 6. 自动激活机制

### 6.1 查找优先级

自动激活按以下顺序工作：

1. 最近的父级 `.venv`
2. 最近的父级 `.uvmrc`

### 6.2 `.venv` 逻辑

- 从当前目录开始向上查找
- 找到有效 `.venv` 后直接激活
- 即使当前位于项目子目录，也会继承项目根的 `.venv`

### 6.3 `.uvmrc` 逻辑

- 向上查找最近的 `.uvmrc`
- 读取环境名
- 先验证环境名是否合法
- 再从 record 文件或默认环境目录中解析路径

### 6.4 自动失活逻辑

- 当离开原项目上下文，且当前环境来自自动激活时，自动执行失活
- 手动激活环境不会被误判成自动激活状态

### 6.5 shell hook 机制

- Bash：通过 `PROMPT_COMMAND` 注入检查逻辑
- Zsh：通过 `chpwd` / `precmd` hook 注入检查逻辑
- 不再覆写 `cd`

---

## 7. 安装流程

### 7.1 安装器职责

`install.sh` 负责：

- 检测运行平台
- 检测 `uv`
- 在需要时下载项目文件
- 安装二进制与库文件
- 初始化配置目录
- 写入 PATH 受管 block
- 可选写入 shell hook 受管 block
- 初始化镜像 block

### 7.2 非交互模式行为

`bash install.sh -y` 或使用 `--envs-dir` 时，会进入非交互模式。

约束：

- 缺少 `uv` 时直接失败
- 适合自动化与 CI

### 7.3 shell 配置写入方式

当前版本通过起止标记写入：

```bash
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<

# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
```

这个机制确保：

- 重复安装不会重复写入
- 升级不会无限追加
- `repair` 可以重建 block
- 卸载可以精准删除 block

### 7.4 mirror 配置写入方式

镜像配置不再粗暴覆盖整个 `uv.toml`，而是仅更新 `uvm` 受管 block，并保留一次性备份。
如果检测到文件中已存在非 `uvm` 管理的 `[[index]]` 或 `[python-downloads]` 段，则跳过写入并给出警告，避免制造冲突配置。

---

## 8. 卸载流程

`uninstall.sh` 负责：

- 展示将被删除的内容
- 备份 shell rc
- 移除 shell 中由 `uvm` 管理的 block
- 删除 `~/.local/bin/uvm`
- 删除 `~/.local/lib/uvm`
- 删除 `~/.config/uvm`

默认保留：

- 虚拟环境目录
- `uv`
- `~/.config/uv/uv.toml`

可选参数：

- `--force`：跳过确认
- `--keep-shell-config`：保留 shell block

---

## 9. 安全设计

### 9.1 环境名校验

允许字符：

- 字母
- 数字
- `.`
- `_`
- `-`

显式拒绝：

- 路径分隔符
- `..`
- 空格
- 命令拼接字符

### 9.2 删除安全

删除前会验证：

- 环境名是否合法
- 目标是否是当前激活环境
- 目标路径是否属于受管记录或默认环境目录的安全子路径

### 9.3 元数据写入

- 使用临时文件 + `mv`
- 使用锁目录避免并发写冲突

### 9.4 shell 配置安全

- 只删除起止标记之间的 `uvm` 受管 block
- 不再使用 `grep -v "uvm"` 这类粗暴清理方式

---

## 10. 测试与 CI

### 10.1 BATS 覆盖范围

当前 `tests/uvm.bats` 已覆盖：

- `UVM_HOME` 下的新目录布局
- 环境名合法/非法校验
- `uvm create --path`
- 元数据新增与删除
- 父级 `.uvmrc` 自动激活继承
- 受管 block 幂等性
- `uvm repair`
- `uvm doctor`

### 10.2 CI 分层

`.github/workflows/ci.yml` 当前包含：

- ShellCheck
- 语法检查
- BATS 行为测试
- Windows Git Bash smoke 测试

Windows smoke 至少覆盖：

- install
- list
- shell-hook
- doctor

---

## 11. 平台支持边界

- Linux：完整支持
- macOS：完整支持
- Windows Git Bash：支持并已进入 CI smoke 范围
- Windows 原生 PowerShell / CMD：本轮未承诺支持，仅为未来扩展预留结构

---

## 12. 已知限制与后续方向

当前限制：

- 仍以 Bash 为唯一核心实现
- 不提供 PowerShell / CMD 原生集成
- 暂无 `export / import`
- 暂无 shell completion

后续方向：

- 环境导出 / 导入
- shell completion
- 更丰富的环境描述信息
- 更多 shell 适配层

---

## 13. 文档同步原则

本文档、`README.md`、`README_CN.md`、`project_document/UNINSTALL.md` 应与以下真实实现保持同步：

- `bin/uvm`
- `lib/uvm-config.sh`
- `lib/uvm-core.sh`
- `lib/uvm-shell-hooks.sh`
- `install.sh`
- `uninstall.sh`

如果未来命令语义、元数据布局、shell block 或 mirror block 发生变化，应优先同步这些文档，避免“实现已改、文档仍旧”的漂移。
