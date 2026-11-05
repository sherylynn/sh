# NewHome chroot 桌面启动恢复边界

2026-11-05。termux_all_in_one.sh 的桌面入口不等于 Android Linux 小窗的打开入口。

- 完整启动负责容器、Wayland transport、source/XFCE 与远程桌面；打开/重开小窗只恢复 presentation，不应重跑整套清理。
- 文件只代表提示。pid 文件先写同目录 .new 再 rename；解析失败不能永久阻止新一代。Android worker.pid 归 NewHome Rust bootstrap watcher，此脚本不重复管理。
- transport start/stop 使用同一 transport.lock；锁文件本身不清理，避免锁 inode 分叉。acceptor child 必须关闭继承的锁 FD。
- 启动先检查 /proc/net/unix 中真实 AF_UNIX stream LISTEN；健康 listener 复用。无 listener 时，先有界等待旧的明确 acceptor 命令退出，再复查后仅删 stale socket。
- 不允许启动时递归删除整个 runtime、所有 X11 socket/lock、用户配置/身份。PID 可能复用，不能仅凭数字杀无关进程。
- alive-but-unready child 必须 TERM/KILL/reap 后才重试；禁止超时后直接 wait 无限阻塞。所有等待有上限，保留具体日志。
- XFCE 完整重启和 source 更换是显式动作；不能用“清理一切再试”替代 generation/source/presentation 就绪验证。
- 上层完成至少验证 worker/Binder、sourceAvailable、attach/first-present，Linux text-input.active 与 Android IMMS-served view/键盘/实际文本提交分别验收。

回归：在 sh 仓库运行
`python3 -m unittest discover -s tests -p test_wayland_transport_recovery.py -v`。
测试执行生产函数本身，使用独立临时目录、真实 Unix socket 和子进程，不触碰真实桌面：健康复用且锁不被子进程持有、stale socket 恢复、未就绪子进程有界退出。

完整跨层设计位于 newhome 仓库 `docs/LINUX_FLOATING_STARTUP_AND_IME_RECOVERY.md`。
