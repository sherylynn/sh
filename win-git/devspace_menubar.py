#!/usr/bin/env python3
"""macOS menu-bar controller for DevSpace MCP.

设计要点（都是踩过的坑）：

1. 状态采集一律走 `devspace.sh states`（key=value，纯本地无网络请求），
   不再解析中文 status 文本。进程存活 != 隧道可用：cloudflared 可能在跑而
   一个边缘连接都没有，此时公网是 530，只看 pgrep 永远发现不了。
2. 所有采集放后台线程，UI 操作一律经 `callAfter` 回主线程。
   后台线程里直接调 rumps.alert()/notification() 会抛
   NSInternalInconsistencyException（NSWindow drag regions ... Main Thread），
   异常又被线程吞掉 —— 表现为"点了没反应、也看不到报错"。
"""

import os
import subprocess
import sys
import threading
from pathlib import Path

try:
    import rumps
except ImportError:
    print("Missing rumps. Run devspace.sh install to install the macOS menu bar dependency.", file=sys.stderr)
    raise

try:
    from PyObjCTools import AppHelper
except ImportError:  # pyobjc 理论上必装，兜底直调
    AppHelper = None

SCRIPT_DIR = Path(__file__).resolve().parent
DEVSPACE = str(SCRIPT_DIR / "devspace.sh")
HOME = Path.home()
DEFAULT_EXPORT = HOME / "Downloads" / "devspace-mcp-migration.tar.gz"

REFRESH_SECONDS = int(os.environ.get("DEVSPACE_MENUBAR_REFRESH", "15"))

TUNNEL_LABEL = {
    "connected": "已连接 Cloudflare",
    "disconnected": "未连接（进程在跑，隧道未注册）",
    "stopped": "已停止",
    "unknown": "状态未知",
}
SERVE_LABEL = {"running": "运行中", "stopped": "已停止"}


def shell(*args):
    return subprocess.run(["/bin/bash", DEVSPACE, *args], text=True, capture_output=True)


def ui(fn, *args):
    """把 UI 调用调度回主线程（后台线程直接弹窗会崩）。"""
    if AppHelper is not None:
        AppHelper.callAfter(fn, *args)
    else:
        fn(*args)


def fetch_states():
    """采集一次状态。返回 dict；失败返回 None（保留上一次快照）。"""
    result = shell("states")
    if result.returncode != 0:
        return None
    data = {}
    for line in result.stdout.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            data[key.strip()] = value.strip()
    if "tunnel" not in data:
        return None
    data["devspace_autostart"] = auto("devspace")
    data["cloudflared_autostart"] = auto("cloudflared")
    return data


def auto(component):
    return shell(f"{component}-autostart-status").stdout.strip() == "enabled"


def menu_bar_title(serve, tunnel):
    """一个字符表达汇总状态（刘海屏宽度有限）。"""
    if serve == "running" and tunnel == "connected":
        return "◆"          # 全部正常
    if tunnel == "disconnected":
        return "◐"          # 进程在跑但没连上 Cloudflare
    if serve != "running" and tunnel == "stopped":
        return "◇"          # 全停
    return "◈"              # 其他混合状态


def tunnel_line(snap):
    """Cloudflare 那一行的文案：必须体现"有没有真的连上"。"""
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


def action(args, label, callback=None):
    def worker():
        result = shell(*args)
        detail = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
        if result.returncode == 0:
            ui(rumps.notification, "DevSpace", label, "完成")
        else:
            ui(rumps.alert, f"{label}失败", detail[-1200:] or "未知错误")
        if callback:
            ui(callback)
    threading.Thread(target=worker, daemon=True).start()


class DevSpaceMenu(rumps.App):
    def __init__(self):
        # 刘海屏菜单栏空间有限：只占一个字符宽度，但那个字符要能表达连通性。
        super().__init__("◇", quit_button=None)
        self.lock = threading.Lock()
        self.snapshot = None
        self.fetching = False
        self.timer = rumps.Timer(self.tick, REFRESH_SECONDS)
        self.timer.start()
        self.refresh_async()

    # --- 采集（后台线程） ---------------------------------------------------
    def refresh_async(self):
        with self.lock:
            if self.fetching:
                return
            self.fetching = True
        threading.Thread(target=self.fetch_worker, daemon=True).start()

    def fetch_worker(self):
        try:
            data = fetch_states()
        except Exception:
            data = None
        with self.lock:
            self.fetching = False
            if data is not None:
                self.snapshot = data
        ui(self.render)

    def tick(self, _=None):
        self.refresh_async()

    # --- 渲染（主线程） -----------------------------------------------------
    def render(self, _=None):
        snap = self.snapshot
        if not snap:
            self.title = "◌"
            menu = [
                rumps.MenuItem("正在读取状态…"),
                None,
                rumps.MenuItem("刷新状态", callback=lambda _: self.refresh_async()),
                rumps.MenuItem("退出菜单栏", callback=lambda _: rumps.quit_application()),
            ]
            self.menu.clear()
            self.menu.update(menu)
            return

        serve = snap.get("serve", "stopped")
        tunnel = snap.get("tunnel", "unknown")
        da = snap.get("devspace_autostart") == "enabled"
        serve_up = serve == "running"

        # 一个字符表达三种状态：正常 / 有问题 / 全停
        self.title = menu_bar_title(serve, tunnel)

        tunnel_line_text = tunnel_line(snap)

        menu = [
            rumps.MenuItem(f"DevSpace：{SERVE_LABEL.get(serve, serve)} / 自启动{'开' if da else '关'}"),
            rumps.MenuItem(tunnel_line_text),
        ]
        if tunnel in ("disconnected", "unknown"):
            err = snap.get("tunnel_error")
            menu.append(rumps.MenuItem(f"  ⚠ {err[:90]}" if err else "  ⚠ 公网访问会失败"))
        menu.append(None)

        dsm = rumps.MenuItem("DevSpace 服务")
        if serve_up:
            dsm.add(rumps.MenuItem("停止", callback=lambda _: action(["stop-devspace"], "停止 DevSpace", self.refresh_async)))
            dsm.add(rumps.MenuItem("重启", callback=lambda _: action(["restart-devspace"], "重启 DevSpace", self.refresh_async)))
        else:
            dsm.add(rumps.MenuItem("启动", callback=lambda _: action(["start-devspace"], "启动 DevSpace", self.refresh_async)))
        dsm.add(None)
        dsm.add(rumps.MenuItem("关闭开机自启动" if da else "开启开机自启动",
            callback=lambda _: action(["disable-devspace-autostart" if da else "enable-devspace-autostart"], "更新 DevSpace 自启动", self.refresh_async)))
        menu.append(dsm)

        cfm = rumps.MenuItem("Cloudflare Tunnel")
        # 进程活着但没连上 edge 时，给的是"重连"而不是"启动"：
        # cloudflared 自己会重试，但 fake-IP/DNS 缓存过期时只有重启才会重新解析。
        if tunnel in ("connected", "disconnected", "unknown"):
            cfm.add(rumps.MenuItem("重连（重启隧道）", callback=lambda _: action(["restart-cloudflared"], "重连 Cloudflare Tunnel", self.refresh_async)))
            cfm.add(rumps.MenuItem("停止", callback=lambda _: action(["stop-cloudflared"], "停止 Cloudflare Tunnel", self.refresh_async)))
        else:
            cfm.add(rumps.MenuItem("启动", callback=lambda _: action(["start-cloudflared"], "启动 Cloudflare Tunnel", self.refresh_async)))
        cfm.add(None)
        cfm.add(rumps.MenuItem("关闭开机自启动" if ca else "开启开机自启动",
            callback=lambda _: action(["disable-cloudflared-autostart" if ca else "enable-cloudflared-autostart"], "更新 Cloudflare 自启动", self.refresh_async)))
        menu.append(cfm)

        both = rumps.MenuItem("整套服务")
        both.add(rumps.MenuItem("全部启动", callback=lambda _: action(["start"], "启动整套服务", self.refresh_async)))
        both.add(rumps.MenuItem("全部停止", callback=lambda _: action(["stop"], "停止整套服务", self.refresh_async)))
        both.add(rumps.MenuItem("全部重启", callback=lambda _: action(["restart"], "重启整套服务", self.refresh_async)))
        menu.extend([both, None])

        menu.extend([
            rumps.MenuItem("刷新状态", callback=lambda _: self.refresh_async()),
            rumps.MenuItem("管理工作目录…", callback=self.manage_roots),
            rumps.MenuItem("打开 ChatGPT 卡片清理扩展目录", callback=self.open_card_cleaner),
            rumps.MenuItem("导出配置…", callback=self.export_config),
            rumps.MenuItem("导入配置…", callback=self.import_config),
            rumps.MenuItem("查看详细状态…", callback=self.show_detail),
            None,
            rumps.MenuItem("退出菜单栏", callback=lambda _: rumps.quit_application()),
        ])
        self.menu.clear()
        self.menu.update(menu)

    def show_detail(self, _):
        # 完整 status 含公网探测（最坏 20s+），必须放后台线程。
        def worker():
            result = shell("status")
            text = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
            ui(rumps.alert, "DevSpace 状态", text[-3000:] or "无状态信息")
        threading.Thread(target=worker, daemon=True).start()

    def manage_roots(self, _):
        # 目录扫描可能很慢，同样不能阻塞菜单栏主线程。
        def worker():
            result = shell("roots-scan")
            if result.returncode != 0:
                ui(rumps.alert, "扫描失败", result.stderr or result.stdout)
                return
            candidates = [x for x in result.stdout.splitlines() if x.strip()]
            if not candidates:
                ui(rumps.alert, "管理工作目录", "没有扫描到 Git 仓库。")
                return
            selected = set(shell("roots-list").stdout.splitlines())
            ui(self.show_roots_window, candidates, selected)
        threading.Thread(target=worker, daemon=True).start()

    def show_roots_window(self, candidates, selected):
        # rumps 没有多选列表控件。用一个真正的 Cocoa 窗口显示可滚动 checkbox，
        # 用户一次勾选后点“保存”，而不是旧版需要再打开菜单才能看到子项。
        from AppKit import (NSAlert, NSButton, NSButtonTypeSwitch, NSMakeRect,
                            NSModalResponseOK, NSScrollView, NSStackView,
                            NSUserInterfaceLayoutOrientationVertical, NSView)

        alert = NSAlert.alloc().init()
        alert.setMessageText_("管理 DevSpace 工作目录")
        alert.setInformativeText_("勾选允许 ChatGPT/DevSpace 打开的目录。保存后会重启 DevSpace。")
        alert.addButtonWithTitle_("保存")
        alert.addButtonWithTitle_("取消")

        container = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, 620, 420))
        scroll = NSScrollView.alloc().initWithFrame_(NSMakeRect(0, 0, 620, 420))
        scroll.setHasVerticalScroller_(True)
        scroll.setAutohidesScrollers_(True)
        stack = NSStackView.alloc().initWithFrame_(NSMakeRect(0, 0, 590, max(420, len(candidates) * 28)))
        stack.setOrientation_(NSUserInterfaceLayoutOrientationVertical)
        stack.setSpacing_(5)
        stack.setEdgeInsets_((8, 8, 8, 8))
        buttons = []
        for path in candidates:
            button = NSButton.alloc().init()
            button.setButtonType_(NSButtonTypeSwitch)
            button.setTitle_(path)
            button.setState_(1 if path in selected else 0)
            stack.addArrangedSubview_(button)
            buttons.append((button, path))
        scroll.setDocumentView_(stack)
        container.addSubview_(scroll)
        alert.setAccessoryView_(container)

        if alert.runModal() != NSModalResponseOK:
            return
        wanted = [path for button, path in buttons if button.state() == 1]
        result = shell("roots-set", *wanted)
        if result.returncode != 0:
            rumps.alert("保存工作目录失败", result.stderr or result.stdout)
            return
        action(["restart-devspace"], "应用工作目录", self.refresh_async)

    def open_card_cleaner(self, _):
        # 扩展源码跟随当前仓库管理；Finder 打开后可直接在 Firefox/Chromium 中加载。
        extension_dir = SCRIPT_DIR / "chatgpt-devspace-cleaner"
        subprocess.run(["/usr/bin/open", str(extension_dir)], check=False)

    def export_config(self, _):
        window = rumps.Window("导出文件路径", "导出 DevSpace 配置", default_text=str(DEFAULT_EXPORT))
        response = window.run()
        if response.clicked and response.text.strip():
            action(["export", response.text.strip()], "导出配置")

    def import_config(self, _):
        window = rumps.Window("迁移包路径", "导入 DevSpace 配置", default_text=str(DEFAULT_EXPORT))
        response = window.run()
        if not response.clicked or not response.text.strip():
            return
        if rumps.alert("确认导入", "会备份并替换 DevSpace/Cloudflare 配置，同时保留本机工作目录。", ok="导入", cancel="取消") == 1:
            action(["import", response.text.strip()], "导入配置", lambda: action(["install"], "应用导入配置", self.refresh_async))


if __name__ == "__main__":
    DevSpaceMenu().run()
