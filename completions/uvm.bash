#!/usr/bin/env bash
# Bash tab-completion for uvm
# Source this file or install it to ~/.local/share/bash-completion/completions/uvm

_uvm_list_env_names() {
    local records_dir="${UVM_HOME:-${HOME}/.config/uvm}/envs.d"
    if [ -d "$records_dir" ]; then
        for f in "$records_dir"/*.env; do
            [ -f "$f" ] && basename "$f" .env
        done
    fi
}

_uvm_completions() {
    local cur prev cmd
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    cmd="${COMP_WORDS[1]}"

    local commands="create activate deactivate delete list scan init doctor repair config run rename clone export import update trust untrust shell-hook help version"

    if [ "${COMP_CWORD}" -eq 1 ]; then
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return 0
    fi

    # Second word completions for env-name commands
    case "$cmd" in
        activate|delete|rm|remove|run|rename|clone|export)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -W "$(_uvm_list_env_names)" -- "$cur"))
                return 0
            fi
            ;;
    esac

    # Flag completions
    case "$prev" in
        --python)
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "3.8 3.9 3.10 3.11 3.12 3.13 3.14" -- "$cur"))
            return 0
            ;;
        --path|--from)
            # Directory / file completion
            COMPREPLY=()
            compopt -o filenames 2>/dev/null
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
    esac

    # Sub-command specific completions
    case "$cmd" in
        create)
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "--python --path" -- "$cur"))
            ;;
        delete|rm|remove)
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "$(_uvm_list_env_names) --force -f" -- "$cur"))
            ;;
        list|ls)
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "--all --json" -- "$cur"))
            ;;
        import)
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "--from" -- "$cur"))
            ;;
        trust)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207 # Bash 3.2 has no mapfile; compgen output is intentionally split.
                COMPREPLY=($(compgen -W "list" -- "$cur"))
                compopt -o filenames 2>/dev/null
                # shellcheck disable=SC2207 # Bash 3.2 has no mapfile; compgen output is intentionally split.
                COMPREPLY+=( $(compgen -d -- "$cur") )
            fi
            ;;
        untrust)
            compopt -o filenames 2>/dev/null
            # shellcheck disable=SC2207 # Bash 3.2 has no mapfile; compgen output is intentionally split.
            COMPREPLY=($(compgen -d -- "$cur"))
            ;;
        config)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -W "show mirror" -- "$cur"))
            elif [ "${COMP_CWORD}" -eq 3 ] && [ "${COMP_WORDS[2]}" = "mirror" ]; then
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -W "set remove show" -- "$cur"))
            fi
            ;;
        run)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -W "$(_uvm_list_env_names)" -- "$cur"))
            elif [ "${COMP_CWORD}" -ge 3 ]; then
                # Complete with system commands after env name
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -c -- "$cur"))
            fi
            ;;
        rename)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -W "$(_uvm_list_env_names)" -- "$cur"))
            fi
            ;;
        clone)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -W "$(_uvm_list_env_names)" -- "$cur"))
            fi
            ;;
    esac
}

complete -F _uvm_completions uvm
