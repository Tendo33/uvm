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
deactivate() {
    unset VIRTUAL_ENV
    unset UVM_ACTIVE_ENV
    unset UVM_AUTO_ACTIVATED
    unset UVM_AUTO_ACTIVATED_PATH
}
export VIRTUAL_ENV
EOF
}

load_install_functions() {
    mkdir -p "${HOME}/.local/lib/uvm"
    cp "${BATS_TEST_DIRNAME}/../lib/uvm-config.sh" "${HOME}/.local/lib/uvm/uvm-config.sh"
    export UVM_INSTALL_SKIP_MAIN=1
    # shellcheck source=/dev/null
    source "${BATS_TEST_DIRNAME}/../install.sh"
    unset UVM_INSTALL_SKIP_MAIN
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
    run uvm_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"customenv"* ]]
    [[ "$output" == *"$custom_path"* ]]
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

@test "setup_uv_mirror leaves existing unmanaged python-downloads config untouched" {
    local uv_config_dir="${HOME}/.config/uv"
    local uv_config_file="${uv_config_dir}/uv.toml"

    mkdir -p "$uv_config_dir"
    cat > "$uv_config_file" <<'EOF'
[python-downloads]
url = "https://example.com/python"
EOF

    run setup_uv_mirror

    [ "$status" -eq 0 ]
    [[ "$output" == *"conflict"* ]]
    run cat "$uv_config_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *'url = "https://example.com/python"'* ]]
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

    run env HOME="$TEST_HOME" /usr/bin/bash "$uninstall_copy" --force

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

    run env HOME="$TEST_HOME" UVM_HOME="$custom_home" /usr/bin/bash "$uninstall_copy" --force --keep-shell-config

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

    run env HOME="$TEST_HOME" UVM_HOME="$custom_home" /usr/bin/bash "$uninstall_copy" --force --keep-shell-config

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
