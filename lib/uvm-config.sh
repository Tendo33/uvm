#!/bin/bash

uvm_get_home() {
    echo "${UVM_HOME:-${HOME}/.config/uvm}"
}

uvm_get_default_envs_dir() {
    echo "${UVM_ENVS_DIR:-${HOME}/uv_envs}"
}

uvm_get_config_file() {
    echo "$(uvm_get_home)/config"
}

uvm_get_env_records_dir() {
    echo "$(uvm_get_home)/envs.d"
}

uvm_get_lock_root() {
    echo "$(uvm_get_home)/locks"
}

uvm_get_legacy_envs_file() {
    echo "$(uvm_get_home)/envs.json"
}

uvm_get_uv_config_dir() {
    echo "${HOME}/.config/uv"
}

uvm_get_uv_config_file() {
    echo "$(uvm_get_uv_config_dir)/uv.toml"
}

uvm_get_shell_hook_start_marker() {
    echo "# >>> uvm shell >>>"
}

uvm_get_shell_hook_end_marker() {
    echo "# <<< uvm shell <<<"
}

uvm_get_mirror_start_marker() {
    echo "# >>> uvm mirror >>>"
}

uvm_get_mirror_end_marker() {
    echo "# <<< uvm mirror <<<"
}

uvm_detect_platform() {
    case "$(uname -s)" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

uvm_get_iso_timestamp() {
    # GNU date supports -Iseconds; BSD date (macOS) does not.
    # Fall back to an equivalent format that works on both.
    if date -Iseconds >/dev/null 2>&1; then
        date -Iseconds
    else
        # BSD date: produce RFC 3339 / ISO 8601 compatible output
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

uvm_resolve_dir_path() {
    local path="$1"

    if [ -z "$path" ] || [ ! -d "$path" ]; then
        return 1
    fi

    (
        cd "$path" >/dev/null 2>&1 && pwd -P
    )
}

uvm_resolve_existing_path() {
    local path="$1"

    if [ -z "$path" ] || [ ! -e "$path" ]; then
        return 1
    fi

    if [ -d "$path" ]; then
        uvm_resolve_dir_path "$path"
        return $?
    fi

    local dir_name
    local base_name

    dir_name=$(dirname "$path")
    base_name=$(basename "$path")
    dir_name=$(uvm_resolve_dir_path "$dir_name") || return 1
    printf '%s/%s\n' "$dir_name" "$base_name"
}

uvm_path_is_within() {
    local root_path="$1"
    local candidate_path="$2"
    local resolved_root
    local resolved_candidate

    resolved_root=$(uvm_resolve_existing_path "$root_path") || return 1
    resolved_candidate=$(uvm_resolve_existing_path "$candidate_path") || return 1

    case "${resolved_candidate}/" in
        "${resolved_root}/"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

uvm_is_valid_env_name() {
    local env_name="$1"

    [ -n "$env_name" ] || return 1

    case "$env_name" in
        *[!/A-Za-z0-9._-]*)
            return 1
            ;;
        .*|*..*|*/*|*\\*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

uvm_env_activate_script() {
    local env_path="$1"

    if [ -f "${env_path}/bin/activate" ]; then
        echo "${env_path}/bin/activate"
        return 0
    fi

    if [ -f "${env_path}/Scripts/activate" ]; then
        echo "${env_path}/Scripts/activate"
        return 0
    fi

    return 1
}

uvm_env_python_binary() {
    local env_path="$1"

    if [ -f "${env_path}/bin/python" ]; then
        echo "${env_path}/bin/python"
        return 0
    fi

    if [ -f "${env_path}/Scripts/python.exe" ]; then
        echo "${env_path}/Scripts/python.exe"
        return 0
    fi

    return 1
}

uvm_is_valid_uv_env() {
    local env_path="$1"

    [ -d "$env_path" ] || return 1
    [ -f "${env_path}/pyvenv.cfg" ] || return 1
    uvm_env_activate_script "$env_path" >/dev/null 2>&1
}

get_env_python_version() {
    local env_path="$1"
    local python_binary

    python_binary=$(uvm_env_python_binary "$env_path") || {
        echo "unknown"
        return 0
    }

    "$python_binary" --version 2>&1 | awk '{print $2}'
}

uvm_load_user_config() {
    export UVM_HOME="${UVM_HOME:-${HOME}/.config/uvm}"

    if [ -f "$(uvm_get_config_file)" ]; then
        # shellcheck source=/dev/null
        source "$(uvm_get_config_file)"
    fi

    export UVM_HOME="${UVM_HOME:-${HOME}/.config/uvm}"
    export UVM_ENVS_DIR="${UVM_ENVS_DIR:-${HOME}/uv_envs}"
}

uvm_metadata_lock_path() {
    echo "$(uvm_get_lock_root)/metadata.lock"
}

uvm_acquire_metadata_lock() {
    local lock_path
    local attempts

    lock_path=$(uvm_metadata_lock_path)
    mkdir -p "$(uvm_get_lock_root)"
    attempts=0

    while ! mkdir "$lock_path" 2>/dev/null; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 50 ]; then
            echo "Error: Timed out waiting for uvm metadata lock" >&2
            return 1
        fi
        sleep 0.1
    done

    return 0
}

uvm_release_metadata_lock() {
    rmdir "$(uvm_metadata_lock_path)" 2>/dev/null || true
}

uvm_record_file_path() {
    local env_name="$1"
    printf '%s/%s.env\n' "$(uvm_get_env_records_dir)" "$env_name"
}

uvm_load_env_record() {
    local env_name="$1"
    local record_file

    record_file=$(uvm_record_file_path "$env_name")
    [ -f "$record_file" ] || return 1

    unset UVM_RECORD_NAME UVM_RECORD_PATH UVM_RECORD_PYTHON UVM_RECORD_CREATED
    # shellcheck source=/dev/null
    source "$record_file"

    [ -n "${UVM_RECORD_NAME:-}" ] || return 1
    [ -n "${UVM_RECORD_PATH:-}" ] || return 1
    return 0
}

uvm_write_env_record_unlocked() {
    local env_name="$1"
    local env_path="$2"
    local python_version="$3"
    local created_at="$4"
    local record_file
    local temp_file

    record_file=$(uvm_record_file_path "$env_name")
    temp_file="${record_file}.tmp.$$"

    mkdir -p "$(uvm_get_env_records_dir)" || return 1

    {
        printf 'UVM_RECORD_NAME=%q\n' "$env_name"
        printf 'UVM_RECORD_PATH=%q\n' "$env_path"
        printf 'UVM_RECORD_PYTHON=%q\n' "${python_version:-unknown}"
        printf 'UVM_RECORD_CREATED=%q\n' "${created_at:-$(uvm_get_iso_timestamp)}"
    } > "$temp_file" || return 1

    mv "$temp_file" "$record_file"
}

add_env_record() {
    local env_name="$1"
    local env_path="$2"
    local python_version="$3"
    local created_at

    init_uvm_config || return 1
    created_at=$(uvm_get_iso_timestamp)

    uvm_acquire_metadata_lock || return 1
    uvm_write_env_record_unlocked "$env_name" "$env_path" "$python_version" "$created_at"
    local status=$?
    uvm_release_metadata_lock
    return $status
}

remove_env_record() {
    local env_name="$1"
    local record_file

    record_file=$(uvm_record_file_path "$env_name")
    [ -f "$record_file" ] || return 0

    uvm_acquire_metadata_lock || return 1
    rm -f "$record_file"
    local status=$?
    uvm_release_metadata_lock
    return $status
}

uvm_count_metadata_records() {
    local records_dir

    records_dir=$(uvm_get_env_records_dir)
    if [ ! -d "$records_dir" ]; then
        echo "0"
        return 0
    fi

    find "$records_dir" -type f -name '*.env' | wc -l | awk '{print $1}'
}

uvm_migrate_legacy_envs_file() {
    local legacy_file
    local records_dir
    local has_records
    local objects

    legacy_file=$(uvm_get_legacy_envs_file)
    records_dir=$(uvm_get_env_records_dir)

    [ -f "$legacy_file" ] || return 0
    mkdir -p "$records_dir"
    has_records=$(find "$records_dir" -type f -name '*.env' | head -n 1)
    [ -z "$has_records" ] || return 0

    objects=$(tr -d '\r\n' < "$legacy_file" | grep -o '{[^}]*}' || true)
    [ -n "$objects" ] || return 0

    while IFS= read -r object; do
        local env_name
        local env_path
        local python_version
        local created_at

        env_name=$(printf '%s' "$object" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
        env_path=$(printf '%s' "$object" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')
        python_version=$(printf '%s' "$object" | sed -n 's/.*"python":"\([^"]*\)".*/\1/p')
        created_at=$(printf '%s' "$object" | sed -n 's/.*"created":"\([^"]*\)".*/\1/p')

        if uvm_is_valid_env_name "$env_name" && [ -n "$env_path" ]; then
            uvm_write_env_record_unlocked "$env_name" "$env_path" "$python_version" "$created_at"
        fi
    done <<EOF
$objects
EOF
}

init_uvm_config() {
    local uvm_home
    local config_file

    uvm_home=$(uvm_get_home)
    config_file=$(uvm_get_config_file)

    mkdir -p "$uvm_home" "$(uvm_get_env_records_dir)" "$(uvm_get_lock_root)"

    if [ ! -f "$config_file" ]; then
        printf 'UVM_ENVS_DIR=%q\n' "$(uvm_get_default_envs_dir)" > "$config_file"
    fi

    uvm_migrate_legacy_envs_file
    return 0
}

uvm_list_record_names() {
    local records_dir
    local record_file

    records_dir=$(uvm_get_env_records_dir)
    [ -d "$records_dir" ] || return 0

    for record_file in "$records_dir"/*.env; do
        [ -f "$record_file" ] || continue
        basename "$record_file" .env
    done
}

get_env_path() {
    local env_name="$1"
    local default_path

    uvm_is_valid_env_name "$env_name" || return 1
    init_uvm_config || return 1

    if uvm_load_env_record "$env_name"; then
        if uvm_is_valid_uv_env "$UVM_RECORD_PATH"; then
            echo "$UVM_RECORD_PATH"
            return 0
        fi
    fi

    default_path="$(uvm_get_default_envs_dir)/${env_name}"
    if uvm_is_valid_uv_env "$default_path"; then
        echo "$default_path"
        return 0
    fi

    return 1
}

scan_and_register_envs() {
    local scan_dir="$1"
    local registered_count=0
    local env_dir
    local env_name
    local python_version

    init_uvm_config || return 1
    [ -d "$scan_dir" ] || return 0

    uvm_acquire_metadata_lock || return 1
    for env_dir in "$scan_dir"/*; do
        [ -d "$env_dir" ] || continue
        env_name=$(basename "$env_dir")

        case "$env_name" in
            .*|desktop.ini|*.ico)
                continue
                ;;
        esac

        if ! uvm_is_valid_env_name "$env_name"; then
            continue
        fi

        if uvm_is_valid_uv_env "$env_dir"; then
            python_version=$(get_env_python_version "$env_dir")
            uvm_write_env_record_unlocked "$env_name" "$env_dir" "$python_version" "$(uvm_get_iso_timestamp)"
            registered_count=$((registered_count + 1))
        fi
    done
    uvm_release_metadata_lock

    echo "$registered_count"
}

uvm_prune_invalid_records() {
    local records_dir
    local record_file
    local env_name

    records_dir=$(uvm_get_env_records_dir)
    [ -d "$records_dir" ] || return 0

    uvm_acquire_metadata_lock || return 1
    for record_file in "$records_dir"/*.env; do
        [ -f "$record_file" ] || continue
        env_name=$(basename "$record_file" .env)
        if ! uvm_load_env_record "$env_name" || ! uvm_is_valid_uv_env "$UVM_RECORD_PATH"; then
            rm -f "$record_file"
        fi
    done
    uvm_release_metadata_lock
}

uvm_file_contains_managed_block() {
    local file_path="$1"
    local start_marker="$2"
    local end_marker="$3"

    [ -f "$file_path" ] || return 1
    grep -Fq "$start_marker" "$file_path" 2>/dev/null && grep -Fq "$end_marker" "$file_path" 2>/dev/null
}

uvm_upsert_managed_block() {
    local file_path="$1"
    local start_marker="$2"
    local end_marker="$3"
    local content="$4"
    local temp_file
    local parent_dir

    parent_dir=$(dirname "$file_path")
    mkdir -p "$parent_dir" || return 1

    temp_file=$(mktemp "${TMPDIR:-/tmp}/uvm-block.XXXXXX") || return 1

    if [ -f "$file_path" ]; then
        awk -v start="$start_marker" -v end="$end_marker" '
            $0 == start { skip = 1; next }
            $0 == end { skip = 0; next }
            skip != 1 { print }
        ' "$file_path" > "$temp_file"
    else
        : > "$temp_file"
    fi

    if [ -s "$temp_file" ]; then
        printf '\n' >> "$temp_file"
    fi

    printf '%s\n' "$start_marker" >> "$temp_file"
    printf '%s\n' "$content" >> "$temp_file"
    printf '%s\n' "$end_marker" >> "$temp_file"
    mv "$temp_file" "$file_path"
}

uvm_remove_managed_block() {
    local file_path="$1"
    local start_marker="$2"
    local end_marker="$3"
    local temp_file

    [ -f "$file_path" ] || return 0

    temp_file=$(mktemp "${TMPDIR:-/tmp}/uvm-block.XXXXXX") || return 1
    awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        skip != 1 { print }
    ' "$file_path" > "$temp_file"
    mv "$temp_file" "$file_path"
}

uvm_generate_shell_hook_block() {
    cat <<'EOF'
# UVM (UV Manager) - Shell Integration
eval "$(uvm shell-hook)"
EOF
}

uvm_ensure_shell_hook_configured() {
    local shell_rc="$1"

    uvm_upsert_managed_block \
        "$shell_rc" \
        "$(uvm_get_shell_hook_start_marker)" \
        "$(uvm_get_shell_hook_end_marker)" \
        "$(uvm_generate_shell_hook_block)"
}

uvm_file_has_unmanaged_mirror_config() {
    local file_path="$1"
    local temp_file

    [ -f "$file_path" ] || return 1

    temp_file=$(mktemp "${TMPDIR:-/tmp}/uvm-mirror-check.XXXXXX") || return 1
    awk -v start="$(uvm_get_mirror_start_marker)" -v end="$(uvm_get_mirror_end_marker)" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        skip != 1 { print }
    ' "$file_path" > "$temp_file"

    if grep -Eq '^[[:space:]]*\[\[index\]\][[:space:]]*$|^[[:space:]]*\[python-downloads\][[:space:]]*$' "$temp_file"; then
        rm -f "$temp_file"
        return 0
    fi

    rm -f "$temp_file"
    return 1
}

setup_uv_mirror() {
    local uv_config_dir
    local uv_config_file
    local mirror_block

    uv_config_dir=$(uvm_get_uv_config_dir)
    uv_config_file=$(uvm_get_uv_config_file)
    mirror_block=$(cat <<'EOF'
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true

[python-downloads]
url = "https://mirrors.tuna.tsinghua.edu.cn/python-releases/"
EOF
)

    mkdir -p "$uv_config_dir" || return 1
    if uvm_file_has_unmanaged_mirror_config "$uv_config_file"; then
        echo "Warning: Existing unmanaged mirror config conflict detected in ${uv_config_file}; leaving file unchanged"
        return 0
    fi

    if [ -f "$uv_config_file" ] && [ ! -f "${uv_config_file}.backup" ]; then
        cp "$uv_config_file" "${uv_config_file}.backup"
    fi

    uvm_upsert_managed_block \
        "$uv_config_file" \
        "$(uvm_get_mirror_start_marker)" \
        "$(uvm_get_mirror_end_marker)" \
        "$mirror_block"
}

detect_shell() {
    case "${UVM_SHELL:-${SHELL:-}}" in
        */zsh)
            echo "zsh"
            return 0
            ;;
        */bash)
            echo "bash"
            return 0
            ;;
    esac

    if [ -n "${ZSH_VERSION:-}" ]; then
        echo "zsh"
        return 0
    fi

    if [ -n "${BASH_VERSION:-}" ]; then
        echo "bash"
        return 0
    fi

    echo "unknown"
}

get_shell_rc_file() {
    local platform
    platform="${UVM_PLATFORM_OVERRIDE:-$(uvm_detect_platform)}"

    case "$(detect_shell)" in
        zsh)
            echo "${HOME}/.zshrc"
            ;;
        bash)
            # Windows Git Bash login shells source .bash_profile, not .bashrc.
            # Writing to .bashrc on Windows means the hook silently fails to load
            # on new terminals opened via Git Bash shortcut (login shell).
            if [ "$platform" = "windows" ]; then
                echo "${HOME}/.bash_profile"
            elif [ -f "${HOME}/.bashrc" ]; then
                echo "${HOME}/.bashrc"
            else
                echo "${HOME}/.bash_profile"
            fi
            ;;
        *)
            echo "${HOME}/.profile"
            ;;
    esac
}

uvm_is_shell_hook_configured() {
    local shell_rc="$1"

    uvm_file_contains_managed_block \
        "$shell_rc" \
        "$(uvm_get_shell_hook_start_marker)" \
        "$(uvm_get_shell_hook_end_marker)"
}
