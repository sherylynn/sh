# NewHome ↔ chroot/X11 ↔ noVNC 剪贴板桥

## 目标

让 Android 系统剪贴板、NewHome 输入法已有剪贴板体系、Debian chroot 的 X11 `CLIPBOARD`、以及 x11vnc/noVNC 控制端共享同一份**文本剪贴板**状态，并且不依赖 Termux:X11 Activity 保持前台。

数据链路：

```text
Android system clipboard
        ↕
NewHome ime/ximekb/clipboard/ClipboardManager
(唯一 Android 剪贴板入口：监听、历史、快速发送、图片、系统写回)
        ↕
LinuxClipboardBridge transport adapter
127.0.0.1:4715 (text/base64 protocol)
        ↕
/root/sh/termux/chroot/newhome_clipboard_bridge.py
        ↕
X11 CLIPBOARD (xclip)
        ↕
x11vnc RFB clipboard
        ↕
noVNC / native VNC client
        ↕
Windows / Linux / macOS controller
```

Android 侧的唯一真源是 NewHome **现有** `ime/ximekb/clipboard/ClipboardManager.kt`。Linux bridge 不注册第二个 Android `OnPrimaryClipChangedListener`、不维护第二份历史，也不自行调用系统 `ClipboardManager.setPrimaryClip()`；它只通过 NewHome 现有的 `getCurrentClipboardText()` / `copyToSystemClipboard()` 读写。

Linux 侧的唯一汇合点是 X11 `CLIPBOARD`。不要另外给 noVNC 做一套 Android 专用协议；x11vnc 已负责 RFB clipboard 与 X selection 的交换。

## Android / NewHome

NewHome 现有 `LinuxMicrophoneBridgeService` 被扩展成 Linux 集成服务：

- `127.0.0.1:4714`：原有按需麦克风 PCM。
- `127.0.0.1:4715`：新增文本剪贴板 transport adapter。
- 两个端口只监听 loopback，不暴露到 Wi-Fi/LAN。
- 复用一个 foreground service，不新增第二个常驻通知。
- 当前仍使用 NewHome 的 `linux_microphone_bridge_enabled` 授权开关，因此关闭 Linux 麦克风桥也会关闭剪贴板 transport。

4715 本身不是新的剪贴板数据库，只是把 NewHome 既有剪贴板能力暴露给本机 chroot：

```text
server: HELLO NEWHOME_CLIPBOARD 1
client: GET
server: CLIP <base64-utf8> | EMPTY

client: SET <base64-utf8>
server: OK | ERR ...

client: WATCH
server: OK WATCH
server: CLIP <base64-utf8> | EMPTY
... NewHome 当前系统文本剪贴板变化继续沿同一 socket 推送 ...

client: PING
server: PONG
```

第一版只同步文本，单个 payload 上限 1 MiB。文件、图片、URI/Intent 仍由 NewHome 原剪贴板能力自行管理，不通过 4715 传输，避免无意扩大协议和权限面。

### 为什么不再重复造剪贴板

NewHome 输入法已有：

- Android 系统剪贴板监听；
- 最多 1000 条文本历史；
- 最近项目；
- quick-send；
- pinned 状态；
- 图片复制；
- `copyToSystemClipboard()` / `getCurrentClipboardText()`。

因此 `LinuxClipboardBridge.kt` 只承担协议与连接管理。为了不新增第二个 Android 系统监听器，它定期通过既有 `ClipboardManager.getCurrentClipboardText()` 观察当前文本；Linux 写回则调用既有 `copyToSystemClipboard()`，历史更新仍由 NewHome 原监听链负责。

## chroot / Linux

`termux/chroot/newhome_clipboard_bridge.py`：

- Android → Linux：持久 `WATCH` 连接，有 NewHome 当前文本变化就写入 `xclip -selection clipboard`。
- Linux → Android：约 350ms 读取一次 X11 `CLIPBOARD`，发生变化时发 `SET`。
- 用内容去重避免 Android → X11 → Android 的回环。
- NewHome 服务断开时自动重连。
- `/tmp/newhome-clipboard-bridge.lock` 保证单实例，因此 XFCE autostart 和安装脚本的即时启动可以同时存在。
- 日志：`/tmp/newhome-clipboard-bridge.log`。

`debian/termux_chroot_desktop_setup.sh` 会：

1. 安装 `xclip`。
2. 安装 `~/.config/autostart/newhome-clipboard-bridge.desktop`。
3. 如果 XFCE 已经运行，立即拉起 bridge，不要求重新登录。

`termux/newhome_mic_bridge.sh start` 在存在 `DISPLAY`、`xclip` 和脚本时也会顺带确保剪贴板 bridge 已运行，因此当前 `tstart` / noVNC 启动链无需额外手工命令。

## noVNC / 浏览器说明

Linux ↔ noVNC 使用标准 RFB clipboard，不依赖浏览器 Clipboard API；因此 noVNC 自带剪贴板面板始终可以作为显式中转。

浏览器系统剪贴板能否“无感”读写仍由浏览器安全策略决定：HTTPS/localhost、Clipboard API 权限和 user activation 都可能影响 Windows/Linux/macOS 上的体验。这个限制与 Android ↔ chroot bridge 无关。

因此链路分两层：

- **稳定传输层**：RFB clipboard ↔ X11 ↔ NewHome 既有 ClipboardManager ↔ Android。
- **浏览器自动系统剪贴板层**：能用 Clipboard API 时自动；不能用时通过 noVNC clipboard UI 或后续用户手势辅助功能触发。

当前 noVNC 补丁还会捕获画布上的 `Ctrl+V` / `Cmd+V` 和右键操作：

- 键盘粘贴依赖浏览器原生 `paste` 事件，不要求程序主动读取剪贴板，可作为免安装 CA 时的降级路径。
- 右键直接获取使用 `navigator.clipboard.readText()`，必须处于浏览器认可的可信 HTTPS 环境，并可能仍需用户授予剪贴板权限。
- 私有 IP 的本地 CA 无法被全新控制端自动信任。noVNC 服务提供 `/novnc-ca.crt`，以及 `/install-noVNC-ca.sh`、`/install-noVNC-ca.ps1` 两个安装脚本。

macOS / Linux 下载三个文件后，在同一目录运行：

```bash
bash install-noVNC-ca.sh
```

Windows 当前用户安装（不要求写入整机证书库）：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-noVNC-ca.ps1
```

安装后需完全重启 Firefox。若不安装 CA，可以继续使用 `Ctrl+V` / `Cmd+V` 或 noVNC 剪贴板面板，但浏览器不会允许一次右键静默读取操作系统剪贴板。

## 部署

更新 `newhome` APK 后，确保原来的「Linux 麦克风桥」开关开启；然后 chroot 中：

```bash
cd /root/sh
git pull
bash /root/sh/debian/termux_chroot_desktop_setup.sh
```

检查：

```bash
# Linux bridge
pgrep -af newhome_clipboard_bridge.py
cat /tmp/newhome-clipboard-bridge.log

# X11 clipboard
printf 'linux-test' | xclip -selection clipboard -in
xclip -selection clipboard -out

# NewHome 4715（连接后服务器先发 HELLO）
python3 - <<'PY'
import socket
s=socket.create_connection(('127.0.0.1',4715),2)
f=s.makefile('rw')
print(f.readline().strip())
f.write('GET\n'); f.flush()
print(f.readline().strip())
PY
```

如果现有 chroot 只是 `git pull` 到新脚本，而不是全新安装，仍需执行一次
`termux_chroot_desktop_setup.sh`；否则系统可能没有 `xclip` 和 XFCE 自启动项。
`newhome_mic_bridge.sh start` 会在缺少这些依赖时输出明确提示，不再静默跳过。

Android 日志 tag：`LinuxClipboardBridge`。

## 安全边界

- 4715 只监听 `127.0.0.1`。
- 只允许文本，最大 1 MiB。
- 任何进入 X11 `CLIPBOARD` 的文本（包括来自 VNC/noVNC 的文本）都可能通过 NewHome 原有剪贴板入口同步到 Android 系统剪贴板，这是本功能的明确设计目标。
- 不把剪贴板端口暴露给 LAN，不在日志中记录具体剪贴板内容。
