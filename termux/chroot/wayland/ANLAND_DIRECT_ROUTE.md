# Anland 直连路线与当前基线

## 唯一继续调试的架构

本项目后续只沿下面的直连路线推进：

```text
XFCE Wayland 客户端
        ↓
      Labwc
        ↓
wlroots-anland direct backend
        ↓
Anland display daemon（Termux UID）
        ↓
com.anland.termux Android Activity
```

Weston-Anland 嵌套路线仅保留为历史参考和安装兼容代码，不再把它当作本项目的
目标架构，也不应以它的测试结果否定 direct 路线。

## 2026-09-12 已验证事实

1. Anland 标准 APK 与 Termux 共享 UID。daemon 必须以 Termux UID 运行，不能
   长期以 root 身份运行，也不需要 `anland-compatible`。
2. Android Activity 必须在 Labwc direct backend 启动前连接 daemon，否则后端
   创建时无法取得 consumer 尺寸和四个缓冲区。
3. 纯红测试持续显示，证明 Android 目标 DMA-BUF 的导入、GPU 写入、刷新提交和
   fence 路径正常。
4. presenter 在 Labwc 主线程切换 EGL context 后必须恢复原来的 EGL display、
   context、draw surface 和 read surface。
5. Android BufferQueue 会轮转四个缓冲区。收到 buffer-ready 时应先向 Labwc
   发送 frame；如果本轮没有新 output commit，才把缓存的最后一帧复制到当前
   Android 缓冲区。只等待新 damage 会黑屏/超时，只重放缓存又会冻结新内容。
6. 应用以上两项修复后，真实 XFCE dock、panel 和鼠标在 15 秒后仍持续显示，
   因此 direct 路线已经跨过“只能红屏/黑屏”的阶段。

## 当前未完成问题

真实 XFCE 已经显示，但整体画面上下颠倒。当前默认的
`NEWHOME_ANLAND_FLIP_Y=1` 或源/目标 EGLImage 的坐标约定仍需校正。这个提交只
记录可工作的直连基线，不把方向问题标记为完成，也暂不创建正式 `.ready` 标记。

下一步只对 direct presenter 的纹理坐标或 Labwc output transform 做对照测试：

- 首选切换 `NEWHOME_ANLAND_FLIP_Y=0`，比较截图方向；
- 不修改四缓冲缓存、EGL context 恢复和 daemon/Activity 启动顺序；
- 方向正确且持续稳定后，再写入正式库并启用 `.ready`。

## 冷启动顺序

```text
停止旧 Labwc/XFCE/Anland
→ force-stop com.anland.termux
→ 以 Termux UID 启动 anland daemon
→ 启动 com.anland.termux/.MainActivity
→ 确认 consumer 已连接
→ 挂载或复用 chroot
→ 启动 Labwc direct backend
```

调试过程中必须保持单个 Labwc、单个 daemon 和单个 Android consumer，截图至少
间隔数秒复查，不能把一瞬间的首帧当作成功。
