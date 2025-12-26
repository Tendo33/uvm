# 更新日志

本项目所有重大更改都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

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
  - 详见 [BUGFIX_CONFIG.md](BUGFIX_CONFIG.md) 的详细分析

### 新增
- **一键远程安装**：通过 curl/wget 无需克隆仓库即可安装
- 支持从特定版本标签或分支安装
- 卸载脚本（`uninstall.sh`）支持交互和强制模式
- 完整的卸载文档（[UNINSTALL.md](project_document/UNINSTALL.md)）
- 卸载时自动备份 Shell 配置
- Bug 修复文档（[BUGFIX_CONFIG.md](BUGFIX_CONFIG.md)）

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

[1.0.2]: https://github.com/Tendo33/uvm/releases/tag/v1.0.2
[1.0.1]: https://github.com/Tendo33/uvm/releases/tag/v1.0.1
[1.0.0]: https://github.com/Tendo33/uvm/releases/tag/v1.0.0
