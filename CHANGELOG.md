# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- `uvm run <env> <cmd>` — execute a command inside an environment without activating it
- `uvm rename <old> <new>` — rename an environment (moves directory when under `UVM_ENVS_DIR`)
- `uvm clone <src> <dst>` — clone an environment and its installed packages
- `uvm export <env>` — print installed packages (`pip freeze`) to stdout
- `uvm import <env> --from <file>` — create environment and install from a requirements file
- `uvm update` — self-update uvm from the latest release
- `uvm list --json` — machine-readable JSON output for scripting
- `uvm config mirror set <url>` / `mirror remove` / `mirror show` — granular mirror management
- Bash tab-completion (`completions/uvm.bash`)
- Zsh tab-completion (`completions/_uvm`)
- macOS added to BATS CI matrix

### Changed
- Mirror configuration is now opt-in: `setup_uv_mirror` requires an explicit URL; non-interactive install no longer silently writes a Chinese mirror
- `install.sh` gains `--mirror <url>` and `--no-mirror` flags; interactive wizard asks for mirror URL
- `uvm repair` no longer re-applies the mirror block unless one was already configured
- `uvm doctor` now prints actionable fix hints next to each problem status
- `uvm create` post-success message adapts to whether shell integration is loaded in the current session
- `get_shell_rc_file` on Windows Git Bash now returns `~/.bash_profile` (login shell RC) instead of `~/.bashrc`
- `uvm_get_iso_timestamp` falls back to BSD-compatible `date -u` on macOS
- Help text updated to document all new commands

### Security
- `uvm_load_env_record` and `_uvm_hook_get_env_path` replaced `source "$record_file"` with a safe key=value line parser — injected shell code in metadata files can no longer execute
- `uvm_write_env_record_unlocked` now writes plain single-quoted values instead of `printf '%q'` output, consistent with the new parser

### Removed
- `fix-shell-hook.sh` — fully superseded by `uvm repair`

---

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

### Fixed
- CI build: fixed "file changed as we read it" error during GitHub Release packaging

---

## [1.0.4] - 2026-02-24

### Fixed
- CI quality: resolved all ShellCheck static analysis warnings (SC2155, SC2034, SC1090)
  - SC2155: split `local var=$(cmd)` into two-step assignments to avoid masking return values (26 instances)
  - SC2034: removed/renamed unused variables `is_remote_install`, `show_all`
  - SC1090: added `# shellcheck source=/dev/null` directives for non-constant `source` paths

---

## [1.0.3] - 2026-02-24

### Security
- Path traversal protection: environment names in `.uvmrc` are now validated against the whitelist `^[a-zA-Z0-9_-]+$`, rejecting `../` and special characters
- Command injection fix: replaced `eval echo "$path"` in `install.sh` with safe Bash parameter expansion `"${path/#\~/$HOME}"`

### Changed
- Auto-activation upward search depth capped at 5 levels to avoid unnecessary disk I/O in deeply nested directories

### Added
- GitHub Actions CI (`.github/workflows/ci.yml`): ShellCheck, cross-platform syntax checks (Ubuntu + macOS), BATS tests, security regression tests
- GitHub Actions Release (`.github/workflows/release.yml`): version consistency validation, packaging, and GitHub Release creation on `v*` tags
- BATS test suite (`tests/uvm.bats`) covering core commands and security regression cases

---

## [1.0.2] - 2025-12-26

### Changed
- Installer and uninstaller rewritten to download-then-execute pattern, enabling interactive prompts when piped from curl
- Users can now customise install options interactively

---

## [1.0.1] - 2025-12-26

### Fixed
- Critical: fixed config file corruption during interactive install when `check_uv()` stdout polluted the config file
- Added `>&2` redirects to prevent stdout contamination from UV version output

### Added
- One-command remote install via curl/wget
- `uninstall.sh` with interactive and force modes
- Uninstall documentation (`project_document/UNINSTALL.md`)
- Automatic shell config backup on uninstall

### Changed
- Simplified interactive install prompts
- Improved environment directory selection UX

---

## [1.0.0] - 2025-12-26

### Added
- Initial release of uvm (UV Manager)
- Core commands: `create`, `activate`, `deactivate`, `delete`, `list`
- Auto-activation with two modes: local `.venv` (priority 1) and `.uvmrc` shared environment (priority 2)
- Cross-platform support: Linux, macOS, Windows Git Bash
- Shell integration via `uvm shell-hook`
- Configuration management: `uvm config`
- Install script with dependency checks
- MIT license

---

[Unreleased]: https://github.com/Tendo33/uvm/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/Tendo33/uvm/releases/tag/v1.1.1
[1.1.0]: https://github.com/Tendo33/uvm/releases/tag/v1.1.0
[1.0.5]: https://github.com/Tendo33/uvm/releases/tag/v1.0.5
[1.0.4]: https://github.com/Tendo33/uvm/releases/tag/v1.0.4
[1.0.3]: https://github.com/Tendo33/uvm/releases/tag/v1.0.3
[1.0.2]: https://github.com/Tendo33/uvm/releases/tag/v1.0.2
[1.0.1]: https://github.com/Tendo33/uvm/releases/tag/v1.0.1
[1.0.0]: https://github.com/Tendo33/uvm/releases/tag/v1.0.0
