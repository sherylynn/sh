# NewHome ↔ Linux/chroot 集成架构约束

本文档定义 `newhome`、`sh`、`noVNC` 三个仓库之间的 Linux 集成边界。后续 AI / harness 修改相关代码时，应优先保持这些不变量；除非先明确证明现有设计无法满足需求，否则不要重新引入跨层轮询、触发文件或剪贴板协议复用。

## 1. 总体原则：NewHome 是 Android 边界上的唯一桥

chroot 自己不能可靠地完成“杀掉并重新启动自身”这类生命周期操作。需要跨越 chroot 生命周期的动作，由 NewHome 接收请求并在 Android 侧持有执行权。

当前职责划分：

- `4714/tcp`：可选 Linux 麦克风流。
- `4715/tcp`：**只负责剪贴板文本传输**，协议为 UTF-8 + Base64 的 `GET / SET / WATCH / PING`。
- `@newhome_control_v1`：Android/Linux abstract Unix-domain socket，负责受控生命周期操作。
  - NewHome 使用 `SO_PEERCRED` 校验调用方。
  - 当前只允许 UID 0（root chroot）连接。
  - 当前白名单命令只有 `PING`、`RESTART`。
  - 不允许透传任意 shell 命令。

禁止重新建立 `4716/tcp` 的特权控制端口；Android loopback 是同机 App 共享的，不足以作为 root 操作的访问控制。

## 2. 容器重启：禁止触发文件和 Termux watchdog

正确路径：

```text
root chroot
  -> /root/sh/termux/chroot/newhome_control.py restart
  -> abstract socket @newhome_control_v1
  -> NewHome LinuxControlBridge
  -> NewHome 自身申请 root
  -> root 持有外层进程
  -> 切换到 Termux UID
  -> termux_all_in_one.sh restart
```

关键点：NewHome 在返回 `OK RESTARTING` 前已经创建 Android 侧 root-owned restart 进程。此后 chroot 被 stop、发起请求的 shell 消失，都不会中断外层重启执行者。

**禁止恢复以下旧设计：**

- `/root/.container_restart_request`
- `$CHROOT_DIR/root/.container_restart_request`
- `.processing` 触发文件
- `cli.sh watchdog` / `watchdog_chroot_restart`
- Termux 常驻轮询 restart request
- 把 `CTRL RESTART` 或任何控制消息塞进 4715 `WATCH` 剪贴板流
- 由 XFCE 托盘直接写重启文件

XFCE 托盘的“重启 chroot 容器”入口必须调用 `newhome_control.py restart`，不能自己管理容器生命周期。

## 3. 剪贴板：NewHome ClipboardManager 是 Android 唯一真源

Android 侧已有：

`newhome/app/src/main/java/com/example/customlauncher/ime/ximekb/clipboard/ClipboardManager.kt`

它负责系统剪贴板监听、历史、置顶、最近、快速发送等。`LinuxClipboardBridge` 只是传输适配器。

**禁止：**

- 新建第二套 Android ClipboardManager。
- 新注册一套独立 Android system clipboard listener/history。
- 让 Linux/VNC 维护与 NewHome 相互独立的 Android 剪贴板状态。

Linux 侧唯一合并点是 X11 `CLIPBOARD`：

`sh/termux/chroot/newhome_clipboard_bridge.py`

它通过 `xclip` 把 NewHome 4715 与 X11 双向同步。

## 4. Unicode / 中文：不要再 hook X11 selection API

此前为了 UTF-8 修改 x11vnc preload、拦截 `XConvertSelection` / `XChangeProperty` / `UTF8_STRING`，曾导致原本工作的双向复制一起失效。该方案已经撤销。

`x11vnc_remote_resize.so` 的职责只能是远程 resize / HiDPI 适配，不应承担剪贴板字符集转换。

当前策略：

### 浏览器 -> Linux

- ASCII 与非 ASCII / Unicode 使用同一条 RFB clipboard 路径。
- noVNC 把文本编码为 UTF-8 bytes，再发送经典 `ClientCutText`；支持 Extended Clipboard 时继续使用协议原有的 UTF-8 路径。
- x11vnc 把收到的 bytes 写入 X11 `CLIPBOARD`。
- 不再使用 `/newhome-clipboard` HTTP side channel，也不让浏览器直接调用 NewHome 4715。
- 4715 只负责同机 Android/NewHome 与 X11 之间的 UTF-8 + Base64 同步。

### Linux -> 浏览器

x11vnc 的 legacy `ServerCutText` 可能把 UTF-8 原始字节当成 8-bit 字符串传递。修复放在 noVNC `AsyncClipboard` 层：

- 仅对全体 code point <= 0xff 的非 ASCII 字符串尝试重新解释为原始字节。
- 使用 strict/fatal UTF-8 解码。
- 解码失败则原样保留，因此真正 Latin-1（例如单字节 `é`）不会被误改。
- 不修改 RFB 状态机，也不修改 X11 selection 状态机。

## 5. 麦克风开关不得控制基础桥生命周期

“Linux 麦克风桥”只是 `4714` 的录音功能开关。

即使麦克风关闭：

- 4715 剪贴板仍应运行。
- `@newhome_control_v1` 控制桥仍应运行。
- `termux/newhome_mic_bridge.sh stop` 只能停止麦克风 client / PulseAudio source，不得停止 `newhome_clipboard_bridge.py`。

NewHome 基础 Linux Integration service 在未录音时不应冒充 microphone foreground service；当前 `targetSdk=33` 下使用 `FOREGROUND_SERVICE_TYPE_NONE`，真正开始 AudioRecord 时再切换为 `FOREGROUND_SERVICE_TYPE_MICROPHONE`。

> 若未来 targetSdk 升到 Android 14 / API 34 或更高，需要重新审视 foreground service type；不要直接继续依赖 `TYPE_NONE`。

## 6. 手工验证

安装最新 NewHome、拉取最新 `sh` / `noVNC` 后：

### 控制桥

```bash
python3 /root/sh/termux/chroot/newhome_control.py ping
```

预期：

```text
NewHome control bridge: OK
```

重启：

```bash
python3 /root/sh/termux/chroot/newhome_control.py restart
```

首次使用时 KernelSU / APatch / Magisk 可能弹出 NewHome root 授权。NewHome 必须直接获得 root 授权，不要改成给 Android shell UID 授权后再绕回 NewHome。

### 中文剪贴板

浏览器 -> Linux：复制包含中文和 emoji 的文本，例如：

```text
中文剪贴板🙂 UTF-8
```

在 noVNC 中 Cmd/Ctrl+V，然后在 Linux 查看：

```bash
xclip -selection clipboard -out
```

Linux -> 浏览器：

```bash
printf 'Linux中文🙂 UTF-8' | xclip -selection clipboard -in
```

随后在控制端系统中粘贴，内容应保持 Unicode 原样。

同时回归纯 ASCII 文本，确认原 RFB 双向路径没有被 Unicode 修复破坏。

### 麦克风关闭场景

关闭 NewHome 的 Linux 麦克风功能后仍应满足：

```bash
python3 /root/sh/termux/chroot/newhome_control.py ping
xclip -selection clipboard -out
```

控制和剪贴板正常，只有 4714 录音被拒绝/关闭。

## 7. 修改前检查清单

涉及 Linux 集成的后续改动至少检查：

1. 是否把控制命令误塞回 4715？若是，停止。
2. 是否重新引入触发文件/watchdog？若是，停止。
3. 是否新建第二套 Android clipboard 状态？若是，停止。
4. 是否 hook x11vnc 的 X11 clipboard/selection API 来修 Unicode？若是，停止。
5. 是否让麦克风开关停止 4715 或 control socket？若是，停止。
6. 是否对 privileged control 开放任意 shell command？若是，停止。
7. Unicode 修复失败时，ASCII/RFB 原路径是否仍能工作？必须保留回退。
8. 浏览器与 Linux 之间是否重新引入 `/newhome-clipboard` side channel？若是，停止；该链路只能走 RFB。
