# 更新日志

本项目所有重大更改都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.1.1] - 2026-04-12

### Fixed
- Installer now respects an externally supplied `UVM_HOME` instead of forcing `~/.config/uvm`
- Release-scoped `install.sh` now keeps remote downloads pinned to the matching `v<version>` ref by default
- Uninstall now respects an explicitly supplied `UVM_HOME` and still reports the configured managed environments directory

### Changed
- Added release checks to verify `bin/uvm`, `install.sh`, and the installer download ref stay aligned with the release tag
- Expanded BATS coverage around installer and uninstaller configuration behavior

---

## [1.1.0] - 2026-04-12

### Changed
- Reworked metadata storage to managed record files under `envs.d/`
- Added `uvm doctor` and `uvm repair`
- Hardened environment name validation and delete-path safety checks
- Switched shell integration and mirror configuration to managed block updates
- Rebuilt install/uninstall flows around the shared configuration layer
- Added Windows Git Bash smoke coverage in CI

---

## [1.0.5] - 2026-02-25

### 修复
- **CI 构建**：修复 GitHub Release CI 中打包时的“file changed as we read it”错误

---

## [1.0.4] - 2026-02-24

### 修复
- **CI 质量**：修复所有 ShellCheck 静态分析警告（SC2155、SC2034、SC1090），CI 流水线恢复绿色
  - SC2155：将 `local var=$(cmd)` 拆分为两步赋值，避免屏蔽命令返回值（共 26 处）
  - SC2034：移除/重命名未使用变量 `is_remote_install`、`show_all`
  - SC1090：为非常量路径的 `source` 添加 `# shellcheck source=/dev/null` 指令

---

## [1.0.3] - 2026-02-24

### 安全修复
- **路径穿越防护**：`.uvmrc` 中的环境名称现在通过正则白名单 `^[a-zA-Z0-9_-]+$` 校验，拒绝包含 `../`、特殊字符等危险输入
- **命令注入修复**：`install.sh` 中将 `eval echo "$path"` 替换为安全的 Bash 参数展开 `"${path/#\~/$HOME}"`，消除安装时的命令注入攻击面

### 性能优化
- **cd 钩子优化**：自动激活的 `.venv` 向上递归查找深度限制为最多 5 层，避免在深层目录结构中引起不必要的磁盘 IO 和延迟

### 新增
- **GitHub Actions CI**：新增 `.github/workflows/ci.yml`，包含 ShellCheck 静态分析、跨平台语法检查（Ubuntu + macOS）、BATS 功能测试、安全回归测试
- **GitHub Actions Release**：新增 `.github/workflows/release.yml`，推送 `v*` tag 后自动验证版本一致性、打包并发布 GitHub Release
- **BATS 测试套件**：新增 `tests/uvm.bats`，覆盖核心命令功能测试和安全回归用例

---

## [1.0.2] - 2025-12-26

### 变更
- **文档中文化**：所有项目文档改为中文
- **安装方式优化**：安装/卸载脚本改为先下载后执行，支持交互式操作
  - 修复了通过管道执行时无法接收用户输入的问题
  - 用户现在可以自定义安装选项

---

## [1.0.1] - 2025-12-26

### 修复
- **关键问题**：修复交互式安装时配置文件损坏问题
  - `check_uv()` 输出在 UV 已安装时污染配置文件
  - 自定义环境目录路径被 UV 版本信息覆盖
  - 添加正确的输出重定向（`>&2`）防止 stdout 污染
  - 影响：UV 已安装 + 自定义目录的交互式安装
  - 详细分析见 install.sh 中的注释

### 新增
- **一键远程安装**：通过 curl/wget 无需克隆仓库即可安装
- 支持从特定版本标签或分支安装
- 卸载脚本（`uninstall.sh`）支持交互和强制模式
- 完整的卸载文档（[UNINSTALL.md](project_document/UNINSTALL.md)）
- 卸载时自动备份 Shell 配置
- 在 install.sh 中添加了 Bug 修复注释

### 变更
- 简化交互式安装提示，改善用户体验
- 改进环境目录选择（移除令人困惑的编号选项）
- 增强安装向导，提供更清晰的分步指导

---

## [1.0.0] - 2025-12-26

### 新增
- uvm（UV 管理器）初始发布
- 核心命令：`create`、`activate`、`deactivate`、`delete`、`list`
- 智能自动激活，支持双模式：
  - 优先级 1：本地 `.venv` 检测
  - 优先级 2：通过 `.uvmrc` 使用共享环境
- 自动配置国内镜像（清华大学）
- 跨平台支持（Linux、macOS、Windows Git Bash）
- 通过 `uvm shell-hook` 实现 Shell 集成
- 配置管理：`uvm config`
- 带依赖检查的安装脚本
- 完整文档：
  - README.md 完整功能文档
  - EXAMPLES.md 真实使用场景
  - QUICKSTART.md 快速入门
  - `project_document/` 项目文档
- MIT 许可证

### 功能
- 支持自定义 Python 版本创建环境
- JSON 格式的环境元数据追踪
- 安装时自动配置 PATH
- UV 镜像预配置加速下载
- Shell 检测（Bash/Zsh）
- 通过 `UVM_ENVS_DIR` 支持自定义环境目录
- 强制删除环境选项
- `uvm list` 显示当前环境指示器

### 技术细节
- 模块化架构，职责分离：
  - `uvm-config.sh`：配置管理
  - `uvm-core.sh`：核心命令实现
  - `uvm-shell-hooks.sh`：Shell 集成
- 全面应用 SOLID 原则
- RIPER-7 代码文档标准
- 完善的错误处理
- 跨平台路径处理

## [未发布]

### 计划于 v1.1
- Shell 补全（Bash/Zsh）
- 环境导出/导入命令
- 改进错误信息
- 日志系统

### 计划于 v1.2
- 环境克隆
- Fish shell 支持
- PowerShell 支持
- GUI 安装器

### 计划于 v2.0
- `pyenv` 集成
- 远程环境管理
- 团队环境共享
- Docker 集成

---

[1.1.1]: https://github.com/Tendo33/uvm/releases/tag/v1.1.1
[1.1.0]: https://github.com/Tendo33/uvm/releases/tag/v1.1.0
[1.0.5]: https://github.com/Tendo33/uvm/releases/tag/v1.0.5
[1.0.4]: https://github.com/Tendo33/uvm/releases/tag/v1.0.4
[1.0.3]: https://github.com/Tendo33/uvm/releases/tag/v1.0.3
[1.0.2]: https://github.com/Tendo33/uvm/releases/tag/v1.0.2
[1.0.1]: https://github.com/Tendo33/uvm/releases/tag/v1.0.1
[1.0.0]: https://github.com/Tendo33/uvm/releases/tag/v1.0.0
