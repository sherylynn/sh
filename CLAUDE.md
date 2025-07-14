# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概述 (Overview)

这是一个用于自动化系统管理、软件安装和个性化环境配置的 shell 脚本集合。脚本具有高度的跨平台兼容性，设计用于 Zsh 环境，并在 Linux、macOS、Windows (MINGW/WSL) 和 Android (Termux) 等多种操作系统上运行。

## 核心架构 (Core Architecture)

项目的核心是一个驱动整个环境的初始化和配置管理系统。

### 1. 核心驱动脚本: `win-git/toolsinit.sh`

- **功能**: 这是整个环境的入口点和核心驱动。它在 shell 启动时被加载（通常由 `.zshrc` 加载）。
- **职责**:
    - 检测当前操作系统 (`platform` 函数) 和硬件架构 (`arch` 函数)。
    - 设置全局变量和路径，如 `$INSTALL_PATH` (`~/tools`)。
    - 提供一系列强大的工具函数和别名，用于软件安装、配置管理、代理设置、文件下载等。
    - 实现了 `toolsRC` 机制来管理环境变量。

### 2. 环境持久化机制: `toolsRC`

- **目的**: 动态地、模块化地管理不同工具的环境变量，并使其持久化。
- **工作原理**:
    1. 其他脚本调用 `toolsRC "some_tool_name"` 函数。
    2. `toolsRC` 会在 `$HOME/tools/rc/` 目录下创建一个名为 `some_tool_name` 的文件。
    3. 同时，它确保主配置文件 `$HOME/tools/rc/allToolsrc` 被 `~/.zshrc` 加载。
    4. 最后，它将一行 `source` 命令追加到 `allToolsrc` 中，用于加载具体的 `some_tool_name` 文件。
- **使用方法**: 当你需要为一个新工具添加永久的环境变量时，应该：
    1. 使用 `TOOLSRC_FILE=$(toolsRC "your_tool_name")` 获取配置文件路径。
    2. 将 `export VAR=value` 这样的命令写入到 `$TOOLSRC_FILE` 中。

### 3. 跨平台兼容性

- 脚本通过内置的 `platform` 和 `arch` 函数来识别当前环境，并执行与平台相关的逻辑。这使得许多脚本无需修改即可在不同系统上运行。

## 常用开发任务和命令 (Common Development Tasks & Commands)

- **编辑核心配置**:
  - `zs`: 使用默认编辑器打开 `win-git/toolsinit.sh` 文件。
- **重新加载配置**:
  - `zr` 或 `zreload`: 重新加载 `toolsinit.sh` 使更改生效。
- **代理管理**:
  - `proxy` / `pgit`: 为系统或仅为 Git 设置本地代理。
  - `proxyw` / `pgitw`: 为 WSL 环境设置代理。
  - `proxyu` / `pgitu`: 为 USB 网络共享环境设置代理。
  - `unproxy` / `upgit`: 清除系统或 Git 的代理设置。
  - `proxys` / `pgits`: 查看当前代理状态。
- **Git 工作流**:
  - `zgs`: 查看 `~/sh` 仓库的状态 (`git status`)。
  - `zga`: 添加所有更改到 `~/sh` 仓库 (`git add --all`)。
  - `zg`: 提交 `~/sh` 仓库的更改 (`git commit -a`)。
  - `zp` / `zf`: 推送 (`push`) 或拉取 (`pull`) 包括 `~/sh` 在内的多个常用仓库。
- **与安卓设备交互 (scrcpy)**:
  - `sc` / `scrcpy_adb`: 通过 ADB 连接并镜像安卓设备。
  - `q*` (e.g., `qc`, `qcb`): 快速连接到预设的默认设备。
