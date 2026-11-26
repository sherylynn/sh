#!/bin/bash
# 为现有 NewHome Mac 服务操作安装用户级 launchd 守护。
set -euo pipefail
[ "$(uname -s)" = Darwin ] || { echo 'macOS only' >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"
label=win.sherylynn.devspace.cloudflared-watchdog
domain="gui/$(id -u)"
plist="$HOME/Library/LaunchAgents/$label.plist"
case "${1:-install}" in
  uninstall)
    launchctl bootout "$domain/$label" 2>/dev/null || true
    rm -f "$plist"
    exit
    ;;
  install) ;;
  *) echo "usage: $0 [install|uninstall]" >&2; exit 2 ;;
esac
launchctl print "$domain" >/dev/null
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.devspace"
tmp="$(mktemp "$plist.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
python3 - "$here/server_devspace.sh" "$tmp" "$label" "$HOME/.devspace/cloudflared-watchdog.log" <<'PY'
import plistlib, sys
script,out,label,log = sys.argv[1:]
with open(out,'wb') as f:
    plistlib.dump(dict(Label=label, ProgramArguments=['/bin/bash',script,'watch-cloudflared'],
                       RunAtLoad=True, StartInterval=30, AbandonProcessGroup=True,
                       StandardOutPath=log, StandardErrorPath=log),f)
PY
plutil -lint "$tmp"
if launchctl print "$domain/$label" >/dev/null 2>&1; then
  if cmp -s "$tmp" "$plist"; then exit 0; fi
  launchctl bootout "$domain/$label"
fi
mv -f "$tmp" "$plist"
launchctl bootstrap "$domain" "$plist"
