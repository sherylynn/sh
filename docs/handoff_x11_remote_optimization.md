# Handoff: Termux:X11 / chroot 远程桌面低延迟优化

日期：2026-09-10

## 目标

当前手机 Linux 桌面链路：

```text
Android / Root
  -> Termux
     -> termux/chroot/termux_all_in_one.sh (tstart)
        -> Termux:X11 :1
        -> chroot Debian
           -> XFCE4
           -> x11vnc :5900
           -> noVNC/websockify :10086
```

用户日常通过 USB 连接手机，并使用 `adb forward` 转发 noVNC 端口。用户明确偏好浏览器直接访问，不希望安装 TigerVNC、Xpra 原生客户端或其它 PC 端专用客户端。

因此本轮原则是：

- **保留 noVNC 浏览器前端作为主入口**；
- 不迁移 Wayland；
- 不替换 XFCE4；
- 不修改 Termux:X11 源码；
- 不破坏当前 KGSL / VirGL GPU 渲染；
- 优先优化 `Termux:X11 -> x11vnc -> websockify -> noVNC`；
- 如果替换 x11vnc，也必须优先选择能继续通过浏览器/noVNC 或 HTML5 前端访问的服务端；
- 不再测试 TigerVNC Viewer 或其它必须安装桌面客户端的路线。

---

## 一、当前架构判断

当前仓库关键入口：

```text
termux/chroot/termux_all_in_one.sh
termux/chroot/cli.sh
win-git/server_noVNC.sh
```

`tstart` 启动 Termux:X11 与 chroot，`server_noVNC.sh` 在 `DISPLAY=:1` 上启动 XFCE4、x11vnc 和 noVNC。

当前 GPU 相关路径包括：

```bash
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export TU_DEBUG=noconform
```

或：

```bash
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
```

因此应区分：

```text
Linux 应用 / OpenGL
  -> Mesa KGSL / virpipe
  -> Termux:X11
```

这一段可以 GPU 加速。

而：

```text
Termux:X11 framebuffer
  -> x11vnc 抓屏
  -> RFB 编码
  -> websockify
  -> browser/noVNC
```

目前主要还是 CPU 抓屏、CPU 编码和浏览器解码/绘制路径。

本轮目标是优化后半段，而不是重做 Linux 图形栈。

---

## 二、当前 x11vnc 参数是第一优化重点

当前稳定配置包含：

```text
-noshm
-noxdamage
-noxfixes
```

这三个参数可能显著影响性能：

- `-noshm`：禁用 MIT-SHM，可能增加 framebuffer 读取开销；
- `-noxdamage`：禁用 XDamage，可能导致 x11vnc 更频繁地扫描较大区域；
- `-noxfixes`：禁用 XFixes，可能使 cursor/region 处理退回兼容路径。

这些参数过去可能是为 Termux:X11 兼容性加入，但不要假设现在仍然必须全部关闭。

第一阶段必须逐项恢复并真机验证。

---

## 三、总原则

本地 Agent 调试时必须遵守：

1. 每次只改变一个变量。
2. 当前 `server_noVNC.sh` 稳定配置必须可立即恢复。
3. 实验代码优先放独立脚本，不要一开始重构生产启动链路。
4. 真机结果优先于理论判断。
5. 用户主场景是 USB + ADB，本机带宽较高、RTT 很低，因此可以用更高带宽换更低 CPU 和更低延迟。
6. 浏览器/noVNC 是最终用户入口，所有优化最终必须回到浏览器场景验证。
7. 不把“Linux 应用 GPU 加速”误认为“VNC 编码 GPU 加速”。
8. 每轮记录 CPU、延迟、画质、键鼠、滚轮、组合键、中文输入、剪贴板、resize 和重连稳定性。

---

# 四、Phase 0：建立 noVNC 当前基线

先不要修改代码。

启动：

```bash
tstart
```

记录：

```bash
ps -ef | grep -E 'x11vnc|novnc|websockify|termux-x11|xfce' | grep -v grep
cat ~/.vnc/x11vnc.log
DISPLAY=:1 xdpyinfo -queryExtensions | grep -Ei 'MIT-SHM|DAMAGE|XFIXES|RANDR'
DISPLAY=:1 glxinfo -B
```

监控：

```bash
pidstat -p $(pgrep -n x11vnc) 1
```

同时记录 websockify/noVNC 对应进程 CPU。

测试固定场景：

```text
A. 桌面静止
B. 拖动终端窗口
C. Firefox 快速滚动
D. Firefox 播放视频
E. 终端快速输出
```

记录主观延迟和 CPU。

---

# 五、Phase 1：逐项恢复 XDamage / MIT-SHM / XFixes

建议新增 profile，而不是直接覆盖稳定参数：

```bash
X11VNC_PROFILE=stable
X11VNC_PROFILE=damage
X11VNC_PROFILE=shm
X11VNC_PROFILE=damage-shm
X11VNC_PROFILE=full
```

## Profile A：stable

保持：

```text
-noshm
-noxdamage
-noxfixes
```

## Profile B：只恢复 XDamage

只删除：

```text
-noxdamage
```

观察：

- 是否黑屏；
- 是否局部不刷新；
- 静止桌面 CPU；
- 拖窗延迟；
- Firefox 滚动；
- x11vnc log 中是否有 DAMAGE 错误。

如果稳定，优先保留。

## Profile C：只恢复 MIT-SHM

回到 stable，仅删除：

```text
-noshm
```

检查：

```bash
ls -ld /dev/shm
mount | grep shm
ipcs -m
DISPLAY=:1 xdpyinfo -queryExtensions | grep MIT-SHM
```

观察：

- x11vnc 是否崩溃；
- BadAccess / BadMatch；
- 花屏；
- framebuffer 读取 CPU 是否下降。

如果失败，不要简单写“Termux:X11 不支持 SHM”，要判断是 X server、chroot IPC、`/dev/shm`、权限还是 x11vnc 本身的问题。

## Profile D：XDamage + MIT-SHM

B/C 分别稳定后再组合。

## Profile E：恢复 XFixes

最后再恢复 XFixes，重点看 cursor、残影和 region 更新。

---

# 六、Phase 2：针对 USB 场景优化 x11vnc 编码与刷新

用户通过 ADB/USB 使用，因此优化目标不是省流量，而是：

```text
减少手机 CPU 压缩
允许更高带宽
减少等待和合并帧
降低交互延迟
```

本地 Agent 必须先：

```bash
x11vnc -help
```

确认当前安装版本真实支持的参数，再实验。

重点研究：

```text
-wait
-defer
-nap / -nonap
-pointer_mode
```

每次只调一个参数。

不要盲目提高刷新频率；需要对比手机 CPU、温度与延迟。

---

# 七、Phase 3：优化 websockify / noVNC 本身

因为用户最终一定使用浏览器，所以服务端优化后必须继续检查：

```text
x11vnc -> websockify -> noVNC
```

重点排查：

1. websockify 是否成为单核 CPU 瓶颈；
2. 是否存在不必要的 TLS / 加密开销（用户是 localhost + adb forward 场景）；
3. WebSocket buffer 是否产生额外排队；
4. noVNC quality/compression 配置是否适合 USB 高带宽场景；
5. noVNC 是否启用了适合低延迟的 resize/scale 策略；
6. 浏览器 canvas 绘制是否成为瓶颈；
7. 不同浏览器的性能差异是否明显。

如果 noVNC 支持运行时设置，优先做 A/B：

```text
更低 compression
更高 quality
更少 server CPU
```

允许 USB 流量增加。

记录：

```text
x11vnc CPU
websockify CPU
浏览器 CPU/GPU
USB 流量
主观拖窗延迟
Firefox 滚动延迟
视频连续性
```

---

# 八、Phase 4：研究 x11vnc 的可替代服务端，但必须保留 Web 客户端

只有 x11vnc 优化后仍明显不足，再进入替代方案。

优先条件：

```text
必须能复用现有 Termux:X11 :1 session
最好能 shadow existing X display
必须提供 WebSocket/RFB/HTML5 浏览器访问路径
不要求 PC 安装原生客户端
```

## 1. Xpra HTML5 / Web client

Xpra 可以研究 shadow existing display，并提供 HTML5/WebSocket 访问。

研究重点不是原生 Xpra client，而是：

```text
Termux:X11 :1
  -> Xpra shadow
  -> HTML5/WebSocket
  -> browser
```

必须测试 ARM64 Debian 包实际提供的编码器，以及在手机上的 CPU 开销。

如果它需要明显更复杂的依赖且没有性能收益，就放弃。

## 2. KasmVNC

可以研究，因为它本身以浏览器体验为核心。

但必须先确认能否在当前架构下复用/映射现有 Termux:X11 session。

不要为了 KasmVNC 改成新的独立桌面 session，更不要替换 Termux:X11。

## 3. 其它 noVNC-compatible VNC server

可以搜索 GitHub 上仍在维护的：

```text
VNC server
RFB server
X11 shadow server
WebSocket VNC
```

筛选条件：

- ARM64 可构建；
- 支持已有 X11 display；
- 浏览器/noVNC 可直接接；
- 抓屏路径比 x11vnc 更现代；
- 最好支持 XDamage；
- 最好支持更高效的像素格式转换；
- 不依赖传统 PC GPU/DRM/KMS。

---

# 九、Phase 5：如果传统 RFB 到顶，再研究硬件视频编码 + Web 输入

这是高级路线，不是第一阶段任务。

最终可研究：

```text
视频：
Termux:X11 / Android Surface
  -> 高速 capture
  -> Android MediaCodec H.264/H.265
  -> WebSocket/WebRTC
  -> browser

输入：
browser keyboard/mouse
  -> WebSocket/DataChannel
  -> chroot
  -> XTest / XInput2
  -> DISPLAY=:1
```

这样仍然满足用户要求：

```text
浏览器直接打开
无需安装 PC 客户端
右键/中键/滚轮/组合键由 Web 前端直接注入 X11
```

真正难点是避免从 Termux:X11 framebuffer 做昂贵 CPU readback，再送给 Android MediaCodec。

没有证明 x11vnc/noVNC 已到性能上限前，不投入这一阶段。

---

# 十、建议新增实验工具

建议本地 Agent 创建：

```text
termux/chroot/remote/
  remote_test.sh
  x11vnc_profiles.sh
  novnc_profile.sh
  xpra_web_test.sh
  README.md
```

第一阶段不要重写 `server_noVNC.sh`。

目标接口可设计为：

```bash
bash ~/sh/termux/chroot/remote/remote_test.sh doctor
bash ~/sh/termux/chroot/remote/remote_test.sh baseline
bash ~/sh/termux/chroot/remote/remote_test.sh xdamage
bash ~/sh/termux/chroot/remote/remote_test.sh shm
bash ~/sh/termux/chroot/remote/remote_test.sh damage-shm
bash ~/sh/termux/chroot/remote/remote_test.sh full
bash ~/sh/termux/chroot/remote/remote_test.sh novnc-lowlatency
bash ~/sh/termux/chroot/remote/remote_test.sh xpra-web
bash ~/sh/termux/chroot/remote/remote_test.sh status
```

测试成功以后，再把稳定配置并回：

```text
win-git/server_noVNC.sh
```

---

# 十一、doctor 应收集的信息

```bash
uname -a
uname -m
cat /etc/os-release

echo "DISPLAY=$DISPLAY"
DISPLAY=:1 xdpyinfo -queryExtensions
DISPLAY=:1 glxinfo -B

x11vnc -version
x11vnc -help 2>&1 | head -250

ps -ef | grep -E 'termux-x11|x11vnc|novnc|websockify|xfce' | grep -v grep
ss -ltnp | grep -E '5900|10086|14500'

ls -ld /dev/shm
mount | grep -E 'shm|tmp'
ipcs -m

cat ~/.vnc/x11vnc.log 2>/dev/null
```

Termux 宿主如果可以，再记录：

```bash
getprop ro.product.model
getprop ro.build.version.release
getprop ro.hardware
```

---

# 十二、测试结果必须保存

统一写到：

```text
docs/remote-tests/
```

例如：

```text
2026-09-10-baseline.md
2026-09-10-xdamage.md
2026-09-10-shm.md
2026-09-10-damage-shm.md
2026-09-10-novnc-lowlatency.md
2026-09-10-xpra-web.md
```

每个文件统一包含：

```markdown
## 配置
## 启动命令
## 是否稳定
## x11vnc CPU
## websockify CPU
## 浏览器 CPU/GPU
## 输入体验
## 窗口拖动
## Firefox 滚动
## 视频
## 分辨率调整
## 日志
## 结论
```

失败结果也必须保存，避免以后重复踩坑。

---

# 十三、第一轮真机任务

第一轮只做：

### Task 1：baseline

确认当前 `x11vnc + websockify + noVNC` CPU、输入和延迟。

### Task 2：确认 X extensions

```bash
DISPLAY=:1 xdpyinfo -queryExtensions | grep -Ei 'MIT-SHM|DAMAGE|XFIXES|RANDR'
```

### Task 3：只恢复 XDamage

不要同时动 SHM。

### Task 4：单独恢复 MIT-SHM

收集完整失败原因。

### Task 5：组合 XDamage + MIT-SHM

只在单项都稳定后进行。

### Task 6：优化 noVNC/websockify

在 USB 高带宽条件下测试降低压缩、减少等待是否明显降低延迟。

### Task 7：如果 x11vnc/noVNC 已明显改善

把最稳定 profile 固化，但保留原 stable fallback。

### Task 8：如果仍明显不足

再测试 Xpra HTML5 或其它浏览器优先服务端；不测试 TigerVNC Viewer / Xpra 原生客户端。

---

# 十四、明确不做的路线

本轮明确不做：

```text
TigerVNC Viewer
RealVNC Viewer
Xpra native client
其它要求 PC 安装专用客户端的方案
scrcpy 作为主远程桌面方案
Wayland 迁移
替换 XFCE
重写 Termux:X11
```

用户的产品目标很明确：

> 插 USB，通过 adb forward，然后浏览器直接打开 Linux 桌面。

所有优化都围绕这个体验展开。
