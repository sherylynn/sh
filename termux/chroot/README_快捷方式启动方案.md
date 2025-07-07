# Termux 快捷方式启动方案

## 推荐方案

### tstart.sh - 启动所有服务（持续运行/不会退出）
```bash
bash ~/.shortcuts/tstart.sh
```
- 启动所有服务（X11 + chroot + sysv初始化系统）
- 使用 termux-x11 作为持续进程，不会退出
- 不需要 screen，不需要监控循环
- 兼容性最好

## 快捷方式创建步骤

1. 生成快捷方式脚本：
   ```bash
   bash ~/sh/termux/chroot/create_shortcuts.sh
   ```
2. 在 Android 桌面创建快捷方式，指向 ~/.shortcuts/tstart.sh
3. 或直接在 Termux 中运行：
   ```bash
   bash ~/.shortcuts/tstart.sh
   ```

## 故障排查
- 确保 termux-x11 已安装
- 检查脚本路径是否正确
- 检查 root 权限

## 总结
- 只保留 tstart.sh，采用持续运行方案，专门解决快捷方式退出问题
- 不再推荐 screen/监控/复杂方案，极简高兼容 