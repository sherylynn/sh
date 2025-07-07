# Termux 快捷方式启动方案说明

## 🔍 问题分析

在 Termux 中，通过桌面快捷方式启动脚本时，脚本执行完毕后会自动退出，导致后台进程被终止。

### 问题表现
- ✅ 直接在 Termux 中运行: `tstart` - 正常
- ❌ 通过快捷方式运行: `tstart.sh` - 服务启动后立即退出

## 🛠️ 解决方案

### 方案1: nohup 后台运行 (基础方案)
```bash
# 使用 nohup 保持进程在后台运行
nohup bash script.sh > /dev/null 2>&1 &
```

**优点:**
- 简单易用
- 不需要额外依赖

**缺点:**
- 进程可能不够稳定
- 无法直接查看输出

### 方案2: screen 会话管理 (推荐方案)
```bash
# 使用 screen 创建独立会话
screen -dmS session_name bash -c "cd /path && bash script.sh; exec bash"
```

**优点:**
- 进程稳定可靠
- 可以随时连接查看
- 支持多会话管理

**缺点:**
- 需要安装 screen
- 稍微复杂一些

## 🔧 使用方法

### 1. 重新生成快捷方式
```bash
cd ~/sh/termux/chroot
bash create_shortcuts.sh
```

### 2. 选择启动方案

#### 基础方案 (nohup)
```bash
# 启动所有服务
bash ~/.shortcuts/tstart.sh

# 启动 chroot 容器
bash ~/.shortcuts/cstart.sh
```

#### 推荐方案 (screen)
```bash
# 启动所有服务
bash ~/.shortcuts/tstart_screen.sh

# 启动 chroot 容器
bash ~/.shortcuts/cstart_screen.sh
```

### 3. 管理 screen 会话
```bash
# 查看所有会话
screen -ls

# 连接到服务会话
screen -r termux_services

# 连接到容器会话
screen -r chroot_container

# 断开连接 (保持会话运行)
# 在 screen 中按 Ctrl+A, 然后按 D
```

## 📊 方案对比

| 方案 | 稳定性 | 易用性 | 可管理性 | 推荐度 |
|------|--------|--------|----------|--------|
| 直接运行 | 高 | 高 | 高 | ✅ 最佳 |
| nohup | 中 | 高 | 低 | ⚠️ 基础 |
| screen | 高 | 中 | 高 | ✅ 推荐 |

## 🎯 最佳实践

### 1. 日常使用
- **推荐**: 使用 `tstart_screen.sh` 和 `cstart_screen.sh`
- **备选**: 使用 `tstart.sh` 和 `cstart.sh`

### 2. 服务管理
```bash
# 查看服务状态
bash ~/.shortcuts/tstatus.sh

# 停止服务
bash ~/.shortcuts/tstop.sh

# 停止容器
bash ~/.shortcuts/cstop.sh
```

### 3. 故障排查
```bash
# 查看 screen 会话
screen -ls

# 连接到会话查看日志
screen -r termux_services

# 强制终止会话
screen -S termux_services -X quit
```

## 🔧 安装 screen (如果需要)

如果您的 Termux 没有安装 screen，可以安装：

```bash
# 安装 screen
pkg install screen

# 或者使用 apt
apt update && apt install screen
```

## 📝 快捷方式配置

### 桌面快捷方式设置
1. 在 Android 桌面创建快捷方式
2. 指向 `~/.shortcuts/` 目录下的脚本
3. 建议使用 `*_screen.sh` 脚本

### 权限设置
```bash
# 确保脚本有执行权限
chmod +x ~/.shortcuts/*.sh
```

## 🔄 故障排除

### 1. 服务启动失败
```bash
# 检查脚本是否存在
ls -la ~/sh/termux/chroot/

# 手动运行测试
bash ~/sh/termux/chroot/termux_all_in_one.sh start
```

### 2. screen 不可用
```bash
# 检查 screen 是否安装
which screen

# 如果没有，使用 nohup 方案
bash ~/.shortcuts/tstart.sh
```

### 3. 会话管理
```bash
# 查看所有 screen 会话
screen -ls

# 清理断开的会话
screen -wipe

# 强制终止所有会话
pkill screen
```

## 📚 相关文档

- [README_进程搜索优化.md](./README_进程搜索优化.md) - 进程搜索优化说明
- [cli.sh](./cli.sh) - 主控制脚本
- [create_shortcuts.sh](./create_shortcuts.sh) - 快捷方式生成脚本 