#!/usr/bin/env python3
import fcntl
import json
import os
import re
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

SCALING = "/root/sh/win-git/xfce4-scaling.sh"
CONFIG_DIR = os.path.expanduser("~/.config/termux-x11-display")
PRESETS_FILE = os.path.join(CONFIG_DIR, "presets.json")


def load_presets():
    try:
        with open(PRESETS_FILE, encoding="utf-8") as stream:
            data = json.load(stream)
        return [p for p in data if isinstance(p, dict) and
                all(k in p for k in ("name", "resolution", "scale"))]
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return []


def save_presets(presets):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    temporary = PRESETS_FILE + ".new"
    with open(temporary, "w", encoding="utf-8") as stream:
        json.dump(presets, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    os.replace(temporary, PRESETS_FILE)


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

        custom = Gtk.MenuItem(label="自定义预设")
        custom_menu = Gtk.Menu()
        saved = load_presets()
        if saved:
            for preset in saved:
                label = f"{preset['name']}：{preset['resolution']} + {preset['scale']}x"
                custom_menu.append(self.item(
                    label, lambda _i, p=preset, l=label: run_setting(
                        ["--apply-profile", p["resolution"], str(p["scale"])], l)))
            custom_menu.append(Gtk.SeparatorMenuItem())
        else:
            empty = Gtk.MenuItem(label="（尚未添加）")
            empty.set_sensitive(False)
            custom_menu.append(empty)
        custom_menu.append(self.item("新增…", lambda _i: self.edit_preset()))
        custom_menu.append(self.item("管理（修改/删除）…", lambda _i: self.manage_presets()))
        custom.set_submenu(custom_menu)
        menu.append(custom)

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

    @staticmethod
    def message(text, kind=Gtk.MessageType.ERROR, parent=None):
        dialog = Gtk.MessageDialog(transient_for=parent, modal=True, message_type=kind,
                                   buttons=Gtk.ButtonsType.OK, text=text)
        dialog.run()
        dialog.destroy()

    def edit_preset(self, index=None, parent=None):
        presets = load_presets()
        old = presets[index] if index is not None and index < len(presets) else {}
        dialog = Gtk.Dialog(title="修改自定义预设" if old else "新增自定义预设",
                            transient_for=parent, modal=True)
        dialog.set_position(Gtk.WindowPosition.CENTER)
        dialog.set_default_size(430, 220)
        dialog.add_buttons("取消", Gtk.ResponseType.CANCEL, "保存", Gtk.ResponseType.OK)
        grid = Gtk.Grid(column_spacing=12, row_spacing=12, margin=18)
        fields = []
        for row, (title, value, hint) in enumerate((
                ("名称", old.get("name", ""), "例如：平板高分屏"),
                ("分辨率", old.get("resolution", current_display()), "例如：2560x1600"),
                ("缩放比例", str(old.get("scale", current_scale())), "支持：1、2、3"))):
            entry = Gtk.Entry(text=value)
            entry.set_placeholder_text(hint)
            grid.attach(Gtk.Label(label=title, xalign=0), 0, row, 1, 1)
            grid.attach(entry, 1, row, 1, 1)
            fields.append(entry)
        dialog.get_content_area().add(grid)
        dialog.show_all()
        while dialog.run() == Gtk.ResponseType.OK:
            name, resolution, scale = (field.get_text().strip() for field in fields)
            if not name:
                self.message("名称不能为空。", parent=dialog)
                continue
            match = re.fullmatch(r"([0-9]+)x([0-9]+)", resolution)
            if not match or not (320 <= int(match.group(1)) <= 8192 and
                                 240 <= int(match.group(2)) <= 8192):
                self.message("分辨率格式应为 WIDTHxHEIGHT，范围为 320x240 至 8192x8192。",
                             parent=dialog)
                continue
            if scale not in ("1", "2", "3"):
                self.message("完整应用缩放当前支持 1、2 或 3。", parent=dialog)
                continue
            if any(p["name"] == name for i, p in enumerate(presets) if i != index):
                self.message("已经存在同名预设，请换一个名称。", parent=dialog)
                continue
            value = {"name": name, "resolution": resolution, "scale": int(scale)}
            if index is None:
                presets.append(value)
            else:
                presets[index] = value
            save_presets(presets)
            dialog.destroy()
            notify("显示设置", f"已保存自定义预设：{name}")
            return True
        dialog.destroy()
        return False

    def manage_presets(self):
        dialog = Gtk.Dialog(title="管理自定义显示预设", modal=True)
        dialog.set_position(Gtk.WindowPosition.CENTER)
        dialog.set_default_size(620, 380)
        dialog.add_button("关闭", Gtk.ResponseType.CLOSE)
        box = dialog.get_content_area()
        store = Gtk.ListStore(str, str, str)
        view = Gtk.TreeView(model=store)
        for column, title in enumerate(("名称", "分辨率", "缩放")):
            view.append_column(Gtk.TreeViewColumn(title, Gtk.CellRendererText(), text=column))
        scroll = Gtk.ScrolledWindow()
        scroll.set_hexpand(True)
        scroll.set_vexpand(True)
        scroll.add(view)
        buttons = Gtk.ButtonBox(spacing=8)
        add = Gtk.Button(label="新增")
        edit = Gtk.Button(label="修改")
        delete = Gtk.Button(label="删除")
        for button in (add, edit, delete):
            buttons.add(button)
        box.pack_start(scroll, True, True, 8)
        box.pack_start(buttons, False, False, 8)

        def refresh():
            store.clear()
            for p in load_presets():
                store.append((p["name"], p["resolution"], f"{p['scale']}x"))

        def selected_index():
            model, treeiter = view.get_selection().get_selected()
            return model.get_path(treeiter).get_indices()[0] if treeiter else None

        add.connect("clicked", lambda _b: (self.edit_preset(parent=dialog), refresh()))
        edit.connect("clicked", lambda _b: self._edit_selected(selected_index(), dialog, refresh))
        delete.connect("clicked", lambda _b: self._delete_selected(selected_index(), dialog, refresh))
        refresh()
        dialog.show_all()
        dialog.run()
        dialog.destroy()

    def _edit_selected(self, index, parent, refresh):
        if index is None:
            self.message("请先选择要修改的预设。", parent=parent)
        elif self.edit_preset(index, parent):
            refresh()

    def _delete_selected(self, index, parent, refresh):
        if index is None:
            self.message("请先选择要删除的预设。", parent=parent)
            return
        presets = load_presets()
        confirm = Gtk.MessageDialog(transient_for=parent, modal=True,
                                    message_type=Gtk.MessageType.QUESTION,
                                    buttons=Gtk.ButtonsType.YES_NO,
                                    text=f"确定删除“{presets[index]['name']}”吗？")
        accepted = confirm.run() == Gtk.ResponseType.YES
        confirm.destroy()
        if accepted:
            del presets[index]
            save_presets(presets)
            refresh()

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
