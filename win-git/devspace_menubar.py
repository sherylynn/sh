#!/usr/bin/env python3
"""macOS menu-bar controller for DevSpace MCP."""

import os
import re
import subprocess
import sys
import threading
from pathlib import Path

try:
    import rumps
except ImportError:
    print("Missing rumps. Run devspace.sh install to install the macOS menu bar dependency.", file=sys.stderr)
    raise

SCRIPT_DIR = Path(__file__).resolve().parent
DEVSPACE = str(SCRIPT_DIR / "devspace.sh")
HOME = Path.home()
DEFAULT_EXPORT = HOME / "Downloads" / "devspace-mcp-migration.tar.gz"


def shell(*args):
    return subprocess.run(["/bin/bash", DEVSPACE, *args], text=True, capture_output=True)


def action(args, label, callback=None):
    def worker():
        result = shell(*args)
        detail = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
        if result.returncode == 0:
            rumps.notification("DevSpace", label, "完成")
        else:
            rumps.alert(f"{label}失败", detail[-1200:] or "未知错误")
        if callback:
            callback()
    threading.Thread(target=worker, daemon=True).start()


def status():
    result = shell("status")
    text = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
    return (
        bool(re.search(r"^devspace serve: 运行中", text, re.MULTILINE)),
        bool(re.search(r"^cloudflared tunnel: 运行中", text, re.MULTILINE)),
        text,
    )


def auto(component):
    return shell(f"{component}-autostart-status").stdout.strip() == "enabled"


class DevSpaceMenu(rumps.App):
    def __init__(self):
        # 刘海屏菜单栏空间有限：只占一个字符宽度。运行状态放在菜单内容里，
        # 不再把 DevSpace/Cloudflare 两个状态塞进标题。
        super().__init__("◆", quit_button=None)
        self.timer = rumps.Timer(self.refresh, 15)
        self.timer.start()
        self.refresh()

    def refresh(self, _=None):
        ds, cf, detail = status()
        da, ca = auto("devspace"), auto("cloudflared")
        self.title = "◆" if (ds and cf) else ("◇" if not (ds or cf) else "◈")
        menu = [
            rumps.MenuItem(f"DevSpace：{'运行中' if ds else '已停止'} / 自启动{'开' if da else '关'}"),
            rumps.MenuItem(f"Cloudflare Tunnel：{'运行中' if cf else '已停止'} / 自启动{'开' if ca else '关'}"),
            None,
        ]
        dsm = rumps.MenuItem("DevSpace 服务")
        if ds:
            dsm.add(rumps.MenuItem("停止", callback=lambda _: action(["stop-devspace"], "停止 DevSpace", self.refresh)))
            dsm.add(rumps.MenuItem("重启", callback=lambda _: action(["restart-devspace"], "重启 DevSpace", self.refresh)))
        else:
            dsm.add(rumps.MenuItem("启动", callback=lambda _: action(["start-devspace"], "启动 DevSpace", self.refresh)))
        dsm.add(None)
        dsm.add(rumps.MenuItem("关闭开机自启动" if da else "开启开机自启动",
            callback=lambda _: action(["disable-devspace-autostart" if da else "enable-devspace-autostart"], "更新 DevSpace 自启动", self.refresh)))
        menu.append(dsm)

        cfm = rumps.MenuItem("Cloudflare Tunnel")
        if cf:
            cfm.add(rumps.MenuItem("停止", callback=lambda _: action(["stop-cloudflared"], "停止 Cloudflare Tunnel", self.refresh)))
            cfm.add(rumps.MenuItem("重启", callback=lambda _: action(["restart-cloudflared"], "重启 Cloudflare Tunnel", self.refresh)))
        else:
            cfm.add(rumps.MenuItem("启动", callback=lambda _: action(["start-cloudflared"], "启动 Cloudflare Tunnel", self.refresh)))
        cfm.add(None)
        cfm.add(rumps.MenuItem("关闭开机自启动" if ca else "开启开机自启动",
            callback=lambda _: action(["disable-cloudflared-autostart" if ca else "enable-cloudflared-autostart"], "更新 Cloudflare 自启动", self.refresh)))
        menu.append(cfm)

        both = rumps.MenuItem("整套服务")
        both.add(rumps.MenuItem("全部启动", callback=lambda _: action(["start"], "启动整套服务", self.refresh)))
        both.add(rumps.MenuItem("全部停止", callback=lambda _: action(["stop"], "停止整套服务", self.refresh)))
        both.add(rumps.MenuItem("全部重启", callback=lambda _: action(["restart"], "重启整套服务", self.refresh)))
        menu.extend([both, None])

        roots = rumps.MenuItem("管理工作目录…", callback=self.manage_roots)
        menu.extend([roots,
                     rumps.MenuItem("打开 ChatGPT 卡片清理扩展目录", callback=self.open_card_cleaner),
                     rumps.MenuItem("导出配置…", callback=self.export_config),
                     rumps.MenuItem("导入配置…", callback=self.import_config),
                     rumps.MenuItem("查看详细状态…", callback=lambda _: rumps.alert("DevSpace 状态", detail[-3000:])),
                     None,
                     rumps.MenuItem("退出菜单栏", callback=lambda _: rumps.quit_application())])
        self.menu.clear()
        self.menu.update(menu)

    def manage_roots(self, _):
        result = shell("roots-scan")
        if result.returncode != 0:
            rumps.alert("扫描失败", result.stderr or result.stdout)
            return
        candidates = [x for x in result.stdout.splitlines() if x.strip()]
        selected = set(shell("roots-list").stdout.splitlines())
        if not candidates:
            rumps.alert("管理工作目录", "没有扫描到 Git 仓库。")
            return

        # rumps 没有多选列表控件。用一个真正的 Cocoa 窗口显示可滚动 checkbox，
        # 用户一次勾选后点“保存”，而不是旧版需要再打开菜单才能看到子项。
        self.show_roots_window(candidates, selected)

    def show_roots_window(self, candidates, selected):
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
        action(["restart-devspace"], "应用工作目录", self.refresh)

    def toggle_root(self, path):
        selected = set(shell("roots-list").stdout.splitlines())
        cmd = "roots-remove" if path in selected else "roots-add"
        result = shell(cmd, path)
        if result.returncode != 0:
            rumps.alert("更新工作目录失败", result.stderr or result.stdout)
        else:
            action(["restart-devspace"], "应用工作目录", self.refresh)

    def add_other_root(self, _):
        window = rumps.Window("输入要允许的目录绝对路径", "添加工作目录", default_text=str(HOME) + "/")
        response = window.run()
        if response.clicked and response.text.strip():
            result = shell("roots-add", response.text.strip())
            if result.returncode == 0:
                action(["restart-devspace"], "应用工作目录", self.refresh)
            else:
                rumps.alert("添加失败", result.stderr or result.stdout)

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
            action(["import", response.text.strip()], "导入配置", lambda: action(["install"], "应用导入配置", self.refresh))


if __name__ == "__main__":
    DevSpaceMenu().run()
