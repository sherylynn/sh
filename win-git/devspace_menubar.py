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
        super().__init__("DS", quit_button=None)
        self.timer = rumps.Timer(self.refresh, 15)
        self.timer.start()
        self.refresh()

    def refresh(self, _=None):
        ds, cf, detail = status()
        da, ca = auto("devspace"), auto("cloudflared")
        self.title = f"DS {'●' if ds else '○'} CF {'●' if cf else '○'}"
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
            rumps.alert("扫描失败", result.stderr)
            return
        candidates = [x for x in result.stdout.splitlines() if x.strip()]
        selected = set(shell("roots-list").stdout.splitlines())

        # Cocoa/rumps has no native multi-checkbox dialog. Present each discovered
        # repository as a submenu toggle, then persist immediately on click.
        submenu = rumps.MenuItem("工作目录（点击切换）")
        for path in candidates:
            mark = "✓ " if path in selected else "   "
            submenu.add(rumps.MenuItem(mark + path, callback=lambda _, p=path: self.toggle_root(p)))
        submenu.add(None)
        submenu.add(rumps.MenuItem("选择其他目录…", callback=self.add_other_root))
        self.menu["管理工作目录…"].clear()
        for item in submenu.values():
            self.menu["管理工作目录…"].add(item)
        rumps.notification("DevSpace", "工作目录", "扫描完成；再次点击“管理工作目录…”查看并勾选")

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
