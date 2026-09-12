# Handoff: Wayland Stage3 真机适配调试

## 目标

把当前实验中的 direct Wayland 路线调通到可长期使用：

```text
XFCE components
      |
    Labwc
      |
wlroots 0.18.2 + Anland backend
      |
 GPU-only DMA-BUF presentation
      |
 Anland 5.13.3
      |
   Android / SM8750
```

最终目标是：

1. 不经过 Weston nested compositor；
2. Labwc 直接使用我们维护的 `wlroots-anland` backend；
3. Android consumer 提供 DMA-BUF；
4. 当前 Stage3 第一版允许一次 GPU->GPU blit；
5. 严禁 CPU framebuffer readback / memcpy / upload；
6. 真机验证成功后才创建 `.ready`，让 `auto` 模式切换到 direct；
7. X11 / Termux:X11 现有稳定主线必须始终保留并可随时切回。

---

## 当前固定版本

不要随意升级版本解决编译错误。

```text
Android/Termux side:
  Anland: Termux 5.13.3

Debian chroot:
  Debian 13 / trixie
  Labwc 0.8.3
  wlroots upstream 0.18.2
  Debian wlroots package baseline 0.18.2-3
```

Anland 暂时使用 upstream `lfdevs/anland-termux`，不要 fork Anland。

当前需要适配的是 wlroots backend；开发实现暂时放在 `sh` 仓库 source-overlay/build pipeline 中。等真机稳定后再决定是否拆成 `sherylynn/wlroots` fork。

---

## 绝对不要破坏的现有主线

### X11 主线

不要因为 Wayland 调试修改或删除：

```text
termux/chroot/termux_all_in_one.sh
Termux:X11
XFCE/X11
x11vnc
noVNC
```

Wayland 是独立 profile。

### NewHome 控制链

目前容器 profile 重启已经稳定：

```text
chroot
  -> NewHome abstract Unix socket control bridge
  -> NewHome root execution
  -> restart X11 / restart Wayland
```

禁止重新引入：

- watchdog；
- `.container_restart_request`；
- 文件触发命令；
- 把控制命令塞进 4715 clipboard protocol；
- TCP 4716 控制端口。

### Clipboard

Wayland Stage3 调试期间不要顺手修改 noVNC / x11vnc / NewHome clipboard。

当前 Wayland 显示问题与剪贴板无关。

---

## 当前 Wayland 文件布局

主要入口：

```text
termux/chroot/termux_wayland_all_in_one.sh
termux/chroot/wayland/
termux/chroot/wayland/wlroots-anland/
```

重点文件：

```text
termux/chroot/wayland/anland_versions.sh
termux/chroot/wayland/install_anland_wayland.sh
termux/chroot/wayland/start_labwc_anland.sh
termux/chroot/wayland/wayland_doctor.sh

termux/chroot/wayland/wlroots-anland/README.md
termux/chroot/wayland/wlroots-anland/prepare_transport.sh
termux/chroot/wayland/wlroots-anland/anland_probe.c
termux/chroot/wayland/wlroots-anland/apply_stage1_018.py
termux/chroot/wayland/wlroots-anland/apply_stage2_input.py
termux/chroot/wayland/wlroots-anland/apply_stage3_presentation.py
termux/chroot/wayland/wlroots-anland/apply_stage3_018_fixups.py
termux/chroot/wayland/wlroots-anland/build_direct_backend.sh
termux/chroot/wayland/wlroots-anland/validate_direct_backend.sh
```

如果仓库实际文件名与这里略有变化，以 `master` 当前内容为准，不要凭 handoff 猜代码。

---

## 当前 Stage3 设计

### Stage1

提供：

- `WLR_BACKENDS=anland`；
- Anland daemon 连接；
- Android width/height/refresh；
- `ANLAND-1` output；
- fallback/reconnect。

### Stage2

提供：

- pointer absolute + relative；
- mouse buttons；
- wheel；
- keyboard evdev keycodes；
- touch down/up/motion/frame；
- consumer reconnect 后 input fd 重新挂载。

### Stage3

当前第一版不是最终 zero-blit allocator integration，而是：

```text
Android buffer_ready eventfd
        |
        v
wlr_output_send_frame()
        |
        v
Labwc normal render
        |
        v
wlroots output commit with DMA-BUF source
        |
        v
EGL import source DMA-BUF
        |
        v
EGL import current Anland selected DMA-BUF
        |
        v
GLES framebuffer blit
        |
        v
glFinish()
        |
        v
trigger_refresh()
```

这个路径允许一次 GPU-only blit。

当前目标不是直接 scanout；不要把它描述成 zero-copy/direct scanout。

当前可接受描述：

> GPU-only DMA-BUF presentation; no CPU framebuffer copy.

---

## 为什么第一版选 GPU blit

wlroots 的普通 compositor 流程希望使用自己 allocator/swapchain 得到 output buffer。

Anland 则相反：Android consumer 先提供一组可显示 DMA-BUF，并通过：

```text
get_selected_idx()
```

告诉 producer 当前应该写哪一块。

Weston-Anland 可以直接把这些 consumer-owned DMA-BUF 变成 renderbuffer。

为了不在第一次适配同时改：

- Labwc；
- wlroots allocator；
- wlroots swapchain；
- output backend；

Stage3 第一版采用 normal wlroots source DMA-BUF -> Anland target DMA-BUF 的 GPU blit。

等真机稳定后，下一阶段再研究自定义 allocator，把 Anland consumer buffers 直接纳入 wlroots output allocation，去掉 GPU blit。

---

## 真机环境重点

目标设备：

```text
Qualcomm SM8750
Adreno 830
Android rooted
Termux + Debian chroot
```

期望环境变量：

```bash
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TURNIP_KMD=kgsl
GALLIUM_DRIVER=freedreno
FD_FORCE_KGSL=1
XWAYLAND_FORCE_KGSL_SURFACELESS=1
ANLAND_DRM_DEVICE=/dev/dri/renderD128
```

如果实际设备没有 `/dev/dri/renderD128`，不要直接硬编码另一个设备。

先检查：

```bash
ls -l /dev/dri
ls -l /dev/kgsl-3d0
```

再确认 Mesa 当前实际用的 render node。

---

# 调试顺序

必须按层调试。不要一上来直接跑完整 Labwc 然后同时改十个文件。

## 0. 更新代码并保存现场

```bash
cd ~/sh
git pull

git rev-parse HEAD
```

把 HEAD SHA 写进调试日志。

本地 AI 每次修改前：

```bash
git status --short
git diff
```

禁止覆盖用户未提交修改。

---

## 1. 运行 doctor

Termux：

```bash
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh doctor
```

需要记录：

```text
Anland daemon 是否安装
Anland Android App 是否安装
/dev/kgsl-3d0
/dev/dri/renderD128
Debian 版本
Labwc 版本
系统 wlroots 版本
Anland socket
Weston bootstrap
.built
.ready
```

如果 doctor 已经报基础环境错误，不进入 Stage3 编译。

---

## 2. 单独验证 Anland transport

不要先跑 Labwc。

确保 Anland daemon 已启动，并打开 Anland Android Activity。

在 chroot：

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/prepare_transport.sh
/opt/newhome-wayland/anland-transport/bin/anland-probe
```

必须记录：

```text
screen width/height
refresh mHz
buffer count
selected index
每个 DMA-BUF:
  fd
  stride
  format
  modifier
  offset
input events
```

重点检查 SM8750 返回的 modifier。

如果 modifier 不是 `DRM_FORMAT_MOD_INVALID` / `LINEAR`，Stage3 EGL import 必须真的使用 `EGL_EXT_image_dma_buf_import_modifiers`；禁止忽略 modifier。

### transport probe 不通过时

只查：

```text
Anland daemon
Anland Android Activity
/tmp/anland socket
producer protocol
fd passing
buffer metadata
```

不要改 wlroots。

---

## 3. 构建 direct backend

Termux 总入口：

```bash
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh build-direct
```

或者 chroot：

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/build_direct_backend.sh
```

### 构建失败处理原则

当前 build 使用 pinned Debian `wlroots 0.18.2-3` + `-Werror`。

如果失败：

1. 先读取实际 Debian 源码接口；
2. 再修 overlay；
3. 不通过关闭 `-Werror` 掩盖问题；
4. 不升级 wlroots master；
5. 不换 Labwc 版本绕开 ABI。

每次编译修复需要记录：

```text
第一个 compiler error
涉及的真实 wlroots 0.18 header/API
为什么 overlay 与实际 API 不一致
修复点
```

不要一次批量猜 20 个 API 名称。

---

## 4. 确认构建产物，但不要启用

编译成功后应出现：

```text
/opt/newhome-wayland/wlroots-anland.built
```

不应自动出现：

```text
/opt/newhome-wayland/wlroots-anland.ready
```

检查：

```bash
cat /opt/newhome-wayland/wlroots-anland/BUILD_INFO
cat /opt/newhome-wayland/wlroots-anland.built
ls -l /opt/newhome-wayland/wlroots-anland/lib
```

期望 BUILD_INFO 类似：

```text
stage=3-gpu-dmabuf-blit
presentation=gpu-only-egl-dmabuf-blit
cpu_framebuffer_copy=no
```

---

## 5. 先检查 Labwc 是否真的加载我们的 wlroots

这是非常重要的一步。

执行 direct smoke 前确认：

```bash
LD_LIBRARY_PATH=/opt/newhome-wayland/wlroots-anland/lib \
ldd "$(command -v labwc)" | grep wlroots
```

必须解析到：

```text
/opt/newhome-wayland/wlroots-anland/lib/...
```

如果仍然指向系统 `/usr/lib/...`：

不要调 Stage3 presenter，因为代码根本没被运行。

先修运行时动态库加载。

---

## 6. direct smoke test

确保：

- 没有正在运行的 Labwc；
- 没有正在运行的 Weston；
- Anland daemon 已运行；
- Android Anland Activity 可见；
- `.built` 存在；
- `.ready` 暂时不存在。

运行：

```bash
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh validate-direct
```

或者：

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/validate_direct_backend.sh
```

主要日志：

```text
/tmp/newhome-wayland/direct-smoke.log
```

必须看到：

```text
Created Anland backend
或
Starting Anland backend

Anland Android consumer is ready

Anland presenter initialized

Anland first GPU DMA-BUF frame presented successfully
```

最后一条最重要。

它代表至少完成一次：

```text
source DMA-BUF import
-> target DMA-BUF import
-> GPU blit
-> trigger_refresh
```

---

# Stage3 常见失败分类

## A. `Unable to open Anland render node`

检查：

```bash
ls -l /dev/dri
ls -l /dev/kgsl-3d0
```

确认 chroot bind mount 和权限。

不要先把 backend 改成 SHM。

目标仍是 DMABUF/GPU。

---

## B. Labwc 使用 Pixman/SHM

典型结果：

```text
non-DMA-BUF source
```

检查：

```text
WLR_RENDERER=gles2
backend get_drm_fd()
backend get_buffer_caps()
render node permissions
Mesa Freedreno/KGSL load
GBM allocator creation
```

目标是让 Labwc output commit 中的 `state->buffer` 可以通过：

```c
wlr_buffer_get_dmabuf()
```

禁止为了“先看到画面”增加 CPU map/copy fallback。

---

## C. `DMA-BUF EGL import failed`

分别打印 source 和 target：

```text
width
height
format fourcc
modifier
plane count
fd
offset
stride
```

不要只打印 fd。

重点确认：

1. Android Anland format -> DRM FourCC 映射；
2. `PIXEL_FORMAT_RGBA_8888` 当前应对应实际内存布局，参考 Weston-Anland；
3. modifier extension 是否存在；
4. source/target 是不是同一 GPU 可 import；
5. fd 生命周期是否仍有效。

不要随意把 modifier 改成 INVALID 试图“骗过 EGL”。

---

## D. target framebuffer incomplete

检查：

```text
EGLImage import 是否成功
GL texture target
FBO attachment
target DRM format
Android buffer usage
Adreno 对 target modifier 的 renderability
```

如果 Android consumer buffer 可以 scanout/sampling 但不能 GLES render target，则 GPU blit 路线可能需要：

```text
source
-> intermediate GPU renderable buffer
-> GPU copy/export
-> Anland target
```

但仍禁止 CPU copy。

先保留真实错误日志，不要直接改成 glReadPixels。

---

## E. 画面全黑但日志说 present success

检查：

1. glBlitFramebuffer source/destination 绑定是否正确；
2. Y 方向；
3. RGBA/ABGR/BGRA format；
4. source/destination 尺寸；
5. target selected index；
6. 是否在 Android `buffer_ready` 前写 buffer；
7. `trigger_refresh()` 返回值；
8. consumer 是否随后切到另一个 selected idx。

建议临时加入仅调试用日志：

```text
frame seq
selected idx
source fourcc/modifier
target fourcc/modifier
trigger_refresh return
```

不要每帧永久刷大量日志，验证完收敛到 first-frame/错误日志。

---

## F. 画面颜色红蓝互换

高度怀疑 FourCC 映射，而不是 GPU 坏了。

先对照 Weston-Anland 的：

```text
protocol_format_to_drm()
```

不要凭名称 `RGBA_8888` 猜 DRM FourCC；Android 名称和内存字节布局容易混淆。

---

## G. 画面上下颠倒

Stage3 当前使用 framebuffer blit。

检查 source framebuffer 与 imported DMA-BUF 的坐标原点。

如果需要 Y flip，应在 GPU blit/texture coordinate 层明确处理，而不是 CPU 翻转。

---

## H. 第一帧正常，之后卡住

重点查 buffer-ready/refresh handshake：

```text
Android buffer_ready eventfd
-> consume eventfd
-> send frame
-> Labwc commit
-> GPU blit
-> trigger_refresh
-> Android next buffer_ready
```

不能用固定 60Hz timer 绕开 Anland consumer 同步。

Weston-Anland 的语义是权威参考。

---

## I. 重连 Android Activity 后黑屏

检查 fallback/reconnect 时是否正确：

```text
remove old buffer-ready source
remove input fd source
release/imported target EGLImages
try_exit_fallback()
重新获取 DMA-BUF set
重新 attach input
重新 attach buffer-ready fd
```

Android Activity 重建后，不可以继续使用旧 DMA-BUF fd/EGLImage。

---

# Input 调试

只有显示至少有一帧后再调 input。

检查：

```text
pointer absolute
pointer relative
button
wheel
keyboard
touch
```

键盘 keycode 应保持 Anland Weston 已验证的 evdev 语义。

不要额外做 Android keycode -> evdev 的猜测转换，除非真机日志证明 protocol 发来的不是 evdev code。

---

# XFCE 用户体验层调试

Direct backend 工作后再处理：

```text
xfce4-panel
Thunar
xfce4-terminal
xfce4-notifyd
XWayland apps
```

不要因为某个 XFCE 组件 Wayland 不兼容就修改 Stage3 backend。

先区分：

```text
backend/display bug
Labwc policy bug
XWayland bug
XFCE component compatibility bug
```

---

# Nested fallback

任何 direct 调试失败，都应该还能回到：

```text
Labwc
 -> wlroots Wayland backend
 -> Weston-Anland
 -> Android
```

启动：

```bash
NEWHOME_WAYLAND_MODE=nested \
  bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh restart
```

不要为了 direct 调试破坏 nested fallback。

---

# X11 recovery

如果 Wayland 整体不可用，必须可以通过 NewHome/托盘切回 X11。

不要删除原 X11 profile。

---

# `.ready` 规则

禁止脚本因为以下条件就创建 `.ready`：

```text
编译成功
Labwc 启动成功
Anland consumer connected
EGL init 成功
```

必须至少满足：

1. direct backend 实际加载；
2. Android consumer ready；
3. EGL presenter initialized；
4. source 是 DMA-BUF；
5. target Anland DMA-BUF import 成功；
6. 至少一次 GPU blit 成功；
7. `trigger_refresh()` 成功；
8. Android Activity 实际可见正确桌面；
9. 基本 pointer input 正常。

然后才允许：

```bash
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh activate-direct
```

创建：

```text
/opt/newhome-wayland/wlroots-anland.ready
```

---

# 本地 AI 修改纪律

## 一次只解决一个层次

优先顺序：

```text
transport
-> compile ABI
-> renderer/allocator
-> source DMABUF
-> target DMABUF import
-> blit
-> refresh handshake
-> reconnect
-> input
-> XFCE UX
```

不要同时改 display、input、clipboard、noVNC、NewHome。

## 每次修改必须记录

至少写清：

```text
现象
证据
根因判断
修改文件
为什么修改
验证命令
验证结果
仍未验证的部分
```

## 不要声称未验证内容成功

以下必须明确区分：

```text
代码静态检查通过
编译通过
真机 runtime 通过
Android 可见性通过
性能验证通过
```

没有真机结果时不能写“已修复”。

---

# 推荐调试日志模板

每次调试把结果追加到临时工作记录：

```text
Date:
Git HEAD:
Device: SM8750 / Adreno 830
Android build:
Debian:
Anland:
Labwc:
wlroots:

Command:

Observed:

Relevant log:

Layer classified as:
  [ ] Anland transport
  [ ] wlroots ABI
  [ ] renderer/allocator
  [ ] source DMA-BUF
  [ ] target DMA-BUF
  [ ] EGL/GLES blit
  [ ] buffer-ready/refresh
  [ ] reconnect
  [ ] input
  [ ] XFCE/XWayland

Change made:

Validation:

Remaining uncertainty:
```

---

# 性能阶段

功能稳定之前不要优化性能。

功能稳定后记录：

```text
idle CPU
GPU load
memory
frame pacing
refresh rate
window drag smoothness
browser scroll
power/temperature
```

至少比较：

```text
A: Termux:X11 + XFCE
B: Anland + Weston + Labwc nested
C: Anland + wlroots-anland + Labwc direct
```

Stage3 第一版 direct 有一次 GPU blit，因此如果 C 比 nested 明显好但仍有 GPU overhead，是符合预期的。

下一阶段优化目标才是：

```text
Anland consumer-owned DMA-BUF
 -> custom wlr_buffer / allocator integration
 -> Labwc direct render
 -> trigger_refresh
```

即去掉 Stage3 第一版的 GPU blit。

---

# 本轮本地 AI 的具体任务

请从以下顺序开始，不要重新设计架构：

1. `git pull` 并读本 handoff；
2. 读 `termux/chroot/wayland/wlroots-anland/README.md`；
3. 跑 `doctor`；
4. 跑 `anland-probe`，保存真实 SM8750 DMA-BUF metadata；
5. 跑 `build-direct`；
6. 根据第一个真实编译错误逐项修正 wlroots 0.18 ABI；
7. 编译成功后确认 Labwc 实际链接 isolated wlroots；
8. 跑 `validate-direct`；
9. 按错误分类定位 Stage3；
10. 只有 Android 真正显示正确 Labwc/XFCE 后才运行 `activate-direct`；
11. 每一轮有效修改直接提交到 `sh/master`，commit message 写清具体层，例如：

```text
fix: align anland backend with wlroots 0.18 output ABI
fix: import SM8750 anland dmabuf modifiers in EGL presenter
fix: reattach anland buffers after Android consumer reconnect
```

不要使用模糊的 `update` / `fix things` commit message。

---

## 成功标准

Stage3 本轮可以宣布完成的最低标准：

```text
NewHome / tray -> restart Wayland
        |
        v
Anland Android Activity foreground
        |
        v
Anland daemon
        |
        v
Labwc + custom wlroots-anland
        |
        v
XFCE panel / terminal / Thunar visible
        |
        v
mouse + keyboard basic input
        |
        v
no Weston process required
```

并且：

```text
no CPU framebuffer copy
nested fallback still works
X11 recovery still works
.ready only appears after runtime validation
```

如果上述任一项未验证，明确写“仍在调试”，不要提前宣布 direct backend 完成。
