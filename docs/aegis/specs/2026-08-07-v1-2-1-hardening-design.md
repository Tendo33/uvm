# uvm v1.2.1 Hardening Design

Date: `2026-08-07`
Status: approved for local implementation by the user's `全面改进` request after the read-only audit

## Goal

Make the existing `uvm 1.2.0` feature set safe, truthful, testable against real
`uv`, and releasable as `1.2.1` without expanding the product surface.

## Ownership

- `uvm` owns named shared-environment registration, lifecycle coordination,
  trusted shell integration, diagnostics, and the Conda-style CLI.
- `uv` owns Python discovery/downloads, virtual-environment creation, package
  inspection/installation, and the semantics of `uv.toml`.
- Existing public command names remain stable; unsafe internal implementations
  are replaced rather than retained as fallbacks.

## Required behavior

1. Mirror management must emit configuration accepted by supported `uv`
   versions. PyPI index and Python-install mirrors are distinct settings.
2. Automatic activation must never source an untrusted project `.venv` without
   explicit user trust. Registered `.uvmrc` environments remain automatic.
3. `clone`, `export`, and `import` must use `uv pip --python`; failures must be
   visible and partially created destinations must be cleaned up safely.
4. A registry rename may not move an ordinary virtual environment. The public
   name changes while the path stays stable.
5. Custom paths must be canonical absolute paths. Option arguments must reject
   missing values without looping.
6. JSON output must be valid for every supported filesystem path.
7. Installer/update operations must preserve the configured environment root,
   expose interactive prompts correctly, and resolve `latest` to a release tag.
8. CI must exercise real `uv` environments, supported platforms, release tests,
   and version/document consistency using pinned maintained actions.
9. Documentation and version declarations must agree on `1.2.1`.

## Trust model

- `.uvmrc` names resolve only through registered/default managed environments.
- Local `.venv` auto-activation requires an exact canonical path in a user-owned
  trust registry under `UVM_HOME`.
- Manual `uvm activate` remains available for any known valid environment.
- `doctor` reports pending local `.venv` trust rather than executing it.

## Compatibility boundary

- Existing `envs.d/*.env` files remain readable.
- Existing public commands and aliases remain available.
- No implementation or test may modify real user environments, shell profiles,
  `~/.config/uv/uv.toml`, Git tags, releases, or remote branches.
- The obsolete invalid `[python-downloads]` table and `python -m pip` paths have
  no compatibility value and are retired delete-first.

## Verification

- Focused BATS regressions for trust, arguments, JSON, path canonicalization,
  mirror syntax, rename semantics, installer preservation, and update resolution.
- Real-`uv` integration tests for create/export/import/clone.
- Full BATS suite, Bash syntax checks, ShellCheck where available, document and
  version consistency scans, and a clean diff review.

## Non-goals

- New environment-management commands.
- Adoption of preview-only `centralized-project-envs` as the storage owner.
- PowerShell/CMD support.
- Commit, push, tag, release, or mutation of installed user configuration.

