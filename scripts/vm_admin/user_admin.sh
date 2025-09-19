#!/bin/bash
# Utility functions for managing VM users

function delete_user_and_dirs {
    local username="$1"; shift
    local basedir=""
    local force="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --basedir)
                basedir="$2";
                shift 2
                ;;
            --force)
                force="true";
                shift
                ;;
            *)
                echo "Unknown option for delete_user_and_dirs: $1" >&2; exit 1 ;;
        esac
    done

    local userdir=""
    if [[ -n "$basedir" ]]; then
        userdir="$basedir/$username"
    fi

    sudo deluser --remove-home "$username" || true

    if [[ -n "$userdir" && -d "$userdir" ]]; then

        if [[ "$force" == "true" ]]; then
            echo "Force enabled: deleting $userdir"
            sudo rm -rf "$userdir" || true
        else
            echo "Skipping deletion of $userdir (use --force to override)"
        fi
    fi
}

function add_user_to_groups() {
    local username="$1"; shift
    local groups=("$@")

    if [ ${#groups[@]} -eq 0 ]; then
        echo "No groups specified for user"
        return 1
    fi

    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null; then
            echo "Adding $username to $group..."
            sudo usermod -aG "$group" "$username"
        else
            echo "Group $group does not exist, skipping."
        fi
    done
}

function create_user_and_dirs() {
    local username="$1"; shift
    local basedir=""
    local force="false"
    local groups=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --basedir)
                basedir="$2";
                if [[ ! -d "$basedir" ]]; then
                    echo "Error: base directory '$basedir' does not exist."
                    return 1
                fi
                shift 2
                ;;
            --force)
                force="true";
                shift
                ;;
            --group)
                groups+=("$2")
                shift 2
                ;;
            *)
                echo "Unknown option for create_user_and_dirs: $1" >&2; exit 1 ;;
        esac
    done

    local userdir=""
    if [[ -n "$basedir" ]]; then
        userdir="$basedir/$username"

        if [[ -d "$userdir" ]]; then
            echo "Error: userdir '$userdir' already exists."
            return 1
        fi
    fi

    # shellcheck disable=SC2064
    trap "delete_user_and_dirs '$username' ${basedir:+--basedir \"$basedir\"} ${force:+--force}" ERR

    sudo adduser "$username"
    
    local homedir
    homedir=$(eval echo "~$username")
    
    local scratch_link="$homedir/scratch"
    if [[ -e "$scratch_link" || -L "$scratch_link" ]]; then
        sudo rm -rf "$scratch_link"
    fi

    if [[ -n "$userdir" ]]; then
        if [[ -d "$userdir" && "$force" == "true" ]]; then
            sudo rm -rf "$userdir"
        fi
    
        sudo mkdir -p "$userdir"
        sudo chown -R "$username" "$userdir"
        sudo chmod -R 700 "$userdir"

        sudo ln -s "$userdir" "$scratch_link"
        sudo chown -h "$username:$username" "$scratch_link"

        add_user_to_groups "$username" "${groups[@]}"
    fi

    trap - ERR
    echo "User '$username' created successfully${userdir:+ with home dir $userdir}"
}

function setup_authorized_keys() {
    local username="$1"
    local pubkey="${2:-}"

    local homedir
    homedir=$(eval echo "~$username")

    local sshdir="$homedir/.ssh"
    local authfile="$sshdir/authorized_keys"

    sudo mkdir -p "$sshdir"
    sudo chown "$username:$username" "$sshdir"
    sudo chmod 700 "$sshdir"

    sudo touch "$authfile"
    sudo chown "$username:$username" "$authfile"
    sudo chmod 600 "$authfile"

    if [[ -n "$pubkey" ]]; then
        echo "$pubkey" | sudo tee -a "$authfile" > /dev/null
        sudo chown "$username:$username" "$authfile"
    fi

    echo "authorized_keys set up for $username at $authfile"
}

function setup_user_env() {
    local username="$1"
    local userdir="$2"      # e.g., /mnt/data/alice
    local shell_profile

    local homedir
    homedir=$(eval echo "~$username")

    if [[ ! -d "$userdir" ]]; then
        echo "Error: userdir '$userdir' does not exist."
        return 1
    fi

    # Choose a shell profile to update
    if [[ -f "$homedir/.bashrc" ]]; then
        shell_profile="$homedir/.bashrc"
    else
        shell_profile="$homedir/.profile"
    fi

    sudo bash -c "echo 'export XDG_CACHE_HOME=\"$userdir/.cache\"' >> $shell_profile"
    sudo chown "$username:$username" "$shell_profile"

    sudo mkdir -p "$userdir/.cache"
    sudo chown "$username:$username" "$userdir/.cache"
    sudo chmod 700 "$userdir/.cache"

    echo "Set XDG_CACHE_HOME for $username to $userdir/.cache"
}

# -------------------------------------------------------
# DEPRECATED: We now set XDG_CACHE_HOME in setup_user_env
# -------------------------------------------------------
# function symlink_user_cache() {
#     local username="$1"
#     local target_basedir="$2"

#     local homedir
#     homedir=$(eval echo "~$username")

#     local target_cache="$target_basedir/.cache"
#     local user_cache="$homedir/.cache"

#     sudo mkdir -p "$target_cache"
#     sudo chown "$username:$username" "$target_cache"
#     sudo chmod 700 "$target_cache"

#     if [[ -e "$user_cache" || -L "$user_cache" ]]; then
#         sudo rm -rf "$user_cache"
#     fi


#     sudo ln -s "$target_cache" "$user_cache"
#     sudo chown -h "$username:$username" "$user_cache"

#     echo "Linked $homedir/.cache -> $target_cache"
# }
# -------------------------------------------------------