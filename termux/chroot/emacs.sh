#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

. ./cli.sh

# NewHome owns one Smithay Wayland compositor and one compositor-managed rootless
# XWayland compatibility server. Never start Termux:X11/Xorg or kill NewHome's
# XWayland from this convenience launcher.
container_mounted || container_mount

unset LD_PRELOAD LD_DEBUG
sudo "$busybox" chroot "$CHROOT_DIR" /bin/su - root -c \
  'exec /usr/bin/newhome-wayland-run /usr/bin/emacs'
