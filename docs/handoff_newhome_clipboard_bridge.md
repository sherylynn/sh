# NewHome ↔ chroot/X11 ↔ noVNC 剪贴板桥

## 目标

让 Android 系统剪贴板、Debian chroot 的 X11 `CLIPBOARD`、以及 x11vnc/noVNC 控制端共享同一份**文本剪贴板**状态，并且不依赖 Termux:X11 Activity 保持前台。

数据链路：

```text
Android system clipboard
        ↕
NewHome foreground Linux integration service
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

X11 `CLIPBOARD` 是唯一 Linux 汇合点。不要另外给 noVNC 做一套 Android 专用协议；x11vnc 已负责 RFB clipboard 与 X selection 的交换。

## Android / NewHome

NewHome 现有 `LinuxMicrophoneBridgeService` 被扩展成 Linux 集成服务：

- `127.0.0.1:4714`：原有按需麦克风 PCM。
- `127.0.0.1:4715`：新增文本剪贴板。
- 两个端口只监听 loopback，不暴露到 Wi-Fi/LAN。
- 复用一个 foreground service，不新增第二个常驻通知。
- 当前仍使用 NewHome 的 `linux_microphone_bridge_enabled` 授权开关，因此关闭 Linux 麦克风桥也会关闭剪贴板桥。

4715 协议：

```text
server: HELLO NEWHOME_CLIPBOARD 1
client: GET
server: CLIP <base64-utf8> | EMPTY

client: SET <base64-utf8>
server: OK | ERR ...

client: WATCH
server: OK WATCH
server: CLIP <base64-utf8> | EMPTY
... Android clipboard changes continue on the same socket ...

client: PING
server: PONG
```

第一版只同步文本，单个 payload 上限 1 MiB。文件、图片、URI/Intent 不进入该协议，避免无意扩大权限和兼容面。

## chroot / Linux

`termux/chroot/newhome_clipboard_bridge.py`：

- Android → Linux：持久 `WATCH` 连接，有 Android 新剪贴板就写入 `xclip -selection clipboard`。
- Linux → Android：约 350ms 读取一次 X11 `CLIPBOARD`，发生变化时发 `SET`。
- 用内容去重避免 Android → X11 → Android 的回环。
- NewHome 服务断开时自动重连。
- `/tmp/newhome-clipboard-bridge.lock` 保证单实例，因此 XFCE autostart 和安装脚本的即时启动可以同时存在。
- 日志：`/tmp/newhome-clipboard-bridge.log`。

`debian/termux_chroot_desktop_setup.sh` 会：

1. 安装 `xclip`。
2. 安装 `~/.config/autostart/newhome-clipboard-bridge.desktop`。
3. 如果 XFCE 已经运行，立即拉起 bridge，不要求重新登录。

## noVNC / 浏览器说明

Linux ↔ noVNC 使用标准 RFB clipboard，不依赖浏览器 Clipboard API；因此 noVNC 自带剪贴板面板始终可以作为显式中转。

浏览器系统剪贴板能否“无感”读写仍由浏览器安全策略决定：HTTPS/localhost、Clipboard API 权限和 user activation 都可能影响 Windows/Linux/macOS 上的体验。这个限制与 Android ↔ chroot 桥无关。

因此链路分两层：

- **一定存在的传输层**：RFB clipboard ↔ X11 ↔ NewHome ↔ Android。
- **浏览器自动系统剪贴板层**：能用 Clipboard API 时自动；不能用时通过 noVNC clipboard UI 或后续用户手势辅助功能触发。

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

Android 日志 tag：`LinuxClipboardBridge`。

## 安全边界

- 4715 只监听 `127.0.0.1`。
- 只允许文本，最大 1 MiB。
- 任何进入 X11 `CLIPBOARD` 的文本（包括来自 VNC/noVNC 的文本）都可能同步到 Android 系统剪贴板，这是本功能的明确设计目标。
- 不把剪贴板端口暴露给 LAN，不在日志中记录具体剪贴板内容。
