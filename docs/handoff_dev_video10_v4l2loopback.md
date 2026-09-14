# NewHome Android Camera → `/dev/video10` V4L2 Handoff

## 目标

在保留现有 NewHome Android Camera2 → `@newhome.camera` SharedMemory 摄像头链的基础上，为 Debian chroot 增加一个真正的标准 V4L2 摄像头设备：

```text
/dev/video10
```

最终希望 Firefox、Chromium、Cheese、VLC、ffmpeg、OpenCV、WebRTC 等 Linux 程序把手机摄像头当作普通 webcam 使用，不需要应用专门理解 NewHome 或 PipeWire。

目标架构：

```text
Android Camera2 / ImageReader
        ↓ YUV_420_888
NewHome native NV21 packer
        ↓
2-slot SharedMemory + SCM_RIGHTS
        ↓
@newhome.camera
        ↓
newhome-camera-v4l2
        ↓ NV21
v4l2loopback
        ↓
/dev/video10
        ↓
Firefox / Chromium / Cheese / ffmpeg / OpenCV / WebRTC
```

现有 PipeWire 路径先保留作为回退：

```text
@newhome.camera
   ├─ newhome-camera-pipewire → PipeWire Video/Source
   └─ newhome-camera-v4l2     → /dev/video10
```

第一阶段不要同时运行两个 producer，先做后端二选一，避免多客户端和 Camera2 生命周期问题干扰定位。

---

## 1. 为什么在当前 chroot 架构里 `/dev/video10` 可行

当前 `termux/chroot/cli.sh` 的 `mount_part dev` 已经把 Android 宿主 `/dev` 整体 bind mount 到：

```text
/data/local/mnt/dev
```

也就是 Debian chroot 的 `/dev`。

当前逻辑本质上是：

```bash
mount -o bind /dev /data/local/mnt/dev
```

因此：

- Android 内核创建 `/dev/video10`；
- Termux 宿主立即能看到 `/dev/video10`；
- Debian chroot 也立即能看到同一个 `/dev/video10`；
- 不需要为摄像头额外做一次 bind mount；
- 不需要重启 chroot 才能看到设备节点。

关键点是：**chroot 只是共享 Android Linux kernel 的文件系统隔离环境，没有自己的 kernel。**

所以不能只在 Debian 里安装普通桌面 Linux 的 DKMS 包并期待产生独立内核设备。真正的 `v4l2loopback.ko` 必须能够加载进手机正在运行的 Android kernel。

---

## 2. 为什么推荐 `/dev/video10`，不要抢 `/dev/video0`

Android/Qualcomm 平台往往已经存在很多 `/dev/video*`，这些节点可能属于：

- camera ISP；
- codec；
- media pipeline；
- vendor camera 内部设备；
- 其它 V4L2 子系统。

它们不一定是 Linux 桌面意义上的 webcam。

因此第一版固定：

```text
/dev/video10
card_label = NewHome Camera
```

不要覆盖或替换已有 `/dev/video0`、`/dev/video1`。

先检查：

```bash
ls -l /dev/video* 2>/dev/null
ls -l /sys/class/video4linux 2>/dev/null
ls -l /sys/devices/virtual/video4linux 2>/dev/null
```

如果 `video10` 已被占用，再换到 20 或其它空闲编号，不要删除 Android 原有节点。

---

## 3. 第一关：确认当前 Android kernel 能加载外部模块

### 3.1 基础信息

在 Android root / Termux host 上记录：

```bash
uname -a
uname -r
cat /proc/version
getprop ro.product.device
getprop ro.build.version.release
getprop ro.build.version.security_patch
getprop ro.kernel.version 2>/dev/null || true
```

内核配置：

```bash
zcat /proc/config.gz 2>/dev/null | grep -E \
'CONFIG_MODULES=|CONFIG_MODULE_UNLOAD=|CONFIG_MODVERSIONS=|CONFIG_MEDIA_SUPPORT=|CONFIG_VIDEO_DEV=|CONFIG_V4L2_MEM2MEM_DEV='
```

理想情况至少：

```text
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODVERSIONS=y
CONFIG_MEDIA_SUPPORT=y
CONFIG_VIDEO_DEV=y
```

Android GKI 官方要求通用内核支持 loadable kernel modules；但这不代表任意第三方 `.ko` 一定能加载。具体设备仍可能受到：

- kernel ABI/KMI；
- exported symbol allowlist；
- vermagic；
- module version CRC；
- SELinux；
- 厂商 kernel 修改；
- 模块签名/加载策略

影响。

参考：

- Android Loadable Kernel Modules: https://source.android.com/docs/core/architecture/kernel/loadable-kernel-modules
- v4l2loopback: https://github.com/v4l2loopback/v4l2loopback

### 3.2 看系统现有模块

```bash
lsmod 2>/dev/null | head -50
cat /proc/modules | head -50
find /vendor/lib/modules /vendor_dlkm/lib/modules /system_dlkm/lib/modules \
  -maxdepth 2 -type f -name '*.ko' 2>/dev/null | head -50
```

如果手机本身已经动态加载很多 `.ko`，说明运行时模块机制确实在使用。

### 3.3 不要一开始集成 `tstart`

第一轮只手工测试：

```bash
su
insmod /path/to/v4l2loopback.ko \
  video_nr=10 \
  card_label="NewHome Camera" \
  exclusive_caps=1
```

随后立即检查：

```bash
lsmod | grep v4l2loopback
cat /proc/modules | grep v4l2loopback
ls -l /dev/video10
ls -l /sys/devices/virtual/video4linux/video10 2>/dev/null
```

如果成功，chroot 内无需重启，直接：

```bash
ls -l /dev/video10
```

应该能看到同一设备。

---

## 4. 如果 `insmod` 失败，必须记录什么

不要只写“模块加载失败”。完整记录：

```bash
insmod /path/to/v4l2loopback.ko \
  video_nr=10 card_label="NewHome Camera" exclusive_caps=1
RC=$?
echo "insmod rc=$RC"
dmesg | tail -100
logcat -d | tail -100
modinfo /path/to/v4l2loopback.ko 2>/dev/null || true
uname -r
```

重点区分：

### `invalid module format`

优先检查：

```bash
modinfo v4l2loopback.ko | grep -E 'vermagic|depends'
uname -r
```

通常表示 build kernel / vermagic 不匹配。

### `Unknown symbol ...`

表示模块使用了当前 kernel 没导出或 ABI/KMI 不允许的 symbol。

必须把所有 unknown symbol 原样保存，不要猜。

### `Required key not available` / signature 类问题

说明当前设备的 module 验证策略阻止模块。

### SELinux `avc: denied`

先记录：

```bash
getenforce
logcat -b all -d | grep -i 'avc: denied' | tail -100
dmesg | grep -i 'avc: denied' | tail -100
```

不要把 `setenforce 0` 当正式方案。临时 permissive 只能用于定位“是不是 SELinux”，正式设计必须恢复 enforcing。

---

## 5. v4l2loopback 模块怎么编译

不要直接在 chroot 执行：

```bash
apt install v4l2loopback-dkms
```

然后假设它就能工作。

Debian chroot 的 `uname -r` 虽然等于 Android kernel，但通常没有与手机完全匹配的 Android kernel build tree、generated headers、Module.symvers、toolchain 和 vendor config。

正确方向：

1. 确认当前手机 kernel 的源码来源和版本；
2. 获取与运行内核匹配的 kernel build tree / config；
3. 获取匹配的 `Module.symvers` 或 GKI/KMI 构建环境；
4. 使用 Android kernel 对应 clang toolchain；
5. 在该 kernel tree 下 external-module build `v4l2loopback`；
6. 对生成 `.ko` 检查 vermagic / symbols；
7. 再推到手机手工 `insmod`。

v4l2loopback 上游要求 kernel headers/build environment 与实际运行 kernel 匹配；Android 上要求比普通 Debian 更严格。

上游参考：

https://github.com/v4l2loopback/v4l2loopback

在不知道当前 OnePlus/SM8750 kernel 精确 build 环境之前，不要在文档里硬编码某一个 kernel repo 或 toolchain 版本。

---

## 6. 模块成功后的最小验证

模块成功后先完全不碰 NewHome。

在 chroot 安装测试工具：

```bash
apt-get update
apt-get install -y v4l-utils ffmpeg \
  gstreamer1.0-tools gstreamer1.0-plugins-good
```

查看能力：

```bash
v4l2-ctl -d /dev/video10 --all
v4l2-ctl -d /dev/video10 --list-formats-ext
```

确认 card name：

```bash
v4l2-ctl -d /dev/video10 --info
```

### 6.1 先用纯 Linux 假视频喂 `/dev/video10`

不要一上来就调 Android Camera2。

例如 GStreamer：

```bash
gst-launch-1.0 -v \
  videotestsrc is-live=true \
  ! videoconvert \
  ! video/x-raw,format=YUY2,width=640,height=480,framerate=30/1 \
  ! v4l2sink device=/dev/video10 sync=false
```

另一个终端验证：

```bash
ffplay -f v4l2 /dev/video10
```

或：

```bash
v4l2-ctl -d /dev/video10 --stream-mmap=3 --stream-count=300 --stream-to=/dev/null
```

如果假视频都无法读，问题在：

```text
v4l2loopback / format / V4L2 consumer
```

此时不要碰 NewHome。

---

## 7. NV21 是现有 NewHome 链的优势

当前 NewHome camera bridge 已经把 Android `YUV_420_888` 打包为连续 NV21：

```text
Y plane
V/U interleaved plane
```

现有 wire protocol 中：

```text
NH_FORMAT_NV21 = 2
```

当前 `newhome_camera_pipewire.c` 已经完成：

- 连接 abstract Unix socket `@newhome.camera`；
- `HELLO`；
- `START`；
- 接收 SHM FD；
- mmap 两槽 SharedMemory；
- 接收 `READY`；
- 使用 generation 防止旧 session buffer；
- `DONE` 归还 slot；
- `STOP` 控制 Android Camera2 生命周期。

因此 V4L2 版不要重新设计 Android 协议。

最小改造应复用这一整段 client 协议，只替换输出端：

```text
当前：
@newhome.camera
  → SharedMemory NV21
  → PipeWire pw_stream

新增：
@newhome.camera
  → SharedMemory NV21
  → V4L2 OUTPUT producer
  → /dev/video10
```

v4l2loopback 上游格式列表包含 `V4L2_PIX_FMT_NV21`，所以第一版优先尝试直接 NV21，不要先引入 libyuv / ffmpeg 色彩转换。

格式参考：

https://github.com/v4l2loopback/v4l2loopback/blob/main/doc/v4l2_formats.txt

---

## 8. `newhome-camera-v4l2` 建议实现

建议新增：

```text
termux/chroot/newhome-camera-bridge/
  newhome_camera_pipewire.c
  newhome_camera_v4l2.c
```

后续如果两份代码重复过多，再抽：

```text
newhome_camera_client.c
newhome_camera_client.h
```

第一轮真机验证不要为了“架构漂亮”先做大重构。

### 8.1 打开设备

```c
int fd = open("/dev/video10", O_WRONLY | O_CLOEXEC);
```

生产者侧要把 loopback 设备配置为：

```text
width  = Android 实际返回宽度
height = Android 实际返回高度
format = V4L2_PIX_FMT_NV21
fps    = 30/1
```

使用标准 V4L2 ioctl：

```text
VIDIOC_QUERYCAP
VIDIOC_S_FMT
VIDIOC_S_PARM
```

第一版可先尝试最简单的 `write()` producer：

```c
write(fd, frame, width * height * 3 / 2);
```

如果当前 v4l2loopback / Android kernel 组合要求 streaming I/O，再实现 `REQBUFS + QBUF + STREAMON`。

不要在未验证前一次写完整 MMAP streaming producer。

### 8.2 建议启动顺序

```text
1. connect @newhome.camera
2. receive HELLO
3. START（仅用于拿到真实尺寸/SHM）
4. receive SHM + width/height/NV21
5. STOP
6. open /dev/video10 producer
7. VIDIOC_S_FMT(NV21, real width/height)
8. 等 consumer / 确认开始输出
9. START Android Camera2
10. READY → write frame → DONE
11. consumer 结束 → STOP Camera2
```

“如何可靠判断 V4L2 consumer 已经真正开始使用 `/dev/video10`”是 V4L2 路线需要单独验证的生命周期问题。

第一版允许先让 producer 常驻并一直 START Camera2，证明视频链正确；但是这只能算 `STREAM PASS`，不能算最终 `LIFECYCLE PASS`。

最终必须恢复原设计目标：

```text
没有 Linux consumer
→ Camera2 关闭
→ Android 摄像头隐私指示灯熄灭

Linux consumer 打开 /dev/video10
→ Camera2 打开
→ 开始持续出帧
```

不要为了 `/dev/video10` 牺牲现有按需摄像头生命周期。

---

## 9. `exclusive_caps=1` 的意义

推荐第一轮：

```bash
insmod v4l2loopback.ko \
  video_nr=10 \
  card_label="NewHome Camera" \
  exclusive_caps=1
```

v4l2loopback 上游说明：

- producer 尚未连接时，设备表现为 OUTPUT；
- producer 连接后，设备表现为 CAPTURE；
- 这样对 Chrome/WebRTC 等严格检查 capture capability 的程序更友好。

因此如果出现：

```text
ffmpeg 能看到
但 Chromium / WebRTC 看不到
```

优先检查 `exclusive_caps=1`，不要先改 NewHome Camera2。

上游说明：

https://github.com/v4l2loopback/v4l2loopback#options

---

## 10. `tstart` 集成建议：必须在手工验证成功后做

当前总入口：

```text
termux/chroot/termux_all_in_one.sh
```

现在流程：

```text
check_requirements
→ start_base_services
→ start_x11
→ start_chroot
```

建议最终增加一个宿主侧函数：

```bash
ensure_newhome_v4l2loopback() {
    [ -e /dev/video10 ] && return 0

    local ko="/data/local/newhome/v4l2loopback.ko"
    [ -f "$ko" ] || {
        log "未找到 v4l2loopback.ko，跳过 /dev/video10"
        return 0
    }

    sudo insmod "$ko" \
        video_nr=10 \
        card_label="NewHome Camera" \
        exclusive_caps=1 || {
        log "v4l2loopback 加载失败，保留 PipeWire 路径"
        return 0
    }

    [ -e /dev/video10 ] || {
        log "模块已加载但 /dev/video10 未出现"
        return 0
    }

    log "NewHome V4L2 camera ready: /dev/video10"
}
```

候选顺序：

```text
check_requirements
→ start_base_services
→ start_x11
→ ensure_newhome_v4l2loopback
→ start_chroot
```

或者把模块加载放在 `start_chroot` 前。

### 重要：失败不能阻止 Linux 启动

摄像头不是 `tstart` 的核心依赖。

因此必须：

```text
v4l2loopback 加载失败
→ 打日志
→ 继续启动 chroot
→ PipeWire 摄像头方案仍可用
```

不要因为 `/dev/video10` 实验失败导致整个 `tstart` 失败。

---

## 11. 模块文件建议位置

不要把 `.ko` 提交进 `sh` Git 仓库。

内核模块与设备 kernel build 强绑定，而且是二进制产物。

建议本机路径：

```text
/data/local/newhome/v4l2loopback.ko
```

Git 中只保留：

- 构建说明；
- kernel commit/config/toolchain 信息；
- SHA256；
- 自动加载脚本；
- 验收记录。

例如：

```bash
sha256sum /data/local/newhome/v4l2loopback.ko
modinfo /data/local/newhome/v4l2loopback.ko
```

把结果写进：

```text
docs/camera-v4l2-tests/
```

---

## 12. `tstop` 是否要 `rmmod`

第一版建议：**不要自动 `rmmod`。**

原因：

- 模块本身空闲时开销很小；
- `rmmod` 在 Firefox/Chromium/测试程序仍握着设备 FD 时会失败；
- 自动卸载会增加 race；
- 调试阶段保留 `/dev/video10` 更方便。

先只停止 producer：

```text
newhome-camera-v4l2
```

如果以后确认卸载稳定，再加可选：

```bash
sudo rmmod v4l2loopback
```

运行时加载/卸载是允许的，不需要开机加载。

---

## 13. 推荐的分阶段调试路线

### Phase A：只证明 kernel module

目标：

```text
insmod 成功
/dev/video10 出现
chroot 自动能看到
```

验收：

```bash
lsmod | grep v4l2loopback
ls -l /dev/video10
v4l2-ctl -d /dev/video10 --all
```

### Phase B：只证明 v4l2loopback 视频

目标：

```text
videotestsrc
→ /dev/video10
→ ffplay/其它 consumer
```

不涉及 Android Camera2。

### Phase C：NewHome → `/dev/video10`

目标：

```text
@newhome.camera
→ SharedMemory NV21
→ newhome-camera-v4l2
→ /dev/video10
```

先证明持续 300 / 3000 帧。

### Phase D：桌面应用

依次验证：

```text
ffplay / ffmpeg
Cheese
Firefox WebRTC
Chromium WebRTC
OpenCV
```

Firefox/Chromium 不要作为第一层测试工具，它们引入了 sandbox、portal、permission、WebRTC 枚举等额外变量。

### Phase E：生命周期

最终必须验证：

```text
没有 consumer：Camera2 不占用
打开 consumer：Camera2 开启
关闭 consumer：Camera2 很快释放
```

### Phase F：接入 `tstart`

只有 A-E 成功后才改：

```text
termux_all_in_one.sh
```

不要一边调 kernel module 一边改生产启动链。

---

## 14. 验收命令建议

### Android/host

```bash
uname -a
uname -r
cat /proc/modules | grep v4l2loopback
ls -l /dev/video10
ls -l /sys/devices/virtual/video4linux/video10
```

### chroot

```bash
ls -l /dev/video10
v4l2-ctl -d /dev/video10 --info
v4l2-ctl -d /dev/video10 --all
v4l2-ctl -d /dev/video10 --list-formats-ext
```

### NewHome bridge

```bash
grep -F newhome.camera /proc/net/unix
logcat -v time -s NewHomeCameraBridge
```

### producer

建议日志至少打印：

```text
camera index
real width/height
V4L2 negotiated format
frame bytes
READY count
V4L2 write count
write errors / short writes
START / STOP lifecycle
```

每 300 帧打印一次，不要每帧刷日志。

---

## 15. 建议的状态判定

使用以下结论，避免“看到 `/dev/video10` 就算成功”：

```text
MODULE PASS
    v4l2loopback.ko 成功加载

DEVICE PASS
    /dev/video10 在 Android host 与 chroot 同时可见

LOOPBACK PASS
    Linux videotestsrc → /dev/video10 → consumer 正常

BRIDGE PASS
    NewHome SharedMemory NV21 → /dev/video10 正常

STREAM PASS
    ≥300 帧连续真实 Camera2 视频

APP PASS
    Firefox/Chromium/Cheese 至少一个真实应用正常

LIFECYCLE PASS
    consumer 开关能正确驱动 Camera2 开启/释放

STABILITY PASS
    重复开关、长时间运行无明显 FD/内存/session 泄漏

DEVICE VALIDATED
    上述全部通过
```

---

## 16. 回滚必须非常简单

如果 `/dev/video10` 路线失败，不影响当前 PipeWire 摄像头链。

回滚：

```bash
pkill -x newhome-camera-v4l2 2>/dev/null || true
sudo rmmod v4l2loopback 2>/dev/null || true

bash /root/sh/termux/chroot/newhome_camera_bridge.sh start
```

然后继续使用：

```text
PipeWire newhome.camera
```

不要在 V4L2 真机验证通过之前删除：

```text
newhome_camera_pipewire.c
newhome_camera_bridge.sh
```

---

## 17. 第一轮本地 AI 应该做什么

给后续本地 Agent 的直接任务：

> 不要先改 NewHome Camera2，也不要先改 `tstart`。保持当前 `@newhome.camera` + SharedMemory + NV21 协议不变。第一步采集手机当前 kernel 的 `uname -r`、config、现有 modules、vermagic/KMI 信息，并为该精确 kernel 构建和手工加载 `v4l2loopback.ko`。目标先只是稳定得到 `/dev/video10`，并用纯 Linux `videotestsrc → /dev/video10 → ffplay` 完成 LOOPBACK PASS。之后再基于现有 `newhome_camera_pipewire.c` 协议部分做最小 `newhome_camera_v4l2.c`，直接把 Android SharedMemory 中的 NV21 帧写入 `/dev/video10`。只有 MODULE/DEVICE/LOOPBACK/BRIDGE/LIFECYCLE 全部验证后，才把运行时 `insmod` 和 producer 启动接入 `termux_all_in_one.sh` 的 `tstart`。所有失败的 `insmod` 错误、dmesg、vermagic、Unknown symbol 和测试结果都保存到 `docs/camera-v4l2-tests/`，不要重复试错。

---

## 18. 当前最重要的三个未知量

1. 当前 OnePlus/SM8750 Android kernel 的精确 source/config/Module.symvers/KMI 环境能否拿到并匹配；
2. 当前 kernel 是否允许手工加载构建出来的 `v4l2loopback.ko`；
3. v4l2loopback 当前版本在该 Android kernel 上能否稳定协商 `V4L2_PIX_FMT_NV21` 并被 Firefox/Chromium 识别。

这三项没有真机数据前，不要过早修改生产启动流程。
