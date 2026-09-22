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
3. **渲染必须自己兜异常**：`callAfter` 最终落到 PyObjCMessageRunner.performCall()，
   那里没有 try/except，异常穿过 ObjC 主循环后只进 os_log，
   连 launchd 的 StandardErrorPath 都拿不到（实测 menubar.log 恒为 0 字节）。
   而 render() 一旦抛异常，`menu.clear()/update()` 就没执行过 —— NSStatusItem
   挂着一个**空 NSMenu**，点图标什么都不弹，且没有任何提示。
   所以：渲染异常要写盘 + 标题变 ⚠ + 菜单里显示原因；状态跃迁也记一行日志。
"""

import os
import subprocess
import sys
import threading
import time
import traceback
import unicodedata
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

# 必须与 devspace.sh 里 MENUBAR_LAUNCH_AGENT_FILE 的 Label 保持一致。
MENUBAR_LABEL = "win.sherylynn.devspace-menubar"

LOG_PATH = Path(os.environ.get("DEVSPACE_MENUBAR_LOG", str(HOME / ".devspace" / "menubar.log")))

_last_logged = {"title": None}


def log_line(context, exc=None):
    """追加一行到 menubar.log。

    不能指望 launchd 的 StandardErrorPath：pyobjc 的 callAfter 走
    PyObjCMessageRunner.performCall()，那里**没有** try/except，异常穿透 ObjC
    主循环后只进 os_log —— 现场就是 menubar.log 恒为 0 字节、菜单静默变空。
    """
    if exc is not None:
        detail = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    else:
        detail = traceback.format_exc() if sys.exc_info()[0] else ""
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a") as handle:
            handle.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {context}\n")
            if detail.strip():
                handle.write(detail if detail.endswith("\n") else detail + "\n")
    except OSError:
        pass


def safe_render(fn):
    """渲染异常必须变成"看得见的菜单"，绝不能变成"点了没反应"。

    现场：render() 在构造 Cloudflare 子菜单时抛 NameError，于是
    `self.menu.clear()` / `self.menu.update()` 从未执行 —— NSStatusItem 上挂着
    一个空 NSMenu，点图标毫无反应；异常又被 ObjC 主循环吞掉，日志 0 字节。
    """

    def wrapper(self, *args, **kwargs):
        try:
            result = fn(self, *args, **kwargs)
        except Exception as exc:
            log_line("render() 失败", exc)
            # 标题也要能看出坏了：空菜单 + 无提示是最糟的组合。
            self.title = "⚠"
            _last_logged["title"] = "⚠"
            self.menu.clear()
            self.menu.update([
                rumps.MenuItem("菜单渲染失败，详情见 ~/.devspace/menubar.log"),
                rumps.MenuItem(f"  {type(exc).__name__}: {exc}"[:120]),
                None,
                rumps.MenuItem("刷新状态", callback=lambda _: self.refresh_async()),
                rumps.MenuItem("退出菜单栏（关自启动）", callback=self.quit_controller),
            ])
            return None
        # 状态跃迁记一行：图标停在某个字符不动时，不用点开也知道渲染在跑。
        if _last_logged["title"] != self.title:
            log_line(f"状态跃迁 → {self.title}")
            _last_logged["title"] = self.title
        return result

    return wrapper


TUNNEL_LABEL = {
    "connected": "已连接",
    "disconnected": "未连接",
    "stopped": "已停止",
    "unknown": "状态未知",
}
# 状态本身说不清楚的部分放到下一行 —— 菜单宽度由最长的一行决定，
# 所以这里刻意用短句（原来把"进程在跑，隧道未注册"塞在同一个括号里，
# 一行 70+ 宽）。
TUNNEL_HINT = {
    "disconnected": "进程在跑，隧道未注册",
    "unknown": "读不到隧道状态",
}
SERVE_LABEL = {"running": "运行中", "stopped": "已停止"}

# 菜单最长行的显示宽度上限（CJK 记 2）。超了就是"托盘太宽"，selftest 会失败。
# 拆分前那条 Cloudflare 行是 ~78 格，现在最宽 28 格（「退出菜单栏（关闭此项自启动）」）。
MAX_MENU_WIDTH = 32


def shell(*args):
    return subprocess.run(["/bin/bash", DEVSPACE, *args], text=True, capture_output=True)


def ui(fn, *args):
    """把 UI 调用调度回主线程（后台线程直接弹窗会崩）。"""
    if AppHelper is None:  # pyobjc 缺失时兜底直调
        fn(*args)
        return
    try:
        AppHelper.callAfter(fn, *args)
    except Exception as exc:
        log_line(f"callAfter({getattr(fn, '__name__', fn)}) 调度失败", exc)


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


def display_width(text):
    """近似显示宽度：CJK/全角记 2，其余记 1。

    菜单宽度由最长的一行决定，而这个"最长"用字符数看不出来 —— 所以用它做
    selftest 断言（见 MAX_MENU_WIDTH）。
    """
    return sum(2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1 for ch in str(text))


def short_edges(edges, keep=2):
    """边缘列表截断：连上多个边缘时那一行会又长又没用。"""
    items = [x.strip() for x in (edges or "").split(",") if x.strip()]
    if not items:
        return ""
    if len(items) > keep:
        return "，".join(items[:keep]) + f" 等 {len(items)} 个"
    return "，".join(items)


def tunnel_lines(snap):
    """Cloudflare 那一段的文案，**按语义拆行**（每个 MenuItem 就是一行）。

    挤成一行的旧版是
    `Cloudflare Tunnel：已连接 Cloudflare（2 个边缘连接，lax05,lax07，http2） / 自启动开`
    —— 70+ 宽，整个菜单都被这一行撑开。菜单项不支持可靠换行，所以拆成多行。
    """
    tunnel = snap.get("tunnel", "unknown")
    auto = f"自启动{'开' if snap.get('cloudflared_autostart') else '关'}"
    lines = [f"Cloudflare Tunnel：{TUNNEL_LABEL.get(tunnel, tunnel)}"]

    if tunnel == "connected":
        detail = [f"{snap.get('tunnel_connections') or '?'} 连接"]
        if snap.get("tunnel_protocol"):
            detail.append(snap["tunnel_protocol"])
        detail.append(auto)
        lines.append("  " + " · ".join(detail))
        edges = short_edges(snap.get("tunnel_edges"))
        if edges:
            lines.append(f"  边缘 {edges}")
    else:
        hint = TUNNEL_HINT.get(tunnel)
        if hint:
            lines.append(f"  {hint}")
        lines.append(f"  {auto}")
    return lines


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
        # 先同步铺一次占位菜单：此时还在主线程，且 run() 还没把 NSMenu 挂到
        # NSStatusItem 上。这样即使后续 callAfter 调度失败，图标也一定有点得开的
        # 菜单，而不是一个空 NSMenu（空菜单 = 点了完全没反应）。
        self.render()
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
    @safe_render
    def render(self, _=None):
        snap = self.snapshot
        if not snap:
            self.title = "◌"
            menu = [
                rumps.MenuItem("正在读取状态…"),
                None,
                rumps.MenuItem("刷新状态", callback=lambda _: self.refresh_async()),
                rumps.MenuItem("退出菜单栏（关自启动）", callback=self.quit_controller),
            ]
            self.menu.clear()
            self.menu.update(menu)
            return

        serve = snap.get("serve", "stopped")
        tunnel = snap.get("tunnel", "unknown")
        # 注意：fetch_states() 往里写的是 auto() 的 bool 返回值，不是 "enabled"
        # 字符串。这里再比一次字符串会永远得到 False，自启动状态会一直显示"关"。
        da = bool(snap.get("devspace_autostart"))
        ca = bool(snap.get("cloudflared_autostart"))
        serve_up = serve == "running"

        # 一个字符表达三种状态：正常 / 有问题 / 全停
        self.title = menu_bar_title(serve, tunnel)

        # 每个语义一行：挤成一行会把整个菜单撑得很宽。
        # DevSpace 这一段本身就短（一行 ~24 宽），保持一行不再拆。
        menu = [
            rumps.MenuItem(f"DevSpace：{SERVE_LABEL.get(serve, serve)} · 自启动{'开' if da else '关'}"),
        ]
        menu.extend(rumps.MenuItem(line) for line in tunnel_lines(snap))
        if tunnel in ("disconnected", "unknown"):
            err = snap.get("tunnel_error")
            menu.append(rumps.MenuItem(f"  ⚠ {err[:60]}" if err else "  ⚠ 公网访问会失败"))
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
            rumps.MenuItem("打开卡片清理扩展目录", callback=self.open_card_cleaner),
            rumps.MenuItem("导出配置…", callback=self.export_config),
            rumps.MenuItem("导入配置…", callback=self.import_config),
            rumps.MenuItem("查看详细状态…", callback=self.show_detail),
            None,
            rumps.MenuItem("退出菜单栏（关自启动）", callback=self.quit_controller),
        ])
        self.menu.clear()
        self.menu.update(menu)

    def quit_controller(self, _):
        """退出 = 连这一项的 LaunchAgent 一起关掉。

        plist 里是 KeepAlive=true：只调 quit_application() 的话 launchd 会立刻把
        进程拉回来，图标闪一下就恢复 —— 看起来又是"点了没反应"。所以先 bootout
        自己（手动前台运行时没有这个 job，bootout 失败也无所谓）。
        """
        subprocess.Popen(["/bin/launchctl", "bootout", f"gui/{os.getuid()}/{MENUBAR_LABEL}"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        rumps.quit_application()

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


def selftest():
    """无 GUI 自检：每种隧道状态都必须渲染出非空菜单。

    这是本轮 NameError 的回归网。上一版"跑满两个刷新周期零异常"的结论是错的：
    异常被 ObjC 主循环吞了，肉眼和日志都看不到，只有把 render() 单独拎出来跑
    才暴露出来。`devspace.sh install` 之后应能一条命令验证。
    """
    import tempfile

    # 自检不要污染真实日志（render 会写"状态跃迁"行）。
    global LOG_PATH
    LOG_PATH = Path(tempfile.mkdtemp(prefix="devspace-menubar-selftest-")) / "menubar.log"

    class FakeMenu:
        def __init__(self):
            self.items = []

        def clear(self):
            self.items = []

        def update(self, menu):
            self.items = [x for x in menu if x is not None]

    class Harness(DevSpaceMenu):
        """只借真实类的绑定方法，不跑 rumps.App.__init__（那会去建 NSStatusItem）。

        注意 `menu` 是 property，赋值会转调 `self._menu.update()`，所以这里直接
        塞 `_menu`。
        """

        def __init__(self, snap):
            self._menu = FakeMenu()
            self._title = ""
            self.snapshot = snap
            self.refresh_async = lambda: None

    cases = [
        ("empty", None, "◌"),
        ("connected", {"serve": "running", "tunnel": "connected",
                       "devspace_autostart": True, "cloudflared_autostart": True,
                       "tunnel_connections": "2", "tunnel_edges": "lax05,lax07",
                       "tunnel_protocol": "http2"}, "◆"),
        ("disconnected", {"serve": "running", "tunnel": "disconnected",
                          "devspace_autostart": True, "cloudflared_autostart": False,
                          "tunnel_error": "no ready connections"}, "◐"),
        ("stopped", {"serve": "stopped", "tunnel": "stopped",
                     "devspace_autostart": False, "cloudflared_autostart": False}, "◇"),
        ("unknown", {"serve": "running", "tunnel": "unknown",
                     "devspace_autostart": False, "cloudflared_autostart": True}, "◈"),
    ]
    failures = 0
    for label, snap, expected_title in cases:
        target = Harness(snap)
        try:
            DevSpaceMenu.render(target, None)
        except Exception as exc:
            failures += 1
            print(f"FAIL  {label}: {type(exc).__name__}: {exc}")
            continue
        if target.title != expected_title:
            failures += 1
            print(f"FAIL  {label}: 标题 {target.title!r}，期望 {expected_title!r}")
            continue
        if not target.menu.items:
            failures += 1
            print(f"FAIL  {label}: 菜单为空（点图标将毫无反应）")
            continue
        widest, widest_text = 0, ""
        for item in target.menu.items:
            width = display_width(str(item.title))
            if width > widest:
                widest, widest_text = width, item.title
        if widest > MAX_MENU_WIDTH:
            failures += 1
            print(f"FAIL  {label}: 菜单最宽一行 {widest} 格（上限 {MAX_MENU_WIDTH}）：{widest_text}")
            continue
        print(f"ok    {label}: 标题 {target.title} / {len(target.menu.items)} 项 / 最宽 {widest} 格（{widest_text.strip()}）")
    print("selftest:", "FAILED" if failures else "PASSED")
    return 1 if failures else 0


def _thread_excepthook(args):
    log_line(f"线程 {args.thread.name} 崩溃", args.exc_value)


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    # 后台线程里未捕获的异常同样只进 os_log，统一落盘。
    if hasattr(threading, "excepthook"):
        threading.excepthook = _thread_excepthook
    DevSpaceMenu().run()
