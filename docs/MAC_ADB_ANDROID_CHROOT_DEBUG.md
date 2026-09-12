# macOS 通过 ADB 调试 Android Termux chroot 实战方法

本文记录 2026-09-12 在 macOS 上通过 ADB 调试 Android 设备中
Termux、KernelSU、Debian chroot、Anland、Labwc 和 wayvnc 的实测方法。

目标不是提供一条只能复制一次的长命令，而是说明各层权限、命名空间和文件视图，
以及怎样用日志、截图和最小变量实验定位图形链路问题。

## 1. 本次调试涉及的层次

```text
macOS ~/sh
   │ adb push / adb shell / screencap
   ▼
Android adbd shell
   │ su -M
   ▼
KernelSU root + 全局挂载命名空间
   ├── setpriv 降权到 Termux UID
   │      └── Anland daemon、Termux 脚本
   └── chroot /data/local/mnt
          └── Debian root、Labwc、XFCE、wayvnc、编译工具
```

这几层不能混为一谈：

- Android `shell` 用户看不到或不能访问部分 Termux 私有文件。
- 普通 Termux shell 可能位于私有 mount namespace，看不到全局 chroot 挂载。
- KernelSU 的 `su -M` 用于进入全局挂载命名空间。
- Anland 标准 APK 与 Termux 共用 UID；daemon 应当在 root 完成清理后降权到
  Termux UID 运行。
- Debian chroot 中的 root 负责 Labwc、XFCE、wayvnc 和 wlroots-anland 构建。

## 2. 设备连接与选择

优先连接局域网设备：

```bash
adb connect 192.168.1.133
adb -s 192.168.1.133 get-state
```

项目常见的其他设备地址是 `192.168.43.1`、`172.16.128.251`。网络 ADB
不可用时使用 USB 序列号：

```bash
adb -s 7bfbd0a6 get-state
```

始终显式传入 `-s`，避免多台设备在线时把命令发到错误设备。

## 3. 验证 KernelSU 与 mount namespace

先做只读检查：

```bash
adb -s 192.168.1.133 shell 'su -M -c "id; readlink /proc/self/ns/mnt; readlink /proc/1/ns/mnt"'
```

预期 UID 为 0，并能访问 `/data/local/mnt`。检查 chroot 是否已挂载：

```bash
adb -s 192.168.1.133 shell \
  'su -M -c "mount | grep /data/local/mnt | head"'
```

不要在不带 `-M` 的 Termux 私有命名空间中建立长期 chroot 挂载，否则后续
Android Activity、ADB root 和桌面进程可能看到不同的 `/tmp` 与 socket。

## 4. 获取 Termux UID 并安全降权

不要把 UID 永久写死在通用脚本中。可从 Termux 数据目录读取：

```bash
adb -s 192.168.1.133 shell \
  'su -M -c "stat -c %u /data/data/com.termux"'
```

本次设备得到的是 `10451`。以该 UID 运行 Termux 程序的结构如下：

```bash
adb -s 192.168.1.133 shell 'su -M -c \
  "/data/data/com.termux/files/usr/bin/setpriv \
   --reuid=10451 --regid=10451 --clear-groups \
   env HOME=/data/data/com.termux/files/home \
       PREFIX=/data/data/com.termux/files/usr \
       TMPDIR=/data/data/com.termux/files/usr/tmp \
       PATH=/data/data/com.termux/files/usr/bin:/system/bin \
       /data/data/com.termux/files/usr/bin/bash SCRIPT ARG"'
```

原则是：

1. 用 KernelSU root 清理旧的 root daemon、Activity 和 socket。
2. 再通过 Termux 自带的 `setpriv` 降权。
3. 显式提供 `HOME/PREFIX/TMPDIR/PATH`，不要依赖 Android root 的环境。
4. 不使用 login shell，避免历史 profile 再次提权或覆盖图形变量。

## 5. 进入 Debian chroot

在全局 namespace 中执行：

```bash
adb -s 192.168.1.133 shell \
  'su -M -c "chroot /data/local/mnt /bin/bash --noprofile --norc"'
```

自动化命令必须显式设置 Debian PATH：

```bash
chroot /data/local/mnt /bin/bash --noprofile --norc -c \
  'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
   ps -ef'
```

否则 chroot 可能继承 Android 的 `/system/bin` PATH，表现为 Debian 中明明存在
`mkdir`、`ps`、`grep`，执行时却提示 `command not found`。

## 6. 多层引号的可靠处理方式

复杂命令不要长期嵌套在：

```text
macOS shell → adb shell → su -c → chroot bash -c
```

多层 `$变量`、反斜杠和引号很容易在错误层提前展开。本次曾因此没有杀掉旧
Labwc，最终同时运行两个桌面会话，使截图结论无效。

可靠方法是在 Mac 创建小型诊断脚本，再推送到 Android 临时目录：

```bash
adb -s 192.168.1.133 push /tmp/anland-clean-test.sh \
  /data/local/tmp/anland-clean-test.sh
adb -s 192.168.1.133 shell \
  'su -M -c "chmod 755 /data/local/tmp/anland-clean-test.sh; \
              /data/local/tmp/anland-clean-test.sh"'
```

仓库文件使用 `apply_patch` 修改；`/data/local/tmp` 只存放可丢弃的诊断脚本。

`pkill -f` 还可能匹配包含搜索文本的诊断脚本自身。应使用严格进程名，或者用
正则断开文本：

```bash
pkill -x labwc
pkill -f '[w]ayland_profile_tray.py'
```

## 7. Mac、Termux 与 chroot 的三份仓库

本次环境中存在三份独立 Git 工作树：

```text
Mac:     /Users/lynn/sh
Termux:  /data/data/com.termux/files/home/sh
chroot:  /root/sh
```

Termux 与 chroot 的目录 inode 不同，不能假设修改或提交其中一份会自动同步另外
两份。每次调试前后都应分别检查：

```bash
git -C /Users/lynn/sh status --short --branch
git -C /data/data/com.termux/files/home/sh status --short --branch
git -C /root/sh status --short --branch
```

ADB 的 shell 用户访问 Termux 仓库时可能触发 Git `dubious ownership`。只读
检查可临时使用：

```bash
git -c safe.directory=/data/data/com.termux/files/home/sh \
  -C /data/data/com.termux/files/home/sh status --short
```

正式操作仍应降权到 Termux UID。不要先执行 `git checkout .` 再期待尚未 push
的 Mac 提交通过 `git pull` 回来。

## 8. 无法直接 adb push 到 Termux 私有目录时

先推送到 `/data/local/tmp`，再由 KernelSU root 复制并恢复所有权：

```bash
adb -s 192.168.1.133 push local-script.sh /data/local/tmp/local-script.sh
adb -s 192.168.1.133 shell 'su -M -c \
  "cp /data/local/tmp/local-script.sh \
      /data/data/com.termux/files/home/sh/path/local-script.sh;
   chown 10451:10451 \
      /data/data/com.termux/files/home/sh/path/local-script.sh;
   chmod 755 /data/data/com.termux/files/home/sh/path/local-script.sh"'
```

复制到 chroot `/root/sh` 时也要明确那是另一份工作树。

## 9. Anland direct 冷启动顺序

本次验证成功的顺序是：

```text
停止旧 Labwc/XFCE/Weston/Xwayland
→ force-stop com.anland.termux
→ 清理旧 Anland daemon 和 socket
→ 以 Termux UID 启动 Anland daemon
→ 启动 com.anland.termux/.MainActivity
→ 等待 consumer 连接和尺寸信息
→ 挂载/复用 chroot，并确认 /tmp bridge
→ 启动 Labwc + wlroots-anland direct backend
→ 启动 XFCE 组件
```

Activity 必须先于 direct Labwc，因为 backend 创建时就需要 Android consumer
提供屏幕尺寸和四个目标缓冲区。

一键入口是：

```bash
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start
```

或者在 Termux 的 `toolsinit.sh` 已加载时使用：

```bash
wstart
wstop
wrestart
wstatus
wdoctor
```

## 10. 日志与进程取证

核心日志：

```text
Termux Anland daemon:
  $PREFIX/tmp/anland/newhome-anland.log

Wayland session supervisor:
  /tmp/newhome-wayland-session-supervisor.log

Labwc/direct smoke:
  /tmp/newhome-wayland/direct-smoke.log

wayvnc:
  /root/.vnc/wayvnc.log

noVNC proxy:
  /root/.vnc/novnc-proxy.log

noVNC SysV startup:
  /root/.vnc/server-noVNC-startup.log
```

检查时必须同时查看进程数量，避免旧会话污染：

```bash
ps -eo pid,ppid,comm,args | \
  grep -E 'anland|labwc|weston|Xwayland|xfce4-panel|wayvnc|x11vnc'
```

不能只以“进程存在”判断成功，还要检查：

- daemon 是否依次记录 consumer connected、screen info、producer connected；
- Labwc 是否只有一个实例；
- direct 模式是否加载 `/opt/newhome-wayland/wlroots-anland/lib`；
- 5900 的 RFB 后端和 10086 的 noVNC 代理是否同时可用。

## 11. 使用 Android 截图验证真实输出

从 Mac 直接保存 Android 合成后的画面：

```bash
adb -s 192.168.1.133 exec-out screencap -p \
  > /tmp/anland-screen.png
```

截图必须在多个时间点采集，例如启动后 5 秒和 15 秒。首帧出现不等于四缓冲
轮转稳定；只看一瞬间会漏掉“纯红变闪红”“首帧后变黑”等问题。

## 12. 本次 GPU 显示问题的定位过程

最终 direct 路线为：

```text
XFCE → Labwc → wlroots-anland presenter → Anland DMA-BUF → Android
```

采用逐层替换法定位：

1. presenter 不采样 Labwc 源纹理，直接向 Android 目标 FBO 清纯红。
2. 红色能稳定持续，证明目标 DMA-BUF 导入、GPU 写入、刷新提交和 fence 正常。
3. 恢复真实纹理后出现鼠标但桌面黑，范围缩小到 compositor 源纹理和 presenter。
4. 发现 presenter 在 Labwc 主线程调用 `eglMakeCurrent()`，完成后没有恢复
   wlroots 原有 EGL display/context/read/draw surface。
5. 保存并恢复旧 EGL 状态后，真实 XFCE 可以绘制。
6. Android BufferQueue 使用四缓冲。静态桌面没有新 damage 时，Labwc 不会提交
   新帧，未填充的轮转槽位会黑屏或超时。
7. buffer-ready 的正确逻辑是：先向 Labwc 发送 frame；记录提交计数；如果本轮
   没有新 commit，才把锁定的最后一帧复制到当前 Android 缓冲区。
8. 默认 Y 翻转导致真实 XFCE 上下颠倒。A/B 测试确认
   `NEWHOME_ANLAND_FLIP_Y=0` 方向正确，因此库默认不翻转。

这里最重要的是每次只替换一层：纯色验证目标、真实纹理验证源、延时截图验证
轮转、Y 翻转变量验证坐标。不要同时改分辨率、renderer、compositor 和 daemon。

## 13. noVNC/wayvnc 的定位方法

原 noVNC 网页代理在 10086 正常，但 x11vnc 错误连接残留的 `DISPLAY=:1`。
将它改接 Labwc 的 `:0` 后，又出现 `X_GetImage BadMatch`，原因是 Labwc 启动的
Xwayland 为 rootless 模式，没有能让 x11vnc 抓取的根 framebuffer。

正确结构是：

```text
Labwc wlr-screencopy + virtual input
               ↓
          wayvnc :5900
               ↓
 noVNC/websockify TLS :10086
```

Termux:X11 profile 继续使用 x11vnc；Anland/Labwc profile 使用 wayvnc。不能只
根据 `/tmp/.X11-unix/X1` 文件存在判断 Termux:X11，因为 socket 可能是残留文件。

wayvnc 配置和凭据：

```text
/root/.config/wayvnc/config
/root/.vnc/wayvnc.credentials
```

两者必须为 root-only 权限。部署入口 `server_configure.sh` 会安装 wayvnc、生成
认证配置，并保留现有 noVNC TLS 层。

## 14. SELinux 与破坏性操作

KernelSU UID 0 不代表一定能穿过所有 SELinux 检查。先记录：

```bash
getenforce
ls -Zd /data/local/mnt
```

不要把永久关闭 SELinux 当成解决办法。本次主要问题最终都通过正确 namespace、
UID、PATH、进程清理和代码修复解决。若为了单次诊断临时切换 enforcing 状态，
必须记录原状态并在实验结束后恢复；生产启动脚本不应依赖 permissive。

停止容器会卸载 `/data/local/mnt`。随后不能直接执行手工 chroot 测试，必须先用
编排器重新挂载。删除 socket、marker 或旧库前要确认目标，正式库替换前保留明确
命名的备份，不对工作树执行 `git reset --hard`。

## 15. 完成标准

一次可靠的 Anland direct 调试至少应满足：

- 单个 Anland daemon、单个 consumer、单个 Labwc；
- daemon 以 Termux UID 运行；
- chroot `/tmp` 与 Termux tmp 是同一 socket 视图；
- direct backend 加载正式库；
- XFCE panel、dock、文字和鼠标方向正确；
- 间隔十余秒截图仍一致，无闪红、黑屏或固定旧帧；
- wayvnc 监听 127.0.0.1:5900；
- noVNC TLS 页面在 10086 可达；
- Termux:X11 与 Anland profile 不同时抢占前台；
- 所有生成器、安装依赖和启动修复已进入 Git，而不是只留在设备临时目录。

相关路线文档：

- `termux/chroot/wayland/ANLAND_DIRECT_ROUTE.md`
- `docs/HANDOFF_WAYLAND_STAGE3_DEBUG.md`
- `docs/WAYLAND_ANLAND.md`
