#!/usr/bin/env bash
set -Eeuo pipefail
# Regression for the *generated* launcher and the already installed launcher.
# No actual WorkBuddy process/window is touched.
source_script="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/workbuddy-desktop.sh}"
installed_script="${2:-}"
tmp="$(mktemp -d /tmp/nh-workbuddy-ozone-test-XXXXXX)"
socket_pid=""
cleanup() {
  if [[ -n "$socket_pid" ]]; then kill "$socket_pid" 2>/dev/null || true; wait "$socket_pid" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

# This source is the code generator, not an existing executable launcher.
grep -Fq 'has_ozone_override=0' "$source_script"
grep -Fq 'EXTRA_FLAGS+=(--ozone-platform=wayland)' "$source_script"
[[ -z "$installed_script" ]] && exit 0
bash -n "$installed_script"
mkdir -p "$tmp/app/resources/app" "$tmp/home"
cp "$installed_script" "$tmp/app/start.sh"
cat > "$tmp/app/electron" <<'ELECTRON'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$NH_MOCK_ELECTRON_ARGS"
ELECTRON
chmod +x "$tmp/app/electron" "$tmp/app/start.sh"
cat > "$tmp/app/electron-flags.conf" <<'FLAGS'
# preserve existing software fallback without affecting display-scale behavior
--disable-gpu
--disable-gpu-compositing
FLAGS
python3 - "$tmp/wayland-test" <<'PY' &
import socket,sys,time
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
s.bind(sys.argv[1]);s.listen(1);time.sleep(30)
PY
socket_pid=$!
for _ in {1..35}; do [[ -S "$tmp/wayland-test" ]] && break; sleep .06; done
[[ -S "$tmp/wayland-test" ]] || { echo 'test socket missing' >&2; exit 1; }

run_case() {
  local label="$1"; shift
  NH_MOCK_ELECTRON_ARGS="$tmp/args-$label" HOME="$tmp/home" "$@" "$tmp/app/start.sh"
}
run_case absolute env WAYLAND_DISPLAY="$tmp/wayland-test" ELECTRON_OZONE_PLATFORM_HINT=auto
grep -Fxq -- '--ozone-platform=wayland' "$tmp/args-absolute"
grep -Fxq -- '--disable-gpu' "$tmp/args-absolute"

run_case relative env XDG_RUNTIME_DIR="$tmp" WAYLAND_DISPLAY=wayland-test ELECTRON_OZONE_PLATFORM_HINT=auto
grep -Fxq -- '--ozone-platform=wayland' "$tmp/args-relative"

run_case absent env -u WAYLAND_DISPLAY ELECTRON_OZONE_PLATFORM_HINT=auto
! grep -Fq -- '--ozone-platform=wayland' "$tmp/args-absent"

run_case invalid env WAYLAND_DISPLAY="$tmp/does-not-exist" ELECTRON_OZONE_PLATFORM_HINT=auto
! grep -Fq -- '--ozone-platform=wayland' "$tmp/args-invalid"

run_case hint-x11 env WAYLAND_DISPLAY="$tmp/wayland-test" ELECTRON_OZONE_PLATFORM_HINT=x11
! grep -Fq -- '--ozone-platform=wayland' "$tmp/args-hint-x11"

printf '%s\n' '--ozone-platform=x11' >> "$tmp/app/electron-flags.conf"
run_case explicit-config env WAYLAND_DISPLAY="$tmp/wayland-test" ELECTRON_OZONE_PLATFORM_HINT=auto
grep -Fxq -- '--ozone-platform=x11' "$tmp/args-explicit-config"
! grep -Fq -- '--ozone-platform=wayland' "$tmp/args-explicit-config"

sed -i '/^--ozone-platform=x11$/d' "$tmp/app/electron-flags.conf"
NH_MOCK_ELECTRON_ARGS="$tmp/args-argv" HOME="$tmp/home" WAYLAND_DISPLAY="$tmp/wayland-test" ELECTRON_OZONE_PLATFORM_HINT=auto "$tmp/app/start.sh" --ozone-platform=x11
grep -Fxq -- '--ozone-platform=x11' "$tmp/args-argv"
! grep -Fq -- '--ozone-platform=wayland' "$tmp/args-argv"
echo 'WorkBuddy native Wayland DPR launcher: 7 cases PASS (absolute/relative/absent/invalid/hint override/explicit config/argv).'
