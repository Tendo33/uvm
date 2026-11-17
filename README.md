# uvm — UV Environment Manager (1.3.3)

<div align="center">

**Named, shared environments for `uv` — the conda workflow without conda**

[中文文档](README_CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20Git%20Bash-blue.svg)](https://github.com/Tendo33/uvm)
[![CI](https://github.com/Tendo33/uvm/actions/workflows/ci.yml/badge.svg)](https://github.com/Tendo33/uvm/actions/workflows/ci.yml)

</div>

`uv` is fast, but it has no concept of a named, shared environment you can activate by name from any directory. `uvm` adds that layer — `create`, `activate`, `deactivate`, `list`, `delete` — while delegating every Python, venv, and package operation to `uv`. You keep the speed; you get the workflow.

## Why uvm?

| Task | Without uvm | With uvm |
|------|-------------|----------|
| Create a named env | `uv venv ~/uv_envs/myenv --python 3.11` | `uvm create myenv --python 3.11` |
| Activate by name | `source ~/uv_envs/myenv/bin/activate` | `uvm activate myenv` |
| Auto-activate per project | manual | `.uvmrc` or trusted `.venv` |
| List all envs | `ls ~/uv_envs` | `uvm list` |
| Move / share envs across machines | manual | `uvm export` / `uvm import` |

uvm does not replace `uv`. It is a thin shell wrapper (~1 200 lines of Bash) that tracks environment metadata and provides the activation plumbing `uv` deliberately omits.

## Quick Start

```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y
source ~/.zshrc          # or ~/.bashrc

# 2. Create and activate
uvm create myenv --python 3.11
uvm activate myenv

# 3. Work
python -m pip install requests
python my_script.py

# 4. Done
uvm deactivate
```

## Requirements

- Bash ≥ 3.2 or Zsh
- [`uv`](https://docs.astral.sh/uv/) (the installer can install it for you on Linux/macOS)
- Linux, macOS, or Windows with Git Bash

PowerShell and CMD are not supported.

## Installation

### Interactive (recommended for first install)

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh

# Windows (Git Bash) — install uv in PowerShell first
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh
```

The wizard asks for an environment directory, whether to install `uv`, and whether to enable auto-activation.

### Non-interactive (CI / scripted)

```bash
# Pipe directly — no temp file needed
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y

# With a custom environment directory
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y --envs-dir /path/to/envs

# With a PyPI mirror (useful in China)
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh | bash -s -- -y \
  --mirror https://pypi.tuna.tsinghua.edu.cn/simple
```

In non-interactive mode, missing `uv` is a hard error. Use `--mirror` or `--no-mirror` to control PyPI mirror configuration; it is opt-in and skipped by default.

The installer puts `uvm` in `~/.local/bin`, libraries in `~/.local/lib/uvm`, and config in `~/.config/uvm`. It writes managed blocks in your shell RC for PATH and the shell hook, so reinstalls and uninstalls are clean.

### Custom environment directory

```bash
bash install.sh --envs-dir /path/to/envs
```

### Local development install

```bash
git clone https://github.com/Tendo33/uvm.git
cd uvm
bash install.sh
```

### Upgrade

```bash
uvm update           # latest release
uvm update --check   # check without installing (uses GitHub API)
uvm update v1.2.3    # specific version
```

After updating, restart your shell: `exec "$SHELL"`

---

## Common Commands

These cover 90% of daily use:

```bash
uvm create myenv --python 3.11   # create named environment
uvm activate myenv               # activate (requires shell integration)
uvm deactivate                   # deactivate current environment
uvm list                         # list all environments
uvm status                       # show active env and config at a glance
uvm delete myenv                 # delete environment
uvm run myenv python -V          # run command without activating
```

---

## Full Command Reference

### create

```bash
uvm create myenv
uvm create myenv --python 3.12
uvm create myenv --path /work/envs/myenv
```

Validates the name before touching the filesystem. `--path` environments are tracked by metadata and appear in `uvm list`.

### activate / deactivate

```bash
uvm activate myenv
uvm deactivate
```

Requires shell integration (`eval "$(uvm shell-hook)"` in your RC file — the installer adds this automatically).

### list

```bash
uvm list
uvm list --all    # show source column (managed / discovered)
uvm list --json   # machine-readable JSON array
```

The active environment is marked with a green `*`.

### status

```bash
uvm status           # active env, envs-dir, record count
uvm status --json    # {"active_env":"myenv","active_path":"...","envs_dir":"...","records":3}
```

### delete

```bash
uvm delete myenv
uvm delete myenv --force   # skip confirmation
```

Refuses to delete the active environment. Also clears the trust entry for that path, so a future venv created there is not silently trusted.

### run

```bash
uvm run myenv python my_script.py
uvm run myenv pytest tests/
```

Runs the command inside the environment without modifying the calling shell.

### rename

```bash
uvm rename myenv myenv-v2
```

Changes the managed name only; does not move the directory. Warns if any `.uvmrc` files in the current tree still reference the old name.

### clone

```bash
uvm clone myenv myenv-copy
```

Copies the source environment and transfers packages via `uv pip`.

### export / import

```bash
uvm export myenv > requirements.txt
uvm import restored --from requirements.txt
```

Uses `uv pip freeze` and `uv pip install`. No seeded `pip` required.

### trust / untrust

```bash
uvm trust            # trust ./.venv (inspect the activation script first)
uvm trust /path      # trust a specific path
uvm trust list       # list trusted paths
uvm untrust          # revoke trust for ./.venv
```

Local `.venv` activation scripts are executable shell code. uvm never sources them automatically until you explicitly trust their canonical path. Managed `.uvmrc` environments skip this step.

### update

```bash
uvm update            # latest release
uvm update --check    # compare installed vs available (GitHub API, no download)
uvm update v1.2.3     # specific release
```

Refuses downgrade. Preserves `UVM_HOME`, `UVM_ENVS_DIR`, and your auto-activation preference.

### doctor

```bash
uvm doctor
```

Shows installation health, shell hook status, active environment, mirror config, and pending trust warnings — grouped and color-coded. Run this first when something is not working.

### repair

```bash
uvm repair
```

Prunes stale metadata records, rescans the default environment directory, and rewrites the managed shell-hook block. Does not delete valid environments.

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

`config mirror` manages the PyPI package index used by `uv pip install`. `config python-mirror` manages the URL uv uses to download Python interpreters. Both are written to uv's user-level `uv.toml`. If an unmanaged setting of the same kind already exists, uvm leaves the file unchanged.

---

## Auto-Activation

Enable by adding this to your shell RC (the installer does this automatically):

```bash
eval "$(uvm shell-hook)"
```

Once enabled, uvm checks for an activation target whenever you change directory. Priority:

1. Nearest trusted parent `.venv`
2. Nearest parent `.uvmrc`

Leaving the project tree deactivates the auto-activated environment.

### Auto-activate a local .venv

```bash
cd ~/project
uv venv                # create .venv with uv
uvm trust              # explicitly trust it (inspect the activation script first)
cd ~/project/src       # activates automatically
```

### Auto-activate a shared named environment

```bash
uvm create shared-311 --python 3.11
echo "shared-311" > ~/project/.uvmrc
cd ~/project/src       # activates shared-311 automatically
```

---

## Configuration

| Item | Default | Override |
|------|---------|----------|
| `UVM_HOME` | `~/.config/uvm` | export before install |
| `UVM_ENVS_DIR` | `~/uv_envs` | `uvm config set envs-dir` |
| Config file | `~/.config/uvm/config` | — |
| Metadata | `~/.config/uvm/envs.d/*.env` | — |
| uv config | `~/.config/uv/uv.toml` | `XDG_CONFIG_HOME` |

The config file uses plain `KEY="value"` lines that uvm parses but never executes.

Metadata is one file per environment under `envs.d/`, written atomically via `mktemp` + `mv`. A legacy `envs.json` from older versions is migrated once and not written again.

The installer writes stable managed blocks in your shell RC:

```bash
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<

# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
```

These markers make install, repair, reinstall, and uninstall idempotent.

The mirror blocks in `uv.toml` follow the same pattern:

```toml
# >>> uvm mirror >>>
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
# <<< uvm mirror <<<
```

`uvm doctor` prints the resolved `uv.toml` path. `UV_DEFAULT_INDEX` and `UV_PYTHON_INSTALL_MIRROR` environment variables override the managed blocks; `uvm config show` notes when they are set.

---

## Troubleshooting

**`uvm: command not found`**
```bash
source ~/.zshrc    # or ~/.bashrc
uvm doctor
```
If `PATH ~/.local/bin` shows MISSING, rerun `bash install.sh -y`.

**`uvm activate` says shell integration is required**
```bash
uvm repair && source ~/.zshrc
```

**An environment is missing from `uvm list`**
```bash
uvm repair            # prune stale records and rescan
uvm list --all        # check source labels
```

**Auto-activation is not working**
```bash
uvm doctor            # check hook status and pending trust warnings
uvm repair
```

**After `uvm update`, the shell still shows the old version**
```bash
exec "$SHELL"         # reload shell to pick up the new hook
```

---

## Uninstall

```bash
bash uninstall.sh
bash uninstall.sh --force             # skip confirmation
bash uninstall.sh --keep-shell-config # leave shell RC blocks untouched
```

Removes `~/.local/bin/uvm`, `~/.local/lib/uvm`, `UVM_HOME`, and managed shell blocks. Your virtual environments and uv are kept.

If you used a custom `UVM_HOME`:
```bash
UVM_HOME=/custom/path bash uninstall.sh --force
```

---

## Platform Notes

| Platform | Status |
|----------|--------|
| Linux | Supported |
| macOS | Supported |
| Windows Git Bash | Supported (install uv in PowerShell first) |
| PowerShell / CMD | Not supported |

---

## License

MIT. See [LICENSE](LICENSE).

