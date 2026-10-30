#!/bin/bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

assert_contains() {
  local file=$1 expected=$2
  grep -Fq -- "$expected" "$file" || {
    echo "missing expected text in $file: $expected" >&2
    exit 1
  }
}

# Simulate MSYS2 without invoking PowerShell: the installer binary already exists and the test
# exercises persistent allToolsrc/newhomeadbrc resolution.
home=$root/home
newhome_repo=$root/newhome
rust_bin=$root/windows-user/tools/newhome-adb
sdk=$root/sdk
mkdir -p "$home" "$newhome_repo/win/scripts" "$rust_bin" "$sdk/platform-tools"
touch "$home/.zshrc"
: >"$newhome_repo/win/scripts/install-rust-adb.ps1"
cat >"$rust_bin/newhome-adb.exe" <<'SH'
#!/usr/bin/env bash
echo 'NewHome Rust ADB 1.0'
SH
cat >"$sdk/platform-tools/adb.exe" <<'SH'
#!/usr/bin/env bash
echo 'Android Debug Bridge official'
SH
chmod +x "$rust_bin/newhome-adb.exe" "$sdk/platform-tools/adb.exe"

HOME="$home" \
USERPROFILE='' \
NEWHOME_REPO="$newhome_repo" \
NEWHOME_PLATFORM_OVERRIDE=win \
NEWHOME_ADB_SKIP_INSTALL=1 \
NEWHOME_ADB_WINDOWS_BIN="$rust_bin" \
NEWHOME_ANDROID_SDK_WINDOWS="$sdk" \
bash "$repo_dir/win-git/newhome_rust_adb_setup.sh" >/dev/null

newhome_rc="$home/tools/rc/newhomeadbrc"
all_rc="$home/tools/rc/allToolsrc"
assert_contains "$newhome_rc" "export NEWHOME_ADB_BIN=\"$rust_bin\""
assert_contains "$newhome_rc" 'adb() { "$NEWHOME_ADB" "$@"; }'
assert_contains "$newhome_rc" "export ANDROID_ADB_FALLBACK=\"$sdk/platform-tools/adb.exe\""
test "$(tail -n 1 "$all_rc")" = "test -f $newhome_rc && . $newhome_rc"
HOME="$home" PATH=/usr/bin:/bin bash -c ". '$all_rc'; type adb | grep -q 'function'; adb version | grep -q 'NewHome Rust ADB'; test \"\$ANDROID_ADB_FALLBACK\" = '$sdk/platform-tools/adb.exe'"

# Simulate the Android SDK/JBR discovery branch. Windows must only write rc state; it must never
# enter the ARM64 Linux download/install path.
android_home=$root/android-home
android_sdk=$root/android-sdk
studio=$root/android-studio
mkdir -p "$android_home" "$android_sdk/platform-tools" "$android_sdk/cmdline-tools/latest/bin" "$studio/jbr/bin"
touch "$android_home/.zshrc"
cat >"$android_sdk/platform-tools/adb.exe" <<'SH'
#!/usr/bin/env bash
echo official-adb
SH
cat >"$studio/jbr/bin/java.exe" <<'SH'
#!/usr/bin/env bash
echo java
SH
chmod +x "$android_sdk/platform-tools/adb.exe" "$studio/jbr/bin/java.exe"

(
  cd "$repo_dir/win-git"
  HOME="$android_home" \
  NEWHOME_PLATFORM_OVERRIDE=win \
  NEWHOME_ANDROID_SDK_WINDOWS="$android_sdk" \
  NEWHOME_ANDROID_STUDIO_WINDOWS="$studio" \
  NEWHOME_JAVA_HOME_WINDOWS="$studio/jbr" \
  bash ./android.sh >/dev/null
)

android_rc="$android_home/tools/rc/androidrc"
assert_contains "$android_rc" "export ANDROID_HOME=\"$android_sdk\""
assert_contains "$android_rc" "export ANDROID_SDK_ROOT=\"$android_sdk\""
assert_contains "$android_rc" "export JAVA_HOME=\"$studio/jbr\""
assert_contains "$android_rc" 'export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"'
HOME="$android_home" PATH=/usr/bin:/bin bash -c ". '$android_home/tools/rc/allToolsrc'; test \"\$ANDROID_HOME\" = '$android_sdk'; test \"\$JAVA_HOME\" = '$studio/jbr'; adb.exe | grep -q official-adb"

echo 'MSYS2 Windows Android/NewHome ADB rc persistence: PASS'
