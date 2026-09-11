# 远程桌面测试记录

- `2026-09-10-x11vnc-parameter-matrix.md`：x11vnc 的 XDamage、MIT-SHM、XFixes、刷新延时、scroll-copy 与 Tight 压缩对比。
- `termux/chroot/remote/rfb_load_client.c`：仓库内的轻量 RFB 负载客户端源码，用于自动验证认证、画面更新和分辨率变化。

编译测试客户端：

```sh
gcc -O2 -Wall -Wextra -Werror \
  -o /tmp/rfb_load_client \
  termux/chroot/remote/rfb_load_client.c \
  -lvncclient -lvncserver
```

运行 15 秒，使用与 noVNC 默认值一致的 compression 2 / quality 6：

```sh
/tmp/rfb_load_client 15 2 6
```

测试带 NewHome HiDPI 标志的远程调整大小（尺寸 2464x1429、DPI 192）：

```sh
/tmp/rfb_load_client 15 2 6 2464 1429 192
```

客户端读取现有 `/root/.vnc/passwd` 完成认证，但不会输出密码。
