# Firefox Remote DOM Debug

## 用途

在 macOS 上通过 DevSpace/MCP 操作本机 Firefox，对用户正在使用的真实网页执行 DOM 调试。适合：

- 页面结构无法靠源码或截图准确判断；
- 浏览器扩展需要针对真实 DOM 编写稳定 selector；
- 排查 iframe、组件数量、页面内存膨胀；
- 用户不能安装新版 Chrome，但 Firefox 支持 WebDriver BiDi。

本 Skill 来自 2026-09-22 对 ChatGPT MCP 工具卡内存问题的实际调试。

## 前提

Firefox `about:config`：

- `devtools.debugger.remote-enabled = true`
- `devtools.chrome.enabled = true`
- `devtools.debugger.prompt-connection = false`

Firefox 156 已支持：

```text
--remote-debugging-port [port]
```

它启动的是 Firefox Remote Agent / WebDriver BiDi，不是 Chrome CDP。因此不要使用 Chrome 的 `/json/version`、`/json/list` 接口判断是否成功。

## 启动

远程调试参数必须在 Firefox 进程启动时传入。仅修改 about:config 不会自动监听端口。

macOS 示例：

```bash
osascript -e 'tell application "Firefox" to quit'
open -na Firefox --args --remote-debugging-port 9222
lsof -nP -iTCP:9222 -sTCP:LISTEN
```

应看到 Firefox 监听 `127.0.0.1:9222`。

如果已有 BiDi session 没有正常结束，Firefox 一般只允许一个 active session，可能返回 `Maximum number of active sessions`。调试脚本应发送 `session.end`；必要时重启 Firefox 清理残留 session。

## WebDriver BiDi 连接

WebSocket 地址：

```text
ws://127.0.0.1:9222/session
```

Node 22 自带全局 `WebSocket`，无需安装额外 npm 包。

基本流程：

1. 连接 `ws://127.0.0.1:9222/session`。
2. 发送 `session.new`。
3. 发送 `browsingContext.getTree` 获取标签页。
4. 按 URL 选择目标 browsing context。
5. 用 `script.evaluate` 在该 context 中执行 JavaScript。
6. 完成后发送 `session.end`。

最小消息格式：

```js
ws.send(JSON.stringify({
  id: 1,
  method: "session.new",
  params: { capabilities: {} }
}));
```

取得 context 后：

```js
ws.send(JSON.stringify({
  id: 3,
  method: "script.evaluate",
  params: {
    expression: "document.title",
    target: { context },
    awaitPromise: false
  }
}));
```

## DOM 排查方法

不要先根据页面可见文字猜 selector。优先从一个可靠入口节点开始，向上检查真实父链。

建议采集每层：

- `tagName`
- `id`
- `className`
- `role`
- `aria-label`
- `data-testid`
- `innerText` 小片段
- `getBoundingClientRect()` 宽高
- 子节点数量
- button 数量
- iframe 数量
- 截断后的 `outerHTML`

必须设置输出长度限制，避免一个长 ChatGPT conversation DOM 产生几十 MB 输出。

## ChatGPT MCP 工具卡：2026-09-22 实测结构

不要匹配 `Ran command` / `Opened workspace` 之类正文文字。回复正文也可能包含这些字符串，会误删整条消息。

当前可靠入口：

```css
button[aria-label="打开工具调用列表"]
```

英文 UI 可兼容：

```css
button[aria-label="Open tool calls"]
```

实测向上结构大致为：

```text
button[aria-label="打开工具调用列表"]
  -> div
  -> button.inline-block
  -> div
  -> span
  -> span.group/tool-message
  -> div.contents
```

这个最近的 `div.contents` 同时包含：

- `span.group/tool-message`
- connector 名称按钮 `mcp`
- CSP 状态按钮
- 一个 MCP widget `iframe`

一次 MCP 调用对应一个这样的组件。一次回复中 8 次 MCP 调用实测出现 8 个 iframe，因此长对话累计大量 iframe 是显著的浏览器内存风险点。

## 安全识别原则

删除/替换前同时验证多个条件，而不是只看文字：

1. 从工具调用 toggle 开始；
2. 向上找到最近的 `div.contents`；
3. 容器包含 `span[class*="group/tool-message"]`；
4. 容器包含文本严格等于 `mcp` 的 connector button；
5. 容器包含 `iframe`；
6. 搜索到 `[data-testid^="conversation-turn"]` 时停止，绝不删除整个 conversation turn。

宁可漏掉组件，也不要扩大父节点范围误删用户/助手正文。

## 降低内存占用

仅用 CSS `display:none` 隐藏 iframe 不等于释放 iframe document/JS context。

为了真正降低资源占用，应将整个单次 MCP `div.contents` 从 DOM detach/remove，或者替换成非常轻的 placeholder：

```js
const placeholder = document.createElement("div");
placeholder.textContent = "MCP";
component.replaceWith(placeholder);
```

这样至少会销毁 DOM 中的 iframe browsing context，比单纯视觉隐藏更有机会释放 renderer 资源。

如果页面由 React 管理，要通过 MutationObserver 持续处理后续新增的工具组件，但应 debounce，避免每个 mutation 都全页扫描。

## 当前实现

仓库中的实际扩展：

```text
win-git/chatgpt-devspace-cleaner/
```

核心脚本：

```text
win-git/chatgpt-devspace-cleaner/content.js
```

当前 Compact 模式精确移除 MCP `div.contents`（含 iframe），替换为轻量 `MCP` 占位；Hide 模式直接 remove；Show 不处理。

## 调试经验

- Firefox 的 `--remote-debugging-port` 是 BiDi，不要套用 Chrome CDP HTTP endpoint。
- `about:config` 打开 remote-enabled 后仍需带启动参数重启 Firefox。
- 第一次 DOM 搜索如果命中助手正文里的同名文本，说明入口选择错误。
- ARIA label、组件边界和 iframe 存在性组合起来，比 Tailwind/hash class 稳定。
- ChatGPT class 名可能随部署变化，避免依赖类似 `fKQ0lq_Layout` 的生成类。
- 做内存优化时先统计每个组件的 iframe 数量；iframe 往往比外层几层 DOM 更值得优先释放。
- 修改扩展后至少运行 `node --check content.js` 和 `git diff --check`。
