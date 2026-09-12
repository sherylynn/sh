#!/data/data/com.termux/files/usr/bin/bash
# Pinned versions for the NewHome/Anland Wayland experiment.
# Keep the Android consumer + Termux daemon on one Anland release.  The
# compositor side may evolve independently (Weston bootstrap today, direct
# wlroots-anland later).

ANLAND_VERSION="5.13.3"
ANLAND_RELEASE_BASE="https://github.com/lfdevs/anland-termux/releases/download/${ANLAND_VERSION}"

ANLAND_APK_STANDARD="AnlandTermux-${ANLAND_VERSION}.apk"
ANLAND_APK_COMPATIBLE="AnlandTermux-${ANLAND_VERSION}-compatible.apk"
ANLAND_DAEMON_DEB="anland_${ANLAND_VERSION}_aarch64.deb"

# Debian 13 / trixie assets from the same upstream release.  Weston is used
# only as a bootstrap compatibility producer until our wlroots Anland backend
# is ready; Labwc remains the user-facing compositor in both modes.
ANLAND_DEBIAN_XWAYLAND_DEB="xwayland_24.1.6-91_arm64.deb"
ANLAND_DEBIAN_WESTON_ZIP="weston_anland-5.13-debian-14.0.2-92.zip"

# Verified upstream SHA-256 values that are useful before installing binaries.
ANLAND_APK_STANDARD_SHA256="b63aa9ae001316e0440ab9f963192554ab9a9e33c1a9ebe0074d9dd023d18a28"
ANLAND_APK_COMPATIBLE_SHA256="929add98d56c247a070cac642d0d1034dcadf23f08c72bcb0966de89ca635838"
ANLAND_DAEMON_DEB_SHA256="62cc21942692377aff64f4e7d6d8cd110c4ed1b49e524c95584c98c7c222d493"

ANLAND_ANDROID_PACKAGE="com.anland.termux"
ANLAND_ANDROID_ACTIVITY="com.anland.termux/.MainActivity"
ANLAND_SOCKET_TERMUX="${PREFIX:-/data/data/com.termux/files/usr}/tmp/anland/display_daemon.sock"
ANLAND_SOCKET_CHROOT="/tmp/anland/display_daemon.sock"

# Debian 13 ships Labwc 0.8.3 on wlroots 0.18.  That is our first direct
# wlroots-anland ABI target: it lets us keep distro Labwc and substitute only
# a patched wlroots 0.18 build via LD_LIBRARY_PATH once the backend is ready.
NEWHOME_LABWC_BASELINE="0.8.3"
NEWHOME_WLROOTS_BASELINE="0.18"
