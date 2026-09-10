# Handoff: Termux:X11 / chroot 远程桌面低延迟优化

日期：2026-09-10

## 目标

当前手机 Linux 桌面已经可以稳定使用：

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

用户日常通过 USB 连接手机，并使用 `adb forward` 转发端口，因此：

- 不需要公网域名；
- 不需要独立 host；
- 不以公网穿透为目标；
- 优先目标是 **低延迟、鼠标/键盘语义完整、保留 XFCE、保留 Termux:X11、保留当前 GPU 渲染能力**；
- 当前 noVNC 输入体验比 scrcpy 更适合 Linux 桌面，因此本轮不把 scrcpy 作为主线；
- 允许继续保留 noVNC 作为兼容和应急方案。

本 handoff 的任务是：**边在真机上测试，边优化或替换 `x11vnc -> noVNC` 这一段远程链路。**

---

## 一、当前仓库真实状态

当前主要启动入口：

```text
termux/chroot/termux_all_in_one.sh
termux/chroot/cli.sh
win-git/server_noVNC.sh
```

`tstart` 会启动 Termux:X11，然后启动 chroot。

当前 `win-git/server_noVNC.sh` 在 Termux:X11 存在时使用：

```bash
DISPLAY=:1
```

并启动 XFCE4 和 x11vnc。

Oryon / 新高通设备分支会设置：

```bash
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export TU_DEBUG=noconform
```

VirGL 路径会设置：

```bash
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
```

所以需要明确区分两个概念：

```text
Linux 应用 / OpenGL
  -> Mesa KGSL / virpipe
  -> Termux:X11
```

这一段**可以有 GPU 加速**。

但后面的：

```text
Termux:X11 framebuffer
  -> x11vnc 抓屏
  -> RFB 编码
  -> websockify
  -> browser/noVNC
```

目前主要还是 CPU 抓屏和 CPU 编码路径。

因此“Linux 桌面用了 GPU”并不代表“VNC 远程传输用了 GPU”。

---

## 二、当前 x11vnc 配置尤其值得检查

当前稳定分支实际使用：

```bash
x11vnc \
  -display :1 \
  -auth "$HOME/.Xauthority" \
  -rfbauth "$HOME/.vnc/passwd" \
  -rfbport 5900 \
  -forever \
  -noshm \
  -shared \
  -noxdamage \
  -noxfixes \
  -cursor arrow \
  -nowf \
  -noscr \
  -xrandr resize \
  -reopen \
  -loop500
```

这里有三个非常重要的性能相关开关：

```text
-noshm
-noxdamage
-noxfixes
```

其中：

- `-noshm` 禁用 MIT-SHM，x11vnc 会退回较慢的 framebuffer 读取方式；
- `-noxdamage` 禁用 XDamage，x11vnc 无法依赖 X server 精确获知屏幕哪些区域发生变化；
- `-noxfixes` 禁用 XFixes，一部分 cursor / region 能力会退回兼容路径。

这些参数过去可能是为了 Termux:X11 兼容性而加入，但**不要假设今天仍然必须全部关闭**。

上游 x11vnc：

```text
https://github.com/LibVNC/x11vnc
```

官方 OPTIONS 文档仍明确说明正常 X display 路径会使用 MIT-SHM。

因此本轮第一优先级不是立刻替换 x11vnc，而是做可靠 A/B 测试。

---

# 三、总原则

本地 Agent 必须遵守：

1. **每次只改变一个变量。**
2. 任何实验失败后必须能一条命令回到当前稳定配置。
3. 暂时不要删除 `server_noVNC.sh` 的现有稳定分支。
4. 不迁移 Wayland。
5. 不替换 XFCE4。
6. 不修改 Termux:X11 源码。
7. 不为了远程桌面破坏当前 KGSL / VirGL 加速。
8. 真机数据优先于理论判断。
9. 对每个方案同时评价：
   - 延迟；
   - CPU；
   - GPU；
   - 功耗；
   - 画质；
   - 鼠标右键/中键/滚轮；
   - Ctrl/Alt/Super/F1-F12；
   - 中文输入；
   - 剪贴板；
   - 动态分辨率；
   - 重连稳定性。
10. 用户主要通过 USB + ADB 使用，优先为 localhost / adb-forward 优化，不需要为公网高 RTT 做复杂设计。

---

# 四、Phase 0：建立当前性能基线

不要先改代码。

启动：

```bash
tstart
```

chroot 内记录：

```bash
ps -ef | grep -E 'x11vnc|novnc|websockify|X11|xfce' | grep -v grep

top -H -p $(pgrep -d, x11vnc)

cat ~/.vnc/x11vnc.log
```

确认 X11 扩展：

```bash
DISPLAY=:1 xdpyinfo | grep -A2 -E 'MIT-SHM|DAMAGE|XFIXES|RANDR'
```

如果 `xdpyinfo` 输出不直观：

```bash
DISPLAY=:1 xdpyinfo -queryExtensions | grep -Ei 'MIT-SHM|DAMAGE|XFIXES|RANDR'
```

确认当前 GPU：

```bash
DISPLAY=:1 glxinfo -B
```

如果有 EGL 工具：

```bash
eglinfo 2>/dev/null | head -100
```

记录：

```text
renderer
vendor
direct rendering
OpenGL version
```

还要记录：

```bash
pidstat -p $(pgrep -n x11vnc) 1
```

没有 `pidstat` 时：

```bash
apt install sysstat
```

人为制造三种场景，每个持续约几十秒即可：

```text
A. 桌面静止
B. 拖动一个终端窗口
C. Firefox 快速滚动网页 / 播放视频
```

记录 x11vnc CPU。

如果方便，可以额外记录手机温度 / 频率，但不是阻塞项。

---

# 五、Phase 1：先确认 noVNC 是否本身就是瓶颈

这是成本最低、信息量最大的实验之一。

当前 x11vnc 已监听：

```text
127.0.0.1/0.0.0.0:5900
```

电脑直接：

```bash
adb forward tcp:5900 tcp:5900
```

然后使用原生 VNC Viewer 连接：

```text
127.0.0.1:5900
```

优先测试：

```text
TigerVNC Viewer
```

项目：

```text
https://github.com/TigerVNC/tigervnc
```

不要通过：

```text
browser -> WebSocket -> websockify -> x11vnc
```

而直接：

```text
TigerVNC Viewer
  -> USB / adb forward
  -> x11vnc
```

### 必须比较

同一时刻、同一桌面、同一分辨率比较：

```text
A. noVNC :10086
B. TigerVNC native client :5900
```

比较：

- 拖动窗口是否跟手；
- 浏览器滚动；
- 终端快速输出；
- Firefox 视频；
- x11vnc CPU；
- websockify CPU；
- 浏览器 CPU；
- 键鼠功能。

### 判定

如果原生 VNC 明显更快：

> 当前主要问题至少有一部分在 noVNC/WebSocket/browser，而不是 x11vnc 本身。

此时不要急着换 VNC server，可以直接把：

```text
原生 VNC over adb
```

作为电脑 USB 场景的新默认方案，把 noVNC 留给浏览器访问。

如果两者一样慢：

> 继续查 x11vnc framebuffer capture / encoding。

---

# 六、Phase 2：逐项恢复 XDamage / MIT-SHM / XFixes

绝对不要一次把三个选项都删除，否则无法知道是谁导致问题。

建议给 `server_noVNC.sh` 增加实验模式，例如环境变量：

```bash
X11VNC_PROFILE=stable
X11VNC_PROFILE=damage
X11VNC_PROFILE=shm
X11VNC_PROFILE=damage-shm
X11VNC_PROFILE=full
```

但第一次真机调试也可以先手工执行。

## Profile A：当前 stable

保持：

```text
-noshm
-noxdamage
-noxfixes
```

作为基准。

## Profile B：只恢复 XDamage

删除：

```text
-noxdamage
```

仍保留：

```text
-noshm
-noxfixes
```

重点观察：

- 是否黑屏；
- 是否局部区域不刷新；
- 窗口拖动是否更快；
- 静止桌面时 CPU 是否下降；
- Firefox 滚动是否改善；
- x11vnc log 是否有 DAMAGE error。

如果稳定，XDamage 应优先保留。

## Profile C：只恢复 MIT-SHM

恢复 stable 后，仅删除：

```text
-noshm
```

保留：

```text
-noxdamage
-noxfixes
```

观察：

- x11vnc 是否启动；
- 是否 Segmentation fault；
- 是否出现 BadAccess / BadMatch；
- 是否花屏；
- framebuffer 抓取 CPU 是否显著降低。

如果失败，完整保留：

```bash
~/.vnc/x11vnc.log
dmesg | tail -100
logcat | tail -200
```

这里非常重要：

> 如果 MIT-SHM 失败，不要简单写“Termux:X11 不支持”。要判断是 X server 不支持、chroot IPC namespace、/dev/shm、权限、还是 x11vnc/Termux:X11 兼容 bug。

检查：

```bash
ls -ld /dev/shm
mount | grep shm
ipcs -m
DISPLAY=:1 xdpyinfo -queryExtensions | grep MIT-SHM
```

## Profile D：XDamage + MIT-SHM

如果 B/C 分别工作，再同时恢复：

```text
XDamage
MIT-SHM
```

仍保留：

```text
-noxfixes
```

这是非常值得期待的组合。

## Profile E：恢复 XFixes

最后再删除：

```text
-noxfixes
```

检查 cursor 是否正常、是否有残影、鼠标样式是否正确。

---

# 七、Phase 3：调 x11vnc，而不是盲目追求“最高画质”

USB/adb 场景特点是：

```text
网络 RTT 很低
带宽较高
手机 CPU 比网络更加珍贵
```

因此优化原则和公网 VNC 不同。

不要为了节省几 Mbps 让手机疯狂压缩。

优先策略：

```text
减少 server CPU 压缩
允许更高带宽
换取更低延迟
```

RFB encoding 很大程度由 client 协商，因此使用 TigerVNC Viewer 时要 A/B：

```text
Tight
ZRLE
低 compression / 高质量 JPEG
```

不要凭感觉选择。

对 Linux 桌面文字来说 Tight 通常值得保留；对于视频区域 JPEG quality 也会影响 CPU 和带宽。

记录：

```text
手机 x11vnc CPU
PC client CPU
USB 实际吞吐
视觉延迟
文字清晰度
```

如果降低压缩后 CPU 明显下降、延迟更低，就符合本项目的 USB 使用场景。

---

# 八、Phase 4：检查当前轮询参数是否人为增加延迟

x11vnc 自身有 screen polling、defer-update 等机制。

上游源码默认值中可以看到类似：

```text
waitms = 20

defer_update = 20
```

当前项目另外使用：

```text
-loop500
```

需要区分：

- `loop500` 是 server 重启/重新打开 display 相关机制；
- screen poll / defer update 才直接影响交互刷新节奏。

本地 Agent 应通过：

```bash
x11vnc -help
```

确认当前安装版本支持的参数，再做实验。

不要从网上复制当前二进制不支持的参数。

可以重点搜索和 A/B：

```text
-wait
-defer
-nap / -nonap
-pointer_mode
```

原则仍然是：一次只调一个参数。

USB 模式可以尝试用更多 CPU polling 换低延迟，但要观察功耗。

---

# 九、Phase 5：第一替代方案 —— Xpra shadow

如果优化 x11vnc 后仍达不到要求，第一替代方案优先测试：

```text
Xpra
```

项目：

```text
https://github.com/Xpra-org/xpra
```

Xpra 当前明确支持：

```text
shadow an existing display
```

这正符合我们的要求，因为不能另起一个 Xvnc desktop，必须尽量复用：

```text
Termux:X11 :1
```

理想结构：

```text
XFCE4
  -> Termux:X11 :1
      -> Xpra shadow
          -> TCP localhost
              -> adb forward
                  -> PC Xpra client
```

### 首轮实验

chroot 内先确认 Debian 包版本：

```bash
apt-cache policy xpra
```

安装：

```bash
apt install xpra
```

查看当前版本支持的准确语法：

```bash
xpra shadow --help
```

目标是 shadow：

```text
DISPLAY=:1
```

并只监听 localhost，例如目标端口：

```text
14500
```

电脑：

```bash
adb forward tcp:14500 tcp:14500
```

PC 使用原生 Xpra client。

不要第一轮就使用 Xpra HTML5 client，否则又把 browser/WebSocket 变量加进来了。

### Xpra 必测项目

- 是否能正确 shadow Termux:X11；
- 鼠标右键、中键、滚轮；
- Ctrl/Alt/Super；
- 中文输入；
- clipboard；
- resize；
- 视频时 CPU；
- 窗口拖动延迟；
- client OpenGL；
- 是否能使用 H.264/H.265 encoder；
- Debian/ARM64 包提供哪些 codecs。

查看：

```bash
xpra encoding
xpra showconfig | grep -Ei 'encoding|codec|video|opengl'
```

具体命令以当前版本 `--help` 为准。

### 为什么 Xpra 优先于 KasmVNC

Xpra 官方当前明确支持：

```text
Shadow an existing display
```

并且支持原生客户端、TCP、WebSocket、RFB 等协议。

它更适合“保留 Termux:X11 :1 当前 session”。

而很多 VNC server 更擅长自己创建一个新的 X server/session，这不符合我们当前架构。

---

# 十、可以研究，但暂不作为首选的方案

## 1. KasmVNC

项目：

```text
https://github.com/kasmtech/KasmVNC
```

优势是浏览器体验和现代 web remote desktop。

问题是它更偏向：

```text
KasmVNC 自己作为 X server
```

而我们的核心要求是复用：

```text
Termux:X11 :1
```

因此只有确认它能可靠 shadow existing X11 display 后才进入主线。

不要为了 KasmVNC 换掉现有 Termux:X11。

## 2. TurboVNC + VirtualGL

项目：

```text
https://github.com/TurboVNC/turbovnc
https://github.com/VirtualGL/virtualgl
```

它们在传统 Linux GPU workstation/HPC 环境很成熟，但通常假设：

```text
标准 Xorg
标准 DRM/DRI
正常 Linux GPU device
```

我们这里是：

```text
Android Adreno
Termux:X11
KGSL / Turnip / VirGL
chroot
```

适配风险明显更高。

可以作为后续研究，但不要第一阶段投入大量修改。

## 3. Sunshine / Moonlight

理论上的低延迟视频体验很好，但 Linux Sunshine host 通常依赖：

```text
DRM/KMS
Wayland/X11 capture
VAAPI/NVENC/AMF 等
```

我们的最终显示是 Android/Termux:X11 Surface，不是传统 Linux KMS desktop。

不要为了 Sunshine 破坏现有架构。

## 4. wayvnc

当前不考虑。

原因：本项目明确暂不迁移 Wayland。

---

# 十一、Phase 6：如果传统 VNC/Xpra 都不够，再研究“视频与输入拆分”

这是后续高级路线，不是第一阶段任务。

核心思路：

```text
视频：
Termux:X11 framebuffer
  -> 高速 capture
  -> Android hardware H.264/H.265
  -> USB/ADB
  -> PC decoder

输入：
PC mouse/keyboard
  -> 极小 TCP protocol
  -> adb forward
  -> chroot
  -> XTest / XInput2
  -> DISPLAY=:1
```

这样输入不经过 Android InputManager，因此可以完整保留 Linux：

```text
right click
middle click
wheel
extra buttons
Ctrl/Alt/Super
key down/up
```

这条路线的真正难点不是输入，而是：

> 怎样从 Termux:X11 / Android Surface 高效取得帧，并送入 Android MediaCodec，而且不再做昂贵的 CPU readback/copy。

在没有证明现有方案做不到之前，不进入这一阶段。

---

# 十二、建议在仓库新增一个实验管理脚本

真机 Agent 可以在确认实验方向后创建：

```text
termux/chroot/remote/
  remote_test.sh
  x11vnc_profiles.sh
  xpra_shadow.sh
  README.md
```

但不要一开始重构 `server_noVNC.sh`。

第一阶段应先写一个独立脚本调用当前 x11vnc，避免破坏生产路径。

例如目标接口：

```bash
bash ~/sh/termux/chroot/remote/remote_test.sh doctor
bash ~/sh/termux/chroot/remote/remote_test.sh baseline
bash ~/sh/termux/chroot/remote/remote_test.sh native-vnc
bash ~/sh/termux/chroot/remote/remote_test.sh xdamage
bash ~/sh/termux/chroot/remote/remote_test.sh shm
bash ~/sh/termux/chroot/remote/remote_test.sh damage-shm
bash ~/sh/termux/chroot/remote/remote_test.sh xpra
bash ~/sh/termux/chroot/remote/remote_test.sh status
```

测试成功以后，再决定哪些配置并入：

```text
win-git/server_noVNC.sh
```

---

# 十三、doctor 应收集的信息

建议最终实现的 `doctor` 一次输出：

```bash
uname -a
uname -m
cat /etc/os-release

echo "DISPLAY=$DISPLAY"

DISPLAY=:1 xdpyinfo -queryExtensions
DISPLAY=:1 glxinfo -B

x11vnc -version
x11vnc -help 2>&1 | head -200

ps -ef | grep -E 'termux-x11|x11vnc|novnc|websockify|xfce' | grep -v grep

ss -ltnp | grep -E '5900|10086|14500'

ls -ld /dev/shm
mount | grep -E 'shm|tmp'
ipcs -m

cat ~/.vnc/x11vnc.log 2>/dev/null
```

Termux 宿主如果可执行，再收集：

```bash
getprop ro.product.model
getprop ro.build.version.release
getprop ro.hardware
```

---

# 十四、建议保存测试结果

每轮测试保存到：

```text
docs/remote-tests/
```

例如：

```text
docs/remote-tests/2026-09-10-baseline.md
docs/remote-tests/2026-09-10-native-vnc.md
docs/remote-tests/2026-09-10-xdamage.md
docs/remote-tests/2026-09-10-shm.md
docs/remote-tests/2026-09-10-xpra.md
```

每个文件统一记录：

```markdown
## 配置

## 启动命令

## 是否稳定

## CPU

## 输入体验

## 窗口拖动

## Firefox 滚动

## 视频

## 分辨率调整

## 日志

## 结论
```

如果实验失败也要保存，避免未来 Agent 重复踩坑。

---

# 十五、第一轮真机任务清单

本地 Agent 拿到这个 handoff 后，第一轮只做以下任务：

### Task 1：建立 baseline

确认当前：

```text
x11vnc + noVNC
```

CPU、输入和延迟情况。

### Task 2：原生 VNC over ADB

电脑：

```bash
adb forward tcp:5900 tcp:5900
```

用 TigerVNC Viewer 直接连接。

这是最高优先级。

### Task 3：确认 X extensions

```bash
DISPLAY=:1 xdpyinfo -queryExtensions | grep -Ei 'MIT-SHM|DAMAGE|XFIXES|RANDR'
```

### Task 4：只恢复 XDamage

不要动 MIT-SHM。

如果稳定，比较 CPU/延迟。

### Task 5：单独恢复 MIT-SHM

重点收集失败原因。

### Task 6：如果 B/C 都稳定，组合 XDamage + MIT-SHM

### Task 7：如果 x11vnc 已明显改善

先不要装 Xpra。

继续把稳定配置做成 profile。

### Task 8：如果 x11vnc 上限仍明显不足

再安装并测试：

```text
Xpra shadow :1
```

---

# 十六、成功判定标准

本项目不是追求理论 benchmark，而是改善实际 Linux 桌面。

优先级：

```text
1. 输入必须完整
2. 稳定
3. 交互延迟
4. 手机 CPU / 功耗
5. Firefox 滚动 / IDE / terminal
6. 视频
7. 带宽
8. 浏览器访问便利性
```

在 USB/ADB 场景，带宽排名很低。

如果一个方案：

```text
多吃 20 Mbps
但手机 CPU 从 80% 降到 30%
并且延迟明显下降
```

这是成功优化。

---

# 十七、目前最可能的收敛路线

优先猜测，但必须由真机数据验证：

```text
方案 A：
Termux:X11 :1
  -> x11vnc（重新启用 XDamage，可能重新启用 MIT-SHM）
  -> native TigerVNC client
  -> adb forward
```

这是最小改动、最可能快速改善的路线。

如果仍不够：

```text
方案 B：
Termux:X11 :1
  -> Xpra shadow
  -> native Xpra client
  -> adb forward
```

noVNC 保留：

```text
方案 C：浏览器兼容 / 应急
Termux:X11 :1
  -> x11vnc
  -> noVNC
```

只有前三者都不能达到要求，才研究：

```text
方案 D：
Android hardware video encoding
+
独立 X11 input bridge
```

---

# 十八、参考项目

```text
x11vnc
https://github.com/LibVNC/x11vnc

TigerVNC
https://github.com/TigerVNC/tigervnc

Xpra
https://github.com/Xpra-org/xpra

KasmVNC
https://github.com/kasmtech/KasmVNC

TurboVNC
https://github.com/TurboVNC/turbovnc

VirtualGL
https://github.com/VirtualGL/virtualgl

Termux:X11
https://github.com/termux/termux-x11
```

其中当前优先阅读：

```text
x11vnc OPTIONS
Xpra Shadow Existing Display
Xpra picture/video encodings
TigerVNC client encoding / compression
```

---

# 十九、给下一位 Agent 的一句话任务

> 不要重做桌面环境。保持 `tstart -> Termux:X11 :1 -> XFCE4` 不变，先用真机数据拆解 `x11vnc -> noVNC` 的延迟来源；第一步比较原生 TigerVNC over adb 和 noVNC，随后逐项恢复 XDamage/MIT-SHM/XFixes，确认最优 x11vnc profile；只有 x11vnc 达到上限后再测试 Xpra shadow，所有成功和失败结果都写入 `docs/remote-tests/`，避免重复试错。
