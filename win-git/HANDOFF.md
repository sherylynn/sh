# 工作交接记录（2026-08-18）

给接手的 AI / 协作者：先读本节「环境注意事项」，否则命令全都跑不起来。

## 0. 环境注意事项（重要）

- 本机为 Android 上的 Debian 13 arm64 chroot/proot 环境。
- **宿主 TRAE 的 Shell 工具当前不可用**（报 `ToolHost is not running for shell_execute_strategy=tool_host`）。
  执行命令请改走 MCP：`run_mcp(server=integrated_code_mode, tool=Exec)` 里 `await tools.run_command({command})`。
- run_command 每次在新沙箱中执行，**初始 PATH 不含系统目录**，命令开头先：
  `export PATH=/root/tools/node/node-v22.22.1-linux-arm64/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH`
- **/tmp 不跨命令持久**（每条命令独立沙箱），临时产物放真实路径（如 /root/tools/.../build）。
- /sdcard 是 FUSE 挂载：glob 会出现"幽灵匹配"（glob 命中、stat 却 ENOENT），脚本里已做二次校验。
- 用户沟通语言：中文。

## 1. 已完成事项

1. `traework-desktop.sh`：无参运行默认 `--donor /sdcard/Download/TraeCode_CN-linux-arm64.deb --nsbox`（commit `09a6b1e`，已推送 origin/master）。
2. WorkBuddy DMG → Linux 移植可行性研究：`/root/sh/workbuddy-port-report/workbuddy-port-report.html`。
3. `workbuddy-desktop.sh` 编写完成，本次修复 4 个问题后**端到端跑通**（未提交 git）。

## 2. workbuddy-desktop.sh 本次修复的问题

| # | 问题 | 修复 |
|---|------|------|
| 1 | `npm install @electron/asar` 默认装 v4（ESM），CLI 是 `bin/asar.mjs`，脚本硬编码 v3 的 `bin/asar.js` → MODULE_NOT_FOUND | 不再走 CLI，自写 `asar-extract.mjs` 用 `extractAll()` API |
| 2 | electron-builder 裁掉了 DMG 内 unpacked 目录中其他平台二进制，但 asar 头仍引用 → extractAll 读外部文件 ENOENT 整体失败 | 解包器对缺失外部文件建空占位重试，随后 unpacked 目录叠加拷贝覆盖回真实文件 |
| 3 | 自动扫描抓到本地 `electron-v42.3.0` zip，与应用要求的 37.10.3 不匹配（ABI v136 的 better-sqlite3 prebuild 会加载失败） | 自动扫描只认精确版本；显式 `--electron-zip` 传错版本会报错（`WORKBUDDY_ALLOW_ELECTRON_MISMATCH=1` 可强制） |
| 4 | /sdcard FUSE glob 幽灵匹配：glob 返回 `electron-v37.10.3-...zip` 但文件不存在，直接 die | 扫描结果二次 `[[ -f ]]` 校验，失败改走下载分支 |

## 3. 安装产物状态（/root/tools/workbuddy-desktop/app）

`start.sh --diagnose` 结果：

- ok(ELF)：electron、main/index.js、koffi/linux_arm64、node-pty/prebuilds/linux-arm64（@lydell 变体包回填）、better-sqlite3/build/Release（GitHub prebuild，ABI v136，Electron 37 匹配）
- **已知遗留**：`cli/vendor/ripgrep/arm64-linux/ripgrep.node` 是空占位（DMG 只带 `arm64-darwin`；该 NAPI 变体无法合成；系统无 /usr/bin/rg 可回填 `rg`）→ 应用内置搜索可能不可用。解决思路：找 WorkBuddy 官方 linux 包提取该文件，或装 ripgrep 后重跑脚本回填 `arm64-linux/rg`。
- 待用户实际启动验证：`/root/tools/workbuddy-desktop/app/start.sh`（alias `workbuddy`）。

## 4. ToolHost / Shell 工具不可用——排查结论（核心交接内容）

用户问题："traework 本身是从 macOS DMG（traefikwork-desktop.sh）移植的，为什么 Shell 工具不可用？"

### 证据链（日志：/root/.config/TRAE SOLO CN/logs/20260818T111758/Modular/）

1. 报错字符串 `ToolHost is not running for shell_execute_strategy=tool_host` 位于 `app/resources/app/modules/ai-agent/libai_agent.so`（195MB Rust 库）；workbench JS 只是把 `shell_execute_strategy` 作为 common_params 上报，真正决策在 so 内。
2. **后端 Host ToolHost 是活着的**：
   - 二进制存在：`modules/ai-agent/bin/agent-tool-host`（40MB）
   - `ai-agent_0_*.log` L103-139：`[Toolhost:Host] eager start: conditions met` → UDS `/tmp/agent-code-toolhost-29053-*.sock` ready
   - `toolhost-host-*/toolhost.log`：启动 1.5 小时后仍在正常响应 fileFinder 请求
3. **失败点在 IDE 侧调用链**：`ai-agent` 通过 aha_ipc 让 IDE 执行 `icube.common.commands.tooling.runCommandInTerminal`，IDE 侧返回 `ToolHost is not running`（stdout.log L17567 `[ToolhostDiag][vm_invoke_error] reason=invoke_failed`）。
   - 结论：**不是进程没起来，而是某层判定"该场景（Linux desktop/移植版）不启用/未绑定 ToolHost"**。
4. 对照组：MCP `run_command`（本交接文档用的通道）正常，它走 `app/modules/sandbox/trae-sandbox exec`，与 ToolHost 平行；日志中成功的 run_command 均为 `exec_env=Some("sandbox")`，而失败的 Shell 工具请求的是 host/terminal 场景。
5. 早期 probe（/root/sh/probe-toolhost.py）发现 workbench JS 里有 `enableToolhost` 类守卫（疑似 `(Windows || macOS) && solo-lite` 才启用），Linux 被 gate 掉——与"后端起了但 IDE 侧拒绝"的现象吻合，但尚未最终实锤是哪一行判定。

### 顺带发现的环境问题（独立于 ToolHost，但干扰排查）

- 沙箱初始 PATH 缺系统目录：每次命令 toolsinit.sh 报 `whoami/mkdir/getconf: command not found`。
- TRAE 自带 rg（@vscode/ripgrep）二进制架构错误：Grep 工具报 `Exec format error (os error 8)`——说明**移植时 rg 没换成 arm64 版**，这可能是移植脚本的另一个待修点（traework-desktop.sh 可参考 workbuddy 的 ripgrep 回填逻辑）。
- `ai-agent_panic_*.log`：slardar 遥测事件名解析 panic（`my_space_artifact_operation: VariantNotFound`），非致命。

### 下一步建议（按优先级）

1. strings/反汇编 `libai_agent.so` 中 `shell_execute_strategy` 取值来源（动态配置 key、平台判定、env 开关），找可注入的强制项（如强制 `sandbox`/`shell_exec` 策略）。
2. 在 workbench JS 里定位 IDE 侧 ToolHost 场景守卫（搜 `enableToolhost`、`runCommandInTerminal` handler），patch 掉平台 gate。
3. 修 TRAE 自带 rg 架构问题（Grep 工具恢复）。
4. 验证入口：`grep -n 'ToolhostDiag' ai-agent_*_stdout.log`。

## 5. Git 状态

- win-git 仓库：`workbuddy-desktop.sh` 为新增未跟踪文件；`probe-toolhost.py`、`workbuddy-port-report/`、`.trae-html-share-packages/` 在仓库外层未跟踪。
- 用户此前的提交偏好：改完脚本 → commit → push（traework 那次是明确要求的；workbuddy 尚未要求提交，交接后可询问）。
