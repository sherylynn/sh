# x11vnc / noVNC 参数实测（2026-09-10）

## 环境与目标

- Termux:X11：`:1`，测试时分辨率在 `1920x955` 与 `1904x952` 间切换。
- x11vnc 0.9.17 / LibVNCServer 0.9.15。
- noVNC 默认客户端参数：Tight、compression 2、quality 6。
- 目标：保持 noVNC 远程调整大小稳定，在此基础上逐项验证性能参数。

测试开始时的稳定基线：

```text
-noshm -shared -noxdamage -noxfixes -cursor arrow -nowf -noscr
-xrandr resize -reopen -loop500
```

测试结束后按实际使用需求启用 XFixes，并将固定箭头改为 `-cursor most`；其余性能相关参数不变。

Retina/HiDPI 浏览器计算出的宽度可能不是 8 的倍数，例如 2468。Termux:X11
会把它对齐为 2464；noVNC 补丁在发送前采用相同的向下对齐规则，避免服务端
返回 2464 后客户端再次请求 2468 所形成的持续调整循环。

测试使用 `termux/chroot/remote/rfb_load_client.c` 模拟已认证的 noVNC 客户端，并在持续画面更新时切换分辨率。CPU 数值只适合在本机同轮测试中横向比较，不能当作绝对基准。

## 结果

| 变量 | 结果 | 决定 |
| --- | --- | --- |
| 稳定基线 | CPU 约 2.61%，682 次更新，调整大小后连接和进程均存活 | 保留 |
| 启用 XDamage | CPU 约 6.36%；无客户端持续绘制时约 34% | 拒绝，保留 `-noxdamage` |
| 启用 MIT-SHM | `shmget(scanline) failed: Function not implemented`，监听子进程退出 | 拒绝，保留 `-noshm` |
| 启用 XFixes | CPU 约 2.24%，1264 次更新，未崩溃 | 为获得文本、缩放、拖动等动态鼠标形状，启用并使用 `-cursor most` |
| `-wait 5` | CPU 约 3.01%，641 次更新 | 拒绝 |
| `-defer 5` | CPU 约 3.15%，820 次更新；一次尺寸同步滞后 | 拒绝 |
| 启用 scroll-copy | CPU 约 3.14%，325 次更新，未观察到有效 CopyRect 命中 | 拒绝，保留 `-noscr` |
| compression 0 / quality 6 | CPU 约 2.47%，628 次更新；收益小且吞吐更低 | 不改 noVNC 默认值 |

部分早期轮次使用 compression 3 / quality 5，后续已把测试客户端修正为 noVNC 的 compression 2 / quality 6。不同客户端参数的轮次不作直接定量比较。

## SHM 根因

这不是 Termux:X11 启动参数造成的：

1. X 服务端确实公布了 MIT-SHM 扩展。
2. Debian 环境直接执行 `shmget` 仍返回 `ENOSYS`，且没有传统 Linux SysV SHM 的相关 `/proc/sys/kernel/shm*` 接口。
3. x11vnc 进程未被 seccomp 限制，因此不是沙箱拦截。
4. Termux:X11 源码把 `shmget` 映射到 Android 专用的 `libandroid_shmget` 兼容实现；它是给 bionic 程序使用的私有适配。
5. Debian 的 x11vnc 是 glibc 程序，不能安全地直接预加载宿主的 bionic `libandroid-shmem.so`。

所以 `-ac`、`-dpi`、`+extension` 等 Termux:X11 命令行参数无法修复 x11vnc 的 SHM。除非为 glibc/x11vnc 单独移植同等兼容层，否则必须使用 `-noshm`。

## 结论

本轮没有找到可以在当前设备上稳定提高性能的 x11vnc 开关。性能相关参数保持基线；XFixes 虽无性能收益，但其动态鼠标形状属于必要功能，因此生产配置启用 XFixes 并从固定 `-cursor arrow` 改为 `-cursor most`。后续若继续优化，应优先做真实浏览器中的画质、输入延迟和长时间稳定性验收，而不是同时开启多个服务端实验参数。
