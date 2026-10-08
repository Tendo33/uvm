# uvm - UV Environment Manager

<div align="center">

**A Bash-first, Conda-style environment manager for `uv`**

[中文文档](README_CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20Git%20Bash-blue.svg)](https://github.com/Tendo33/uvm)

</div>

`uvm` keeps the familiar `create / activate / deactivate / list / delete` workflow, while delegating Python, virtual-environment, and package operations to `uv`. Version `1.2.3` makes `uvm update` safe to run (no more false failure after a successful update), adds `uvm config set envs-dir` and a Python download mirror, and parses the config file instead of executing it. 1.2.2 wrote mirror configuration where uv actually reads it and keeps CI tracking the latest uv release, on top of the 1.2.1 hardening: trusted local activation, real `uv pip` package transfer, valid mirror configuration, stable rename semantics, and release-grade integration tests.

## Features

- Conda-style commands with a small Bash footprint
- Shared environments under `UVM_ENVS_DIR` and tracked custom `--path` environments
- Explicitly trusted upward auto-activation for local `.venv`, plus managed `.uvmrc` activation
- Safer metadata storage under `envs.d/` instead of fragile JSON string assembly
- `run`, metadata-only `rename`, `clone`, `export`, `import`, and self-update workflows
- Managed shell and PyPI mirror updates with stable start/end markers
- Diagnostics and recovery commands: `uvm doctor`, `uvm repair`
- Linux, macOS, and Windows Git Bash support

## Requirements

- Bash or Zsh
- `uv`
- Linux, macOS, or Windows with Git Bash

Notes:
- PowerShell and CMD are not supported in this release.
- On Windows, install `uv` in PowerShell first, then use `uvm` from Git Bash.

## Installation

### Recommended: download, then execute

Interactive installation needs a real script file, so download it first instead of piping it directly into `bash`.

Linux / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh
```

Windows (Git Bash):

```bash
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
curl -fsSL https://raw.githubusercontent.com/Tendo33/uvm/main/install.sh -o install.sh
bash install.sh
rm install.sh
```

The installer:

- installs `uvm` to `~/.local/bin/uvm`
- installs libraries to `~/.local/lib/uvm`
- initializes `UVM_HOME` at `${UVM_HOME:-~/.config/uvm}`
- initializes `UVM_ENVS_DIR` at `~/uv_envs` unless overridden
- registers existing managed environments in the default environment directory
- writes managed PATH and shell-hook blocks instead of appending loose lines
- optionally updates the `uv` PyPI index configuration through a validated managed block
- when `install.sh` is fetched from a tagged release, remote file downloads stay pinned to that same tag by default

### Non-interactive installation

```bash
bash install.sh -y
```

Important:

- In non-interactive mode, missing `uv` is a hard error.
- Use this mode for CI, automation, or repeatable local setup.
- Existing `UVM_HOME` and `UVM_ENVS_DIR` configuration is preserved during non-interactive reinstall/update.

### Custom managed environment directory

```bash
bash install.sh --envs-dir /path/to/envs
```

This writes the selected directory into `$(uvm config show)` through `UVM_HOME/config`.

### Advanced: override the remote download ref

When you download a release-scoped `install.sh`, the installer downloads `bin/`, `lib/`, and `completions/` from the matching `v<version>` ref by default.

If you intentionally want another ref, override it explicitly:

```bash
UVM_DOWNLOAD_REF=main bash install.sh -y
```

### Local development install

```bash
git clone https://github.com/Tendo33/uvm.git
cd uvm
bash install.sh
```

## Quick Start

```bash
uvm create myenv --python 3.11
source ~/.bashrc   # or ~/.zshrc after install
uvm activate myenv
uvm list
uvm deactivate
uvm delete myenv
```

## Command Reference

### `uvm create`

```bash
uvm create myenv
uvm create myenv --python 3.12
uvm create myenv --path /work/envs/myenv
```

Behavior:

- environment names are validated before any filesystem write
- `--path` creates the environment at a custom location
- custom-path environments are still tracked by metadata and show up in `uvm list`

### `uvm activate`

```bash
uvm activate myenv
```

`activate` must run inside shell integration because it needs to `source` the target environment into the current shell.

If it says shell integration is required, add this to your shell rc file:

```bash
eval "$(uvm shell-hook)"
```

The installer can manage that block for you automatically.

### `uvm deactivate`

```bash
uvm deactivate
```

Like `activate`, this works through shell integration.

### `uvm list`

```bash
uvm list
uvm list --all
```

Behavior:

- lists managed records from `envs.d/`
- also discovers valid environments under the default `UVM_ENVS_DIR`
- marks the current active environment with `*`
- `--all` adds the source column so you can see whether an entry is `managed` or `discovered`

### `uvm delete`

```bash
uvm delete myenv
uvm delete myenv --force
```

Safety rules:

- refuses invalid environment names
- refuses to delete the currently active environment
- refuses to delete unmanaged or out-of-scope paths
- removes both the directory and the corresponding metadata record

### `uvm run`, `rename`, `clone`, `export`, and `import`

```bash
uvm run myenv python -V
uvm rename myenv renamed
uvm clone renamed copied
uvm export renamed > requirements.txt
uvm import restored --from requirements.txt
```

- `run` executes in a subshell and does not modify the calling shell.
- `rename` changes the managed name only; it does not move a non-relocatable venv.
- `clone`, `export`, and `import` delegate package operations to `uv pip --python`, so seeded `pip` is not required.
- failed package import/clone operations return a failure instead of reporting partial success.

### `uvm trust` and `uvm untrust`

```bash
cd ~/project
uvm trust          # review first; defaults to ./.venv
uvm trust list
uvm untrust
```

Local `.venv` activation scripts are executable shell code. `uvm` therefore refuses to source them automatically until their canonical path is explicitly trusted. Managed `.uvmrc` environments do not need this local-path trust step.

### `uvm update`

```bash
uvm update            # latest release
uvm update --check    # only report installed vs. available version
uvm update v1.2.3     # a specific release; also reinstalls the current one
```

`latest` resolves through GitHub Releases, refuses version downgrade, and preserves the configured environment directory. When you are already on the latest release it says so instead of reinstalling. If you installed without auto-activation, the update keeps it off. Restart your shell afterwards (`exec "$SHELL"`) so the current session loads the new version.

Upgrading from a release older than 1.2.0 (`uvm version` shows 1.0.x or 1.1.x, and `uvm update` reports `Unknown command`): reinstall once, then `uvm update` is available from then on. Existing environments and the configured environment directory are kept.

```bash
curl -fsSL https://github.com/Tendo33/uvm/releases/latest/download/install.sh -o install.sh
bash install.sh -y
rm install.sh
exec "$SHELL"
```

Older installers appended a bare `eval "$(uvm shell-hook)"` line to your shell rc file. The new installer writes its own block between `# >>> uvm shell >>>` markers, so delete the old bare line to avoid loading the hook twice.

### `uvm scan`

```bash
uvm scan
uvm scan /path/to/envs
```

Scans a directory and registers valid environments found there.

### `uvm init`

```bash
uvm init
```

Initializes `UVM_HOME`, ensures the default environment directory exists, and scans it. Mirror configuration remains opt-in.

### `uvm doctor`

```bash
uvm doctor
```

Reports:

- platform and shell
- resolved shell rc file
- shell hook status
- `UVM_HOME`
- `UVM_ENVS_DIR`
- metadata record count
- whether `~/.local/bin` is in `PATH`
- detected `uv` version
- mirror block status
- current active environment
- whether the current environment came from auto-activation

Use this first when `activate`, `list`, or auto-activation does not behave as expected.

### `uvm repair`

```bash
uvm repair
```

Repairs safe, recoverable state by:

- pruning invalid metadata records
- rescanning the default `UVM_ENVS_DIR`
- rewriting the managed shell-hook block
- preserving any existing managed mirror block without inventing a replacement URL

It does not delete valid environments automatically.

### `uvm config`

```bash
uvm config show                          # every effective setting, including both mirrors
uvm config get envs-dir
uvm config set envs-dir ~/my-envs        # directory for new environments
uvm config mirror set https://pypi.tuna.tsinghua.edu.cn/simple
uvm config mirror show
uvm config mirror remove
uvm config python-mirror set https://mirror.nju.edu.cn/github-release/astral-sh/python-build-standalone
uvm config python-mirror show
uvm config python-mirror remove
```

- `config set envs-dir` creates the directory, saves it, and registers any environments already inside it. Existing environments elsewhere stay where they are and remain registered.
- `config mirror` manages the PyPI package index (`[[index]]`) used for `pip install`.
- `config python-mirror` manages `python-install-mirror`, which uv uses to download Python interpreters (`uvm create --python 3.12` on a machine without that version).
- Both are written to uv's user config file (see [Managed mirror block](#managed-mirror-block)). If an unmanaged setting of the same kind already exists, `uvm` leaves the file unchanged.

### `uvm shell-hook`

```bash
eval "$(uvm shell-hook)"
```

This command emits the shell runtime needed for:

- `uvm activate`
- `uvm deactivate`
- prompt-based auto-activation checks

The shell hook no longer overrides `cd`. It uses prompt/chpwd hooks instead.

## Auto-Activation

`uvm` checks for activation targets upward from the current directory on every prompt.

Priority order:

1. nearest explicitly trusted parent `.venv`
2. nearest parent `.uvmrc`

That means:

- entering a project subdirectory still keeps the project environment active
- leaving the project tree deactivates auto-activated environments
- `.venv` wins over `.uvmrc` when both exist in scope

An untrusted `.venv` is detected but never sourced. `uvm doctor` reports the pending path; inspect it and run `uvm trust` only when you accept its activation script.

### Local `.venv`

```bash
cd ~/project
uv venv
uvm trust
cd ~/project/src/module
```

After trust is granted, `~/project/.venv` is auto-activated even from `src/module`.

### Shared environment with `.uvmrc`

```bash
uvm create shared-311 --python 3.11
echo "shared-311" > .uvmrc
```

Any directory inside that project tree inherits the nearest parent `.uvmrc`.

## Configuration Model

### Effective paths

- `UVM_HOME`: defaults to `~/.config/uvm`
- `UVM_ENVS_DIR`: defaults to `~/uv_envs`; change it with `uvm config set envs-dir <dir>`
- config file: `~/.config/uvm/config`, plain `KEY="value"` lines that uvm parses but never executes
- metadata directory: `~/.config/uvm/envs.d`
- the installer respects an already-exported `UVM_HOME`

### Metadata format

`uvm` now stores one record per environment:

```text
~/.config/uvm/envs.d/
  myenv.env
  py311.env
```

Benefits:

- no manual JSON string assembly
- atomic record writes through temporary files + move
- stable add/update/remove behavior in pure Bash
- lock directory reserved for concurrent metadata writes

Legacy `envs.json` is only used for one-time migration when record files do not exist yet.

### Managed shell blocks

The installer and repair flow write stable markers such as:

```bash
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<

# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
```

These markers make install, repair, reinstall, and uninstall idempotent.

### Managed mirror block

`uvm config mirror set <url>` updates only the managed PyPI index block inside uv's user-level `uv.toml`, at the same location uv reads:

- Linux / macOS: `$XDG_CONFIG_HOME/uv/uv.toml` when `XDG_CONFIG_HOME` is an absolute path, otherwise `~/.config/uv/uv.toml`
- Windows Git Bash: `%APPDATA%\uv\uv.toml`

`uvm doctor` prints the resolved path. A managed block left in `~/.config/uv/uv.toml` by uvm 1.2.1 or earlier, where uv does not read it, is reported by `uvm doctor` and removed by the next `config mirror set` or `config mirror remove`.



```toml
# >>> uvm mirror >>>
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
# <<< uvm mirror <<<
```

`uvm config python-mirror set <url>` writes its own block at the top of the same file, because `python-install-mirror` is a top-level key and must come before any TOML table:

```toml
# >>> uvm python-mirror >>>
python-install-mirror = "https://mirror.nju.edu.cn/github-release/astral-sh/python-build-standalone"
# <<< uvm python-mirror <<<
```

If `uv.toml` already exists, `uvm` keeps a one-time backup as `uv.toml.backup`.
An unmanaged `[[index]]` blocks `config mirror set`, and an unmanaged `python-install-mirror` blocks `config python-mirror set`; in both cases the file is left unchanged. The two mirrors are independent and neither is inferred from the other. The `UV_DEFAULT_INDEX` / `UV_INDEX_URL` and `UV_PYTHON_INSTALL_MIRROR` environment variables override them, and `uvm config show` points this out when they are set.

## Troubleshooting

### `uvm: command not found`

Run:

```bash
source ~/.bashrc   # or ~/.zshrc
uvm doctor
```

If `PATH ~/.local/bin` shows `missing`, add:

```bash
export PATH="${HOME}/.local/bin:$PATH"
```

or rerun:

```bash
bash install.sh -y
```

### `uvm activate` says shell integration is required

Run:

```bash
uvm repair
source ~/.bashrc   # or ~/.zshrc
```

Then verify with:

```bash
uvm doctor
```

### `uvm list` is missing an environment

Checklist:

- if it was created with `uvm create --path`, confirm the path still exists
- run `uvm repair` to prune stale records and rescan the default directory
- run `uvm list --all` to inspect source labels

### Auto-activation is not working

Checklist:

- the shell rc file contains the managed `uvm shell` block
- the shell has been reloaded
- `.venv` is a valid `uv` environment with an activation script
- `.uvmrc` contains a valid environment name
- the referenced shared environment still exists

Use:

```bash
uvm doctor
uvm repair
```

### `uv` is missing

`uvm` does not bundle `uv`.

- interactive install can offer installation on Linux/macOS
- non-interactive install fails if `uv` is missing
- Windows users should install `uv` in PowerShell first

## Uninstall

```bash
bash uninstall.sh
bash uninstall.sh --force
bash uninstall.sh --keep-shell-config
```

Uninstall removes:

- `~/.local/bin/uvm`
- `~/.local/lib/uvm`
- the effective `UVM_HOME` directory
- managed shell blocks, unless `--keep-shell-config` is used

Uninstall keeps:

- your virtual environments
- `uv`
- uv's `uv.toml`

If you installed with a custom `UVM_HOME`, export the same value before uninstalling:

```bash
UVM_HOME=/custom/uvm-home bash uninstall.sh --force
```

Details: [project_document/UNINSTALL.md](project_document/UNINSTALL.md)

## Platform Support

- Linux: supported
- macOS: supported
- Windows Git Bash: supported
- PowerShell / CMD: not supported in this release

## Verification Snapshot

This repository currently includes:

- BATS tests for metadata, name validation, managed blocks, `doctor`, `repair`, `--path`, and upward `.uvmrc` activation
- CI jobs for syntax checks, BATS, and Windows Git Bash smoke coverage

## Roadmap

- environment export / import
- shell completion
- richer environment descriptions
- future shell adapters beyond Bash/Zsh after the current Bash core remains stable

## License

MIT. See [LICENSE](LICENSE).
