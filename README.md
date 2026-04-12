# uvm - UV Environment Manager

<div align="center">

**A Bash-first, Conda-style environment manager for `uv`**

[中文文档](README_CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20Git%20Bash-blue.svg)](https://github.com/Tendo33/uvm)

</div>

`uvm` keeps the familiar `create / activate / deactivate / list / delete` workflow, while using `uv` for environment creation and package management. Version `1.1.1` focuses on reliability: unified config resolution, safer metadata, managed shell integration blocks, upward auto-activation lookup, and first-line diagnostics through `doctor` and `repair`.

## Features

- Conda-style commands with a small Bash footprint
- Shared environments under `UVM_ENVS_DIR` and tracked custom `--path` environments
- Upward auto-activation for both `.venv` and `.uvmrc`
- Safer metadata storage under `envs.d/` instead of fragile JSON string assembly
- Managed shell and mirror updates with stable start/end markers
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
- updates the `uv` mirror configuration through a managed block
- when `install.sh` is fetched from a tagged release, remote file downloads stay pinned to that same tag by default

### Non-interactive installation

```bash
bash install.sh -y
```

Important:

- In non-interactive mode, missing `uv` is a hard error.
- Use this mode for CI, automation, or repeatable local setup.
- If `UVM_HOME` is already exported, the installer reuses it instead of forcing `~/.config/uvm`.

### Custom managed environment directory

```bash
bash install.sh --envs-dir /path/to/envs
```

This writes the selected directory into `$(uvm config show)` through `UVM_HOME/config`.

### Advanced: override the remote download ref

When you download a release-scoped `install.sh`, the installer downloads `bin/`, `lib/`, and `templates/` from the matching `v<version>` ref by default.

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

Initializes `UVM_HOME`, ensures the default environment directory exists, configures the mirror block, and scans the default environment directory.

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
- rewriting the managed mirror block

It does not delete valid environments automatically.

### `uvm config`

```bash
uvm config show
uvm config mirror
```

`config show` prints the effective config paths.  
`config mirror` refreshes the managed mirror block in `~/.config/uv/uv.toml`.
If `uvm` detects unmanaged mirror sections that would conflict, it warns and leaves the file unchanged.

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

`uvm` checks for activation targets upward from the current directory.

Priority order:

1. nearest parent `.venv`
2. nearest parent `.uvmrc`

That means:

- entering a project subdirectory still keeps the project environment active
- leaving the project tree deactivates auto-activated environments
- `.venv` wins over `.uvmrc` when both exist in scope

### Local `.venv`

```bash
cd ~/project
uv venv
cd ~/project/src/module
```

If `~/project/.venv` exists and is valid, it is auto-activated even from `src/module`.

### Shared environment with `.uvmrc`

```bash
uvm create shared-311 --python 3.11
echo "shared-311" > .uvmrc
```

Any directory inside that project tree inherits the nearest parent `.uvmrc`.

## Configuration Model

### Effective paths

- `UVM_HOME`: defaults to `~/.config/uvm`
- `UVM_ENVS_DIR`: defaults to `~/uv_envs`
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

`uvm config mirror` and `uvm repair` update only the managed block inside `~/.config/uv/uv.toml`:

```toml
# >>> uvm mirror >>>
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true

[python-downloads]
url = "https://mirrors.tuna.tsinghua.edu.cn/python-releases/"
# <<< uvm mirror <<<
```

If `uv.toml` already exists, `uvm` keeps a one-time backup as `uv.toml.backup`.
If unmanaged `[[index]]` or `[python-downloads]` sections are already present, `uvm` skips writing its managed mirror block to avoid producing an invalid or ambiguous TOML configuration.

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
- `~/.config/uv/uv.toml`

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
