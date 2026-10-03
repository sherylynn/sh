# Linux 默认 NewHome Rust ADB

`win-git/server_configure.sh` 的实际部署链为：

1. `debian/termux_chroot_desktop_setup.sh` 构建 NewHome 的 `linux/scripts/build-rust-candidate-deb.sh` 并安装本次精确产物，不再构建历史 Python 包。
2. Rust 包包含 `newhome-adb`、`newhome-adb-server`，安装脚本自动设置默认入口。
3. `win-git/newhome_rust_adb_setup.sh` 再次幂等核验，失败则停止系统配置。

默认 `/usr/local/bin/adb` 是指向 `/usr/bin/newhome-adb` 的符号链接。保留发行版 `/usr/bin/adb` 及 SDK 原生二进制；若原先 `/usr/local/bin/adb` 属于其它实现，先备份为 `adb.pre-newhome`，不覆盖已有备份。

Android chroot 中，Rust ADB 通过仅 root 可访问的 `@newhome_control_v1` 请求 Android 唯一网络 owner。已认证并具备 ADB tunnel 能力的在线设备自动列为 `newhome:<deviceId>`，不需要直连目标 `5555` 或重新生成桌面 RSA 身份。

```sh
command -v adb
adb version
adb devices
adb -s newhome:<deviceId> shell getprop ro.product.model
```

默认 Rust smart-socket server 使用 loopback `5038`，不接管其它会话的官方 `5037`。USB 枚举、完整官方 CLI 兼容仍有未实现边界，不能把默认命令切换理解为所有官方功能都已替代。原生 TCP ADB 必须使用合法的既有密钥；损坏密钥不会阻止 NewHome 通道启动，也不会被重新生成或替换。

验收必须包括命令正常结束、文件 push/pull 字节一致和保留数据安装。设备列表或单次输出不等于稳定性通过。2026-10-03 已通过默认入口及包部署测试；红米型号输出和小文件 push 有成功证据，但 Aware 再次中断，回读和红米升级尚未通过。

测试入口：`bash tests/newhome_rust_adb_setup_test.sh`。使用隔离目录验证实际入口执行、备份、幂等和缺少产物拒绝，不执行整套系统配置。
