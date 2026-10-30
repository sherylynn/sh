#!/usr/bin/env bash
# Keep one SSH agent per account across chroot login shells.
# Source this file from shell RC, or execute during server provisioning.
_ssh_agent_dir="${HOME}/.ssh"
_ssh_agent_socket="${_ssh_agent_dir}/agent-shared.sock"
_ssh_agent_lock="${_ssh_agent_dir}/.agent-shared.lock"
mkdir -p "$_ssh_agent_dir" || { return 1 2>/dev/null || exit 1; }
chmod 700 "$_ssh_agent_dir"
# Do not replace a working external agent explicitly supplied by the session.
if [ -n "${SSH_AUTH_SOCK:-}" ] && SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ssh-add -l >/dev/null 2>&1; then
    :
else
    export SSH_AUTH_SOCK="$_ssh_agent_socket"
    # ssh-add returns 1 for an empty but healthy agent; 2 means unavailable.
    ssh-add -l >/dev/null 2>&1
    _ssh_agent_status=$?
    if [ "$_ssh_agent_status" -eq 2 ]; then
        (
            flock -x 9 || exit 1
            ssh-add -l >/dev/null 2>&1
            [ "$?" -ne 2 ] && exit 0
            # Remove only a stale socket after verifying that it does not respond.
            [ ! -S "$_ssh_agent_socket" ] || rm -f "$_ssh_agent_socket"
            ssh-agent -a "$_ssh_agent_socket" -s >/dev/null
        ) 9>"$_ssh_agent_lock"
    fi
fi
unset _ssh_agent_dir _ssh_agent_socket _ssh_agent_lock _ssh_agent_status
