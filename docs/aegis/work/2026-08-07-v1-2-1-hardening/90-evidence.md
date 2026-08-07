# uvm v1.2.1 comprehensive hardening - Evidence

- BATS v1.12.0: 50/50 passed with the host `uv 0.10.0`.
- BATS v1.12.0: 50/50 passed with a temporary official `uv 0.12.2` binary.
- ShellCheck 0.10.0, `bash -n`, workflow YAML parsing, consistency scans, and
  `git diff --check` passed.
- An isolated-home installation exercised a spaced environment root, create,
  activation, export, metadata-only rename, JSON parsing, delete, trust,
  untrust, and doctor successfully.
- The original main worktree remained clean. No commit, push, tag, release, or
  installed user configuration was changed.

Remote Ubuntu, Windows Git Bash, and GitHub release jobs remain future CI
evidence; local source checks do not claim those hosted jobs have run.

## EvidenceBundleDraft

- Artifact key: bats-uv-0-10
- Type: test
- Source: BATS v1.12.0 with uv 0.10.0
- Summary: 50 of 50 tests passed on macOS using uv 0.10.0.
- Verifier: Codex

## EvidenceBundleDraft

- Artifact key: bats-uv-0-12
- Type: test
- Source: BATS v1.12.0 with official uv 0.12.2 temporary binary
- Summary: 50 of 50 tests passed on macOS using uv 0.12.2.
- Verifier: Codex

## EvidenceBundleDraft

- Artifact key: shell-static
- Type: static-analysis
- Source: ShellCheck 0.10.0, bash -n, Ruby YAML parse, git diff --check
- Summary: All static, syntax, workflow YAML, and whitespace checks passed.
- Verifier: Codex

## EvidenceBundleDraft

- Artifact key: installed-e2e
- Type: integration
- Source: isolated HOME local install smoke test
- Summary: Install with spaced env root plus create, activate, export, rename, JSON parse, delete, trust, untrust, and doctor passed.
- Verifier: Codex
