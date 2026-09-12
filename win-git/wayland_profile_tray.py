#!/usr/bin/env python3
"""Small profile/status tray for the Labwc/Anland desktop.

The existing xfce_display_tray.py remains X11-specific because its resolution
controls intentionally use xrandr/Termux:X11.  This tray only owns lifecycle
switching and diagnostics, so it is safe under native Wayland/XWayland.
"""

import fcntl
import os
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

CONTROL_CLIENT = "/root/sh/termux/chroot/newhome_control.py"
WAYLAND_ORCHESTRATOR = "/root/sh/termux/chroot/termux_wayland_all_in_one.sh"


def notify(title, body, urgency="normal"):
    subprocess.Popen(
        ["notify-send", "-u", urgency, title, body],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def request_restart(profile):
    command = "restart-wayland" if profile == "wayland" else "restart-x11"
    label = "Wayland（Anland + Labwc）" if profile == "wayland" else "X11（Termux:X11）"
    notify("桌面切换", f"正在请求 NewHome 重启到 {label}…")

    def worker():
        try:
            result = subprocess.run(
                [sys.executable, CONTROL_CLIENT, command],
                text=True,
                capture_output=True,
                timeout=25,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            GLib.idle_add(notify, "桌面切换失败", f"NewHome 控制桥不可用：{exc}", "critical")
            return

        if result.returncode != 0:
            detail = (result.stderr or result.stdout or "NewHome 拒绝了重启请求").strip()[-500:]
            GLib.idle_add(notify, "桌面切换失败", detail, "critical")

    threading.Thread(target=worker, daemon=True).start()


def session_status():
    wayland = os.environ.get("WAYLAND_DISPLAY", "未知")
    mode = os.environ.get("NEWHOME_WAYLAND_MODE", "auto")
    direct = os.path.exists("/opt/newhome-wayland/wlroots-anland.ready")
    transport = "direct wlroots-anland" if direct and mode != "nested" else "Weston bootstrap"
    return f"Wayland: {wayland} · {transport}"


def run_doctor():
    # We are already inside chroot.  The doctor has a Termux-side section, so
    # launch a terminal with a simple local process/status snapshot instead of
    # pretending the Android namespace is visible here.
    command = (
        "printf '=== Wayland session ===\\n'; "
        "printf 'WAYLAND_DISPLAY=%s\\n' \"$WAYLAND_DISPLAY\"; "
        "printf 'XDG_SESSION_TYPE=%s\\n' \"$XDG_SESSION_TYPE\"; "
        "printf '\\nProcesses:\\n'; "
        "pgrep -a -x labwc || true; pgrep -a -x weston || true; "
        "printf '\\nDirect backend marker:\\n'; "
        "cat /opt/newhome-wayland/wlroots-anland.ready 2>/dev/null || echo 'not ready'; "
        "printf '\\nPress Enter to close...'; read _"
    )
    subprocess.Popen(["xfce4-terminal", "--command", f"bash -lc {command!r}"])


class WaylandTray:
    def __init__(self):
        self.icon = Gtk.StatusIcon.new_from_icon_name("video-display")
        self.icon.set_title("Anland / Labwc")
        self.icon.set_tooltip_text("Wayland 桌面与启动 profile")
        self.icon.set_visible(True)
        self.icon.connect("popup-menu", self.popup)
        self.icon.connect("activate", self.activate)

    @staticmethod
    def item(label, callback):
        item = Gtk.MenuItem(label=label)
        item.connect("activate", callback)
        return item

    def build_menu(self):
        menu = Gtk.Menu()
        current = Gtk.MenuItem(label=session_status())
        current.set_sensitive(False)
        menu.append(current)
        menu.append(Gtk.SeparatorMenuItem())
        menu.append(self.item(
            "重启 Wayland（Anland + Labwc）",
            lambda _i: request_restart("wayland"),
        ))
        menu.append(self.item(
            "重启到 X11（Termux:X11）",
            lambda _i: request_restart("x11"),
        ))
        menu.append(Gtk.SeparatorMenuItem())
        menu.append(self.item("会话诊断…", lambda _i: run_doctor()))
        menu.append(self.item("退出托盘", lambda _i: Gtk.main_quit()))
        menu.show_all()
        return menu

    def popup(self, icon, button, activate_time):
        self.build_menu().popup(
            None, None, Gtk.StatusIcon.position_menu, icon, button, activate_time
        )

    def activate(self, icon):
        self.build_menu().popup(
            None, None, Gtk.StatusIcon.position_menu,
            icon, 0, Gtk.get_current_event_time()
        )


if __name__ == "__main__":
    os.environ.pop("LD_PRELOAD", None)
    os.environ.pop("LD_DEBUG", None)
    lock = open("/tmp/newhome-wayland-tray.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)
    WaylandTray()
    Gtk.main()
