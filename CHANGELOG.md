# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-12-26

### Fixed
- **Critical:** Fixed configuration file corruption during interactive installation
  - `check_uv()` output was polluting the config file when UV was already installed
  - Custom environment directory path was being overwritten with UV version message
  - Added proper output redirection (`>&2`) to prevent stdout pollution
  - Affects: Interactive installation with UV already installed + custom directory
  - See [BUGFIX_CONFIG.md](BUGFIX_CONFIG.md) for detailed analysis

### Added
- Uninstall script (`uninstall.sh`) with interactive and force modes
- Comprehensive uninstallation documentation ([UNINSTALL.md](UNINSTALL.md))
- Automatic shell config backup during uninstallation
- Bug fix documentation ([BUGFIX_CONFIG.md](BUGFIX_CONFIG.md))

### Changed
- Simplified interactive installation prompts for better UX
- Improved environment directory selection (removed confusing numbered options)
- Enhanced installation wizard with clearer step-by-step guidance

---

## [1.0.0] - 2025-12-26

### Added
- Initial release of uvm (UV Manager)
- Core commands: `create`, `activate`, `deactivate`, `delete`, `list`
- Smart auto-activation with dual-mode support:
  - Priority 1: Local `.venv` detection
  - Priority 2: Shared environment via `.uvmrc`
- Automatic China mirror configuration (Tsinghua University)
- Cross-platform support (Linux, macOS, Windows Git Bash)
- Shell integration via `uvm shell-hook`
- Configuration management: `uvm config`
- Installation script with dependency checking
- Comprehensive documentation:
  - README.md with full feature documentation
  - EXAMPLES.md with real-world usage scenarios
  - QUICKSTART.md for rapid onboarding
  - Project documentation in `project_document/`
- MIT License

### Features
- Environment creation with custom Python versions
- Environment metadata tracking in JSON format
- Automatic PATH configuration during installation
- UV mirror pre-configuration for faster downloads
- Shell detection (Bash/Zsh)
- Custom environment directory support via `UVM_ENVS_DIR`
- Force delete option for environments
- Current environment indicator in `uvm list`

### Technical Details
- Modular architecture with separate concerns:
  - `uvm-config.sh`: Configuration management
  - `uvm-core.sh`: Core command implementation
  - `uvm-shell-hooks.sh`: Shell integration
- SOLID principles applied throughout
- RIPER-7 code documentation standards
- Comprehensive error handling
- Cross-platform path handling

## [Unreleased]

### Planned for v1.1
- Shell completion (Bash/Zsh)
- Environment export/import commands
- Improved error messages
- Logging system

### Planned for v1.2
- Environment cloning
- Fish shell support
- PowerShell support
- GUI installer

### Planned for v2.0
- `pyenv` integration
- Remote environment management
- Team environment sharing
- Docker integration

---

[1.0.0]: https://github.com/yourusername/uvm/releases/tag/v1.0.0

