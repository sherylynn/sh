# Handoff：容器重启后恢复 Termux:X11 前台与 noVNC 远程分辨率

日期：2026-09-12

## 一、当前结论和唯一剩余目标

用户已经真机确认：**NewHome/XFCE 托盘触发的容器重启功能已经完美解决**。重启后 chroot、XFCE4、x11vnc 和 noVNC 都能重新启动。后续不要再调查或重写容器重启控制协议，也不要恢复触发文件、watchdog 或剪贴板控制消息等旧方案。

当前唯一剩余问题是：

> NewHome 发起整体重启后，Termux:X11 的 X server 进程虽然已经运行，但 Termux:X11 Android Activity 似乎没有被可靠地拉到前台或恢复到可处理偏好变更的状态。noVNC 能收到浏览器的远程调整大小请求，内部适配层也执行了分辨率应用流程，但 X framebuffer 仍停留在 `1280x1024`。

目标是让用户从托盘重启容器后：

1. Termux:X11 Activity 被可靠启动并切到前台；
2. XFCE4、x11vnc、noVNC 继续自动恢复；
3. noVNC 的“远程调整大小”能够再次把任意浏览器视口尺寸应用到 Termux:X11；
4. 不破坏已经验收通过的重启、Unicode 剪贴板、麦克风桥、显示托盘和 noVNC 稳定性。

## 二、不要回退的已完成工作

### 1. NewHome 持有容器重启生命周期

当前正确调用链：

```text
XFCE 托盘
  -> /root/sh/termux/chroot/newhome_control.py restart
  -> Android abstract Unix socket @newhome_control_v1
  -> NewHome LinuxControlBridge
  -> NewHome 自身获得 root
  -> su -M 进入 Android 全局 mount namespace
  -> 切换到 Termux UID
  -> /data/data/com.termux/files/home/sh/termux/chroot/termux_all_in_one.sh restart
```

关键文件：

```text
/root/newhome/app/src/main/java/com/example/customlauncher/audio/LinuxControlBridge.kt
/root/sh/termux/chroot/newhome_control.py
/root/sh/win-git/xfce_display_tray.py
/root/sh/docs/NEWHOME_LINUX_INTEGRATION.md
```

架构约束：

- 控制通道只能使用受 `SO_PEERCRED` 保护的 `@newhome_control_v1`；
- 当前仅允许 chroot root UID 连接；
- 只允许 `PING`、`RESTART` 白名单命令；
- 不恢复 `4716/tcp`、重启触发文件或 Termux watchdog；
- 不把控制命令塞入 `4715` 剪贴板协议；
- 用户已经确认重启动作本身成功，下一窗口不要重复修这一层。

### 2. noVNC 随重启自动恢复已经解决

此前重启后只有 x11vnc 留下，noVNC 没有启动。根因是 rc3 服务异步启动时，`server_noVNC.sh` 仍继承短生命周期的 NewHome/Termux 控制管道；脚本执行完 x11vnc 后可能在继续输出状态时终止，还未执行到底部的 noVNC 启动段。

现在已经改为：

- `/etc/init.d/noVNC` 从入口就用 `nohup + setsid` 脱离完整的 `server_noVNC.sh`；
- `novnc_proxy` 自身也使用独立 session；
- 使用 PID 文件和精确进程特征停止；
- 写入独立启动日志。

对应代码：

```text
/root/sh/win-git/init_d_noVNC.sh
/root/sh/win-git/server_noVNC.sh
```

对应日志：

```text
/root/.vnc/server-noVNC-startup.log
/root/.vnc/novnc-proxy.log
/root/.vnc/x11vnc.log
```

2026-09-12 00:41 的最近一次用户重启后已验证：

- `termux-x11 :1` 存活；
- `xfce4-session` 存活；
- `x11vnc :5900` 存活；
- `novnc_proxy/newhome_websockify.py :10086` 存活；
- `https://127.0.0.1:10086/vnc.html` 返回 HTTP 200；
- `server-noVNC-startup.log` 明确记录 `x11vnc 已成功启动` 和 `noVNC 已成功启动`。

因此下一窗口不要再把问题归因于 noVNC 没有随容器重启启动。

### 3. noVNC/Unicode 剪贴板已稳定

浏览器与 Linux 之间的中文剪贴板已经走纯 RFB UTF-8 路径并由用户确认可用。不要重新增加 HTTP clipboard side channel，也不要让 `x11vnc_remote_resize.so` hook X11 selection API。

相关完整约束见：

```text
/root/sh/docs/NEWHOME_LINUX_INTEGRATION.md
/root/sh/docs/handoff_newhome_clipboard_bridge.md
```

## 三、当前仓库基线

写入本文档前，三个仓库均为干净工作树，并与各自远端分支同步；写入后 `/root/sh` 只新增了本 handoff 文件：

```text
/root/sh
  branch: master
  HEAD: 259f0f0 修复novnc启动
  remote: http://github.com/sherylynn/sh

/root/newhome
  branch: main
  HEAD: 0ea7e6b 增加容器调整功能
  remote: https://github.com/sherylynn/newhome

/root/tools/noVNC
  branch: master
  HEAD: 5db93e5 fix: complete local Unicode clipboard integration
  origin: https://github.com/sherylynn/noVNC.git
  upstream: https://github.com/novnc/noVNC.git
```

开始工作前重新检查状态，保留用户后来产生的任何修改。

## 四、已有运行态证据

### 1. 浏览器请求已经到达，不是 noVNC 没发送

`/tmp/x11vnc-remote-resize.log` 在最近一次重启后包含：

```text
adapter=loaded framebuffer=1280x1024
request=2472x1429 ... dpi=192 mode=resize ...
apply-profile=2472x1429 dpi=192 scale=2
request=1280x1024 ... mode=remote ...
```

这证明：

```text
noVNC 浏览器
  -> RFB SetDesktopSize
  -> x11vnc_remote_resize.so
  -> noVNC_remote_profile.sh
  -> xfce4-scaling.sh --remote-resize
```

至少已经运行到 `apply-profile`。不要再优先修改 noVNC canvas、本地缩放或 HiDPI 尺寸计算。

### 2. X framebuffer 实际没有切换

同一时刻只读检查：

```text
DISPLAY=:1 xrandr
Screen 0: current 1280 x 1024
```

也就是说，适配层收到 `2472x1429` 后，最终 framebuffer 仍为 `1280x1024`。当前故障点在 Termux:X11 偏好变更被接收/应用的末端，而不是浏览器请求入口。

### 3. Activity 前台状态尚未被可靠证明

从 Debian chroot 直接执行 `/system/bin/dumpsys` 没有拿到 Activity 明细。随后直接执行 `su -M` 实际调用的是 Debian 的 util-linux `su`，它不支持 KernelSU 的 `-M`；这条探测方式无效，不能据此判断 Activity 状态。

下一窗口应从以下任一真实 Android/Termux 上下文取证：

- ADB root/shell；
- Termux 宿主 shell；
- 通过正在运行的 `termux-x11` 进程的 `/proc/<pid>/root` 进入宿主环境；
- NewHome 已持有的 Android root 进程，但不要扩大为任意命令控制接口。

需要记录：

```text
dumpsys activity activities 中的 mResumedActivity/topResumedActivity
dumpsys window 中的 mCurrentFocus/mFocusedApp
am start -W 的完整 stdout、stderr 和退出状态
```

不要再使用 `2>/dev/null || true` 后声称 Activity 已成功拉起。

## 五、最值得优先验证的代码差异

当前实际重启入口是：

```text
/root/sh/termux/chroot/termux_all_in_one.sh restart
```

其中 chroot 版 `start_x11()` 当前顺序是：

```text
1. kill 旧 termux-x11 / Termux:X11 App
2. clean_tmp
3. am start com.termux.x11/com.termux.x11.MainActivity
4. termux-x11 :1 -ac +extension DPMS -dpi 100 &
5. 固定 sleep 2
6. 启动 chroot 和 rc3 服务
```

这里暴露出两个需要在 chroot 真机上验证的风险点，尚不能直接认定为根因：

1. **Activity 在 X server 之前启动**；Activity 可能打开时找不到可连接的 `:1`，之后没有再次显式拉前台。
2. `am start` 的输出被丢弃，并且 `|| true` 会把 Android 拒绝后台启动、组件启动失败或超时全部伪装成成功。

仓库中还存在一份由 AI 针对 **proot 环境**重写的实现：

```text
/root/sh/termux/chroot/proot_all_in_one.sh
```

其 `start_x11()` 采用：

```text
1. 清理旧进程/Activity
2. 启动 termux-x11 :1，并把输出写日志
3. 等待 X server 稳定
4. am start Termux:X11 MainActivity
5. 再等待 Activity
6. 重新获取 termux-wake-lock
```

但这份 proot 实现的进程权限、mount namespace、runit 管理方式和生命周期都可能与当前 rooted chroot 不同，**它没有经过当前 chroot 场景验证，不是权威实现，也不能直接复制到 chroot**。它只能提示“启动 Activity 与 X server 的先后顺序值得验证”。

下一窗口第一优先级应是从当前 chroot 的真实日志、Termux:X11 行为和 Android Activity 状态独立确认原因，再决定是否调整顺序，而不是把 proot 代码当作正确答案，也不是继续改 noVNC。

## 六、建议的调查和修复顺序

### Phase 1：先建立可观测性，不重写架构

在 `termux_all_in_one.sh::start_x11()` 为每一步留下持久日志，至少包括：

- kill/stop 旧 Activity 的结果；
- `termux-x11 :1` 的 PID 和启动日志；
- `/tmp/.X11-unix/X1` 是否出现；
- X server 是否能接受连接；
- `am start -W --user 0 -n com.termux.x11/com.termux.x11.MainActivity` 的完整结果；
- Activity 是否成为 resumed/current focus；
- wake lock 是否重新获得。

不要只增加更长的盲目 `sleep`。应等待 X socket/进程达到明确条件，并给出有限超时与真实失败状态。

### Phase 2：基于 chroot 实测确定可靠启动顺序

只有 Phase 1 证明 Activity 提前启动确实导致问题后，才尝试把 chroot 版调整为：

```text
clean old state
  -> start termux-x11 :1
  -> wait until X server is ready
  -> start/bring Termux:X11 MainActivity to front
  -> verify resumed/focus state
  -> acquire wake lock
  -> start chroot rc3 services
```

这只是待验证假设，不是预定方案。若日志表明根因是 Android 后台 Activity 启动限制、Activity 已启动但 Surface 未恢复、X socket 就绪判断错误，或 Termux:X11 preference receiver 的状态问题，应按证据修对应层，不能为了“对齐 proot”而机械改序。

实现时严格保留 chroot 与 proot 的边界：

- 用户当前 NewHome 重启桥明确调用 `termux_all_in_one.sh`；
- 不要误改成 ruri；
- `proot_all_in_one.sh` 是独立的 proot 实现，不代表 chroot 设计；
- 不要把当前修复只写进 `proot_all_in_one.sh`；
- 不要为了复用代码贸然抽取 chroot/proot 公共启动函数；两者只有分别验证后才能共享逻辑。

### Phase 3：若 Termux UID 的 `am start` 被 Android 后台启动策略拒绝

只有拿到 `am start -W`/ActivityTaskManager 的明确拒绝证据后，再考虑把“最后拉起 Termux:X11 Activity”放到 NewHome 已持有的 root 外层进程中。

当前 `LinuxControlBridge.buildRootRestartCommand()` 最后使用：

```text
exec su -M <TERMUX_UID> -c "... termux_all_in_one.sh restart"
```

由于使用 `exec`，Termux 脚本完成后不会回到外层 root shell。若确实需要 Android root 在重启完成后执行 `am start -W`，可以评估改为：

```text
su -M <TERMUX_UID> -c "... termux_all_in_one.sh restart"
restart_rc=$?
以 Android root 上下文显式拉起 Termux:X11 Activity
保留并返回 restart_rc/foreground_rc
```

但这只是第二方案，不能在没有后台启动限制证据时直接扩大 NewHome 的职责。仍然禁止开放任意 shell 控制命令。

### Phase 4：验证分辨率闭环

Activity 前台恢复后，在 noVNC 使用“远程调整大小”并切换浏览器窗口/全屏，验证：

1. `/tmp/x11vnc-remote-resize.log` 收到目标尺寸；
2. `xfce4-scaling.sh` 发出的 `com.termux.x11.CHANGE_PREFERENCE` 有明确 `Done` 结果；
3. `DISPLAY=:1 xrandr` 在超时内变成相同尺寸；
4. x11vnc framebuffer 随 XRandR 更新；
5. noVNC 不断开、不变成居中小画面、不重复放大；
6. Mac、Windows、Linux 浏览器的本地缩放和远程调整模式都不回归。

## 七、现有分辨率链路，不要重复发明

关键文件：

```text
/root/sh/win-git/x11vnc_remote_resize.c
/root/sh/win-git/noVNC_remote_profile.sh
/root/sh/win-git/xfce4-scaling.sh
/root/sh/win-git/server_noVNC.sh
/root/sh/win-git/noVNC_hidpi.patch
/root/sh/win-git/noVNC_firefox_clipboard.patch
```

现有工作方式：

- noVNC 通过 RFB `SetDesktopSize` 发送浏览器尺寸；
- preload 适配层读取 NewHome 自定义 flags 中的 DPI、render scale 和模式；
- `noVNC_remote_profile.sh` 合并密集 resize 请求；
- `xfce4-scaling.sh --remote-resize` 通过有序广播调用：

```text
com.termux.x11.CHANGE_PREFERENCE
displayResolutionMode:custom
displayResolutionCustom:<WIDTH>x<HEIGHT>
displayScale:100
```

- 脚本随后用 `xrandr` 等待 framebuffer 真正切换。

这套链路之前已在 Termux:X11 Activity 正常时工作。当前先修 Activity/X server 生命周期，不要绕过它另造一套 xrandr modeline，也不要直接修改 apt 安装的 x11vnc。

## 八、验收清单

必须由用户操作真实重启做最终验收；Agent 不要在未告知用户时主动重启容器或关闭 Codex。

### 重启主路径

- XFCE 托盘“重启 chroot 容器”能成功；
- NewHome 返回已接受重启；
- Termux:X11 Activity 自动出现在前台；
- XFCE 桌面恢复；
- x11vnc、noVNC 自动恢复；
- `https://127.0.0.1:10086/vnc.html` 可访问。

### 远程分辨率

- noVNC 远程调整模式能应用任意浏览器视口尺寸；
- 全屏、退出全屏、窗口拖动后尺寸均正确；
- `xrandr` 与浏览器请求最终一致；
- 画布不会居中缩小或过度放大；
- x11vnc 不闪退，noVNC 可持续重连。

### 回归项

- 托盘预设和自定义分辨率仍可用；
- 单独调整 Linux DPI/缩放仍可用；
- 中英文和 emoji 剪贴板保持双向；
- macOS Command+C/V 到 Linux Ctrl+C/V 映射不回归；
- NewHome 麦克风开关和按需录音不受影响；
- 麦克风关闭时控制桥和剪贴板仍运行；
- 全新 `install_proot` 部署仍能安装显示托盘、noVNC 适配和 NewHome 音频桥。

## 九、交接原则

1. 用户已确认重启问题完美解决，不要为了 Termux:X11 前台问题回滚重启实现。
2. 当前 noVNC 已启动且已发送 resize 请求，不要再从浏览器渲染算法开始兜圈子。
3. 先保留并检查真实错误输出，再修改启动顺序。
4. proot 的 AI 重写实现只能作为非权威线索，不能代替 chroot 实测或直接照搬。
5. 构建/安装不等于用户验收；最后一次容器重启、Activity 前台和跨设备 resize 必须由用户确认。
6. 若修改代码，先验证当前三个仓库仍干净，再只提交与本问题相关的文件。
