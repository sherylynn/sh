#!/usr/bin/env python3
import fcntl
import os
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

SCALING = "/root/sh/win-git/xfce4-scaling.sh"


def current_display():
    try:
        out = subprocess.check_output(["xrandr", "--current"], text=True, stderr=subprocess.DEVNULL)
        marker = "current "
        value = out.split(marker, 1)[1].split(",", 1)[0]
        return value.replace(" ", "")
    except Exception:
        return "未知"


def current_scale():
    try:
        return subprocess.check_output([
            "xfconf-query", "-c", "xsettings", "-p", "/Gdk/WindowScalingFactor"
        ], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "1"


def notify(title, body, urgency="normal"):
    subprocess.Popen(["notify-send", "-u", urgency, title, body],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run_setting(args, label):
    def worker():
        result = subprocess.run([SCALING, *args], text=True, capture_output=True)
        if result.returncode == 0:
            GLib.idle_add(notify, "显示设置", f"已应用：{label}")
        else:
            detail = (result.stderr or result.stdout or "未知错误").strip()[-500:]
            GLib.idle_add(notify, "显示设置失败", detail, "critical")
    notify("显示设置", f"正在应用：{label}")
    threading.Thread(target=worker, daemon=True).start()


class DisplayTray:
    def __init__(self):
        self.icon = Gtk.StatusIcon.new_from_icon_name("preferences-desktop-display")
        self.icon.set_title("Termux:X11 显示设置")
        self.icon.set_tooltip_text("分辨率与界面缩放")
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
        current = Gtk.MenuItem(label=f"当前：{current_display()} + {current_scale()}x")
        current.set_sensitive(False)
        menu.append(current)
        menu.append(Gtk.SeparatorMenuItem())

        presets = Gtk.MenuItem(label="分辨率 + 缩放预设")
        presets_menu = Gtk.Menu()
        for resolution, scale in (("1920x1080", "1"), ("2560x1600", "2"), ("2376x1080", "2")):
            label = f"{resolution} + {scale}x"
            presets_menu.append(self.item(label, lambda _i, r=resolution, s=scale, l=label:
                                           run_setting(["--apply-profile", r, s], l)))
        presets.set_submenu(presets_menu)
        menu.append(presets)

        scales = Gtk.MenuItem(label="保持当前分辨率，仅调整界面缩放")
        scales_menu = Gtk.Menu()
        for scale in ("1", "2", "3"):
            label = f"界面缩放 {scale}x"
            scales_menu.append(self.item(label, lambda _i, s=scale, l=label:
                                          run_setting(["--apply-scale", s], l)))
        scales.set_submenu(scales_menu)
        menu.append(scales)

        menu.append(Gtk.SeparatorMenuItem())
        menu.append(self.item("打开完整设置窗口…", lambda _i: subprocess.Popen([SCALING, "--gui"])))
        menu.append(self.item("退出显示托盘", lambda _i: Gtk.main_quit()))
        menu.show_all()
        return menu

    def popup(self, icon, button, activate_time):
        self.build_menu().popup(None, None, Gtk.StatusIcon.position_menu,
                                icon, button, activate_time)

    def activate(self, icon):
        self.build_menu().popup(None, None, Gtk.StatusIcon.position_menu,
                                icon, 0, Gtk.get_current_event_time())


if __name__ == "__main__":
    os.environ.pop("LD_PRELOAD", None)
    os.environ.pop("LD_DEBUG", None)
    lock = open("/tmp/xfce-display-tray.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)
    DisplayTray()
    Gtk.main()
