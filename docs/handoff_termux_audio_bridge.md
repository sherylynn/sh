# Handoff: Termux/X11 Chroot 音频桥研究

日期：2026-09-09

## 背景

当前手机 Linux 桌面环境使用：

```text
Android / Root
  -> Termux
     -> termux/chroot/termux_all_in_one.sh (tstart)
        -> PulseAudio service
        -> Termux:X11
        -> chroot Debian
           -> XFCE4
           -> x11vnc / noVNC
```

目标不是切换到 Wayland，而是在 **保留 XFCE4、Termux:X11、x11vnc/noVNC 现有链路** 的前提下，让 chroot Linux 的声音能够输出到 Android，并尽可能把 Android 麦克风暴露给 chroot Linux。

参考项目：

- Anland: https://github.com/SuperTurtleDev/anland
- Termux:X11: https://github.com/termux/termux-x11

## 关键结论

Anland 的音频能力并不是 Wayland 协议本身提供的。

Anland Android consumer 侧存在独立的 `native_audio.c`，使用 Android AAudio；Linux producer 侧存在独立的 `anland_audio.c`，使用 PipeWire，并通过独立 socket 传递 PCM 和音频格式。

因此显示链路和音频链路可以拆开：

```text
显示：XFCE4 -> X11 -> Termux:X11

音频：Linux app -> PulseAudio -> Termux PulseAudio -> Android audio backend
```

没有必要为了声音迁移到 Wayland，也没有必要重新编译 Termux:X11。

## 当前仓库已有基础

`termux/server_pulseaudio.sh` 已经会启动 Termux PulseAudio，并加载：

```text
module-native-protocol-tcp
```

当前监听目标为 localhost，因此 chroot 与 Termux 共享同一 Android 网络命名空间时，可以直接通过：

```text
PULSE_SERVER=tcp:127.0.0.1:4713
```

让 chroot 内的 PulseAudio 客户端直接连接 Termux PulseAudio server。

这意味着 Linux 桌面不一定需要运行自己的 PulseAudio server。

## 新增实验工具

文件：

```text
termux/termux_audio_bridge.sh
```

这个脚本当前只做实验和诊断，不修改 Termux:X11，不修改 XFCE4，不修改 x11vnc/noVNC。

### 命令

```bash
bash ~/sh/termux/termux_audio_bridge.sh doctor
bash ~/sh/termux/termux_audio_bridge.sh start
bash ~/sh/termux/termux_audio_bridge.sh status
bash ~/sh/termux/termux_audio_bridge.sh chroot-config
bash ~/sh/termux/termux_audio_bridge.sh test
bash ~/sh/termux/termux_audio_bridge.sh stop
```

### doctor

检查：

- `pulseaudio`
- `pactl`
- PulseAudio 是否正在运行
- `module-aaudio-sink`
- `module-aaudio-source`
- `module-sles-sink`
- `module-sles-source`
- chroot `cli.sh`
- 当前 sinks / sources / modules

真机研究的第一步必须先运行：

```bash
bash ~/sh/termux/termux_audio_bridge.sh doctor
```

请保留完整输出。

### start

流程：

1. 优先复用已经由 `tstart` 启动的 PulseAudio。
2. 如果 PulseAudio 没运行，尝试启动 Termux PulseAudio。
3. 确保 `module-native-protocol-tcp` 已加载。
4. 优先尝试 Android AAudio backend。
5. AAudio 不可用时尝试 OpenSL ES backend。
6. 打印当前 sinks / sources。

脚本不会停止或替换整个 PulseAudio server。

### chroot-config

在已经启动的 chroot 内写入：

```text
/etc/profile.d/termux-pulse.sh
```

内容核心为：

```bash
export PULSE_SERVER=tcp:127.0.0.1:4713
```

这样重新进入 chroot 后，支持 PulseAudio 的 Linux 应用会优先连接 Termux PulseAudio。

### stop

目前只尝试卸载 localhost 的 native TCP bridge，不停止 PulseAudio 本体，以免影响 `tstart` 的现有服务生命周期。

## 真机测试顺序

### 1. 启动原有桌面环境

```bash
tstart
```

确认 X11、XFCE4、noVNC 等原有功能正常。

### 2. 运行 doctor

```bash
bash ~/sh/termux/termux_audio_bridge.sh doctor
```

重点记录：

```text
module-aaudio-sink
module-aaudio-source
module-sles-sink
module-sles-source
```

是否存在。

还要记录：

```bash
pactl list short sinks
pactl list short sources
pactl list short modules
```

### 3. 启动实验音频桥

```bash
bash ~/sh/termux/termux_audio_bridge.sh start
```

如果有 sink，先验证 Termux 自身是否可以播放声音。

如果没有自动测试音频，可自己准备 wav/ogg：

```bash
paplay /sdcard/Download/test.wav
```

### 4. 配置 chroot

确保 chroot 已经由 `tstart` 启动，然后：

```bash
bash ~/sh/termux/termux_audio_bridge.sh chroot-config
```

重新进入：

```bash
cshell
```

检查：

```bash
echo $PULSE_SERVER
pactl info
pactl list short sinks
pactl list short sources
```

预期：

```text
PULSE_SERVER=tcp:127.0.0.1:4713
```

并且 chroot 内 `pactl info` 应显示正在连接 Termux PulseAudio server。

### 5. Linux 应用播放测试

优先使用简单客户端，随后再测试 Firefox。

例如：

```bash
paplay test.wav
```

或 VLC / mpv。

最后测试：

- Firefox 网页视频
- XFCE 系统声音
- 蓝牙耳机切换
- 手机扬声器
- 有线/USB 音频（如果设备支持）

## 麦克风研究

麦克风是否可以直接通过 Termux PulseAudio 暴露，目前是最大未知项。

需要真机确认 Termux 当前 PulseAudio 包内到底有哪些 Android source backend。

重点看：

```bash
find $PREFIX/lib -name 'module-*source*.so' | sort
pactl list short sources
```

如果存在并能加载：

```text
module-aaudio-source
```

或：

```text
module-sles-source
```

则测试 chroot：

```bash
pactl list short sources
parecord /tmp/mic.wav
```

录几秒后停止，再：

```bash
paplay /tmp/mic.wav
```

如果 Termux PulseAudio 构建没有可用 Android source，则不能简单依赖官方 `termux-microphone-record` 作为实时音频设备。

原因：Termux:API 麦克风接口更偏录制/文件式调用，不适合作为低延迟连续 PCM source。

## 失败分支

### A. Termux 有 Android sink，chroot 播放成功

这是理想结果。

下一步：

1. 把 `termux_audio_bridge.sh start` 纳入 `tstart`。
2. 确保 chroot profile 自动配置。
3. 测试 Firefox、VLC、蓝牙切换和休眠恢复。
4. 根据延迟和稳定性决定 TCP 还是 Unix socket。

### B. Termux 有 sink，但 chroot 连不上

检查：

```bash
ss -ltnp | grep 4713
pactl list short modules | grep native-protocol-tcp
```

chroot 内：

```bash
PULSE_SERVER=tcp:127.0.0.1:4713 pactl info
```

如果 TCP 有异常，可以下一步改为共享 PulseAudio Unix socket。

当前 `mount_config.conf` 已经 bind mount Termux `$PREFIX/tmp` 到 chroot `/tmp`，因此 Unix socket 路线也很适合当前架构。

### C. Termux 没有 AAudio/OpenSL ES sink

先确认当前 Termux PulseAudio 包真实提供的 modules。

不要立刻切 Wayland，也不要改 Termux:X11。

下一阶段考虑一个独立 Android Audio Bridge APK：

```text
Linux PulseAudio/PipeWire
  <-> Unix socket
  <-> Android companion app
  <-> AAudio
```

实现可以直接参考 Anland 的：

```text
consumers/anland_v5/android_consumer/app/src/main/jni/native_audio.c
libdisplay_producer/anland_audio.c
```

只借音频部分，不使用 Anland 的显示协议。

### D. 扬声器成功，麦克风失败

这是很可能出现的中间状态。

保持现有扬声器方案不动。

麦克风单独开发 Android companion bridge，让 Android app 获取 `RECORD_AUDIO` 权限，再把 PCM 通过 Unix socket 提供给 chroot 的 PipeWire/PulseAudio virtual source。

这样仍然不需要修改 Termux:X11。

## 为什么目前不采用 Termux:API 音频转发

Termux:API 适合命令式 Android 功能调用，但官方麦克风接口主要面向录音任务，不是持续低延迟 PCM 设备协议。

如果采用：

```text
termux-microphone-record -> 文件 -> Linux
```

会产生：

- 高延迟
- 启停间隙
- 编解码/文件 IO
- 难以作为浏览器实时麦克风 source

因此 Termux:API 可以用于功能验证，但不作为当前正式实时音频方案。

## 与 Anland 的关系

Anland 给本项目最有价值的启示不是“换 Wayland”，而是：

> Android 显示、Android 音频、Linux 桌面可以是相互独立的桥。

Anland Android 端使用 AAudio；Linux 端通过 PipeWire 创建虚拟 sink/source，再通过 socket 双向传 PCM。

如果 Termux PulseAudio 自带 Android backend 已经能满足需求，我们甚至不需要重复实现 Anland 的 audio bridge。

如果不能满足，则再抽象出独立的 Android audio bridge。

## 当前原则

在真机结果出来前：

- 不修改 Termux:X11。
- 不迁移 Wayland。
- 不替换 XFCE4。
- 不移除 x11vnc/noVNC。
- 不把实验逻辑强制接入 `tstart`。
- 优先验证已有 Termux PulseAudio 能力。
- 扬声器和麦克风分开验证。

## 下一位 Agent 的输入

拿到真机测试结果后，至少需要以下输出：

```bash
bash ~/sh/termux/termux_audio_bridge.sh doctor
bash ~/sh/termux/termux_audio_bridge.sh start
bash ~/sh/termux/termux_audio_bridge.sh chroot-config
bash ~/sh/termux/termux_audio_bridge.sh test
```

以及：

```bash
find $PREFIX/lib -name 'module-*aaudio*.so' -o -name 'module-*sles*.so'
pactl list short sinks
pactl list short sources
pactl list short modules
```

chroot 内：

```bash
echo $PULSE_SERVER
pactl info
pactl list short sinks
pactl list short sources
```

基于这些结果再决定：

1. 直接整合 Termux PulseAudio；
2. 改 Unix socket；
3. 只补 Android 麦克风 bridge；
4. 完整做独立 Android AAudio bridge。
