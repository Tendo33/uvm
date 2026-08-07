#!/usr/bin/env bats

setup() {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    export UVM_HOME="${TEST_HOME}/custom-uvm-home"
    export UVM_ENVS_DIR="${TEST_HOME}/uv_envs"
    export PATH="${BATS_TEST_DIRNAME}/../bin:$PATH"

    source "${BATS_TEST_DIRNAME}/../lib/uvm-config.sh"
    source "${BATS_TEST_DIRNAME}/../lib/uvm-core.sh"
    source "${BATS_TEST_DIRNAME}/../lib/uvm-shell-hooks.sh"
}

teardown() {
    rm -rf "$TEST_HOME"
}

make_fake_env() {
    local env_path="$1"

    mkdir -p "${env_path}/bin"
    cat > "${env_path}/pyvenv.cfg" <<'EOF'
home = /tmp/python
EOF

    cat > "${env_path}/bin/activate" <<EOF
VIRTUAL_ENV="${env_path}"
PATH="${env_path}/bin:${PATH}"
deactivate() {
    unset VIRTUAL_ENV
    unset UVM_ACTIVE_ENV
    unset UVM_AUTO_ACTIVATED
    unset UVM_AUTO_ACTIVATED_PATH
}
export VIRTUAL_ENV
export PATH
EOF
}

make_real_env() {
    local env_path="$1"
    uv venv "$env_path" --python 3.12 >/dev/null
}

load_install_functions() {
    mkdir -p "${HOME}/.local/lib/uvm"
    cp "${BATS_TEST_DIRNAME}/../lib/uvm-config.sh" "${HOME}/.local/lib/uvm/uvm-config.sh"
    export UVM_INSTALL_SKIP_MAIN=1
    # shellcheck source=/dev/null
    source "${BATS_TEST_DIRNAME}/../install.sh"
    unset UVM_INSTALL_SKIP_MAIN
}

load_completion_script() {
    # shellcheck source=/dev/null
    source "${BATS_TEST_DIRNAME}/../completions/uvm.bash"
}

@test "init_uvm_config creates the new metadata layout under UVM_HOME" {
    init_uvm_config

    [ -d "${UVM_HOME}" ]
    [ -d "${UVM_HOME}/envs.d" ]
    [ -d "${UVM_HOME}/locks" ]
    [ -f "${UVM_HOME}/config" ]
}

@test "uvm_get_iso_timestamp returns a valid ISO 8601 timestamp" {
    run uvm_get_iso_timestamp
    [ "$status" -eq 0 ]
    # Must begin with YYYY-MM-DDTHH:MM:SS
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}

@test "environment name validation rejects traversal and shell metacharacters" {
    run uvm_is_valid_env_name "safe_env-1"
    [ "$status" -eq 0 ]

    for invalid in "../bad" "name with spaces" "semi;colon" "nested/path" '$(boom)'; do
        run uvm_is_valid_env_name "$invalid"
        [ "$status" -ne 0 ]
    done
}

@test "uvm_create rejects invalid environment names before touching the filesystem" {
    init_uvm_config

    run uvm_create "../escape"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid environment name"* ]]
    [ ! -d "${UVM_ENVS_DIR}/../escape" ]
}

@test "uvm_create with --path registers a managed environment that list can display" {
    init_uvm_config
    local custom_path="${TEST_HOME}/custom envs/myenv"

    run uvm_create "customenv" --path "$custom_path"

    [ "$status" -eq 0 ]
    [ -d "$custom_path" ]
    local resolved_custom
    resolved_custom=$(cd "$custom_path" && pwd -P)
    run uvm_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"customenv"* ]]
    [[ "$output" == *"$resolved_custom"* ]]
}

@test "managed metadata uses UVM_HOME and stores one record per environment" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/metaenv"

    add_env_record "metaenv" "${UVM_ENVS_DIR}/metaenv" "3.12.1"

    [ -f "${UVM_HOME}/envs.d/metaenv.env" ]
    run get_env_path "metaenv"
    [ "$status" -eq 0 ]
    [ "$output" = "${UVM_ENVS_DIR}/metaenv" ]
}

@test "uvm_load_env_record does not execute injected shell code" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/safeenv"
    add_env_record "safeenv" "${UVM_ENVS_DIR}/safeenv" "3.12.1"

    # Append a line that would run arbitrary code if the file were sourced
    local probe_file="${TMPDIR:-/tmp}/uvm_inject_probe_$$"
    echo "UVM_RECORD_INJECTED=1; touch ${probe_file}" \
        >> "${UVM_HOME}/envs.d/safeenv.env"

    run uvm_load_env_record "safeenv"
    [ "$status" -eq 0 ]
    [ -z "${UVM_RECORD_INJECTED:-}" ]
    [ ! -f "$probe_file" ]
}

@test "remove_env_record only removes the requested environment record" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/env-a"
    make_fake_env "${UVM_ENVS_DIR}/env-b"

    add_env_record "env-a" "${UVM_ENVS_DIR}/env-a" "3.11.9"
    add_env_record "env-b" "${UVM_ENVS_DIR}/env-b" "3.12.1"
    remove_env_record "env-a"

    [ ! -f "${UVM_HOME}/envs.d/env-a.env" ]
    [ -f "${UVM_HOME}/envs.d/env-b.env" ]
}

@test "uvm_run executes command inside named environment without polluting current shell" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/runenv"
    # Provide a fake python that reports the VIRTUAL_ENV it sees
    cat > "${UVM_ENVS_DIR}/runenv/bin/python" <<'EOF'
#!/bin/bash
echo "VENV=${VIRTUAL_ENV:-none}"
EOF
    chmod +x "${UVM_ENVS_DIR}/runenv/bin/python"
    add_env_record "runenv" "${UVM_ENVS_DIR}/runenv" "3.12.1"

    run uvm_run "runenv" python
    [ "$status" -eq 0 ]
    [[ "$output" == *"VENV=${UVM_ENVS_DIR}/runenv"* ]]
    # Caller's VIRTUAL_ENV must be unaffected
    [ -z "${VIRTUAL_ENV:-}" ]
}

@test "uvm_run fails when environment does not exist" {
    init_uvm_config
    run uvm_run "ghost-env" true
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "uvm_rename changes the managed name without moving the environment" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/oldname"
    add_env_record "oldname" "${UVM_ENVS_DIR}/oldname" "3.11.9"

    run uvm_rename "oldname" "newname"
    [ "$status" -eq 0 ]

    [ ! -f "${UVM_HOME}/envs.d/oldname.env" ]
    [ -f "${UVM_HOME}/envs.d/newname.env" ]
    [ ! -d "${UVM_ENVS_DIR}/newname" ]
    [ -d "${UVM_ENVS_DIR}/oldname" ]
    run get_env_path "newname"
    [ "$output" = "${UVM_ENVS_DIR}/oldname" ]
}

@test "uvm_rename for custom-path env only renames record, not directory" {
    init_uvm_config
    local custom="${TEST_HOME}/custom/myenv"
    make_fake_env "$custom"
    add_env_record "myenv" "$custom" "3.12.1"

    run uvm_rename "myenv" "myenv-renamed"
    [ "$status" -eq 0 ]
    [ ! -f "${UVM_HOME}/envs.d/myenv.env" ]
    [ -f "${UVM_HOME}/envs.d/myenv-renamed.env" ]
    [ -d "$custom" ]
}

@test "uvm_rename refuses to rename the active environment" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/activeenv"
    add_env_record "activeenv" "${UVM_ENVS_DIR}/activeenv" "3.12.1"
    export VIRTUAL_ENV="${UVM_ENVS_DIR}/activeenv"

    run uvm_rename "activeenv" "other"
    [ "$status" -ne 0 ]
    [[ "$output" == *"active"* ]]

    unset VIRTUAL_ENV
}

@test "uvm_rename rejects non-existent source environment" {
    init_uvm_config
    run uvm_rename "no-such-env" "newname"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "uvm_clone creates new environment record from source" {
    init_uvm_config
    make_real_env "${UVM_ENVS_DIR}/srcenv"
    add_env_record "srcenv" "${UVM_ENVS_DIR}/srcenv" "3.12.1"

    run uvm_clone "srcenv" "dstenv"
    [ "$status" -eq 0 ]
    [ -f "${UVM_HOME}/envs.d/dstenv.env" ]
    [[ "$output" == *"cloned"* ]]
}

@test "uvm_clone fails when destination already exists" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/srcenv"
    make_fake_env "${UVM_ENVS_DIR}/dstenv"
    add_env_record "srcenv" "${UVM_ENVS_DIR}/srcenv" "3.12.1"
    add_env_record "dstenv" "${UVM_ENVS_DIR}/dstenv" "3.12.1"

    run uvm_clone "srcenv" "dstenv"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "uvm_export works for a standard unseeded uv environment" {
    init_uvm_config
    make_real_env "${UVM_ENVS_DIR}/exportenv"
    add_env_record "exportenv" "${UVM_ENVS_DIR}/exportenv" "3.12.1"

    run uvm_export "exportenv"
    [ "$status" -eq 0 ]
}

@test "uvm_import works for an empty requirements file without seeded pip" {
    init_uvm_config
    local requirements="${TEST_HOME}/requirements.txt"
    : > "$requirements"

    run uvm_import "importenv" --from "$requirements"

    [ "$status" -eq 0 ]
    [ -f "${UVM_HOME}/envs.d/importenv.env" ]
}

@test "uvm_import fails when requirements file does not exist" {
    init_uvm_config
    run uvm_import "newenv" --from "/nonexistent/requirements.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "uvm_list --json outputs a JSON array with environment entries" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/json-env"
    add_env_record "json-env" "${UVM_ENVS_DIR}/json-env" "3.12.1"

    run uvm_list --json
    [ "$status" -eq 0 ]
    [[ "$output" == "["* ]]
    [[ "$output" == *"json-env"* ]]
    [[ "$output" == *'"name"'* ]]
    [[ "$output" == *'"path"'* ]]
    [[ "$output" == *'"source"'* ]]
    [[ "$output" == "]" ]] || [[ "$output" == *$'\n]' ]]
}

@test "uvm_list --json escapes quotes in custom paths" {
    init_uvm_config
    local custom_path="${TEST_HOME}/custom\"quote/json-env"
    make_fake_env "$custom_path"
    add_env_record "json-env" "$custom_path" "3.12.1"

    run uvm_list --json

    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | python3 -m json.tool >/dev/null
}

@test "uvm_auto_activate inherits .uvmrc from a parent directory" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/shared-env"
    add_env_record "shared-env" "${UVM_ENVS_DIR}/shared-env" "3.12.1"

    mkdir -p "${TEST_HOME}/workspace/project/src/module"
    printf 'shared-env\n' > "${TEST_HOME}/workspace/project/.uvmrc"

    cd "${TEST_HOME}/workspace/project/src/module"
    uvm_auto_activate

    [ "$VIRTUAL_ENV" = "${UVM_ENVS_DIR}/shared-env" ]
    [ "$UVM_AUTO_ACTIVATED" = "uvm:shared-env" ]
}

@test "managed block helpers are idempotent and only remove the marked section" {
    init_uvm_config
    local target_file="${TEST_HOME}/shellrc"
    printf 'export PATH="/usr/bin"\n' > "$target_file"

    uvm_upsert_managed_block "$target_file" "# >>> uvm test >>>" "# <<< uvm test <<<" $'line-a\nline-b'
    uvm_upsert_managed_block "$target_file" "# >>> uvm test >>>" "# <<< uvm test <<<" $'line-a\nline-b'
    run grep -c "line-a" "$target_file"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]

    uvm_remove_managed_block "$target_file" "# >>> uvm test >>>" "# <<< uvm test <<<"
    run cat "$target_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *'export PATH="/usr/bin"'* ]]
    [[ "$output" != *"line-a"* ]]
}

@test "uvm_repair rebuilds metadata from the managed environments directory" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/repair-me"
    rm -rf "${UVM_HOME}/envs.d"

    run uvm_repair

    [ "$status" -eq 0 ]
    [ -f "${UVM_HOME}/envs.d/repair-me.env" ]
}

@test "uvm_doctor reports shell hook and metadata health" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/doctorenv"
    add_env_record "doctorenv" "${UVM_ENVS_DIR}/doctorenv" "3.12.1"

    run uvm_doctor

    [ "$status" -eq 0 ]
    [[ "$output" == *"UVM doctor"* ]]
    [[ "$output" == *"Metadata records"* ]]
    [[ "$output" == *"${UVM_HOME}"* ]]
}

@test "detect_shell prefers the user's login shell when running inside bash" {
    local original_shell="${SHELL:-}"

    export SHELL="/bin/zsh"
    run detect_shell
    [ "$status" -eq 0 ]
    [ "$output" = "zsh" ]

    run get_shell_rc_file
    [ "$status" -eq 0 ]
    [ "$output" = "${HOME}/.zshrc" ]

    if [ -n "$original_shell" ]; then
        export SHELL="$original_shell"
    else
        unset SHELL
    fi
}

@test "get_shell_rc_file on Windows Git Bash returns bash_profile regardless of bashrc presence" {
    local original_shell="${SHELL:-}"
    export SHELL="/bin/bash"

    # Ensure .bashrc exists (would normally cause non-Windows to return .bashrc)
    touch "${HOME}/.bashrc"

    UVM_PLATFORM_OVERRIDE="windows" run get_shell_rc_file
    [ "$status" -eq 0 ]
    [ "$output" = "${HOME}/.bash_profile" ]

    if [ -n "$original_shell" ]; then export SHELL="$original_shell"; else unset SHELL; fi
    unset UVM_PLATFORM_OVERRIDE
}

@test "setup_uv_mirror with no URL does nothing (opt-in)" {
    local uv_config_file="${HOME}/.config/uv/uv.toml"

    run setup_uv_mirror
    [ "$status" -eq 0 ]
    [ ! -f "$uv_config_file" ]
}

@test "setup_uv_mirror with URL writes managed block" {
    local uv_config_file="${HOME}/.config/uv/uv.toml"

    run setup_uv_mirror "https://pypi.tuna.tsinghua.edu.cn/simple"
    [ "$status" -eq 0 ]
    [ -f "$uv_config_file" ]
    grep -q "pypi.tuna.tsinghua.edu.cn" "$uv_config_file"
    grep -q "# >>> uvm mirror >>>" "$uv_config_file"
    ! grep -q '\[python-downloads\]' "$uv_config_file"
    uv --config-file "$uv_config_file" python list --only-installed >/dev/null
}

@test "setup_uv_mirror leaves an unmanaged python-install-mirror untouched" {
    local uv_config_dir="${HOME}/.config/uv"
    local uv_config_file="${uv_config_dir}/uv.toml"

    mkdir -p "$uv_config_dir"
    cat > "$uv_config_file" <<'EOF'
python-install-mirror = "https://example.com/python"
EOF

    run setup_uv_mirror "https://pypi.tuna.tsinghua.edu.cn/simple"

    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]
    run cat "$uv_config_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *'python-install-mirror = "https://example.com/python"'* ]]
    [[ "$output" != *"# >>> uvm mirror >>>"* ]]
}

@test "uvm_create rejects duplicate environment names even when a new --path is provided" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/dupenv"
    add_env_record "dupenv" "${UVM_ENVS_DIR}/dupenv" "3.12.1"

    run uvm_create "dupenv" --path "${TEST_HOME}/other/dupenv"

    [ "$status" -ne 0 ]
    [[ "$output" == *"already managed"* ]]
    run get_env_path "dupenv"
    [ "$status" -eq 0 ]
    [ "$output" = "${UVM_ENVS_DIR}/dupenv" ]
}

@test "uninstall fallback removes both shell and path managed blocks" {
    local shell_rc="${HOME}/.bashrc"
    local uninstall_copy="${TEST_HOME}/uninstall-under-test.sh"
    local original_home="$HOME"

    cat > "$shell_rc" <<'EOF'
# >>> uvm path >>>
export PATH="${HOME}/.local/bin:$PATH"
# <<< uvm path <<<
# >>> uvm shell >>>
eval "$(uvm shell-hook)"
# <<< uvm shell <<<
EOF

    cp "${BATS_TEST_DIRNAME}/../uninstall.sh" "$uninstall_copy"

    run env HOME="$TEST_HOME" bash "$uninstall_copy" --force

    [ "$status" -eq 0 ]
    run cat "$shell_rc"
    [ "$status" -eq 0 ]
    [[ "$output" != *"# >>> uvm path >>>"* ]]
    [[ "$output" != *"# >>> uvm shell >>>"* ]]
}

@test "uninstall respects an explicitly supplied UVM_HOME" {
    local uninstall_copy="${TEST_HOME}/uninstall-under-test.sh"
    local custom_home="${TEST_HOME}/custom-uvm-home"

    mkdir -p "${custom_home}"
    cp "${BATS_TEST_DIRNAME}/../uninstall.sh" "$uninstall_copy"

    run env HOME="$TEST_HOME" UVM_HOME="$custom_home" bash "$uninstall_copy" --force --keep-shell-config

    [ "$status" -eq 0 ]
    [ ! -d "$custom_home" ]
    [ ! -d "${TEST_HOME}/.config/uvm" ]
}

@test "uninstall reports the configured managed env directory before removing libraries" {
    local uninstall_copy="${TEST_HOME}/uninstall-under-test.sh"
    local custom_home="${TEST_HOME}/custom-uvm-home"
    local custom_envs="${TEST_HOME}/custom-envs"

    mkdir -p "${HOME}/.local/lib/uvm" "${custom_home}" "${custom_envs}"
    cp "${BATS_TEST_DIRNAME}/../lib/uvm-config.sh" "${HOME}/.local/lib/uvm/uvm-config.sh"
    cp "${BATS_TEST_DIRNAME}/../uninstall.sh" "$uninstall_copy"
    printf 'UVM_ENVS_DIR=%q\n' "$custom_envs" > "${custom_home}/config"

    run env HOME="$TEST_HOME" UVM_HOME="$custom_home" bash "$uninstall_copy" --force --keep-shell-config

    [ "$status" -eq 0 ]
    [[ "$output" == *"$custom_envs"* ]]
}

@test "initialize_config respects externally supplied UVM_HOME" {
    load_install_functions
    export UVM_HOME="${TEST_HOME}/custom-uvm-home"

    run initialize_config "${TEST_HOME}/envs"

    [ "$status" -eq 0 ]
    [ -d "${UVM_HOME}" ]
    [ -f "${UVM_HOME}/config" ]
    [ ! -d "${TEST_HOME}/.config/uvm" ]
}

@test "interactive_setup exposes prompts separately from structured choices" {
    load_install_functions

    interactive_setup <<< $'\n\n\n'

    [ "$UVM_SETUP_ENVS_DIR" = "${HOME}/uv_envs" ]
    [ "$UVM_SETUP_AUTO_ACTIVATION" = "y" ]
    [ -z "$UVM_SETUP_MIRROR_URL" ]
}

@test "non-interactive reinstall preserves the configured environments directory" {
    load_install_functions
    local configured_envs="${TEST_HOME}/existing envs"
    mkdir -p "$configured_envs" "$UVM_HOME"
    printf 'UVM_ENVS_DIR=%q\n' "$configured_envs" > "${UVM_HOME}/config"
    unset UVM_ENVS_DIR

    run resolve_existing_envs_dir

    [ "$status" -eq 0 ]
    [ "$output" = "$configured_envs" ]
}

@test "installer rejects a missing value option immediately" {
    run env HOME="$TEST_HOME" bash "${BATS_TEST_DIRNAME}/../install.sh" --envs-dir

    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a path"* ]]
}

@test "install_uvm stores templates under the effective UVM_HOME" {
    load_install_functions
    export UVM_HOME="${TEST_HOME}/custom-uvm-home"

    run install_uvm "${BATS_TEST_DIRNAME}/.."

    [ "$status" -eq 0 ]
    [ -d "${UVM_HOME}/templates" ]
    [ -f "${UVM_HOME}/templates/uv.toml.template" ]
    [ ! -d "${TEST_HOME}/.config/uvm/templates" ]
}

@test "remote install downloads default to the current release ref" {
    load_install_functions

    run uvm_get_download_base_url

    [ "$status" -eq 0 ]
    [ "$output" = "https://raw.githubusercontent.com/Tendo33/uvm/v${UVM_INSTALL_VERSION}" ]
}

@test "remote install download ref can be overridden explicitly" {
    load_install_functions
    export UVM_DOWNLOAD_REF="main"

    run uvm_get_download_base_url

    [ "$status" -eq 0 ]
    [ "$output" = "https://raw.githubusercontent.com/Tendo33/uvm/main" ]
}

@test "uvm update refuses a downloaded downgrade" {
    local fake_bin="${TEST_HOME}/fake-bin"
    local fake_installer="${TEST_HOME}/old-install.sh"
    mkdir -p "$fake_bin"
    cat > "$fake_installer" <<'EOF'
#!/bin/bash
UVM_INSTALL_VERSION="1.2.0"
EOF
    cat > "${fake_bin}/curl" <<'EOF'
#!/bin/bash
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-o" ]; then
        cp "$UVM_FAKE_INSTALLER" "$2"
        exit 0
    fi
    shift
done
exit 1
EOF
    chmod +x "${fake_bin}/curl"
    export UVM_FAKE_INSTALLER="$fake_installer"
    PATH="${fake_bin}:${PATH}"
    UVM_VERSION="1.2.1"

    run uvm_self_update latest

    [ "$status" -ne 0 ]
    [[ "$output" == *"Refusing to downgrade"* ]]
}

@test "uvm update preserves UVM_HOME and UVM_ENVS_DIR" {
    local fake_bin="${TEST_HOME}/fake-bin"
    local fake_installer="${TEST_HOME}/new-install.sh"
    export UVM_UPDATE_MARKER="${TEST_HOME}/update-marker"
    mkdir -p "$fake_bin" "$UVM_HOME" "$UVM_ENVS_DIR"
    cat > "$fake_installer" <<'EOF'
#!/bin/bash
UVM_INSTALL_VERSION="1.2.2"
printf 'home=%s\nenvs=%s\n' "$UVM_HOME" "$UVM_ENVS_DIR" > "$UVM_UPDATE_MARKER"
printf 'arg=%s\n' "$@" >> "$UVM_UPDATE_MARKER"
EOF
    cat > "${fake_bin}/curl" <<'EOF'
#!/bin/bash
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-o" ]; then
        cp "$UVM_FAKE_INSTALLER" "$2"
        exit 0
    fi
    shift
done
exit 1
EOF
    chmod +x "${fake_bin}/curl"
    export UVM_FAKE_INSTALLER="$fake_installer"
    PATH="${fake_bin}:${PATH}"
    UVM_VERSION="1.2.1"

    run uvm_self_update latest

    [ "$status" -eq 0 ]
    grep -Fqx "home=${UVM_HOME}" "$UVM_UPDATE_MARKER"
    grep -Fqx "envs=${UVM_ENVS_DIR}" "$UVM_UPDATE_MARKER"
    grep -Fqx "arg=--envs-dir" "$UVM_UPDATE_MARKER"
    grep -Fqx "arg=${UVM_ENVS_DIR}" "$UVM_UPDATE_MARKER"
}

@test "uvm update rejects non-version remote targets" {
    run uvm_self_update "main"
    [ "$status" -ne 0 ]
    [[ "$output" == *"version tag"* ]]
}

@test "bash completion script lists environment names from envs.d" {
    init_uvm_config
    make_fake_env "${UVM_ENVS_DIR}/comp-env-1"
    make_fake_env "${UVM_ENVS_DIR}/comp-env-2"
    add_env_record "comp-env-1" "${UVM_ENVS_DIR}/comp-env-1" "3.11.9"
    add_env_record "comp-env-2" "${UVM_ENVS_DIR}/comp-env-2" "3.12.1"

    load_completion_script
    run _uvm_list_env_names
    [ "$status" -eq 0 ]
    [[ "$output" == *"comp-env-1"* ]]
    [[ "$output" == *"comp-env-2"* ]]
}

@test "local .venv requires explicit trust before auto-activation" {
    init_uvm_config
    local non_uvm_venv="${TEST_HOME}/project/.venv"
    make_fake_env "$non_uvm_venv"

    cd "${TEST_HOME}/project"
    uvm_auto_activate
    [ -z "${VIRTUAL_ENV:-}" ]
    [ -n "${UVM_UNTRUSTED_LOCAL_ENV:-}" ]

    uvm_trust_local_env "$non_uvm_venv" >/dev/null
    uvm_auto_activate
    [ "$VIRTUAL_ENV" = "$non_uvm_venv" ]

    cd "$OLDPWD"
}

@test "uvm trust --list exposes trusted canonical paths" {
    init_uvm_config
    local local_env="${TEST_HOME}/trusted-project/.venv"
    make_fake_env "$local_env"
    uvm_trust_local_env "$local_env" >/dev/null

    run "${BATS_TEST_DIRNAME}/../bin/uvm" trust --list

    [ "$status" -eq 0 ]
    [ "$output" = "$(cd "$local_env" && pwd -P)" ]
}

@test "untrusted local activation script is never sourced" {
    init_uvm_config
    local local_env="${TEST_HOME}/malicious/.venv"
    local probe="${TEST_HOME}/activation-probe"
    make_fake_env "$local_env"
    printf 'touch %q\n' "$probe" >> "${local_env}/bin/activate"

    cd "${TEST_HOME}/malicious"
    uvm_auto_activate

    [ ! -e "$probe" ]
    [ -z "${VIRTUAL_ENV:-}" ]
    cd "$OLDPWD"
}

@test "value-taking options reject missing values without looping" {
    run uvm_create "example" --path
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a value"* ]]

    run uvm_import "example" --from
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a value"* ]]
}

@test "relative custom paths are stored as canonical absolute paths" {
    init_uvm_config
    mkdir -p "${TEST_HOME}/relative-work"
    cd "${TEST_HOME}/relative-work"

    run uvm_create "relative" --path "relative-env"
    [ "$status" -eq 0 ]
    run get_env_path "relative"
    [ "$status" -eq 0 ]
    [ "$output" = "$(cd relative-env && pwd -P)" ]

    cd "$OLDPWD"
}
