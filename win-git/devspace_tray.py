#!/usr/bin/env python3
"""XFCE tray controller for the local DevSpace MCP service.

状态采集的统一约定（两个平台的托盘共用同一套语义）：

- 数据源是 `devspace.sh states`：key=value、纯本地、毫秒级返回。
  不再解析中文 status 文本，尤其**不再用 status 做周期刷新** ——
  它内含 5s/20s 超时的 curl（本地 + 公网），在 GTK 主线程上跑会把托盘卡死。
- 进程存活 != 隧道可用。cloudflared 可能在跑而 0 个边缘连接（公网 530），
  所以必须单独显示"已连接/未连接"。
- 采集放后台线程，结果用 GLib.idle_add 回主线程更新 UI。
"""

import fcntl
import os
import re
import subprocess
import threading

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

try:
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3
except (ValueError, ImportError):
    AyatanaAppIndicator3 = None

DEVSPACE = "/root/sh/win-git/devspace.sh"
ACTION_LOG = "/tmp/devspace-tray.log"
SHARE_DIR = "/sdcard/Download/share"
DEFAULT_EXPORT = os.path.join(SHARE_DIR, "devspace-mcp-migration.tar.gz")
REFRESH_SECONDS = int(os.environ.get("DEVSPACE_TRAY_REFRESH", "15"))

TUNNEL_LABEL = {
    "connected": "已连接 Cloudflare",
    "disconnected": "未连接（进程在跑，隧道未注册）",
    "stopped": "已停止",
    "unknown": "状态未知",
}
SERVE_LABEL = {"running": "运行中", "stopped": "已停止"}


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


def run_devspace(args):
    return subprocess.run(["/bin/bash", DEVSPACE, *args], text=True, capture_output=True)


def autostart_enabled(component):
    result = run_devspace(f"{component}-autostart-status")
    return result.returncode == 0 and result.stdout.strip() == "enabled"


def fetch_snapshot():
    """采集一次状态。失败返回 None，由调用方保留上一次快照。"""
    result = run_devspace("states")
    if result.returncode != 0:
        return None
    data = {}
    for line in result.stdout.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            data[key.strip()] = value.strip()
    if "tunnel" not in data:
        return None
    data["devspace_autostart"] = autostart_enabled("devspace")
    data["cloudflared_autostart"] = autostart_enabled("cloudflared")
    return data


def full_status():
    return run_devspace("status")


def tray_title(snap):
    """一个字符表达汇总状态。"""
    if not snap:
        return "◌"
    serve = snap.get("serve", "stopped")
    tunnel = snap.get("tunnel", "unknown")
    if serve == "running" and tunnel == "connected":
        return "◆"
    if tunnel == "disconnected":
        return "◐"
    if serve != "running" and tunnel == "stopped":
        return "◇"
    return "◈"


def tunnel_line(snap):
    tunnel = snap.get("tunnel", "unknown")
    text = f"Cloudflare Tunnel：{TUNNEL_LABEL.get(tunnel, tunnel)}"
    if tunnel == "connected":
        extras = [f"{snap.get('tunnel_connections') or '?'} 个边缘连接"]
        if snap.get("tunnel_edges"):
            extras.append(snap["tunnel_edges"])
        if snap.get("tunnel_protocol"):
            extras.append(snap["tunnel_protocol"])
        text += f"（{'，'.join(extras)}）"
    return f"{text} / 自启动{'开' if snap.get('cloudflared_autostart') else '关'}"


def serve_line(snap):
    serve = snap.get("serve", "stopped")
    return f"DevSpace：{SERVE_LABEL.get(serve, serve)} / 自启动{'开' if snap.get('devspace_autostart') else '关'}"


def run_action(args, label, done=None):
    def worker():
        log(f"开始：{label} args={args}")
        result = run_devspace(args)
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
        self.snapshot = None
        self.fetching = False
        if AyatanaAppIndicator3 is not None:
            # 与分辨率托盘保持同一路径。当前 XFCE/Termux:X11 会话由
            # StatusNotifier 承载托盘菜单，Gtk.StatusIcon 在部分面板组合下
            # 虽能显示图标但收不到右键 popup-menu 事件。
            self.indicator = AyatanaAppIndicator3.Indicator.new(
                "devspace-mcp-controller",
                "network-server",
                AyatanaAppIndicator3.IndicatorCategory.SYSTEM_SERVICES,
            )
            self.indicator.set_status(AyatanaAppIndicator3.IndicatorStatus.ACTIVE)
            self.indicator.set_title("DevSpace MCP")
            self.indicator.set_menu(self.build_menu())
            self.icon = None
        else:
            self.indicator = None
            self.icon = Gtk.StatusIcon.new_from_icon_name("network-server")
            self.icon.set_title("DevSpace MCP")
            self.icon.set_tooltip_text("DevSpace MCP")
            self.icon.set_visible(True)
            self.icon.connect("popup-menu", self.popup)
            self.icon.connect("activate", self.activate)
        GLib.timeout_add_seconds(REFRESH_SECONDS, self.tick)
        self.tick()

    # --- 采集（后台线程） ---------------------------------------------------
    def tick(self):
        self.refresh_async()
        return True

    def refresh_async(self):
        if self.fetching:
            return
        self.fetching = True
        threading.Thread(target=self.fetch_worker, daemon=True).start()

    def fetch_worker(self):
        try:
            snap = fetch_snapshot()
        except Exception:
            snap = None
        GLib.idle_add(self.apply_snapshot, snap)

    # --- 渲染（GTK 主线程） -------------------------------------------------
    def apply_snapshot(self, snap):
        self.fetching = False
        if snap is not None:
            self.snapshot = snap
        snap = self.snapshot
        title = "DevSpace MCP"
        if snap:
            title = (f"{tray_title(snap)} DevSpace：{'运行' if snap.get('serve') == 'running' else '停止'}"
                     f" / Cloudflare：{'已连接' if snap.get('tunnel') == 'connected' else TUNNEL_LABEL.get(snap.get('tunnel'), '?')}")
        else:
            title = "◌ DevSpace MCP（状态读取中）"
        if self.indicator is not None:
            self.indicator.set_title(title)
            # AppIndicator 菜单不能像 Gtk.StatusIcon 那样在点击时动态构建，
            # 定期替换菜单以刷新状态。菜单用快照渲染，不再触发任何 I/O。
            self.indicator.set_menu(self.build_menu())
        elif self.icon is not None:
            self.icon.set_tooltip_text(title)
        return False

    @staticmethod
    def item(label, callback):
        item = Gtk.MenuItem(label=label)
        item.connect("activate", callback)
        return item

    def build_menu(self):
        menu = Gtk.Menu()
        snap = self.snapshot
        if not snap:
            info = Gtk.MenuItem(label="正在读取状态…")
            info.set_sensitive(False)
            menu.append(info)
            menu.append(Gtk.SeparatorMenuItem())
            menu.append(self.item("刷新状态", lambda _i: self.show_status()))
            menu.append(self.item("退出托盘", lambda _i: Gtk.main_quit()))
            menu.show_all()
            return menu

        devspace_running = snap.get("serve") == "running"
        tunnel = snap.get("tunnel", "unknown")
        devspace_auto = bool(snap.get("devspace_autostart"))
        cloudflared_auto = bool(snap.get("cloudflared_autostart"))

        state = Gtk.MenuItem(label=serve_line(snap))
        state.set_sensitive(False)
        menu.append(state)
        cloudflare_state = Gtk.MenuItem(label=tunnel_line(snap))
        cloudflare_state.set_sensitive(False)
        menu.append(cloudflare_state)
        if tunnel in ("disconnected", "unknown"):
            warning = Gtk.MenuItem(label=f"⚠ {snap.get('tunnel_error') or '公网访问会失败'}"[:110])
            warning.set_sensitive(False)
            menu.append(warning)
        menu.append(Gtk.SeparatorMenuItem())

        devspace_menu = Gtk.MenuItem(label="DevSpace 服务")
        devspace_submenu = Gtk.Menu()
        if devspace_running:
            devspace_submenu.append(self.item("停止", lambda _i: run_action(["stop-devspace"], "停止 DevSpace", self.after_action)))
            devspace_submenu.append(self.item("重启", lambda _i: run_action(["restart-devspace"], "重启 DevSpace", self.after_action)))
        else:
            devspace_submenu.append(self.item("启动", lambda _i: run_action(["start-devspace"], "启动 DevSpace", self.after_action)))
        devspace_submenu.append(Gtk.SeparatorMenuItem())
        if devspace_auto:
            devspace_submenu.append(self.item("关闭开机自启动", lambda _i: run_action(["disable-devspace-autostart"], "关闭 DevSpace 自启动", self.after_action)))
        else:
            devspace_submenu.append(self.item("开启开机自启动", lambda _i: run_action(["enable-devspace-autostart"], "开启 DevSpace 自启动", self.after_action)))
        devspace_menu.set_submenu(devspace_submenu)
        menu.append(devspace_menu)

        cloudflare_menu = Gtk.MenuItem(label="Cloudflare Tunnel")
        cloudflare_submenu = Gtk.Menu()
        # 进程活着但没连上 edge 时给"重连"：cloudflared 自己会重试，但
        # fake-IP/DNS 缓存过期时只有重启才会重新解析边缘地址。
        if tunnel in ("connected", "disconnected", "unknown"):
            cloudflare_submenu.append(self.item("重连（重启隧道）", lambda _i: run_action(["restart-cloudflared"], "重连 Cloudflare Tunnel", self.after_action)))
            cloudflare_submenu.append(self.item("停止", lambda _i: run_action(["stop-cloudflared"], "停止 Cloudflare Tunnel", self.after_action)))
        else:
            cloudflare_submenu.append(self.item("启动", lambda _i: run_action(["start-cloudflared"], "启动 Cloudflare Tunnel", self.after_action)))
        cloudflare_submenu.append(Gtk.SeparatorMenuItem())
        if cloudflared_auto:
            cloudflare_submenu.append(self.item("关闭开机自启动", lambda _i: run_action(["disable-cloudflared-autostart"], "关闭 Cloudflare 自启动", self.after_action)))
        else:
            cloudflare_submenu.append(self.item("开启开机自启动", lambda _i: run_action(["enable-cloudflared-autostart"], "开启 Cloudflare 自启动", self.after_action)))
        cloudflare_menu.set_submenu(cloudflare_submenu)
        menu.append(cloudflare_menu)

        whole_menu = Gtk.MenuItem(label="整套服务")
        whole_submenu = Gtk.Menu()
        if devspace_running or tunnel != "stopped":
            whole_submenu.append(self.item("全部停止", lambda _i: run_action(["stop"], "停止整套服务", self.after_action)))
        if not (devspace_running and tunnel == "connected"):
            whole_submenu.append(self.item("全部启动", lambda _i: run_action(["start"], "启动整套服务", self.after_action)))
        if devspace_running or tunnel != "stopped":
            whole_submenu.append(self.item("全部重启", lambda _i: run_action(["restart"], "重启整套服务", self.after_action)))
        whole_menu.set_submenu(whole_submenu)
        menu.append(whole_menu)

        menu.append(Gtk.SeparatorMenuItem())
        menu.append(self.item("刷新状态", lambda _i: self.refresh_async()))
        menu.append(self.item("查看详细状态…", lambda _i: self.show_status()))
        menu.append(Gtk.SeparatorMenuItem())
        menu.append(self.item("导出配置…", lambda _i: self.export_config()))
        menu.append(self.item("导入配置…", lambda _i: self.import_config()))
        menu.append(Gtk.SeparatorMenuItem())
        menu.append(self.item("退出托盘", lambda _i: Gtk.main_quit()))
        menu.show_all()
        return menu

    def after_action(self, _rc, _detail):
        self.refresh_async()
        return False

    def show_status(self):
        """完整 status（含公网探测）放后台，避免阻塞 GTK 主循环。"""
        def worker():
            result = full_status()
            detail = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
            GLib.idle_add(self.render_status_dialog, detail or "无状态信息")
        notify("DevSpace", "正在读取详细状态…")
        threading.Thread(target=worker, daemon=True).start()

    def render_status_dialog(self, detail):
        snap = self.snapshot or {}
        dialog = Gtk.MessageDialog(
            modal=True,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text=(f"DevSpace：{'运行中' if snap.get('serve') == 'running' else '已停止'}\n"
                  f"Cloudflare Tunnel：{TUNNEL_LABEL.get(snap.get('tunnel'), '未知')}\n"
                  f"DevSpace 自启动：{'已启用' if snap.get('devspace_autostart') else '已禁用'}\n"
                  f"Cloudflare 自启动：{'已启用' if snap.get('cloudflared_autostart') else '已禁用'}"),
        )
        dialog.format_secondary_text(detail[-2000:])
        dialog.run()
        dialog.destroy()
        self.refresh_async()
        return False

    def export_config(self):
        dialog = Gtk.FileChooserDialog(
            title="导出 DevSpace 配置",
            action=Gtk.FileChooserAction.SAVE,
        )
        dialog.add_buttons("取消", Gtk.ResponseType.CANCEL, "导出", Gtk.ResponseType.OK)
        dialog.set_do_overwrite_confirmation(True)
        dialog.set_current_name(os.path.basename(DEFAULT_EXPORT))
        os.makedirs(SHARE_DIR, exist_ok=True)
        dialog.set_current_folder(SHARE_DIR)
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
        os.makedirs(SHARE_DIR, exist_ok=True)
        dialog.set_current_folder(SHARE_DIR)
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
    os.environ.pop("LD_PRELOAD", None)
    os.environ.pop("LD_DEBUG", None)
    # 与显示托盘一致，按 DISPLAY 隔离锁，避免不可见会话中的托盘实例
    # 抢占当前会话的 StatusNotifier 项目。
    display_key = re.sub(r"[^A-Za-z0-9_.-]", "_", os.environ.get("DISPLAY", "wayland"))
    lock = open(f"/tmp/devspace-tray-{display_key}.lock", "w", encoding="utf-8")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    DevSpaceTray()
    Gtk.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
