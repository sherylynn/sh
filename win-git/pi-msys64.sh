#!/usr/bin/env bash
# Launch the existing Windows MSYS64 Pi profile without changing the caller's
# working directory, credentials, shell startup files, or native Windows Pi.
set -euo pipefail

if ! command -v cygpath >/dev/null 2>&1; then
  printf '%s\n' 'pi-msys64: run this launcher from Windows MSYS2 Bash.' >&2
  exit 2
fi

msys_home="$(cygpath -u 'C:\msys64\home\lynn')"
pi="$msys_home/tools/node-global/pi"
agent_dir="$msys_home/.pi/agent"

if [[ ! -x "$pi" || ! -f "$agent_dir/settings.json" ]]; then
  printf '%s\n' 'pi-msys64: expected Pi binary or MSYS64 agent settings are missing.' >&2
  exit 1
fi

# Native Node uses Windows homedir by default. Pin the Windows form of the
# existing MSYS64 agent directory only for this invocation.
export PI_CODING_AGENT_DIR="$(cygpath -w "$agent_dir")"
exec "$pi" "$@"
