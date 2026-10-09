#!/usr/bin/env bash
set -Eeuo pipefail

# 回归测试：先补新 Session，并保证业务 whenReady 回调前补默认 Session。
script_dir=$(cd "$(dirname "$0")" && pwd)
builder="$script_dir/codex-desktop-macos12-from-debian.sh"

if grep -Fq "listener.call(this, session)" "$builder"; then
	printf '失败：不能改写 session-created 参数；Electron 43 在本机传入的就是 Session。\n' >&2
	exit 1
fi

grep -Fq "e.app.on('session-created', patchSession);" "$builder" || {
	printf '失败：Owl shim 没有补齐后续新建 Session。\n' >&2
	exit 1
}

grep -Fq "e.app.whenReady = function () { return readyWithSessionPatch; };" "$builder" || {
	printf '失败：Owl shim 没有保证业务回调前补齐默认 Session。\n' >&2
	exit 1
}

grep -Fq "replaceAll('.setWebsiteReportingEnabled(', '.setWebsiteReportingEnabled?.(')" "$builder" || {
	printf '失败：构建器没有将 Owl 专属网站报告 API 改成安全的可选调用。\n' >&2
	exit 1
}

grep -Fq "replaceAll('.setPermissionPromptHandler(', '.setPermissionPromptHandler?.(')" "$builder" || {
	printf '失败：构建器没有将 Owl 专属权限提示 API 改成安全的可选调用。\n' >&2
	exit 1
}

grep -Fq "replaceAll('.setPreferredLanguages(', '.setPreferredLanguages?.(')" "$builder" || {
	printf '失败：构建器没有将 Owl 专属语言设置 API 改成安全的可选调用。\n' >&2
	exit 1
}

grep -Fq "replaceAll('.isCursorScreenPointSupported()', '.isCursorScreenPointSupported?.()')" "$builder" || {
	printf '失败：构建器没有为 stock Electron 缺失的光标坐标能力查询提供降级。\n' >&2
	exit 1
}

grep -Fq "getDownloadHistory?.().catch(()=>null)??Promise.resolve(null)" "$builder" || {
	printf '失败：构建器没有为浏览数据摘要中的 Owl 下载历史接口提供空值降级。\n' >&2
	exit 1
}

grep -Fq "getDownloadHistory?.()??[]" "$builder" || {
	printf '失败：构建器没有为下载管理器中的 Owl 下载历史接口提供空列表降级。\n' >&2
	exit 1
}

grep -Fq '"layoutVersion": 1' "$builder" || {
	printf '失败：构建器没有生成新版插件同步要求的 Codex 包元数据。\n' >&2
	exit 1
}

grep -Fq '"entrypoint": "CodexCLI.app/Contents/MacOS/codex"' "$builder" || {
	printf '失败：Codex 包元数据没有指向实际的 Darwin 应用入口。\n' >&2
	exit 1
}

grep -Fq '"$source_resources/codex-cli/bin/codex-code-mode-host"' "$builder" || {
	printf '失败：新版插件宿主所需的 code-mode helper 没有打入 Codex 包。\n' >&2
	exit 1
}

grep -Fq "replaceAll('socketPeerAuthorizer:a=uf()', 'socketPeerAuthorizer:a=()=>({authorized:!0})')" "$builder" || {
	printf '失败：动态应用工具管道仍要求移植包无法提供的 Owl 签名身份。\n' >&2
	exit 1
}

grep -Fq "patchSession(e.session.defaultSession);" "$builder" || {
	printf '失败：Owl shim 没有补齐默认 Session。\n' >&2
	exit 1
}

grep -Fq 'patch-chatgpt-chat-mcp-activity.mjs' "$builder" || {
	printf '失败：macOS 12 构建链没有自动打入 ChatGPT MCP 内存补丁。\n' >&2
	exit 1
}

grep -Fq 'CHATGPT_CDP_PORT:-9333' "$builder" || {
	printf '失败：macOS 12 启动器没有保留 localhost CDP 调试入口。\n' >&2
	exit 1
}

grep -Fq -- '--remote-debugging-address=127.0.0.1' "$builder" || {
	printf '失败：CDP 调试入口没有限制在 localhost。\n' >&2
	exit 1
}

patcher="$script_dir/patch-chatgpt-chat-mcp-activity.mjs"
node --check "$patcher" || {
	printf '失败：MCP patch 脚本存在 JavaScript 语法错误。\n' >&2
	exit 1
}

grep -Fq 'data-mcp-app-portal-target' "$patcher" || {
	printf '失败：MCP patch 缺少 ecosystem widget portal 截断锚点。\n' >&2
	exit 1
}

grep -Fq 'function ca(e){return null}' "$patcher" || {
	printf '失败：MCP patch 缺少 activity header 清理标记。\n' >&2
	exit 1
}

printf '通过：Owl Session 兼容层、MCP 内存补丁与 localhost CDP 构建入口均已覆盖。\n'
