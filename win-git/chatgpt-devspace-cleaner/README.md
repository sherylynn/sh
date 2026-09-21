# ChatGPT DevSpace Card Cleaner

针对 ChatGPT 网页长时间使用 DevSpace/MCP 后工具卡片大量堆积的轻量浏览器扩展。

## 模式

- **Compact（默认）**：把匹配到的 DevSpace 工具卡片替换成一行轻量占位符。
- **Hide**：直接从 DOM 移除匹配卡片，内存/DOM 优化最激进。
- **Show**：停止处理；刷新页面可恢复此前被替换/移除的内容。

当前只匹配常见 DevSpace 工具状态文案（如 Ran command、Opened workspace 等），避免影响网页搜索等其他 ChatGPT 卡片。ChatGPT DOM 会更新，因此实现刻意避免依赖随机 CSS class，并提供调试日志。

## Firefox 临时安装测试

1. 打开 `about:debugging#/runtime/this-firefox`
2. 选择“临时载入附加组件”
3. 选择本目录的 `manifest.json`
4. 刷新 ChatGPT 页面
5. 点击扩展图标选择 Compact 或 Hide

临时扩展在 Firefox 重启后需要重新载入。验证效果后可再打包/签名安装。

## Chromium 测试

打开 `chrome://extensions`，开启开发者模式，选择“加载已解压的扩展程序”，指向本目录。
