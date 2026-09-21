#!/usr/bin/env python3
"""XFCE tray controller for the local DevSpace MCP service."""

import fcntl
import os
import subprocess
import threading

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

DEVSPACE = "/root/sh/win-git/devspace.sh"
LOCK_PATH = "/tmp/devspace-tray.lock"
ACTION_LOG = "/tmp/devspace-tray.log"
DEFAULT_EXPORT = os.path.expanduser("~/Downloads/devspace-mcp-migration.tar.gz")


def notify(title, body, urgency="normal"):
    subprocess.Popen(
        ["notify-send", "-u", urgency, title, body],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def log(message):
    try:
        with open(ACTION_LOG, "a", encoding="utf-8") as stream:
            stamp = GLib.DateTime.new_now_local().format("%F %T")
            stream.write(f"{stamp} {message}\n")
    except OSError:
        pass


def service_status():
    result = subprocess.run(
        ["/bin/bash", DEVSPACE, "status"], text=True, capture_output=True
    )
    text = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
    low = text.lower()
    running = result.returncode == 0 and (
        "running" in low or "http 401" in low or "运行" in text
    )
    return running, text[-1200:] if text else "无状态信息"


def run_action(args, label, done=None):
    def worker():
        log(f"开始：{label} args={args}")
        result = subprocess.run(
            ["/bin/bash", DEVSPACE, *args], text=True, capture_output=True
        )
        detail = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
        log(f"结束：{label} rc={result.returncode}\n{detail}")
        if result.returncode == 0:
            GLib.idle_add(notify, "DevSpace", f"{label}完成")
        else:
            GLib.idle_add(notify, "DevSpace 操作失败", (detail or "未知错误")[-600:], "critical")
        if done:
            GLib.idle_add(done, result.returncode, detail)

    notify("DevSpace", f"正在{label}…")
    threading.Thread(target=worker, daemon=True).start()


class DevSpaceTray:
    def __init__(self):
        self.icon = Gtk.StatusIcon.new_from_icon_name("network-server")
        self.icon.set_title("DevSpace MCP")
        self.icon.set_visible(True)
        self.icon.connect("popup-menu", self.popup)
        self.icon.connect("activate", self.activate)
        self.refresh_tooltip()
        GLib.timeout_add_seconds(15, self.refresh_tooltip)

    def refresh_tooltip(self):
        running, _ = service_status()
        self.icon.set_tooltip_text(f"DevSpace MCP：{'运行中' if running else '已停止'}")
        return True

    @staticmethod
    def item(label, callback):
        item = Gtk.MenuItem(label=label)
        item.connect("activate", callback)
        return item

    def build_menu(self):
        menu = Gtk.Menu()
        running, detail = service_status()
        current = Gtk.MenuItem(label=f"当前：{'运行中' if running else '已停止'}")
        current.set_sensitive(False)
        menu.append(current)
        menu.append(Gtk.SeparatorMenuItem())

        if running:
            menu.append(self.item("停止 DevSpace", lambda _i: run_action(["stop"], "停止 DevSpace", self.after_action)))
            menu.append(self.item("重启 DevSpace", lambda _i: run_action(["restart"], "重启 DevSpace", self.after_action)))
        else:
            menu.append(self.item("启动 DevSpace", lambda _i: run_action(["start"], "启动 DevSpace", self.after_action)))

        menu.append(self.item("刷新状态", lambda _i: self.show_status()))
        menu.append(Gtk.SeparatorMenuItem())
        menu.append(self.item("导出配置…", lambda _i: self.export_config()))
        menu.append(self.item("导入配置…", lambda _i: self.import_config()))
        menu.append(Gtk.SeparatorMenuItem())

        status = Gtk.MenuItem(label=(detail.splitlines()[0][:80] if detail else ""))
        status.set_sensitive(False)
        menu.append(status)
        menu.append(self.item("退出托盘", lambda _i: Gtk.main_quit()))
        menu.show_all()
        return menu

    def after_action(self, _rc, _detail):
        self.refresh_tooltip()
        return False

    def show_status(self):
        running, detail = service_status()
        dialog = Gtk.MessageDialog(
            modal=True,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text=f"DevSpace MCP：{'运行中' if running else '已停止'}",
        )
        dialog.format_secondary_text(detail)
        dialog.run()
        dialog.destroy()
        self.refresh_tooltip()

    def export_config(self):
        dialog = Gtk.FileChooserDialog(
            title="导出 DevSpace 配置",
            action=Gtk.FileChooserAction.SAVE,
        )
        dialog.add_buttons("取消", Gtk.ResponseType.CANCEL, "导出", Gtk.ResponseType.OK)
        dialog.set_do_overwrite_confirmation(True)
        dialog.set_current_name(os.path.basename(DEFAULT_EXPORT))
        downloads = os.path.dirname(DEFAULT_EXPORT)
        if os.path.isdir(downloads):
            dialog.set_current_folder(downloads)
        if dialog.run() == Gtk.ResponseType.OK:
            path = dialog.get_filename()
            dialog.destroy()
            run_action(["export", path], "导出配置")
            return
        dialog.destroy()

    def import_config(self):
        dialog = Gtk.FileChooserDialog(
            title="导入 DevSpace 配置",
            action=Gtk.FileChooserAction.OPEN,
        )
        dialog.add_buttons("取消", Gtk.ResponseType.CANCEL, "导入", Gtk.ResponseType.OK)
        filt = Gtk.FileFilter()
        filt.set_name("DevSpace 迁移包 (*.tar.gz)")
        filt.add_pattern("*.tar.gz")
        dialog.add_filter(filt)
        if dialog.run() != Gtk.ResponseType.OK:
            dialog.destroy()
            return
        path = dialog.get_filename()
        dialog.destroy()

        confirm = Gtk.MessageDialog(
            modal=True,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text="导入会替换本机 DevSpace 与 Cloudflare Tunnel 配置",
        )
        confirm.format_secondary_text(
            "现有配置会先自动备份。导入包包含 owner token、Tunnel 凭据和 OAuth token。"
        )
        response = confirm.run()
        confirm.destroy()
        if response != Gtk.ResponseType.OK:
            return

        def imported(rc, _detail):
            if rc == 0:
                run_action(["install"], "应用导入配置并启用自启动", self.after_action)
            return False

        run_action(["import", path], "导入配置", imported)

    def popup(self, icon, button, activate_time):
        self.build_menu().popup(
            None, None, Gtk.StatusIcon.position_menu, icon, button, activate_time
        )

    def activate(self, icon):
        self.build_menu().popup(
            None, None, Gtk.StatusIcon.position_menu, icon, 0, Gtk.get_current_event_time()
        )


def main():
    lock = open(LOCK_PATH, "w", encoding="utf-8")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    DevSpaceTray()
    Gtk.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
