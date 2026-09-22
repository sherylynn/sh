# Android Firefox Chroot Remote Debug

## 用途

当 Firefox 运行在 Android 主系统，而调试工具运行在同一台 Android 设备的 chroot Linux 中时，直接从 chroot 调试 Android Firefox 的真实网页 DOM。

这种同机架构优先走 Firefox 暴露的 abstract Unix domain socket，不需要经过 USB、ADB port-forward 或 Chrome CDP。

适合：
- MCP/Agent 读取 Android Firefox 当前标签页；
- 根据真实 DOM 排查网页或浏览器扩展问题；
- 执行少量 JavaScript 验证页面状态；
- 获取元素文本、HTML、位置和尺寸。

## 隐私与公开仓库规则

本 Skill 可以提交到公开仓库，但必须保持通用：
- 不记录真实用户名、HOME 绝对路径、设备序列号、Android ID、证书指纹；
- 不记录真实 IP、Wi-Fi SSID、局域网拓扑；
- 不记录私人网页完整 URL、会话 ID、项目 ID；
- 不记录页面正文、账号信息、Cookie、localStorage、Token；
- 示例一律使用通用 selector、占位站点和匿名设备名称；
- 调试输出只用于当前会话，除非已经人工去敏，否则不要写入仓库。

提交前至少执行：

~~~bash
git diff --check
git diff --cached
~~~

并人工检查新增内容是否出现个人目录、真实 URL、设备标识或凭据。

## 前提

Android Firefox 需要开启远程调试。不同版本菜单名称可能略有差异，通常位于：

~~~text
Firefox -> 设置 -> 高级 -> Remote debugging via USB
~~~

虽然菜单名字带 USB，但在“Android Firefox + 同机 chroot”场景中，真正使用的是 Android abstract Unix socket，USB 本身不是必要传输链路。

默认正式 Firefox 的调试 socket 常见为：

~~~text
@org.mozilla.firefox/firefox-debugger-socket
~~~

Linux/Python 中 abstract socket 的真实地址首字节是 NUL，因此连接形式是：

~~~python
socket.connect("\\0org.mozilla.firefox/firefox-debugger-socket")
~~~

不同 Firefox 渠道或包名可能使用不同 socket 名。不要硬猜；优先检查：

~~~bash
grep -Ei 'firefox|mozilla|debugger' /proc/net/unix
~~~

## 快速检查

确认 chroot 里有 Python：

~~~bash
python3 --version
~~~

确认 Firefox debugger socket 存在：

~~~bash
grep -Ei 'firefox|mozilla|debugger' /proc/net/unix
~~~

如果 socket 不存在：
1. 确认 Android Firefox 正在运行；
2. 确认 Firefox 自身远程调试已开启；
3. 完全退出并重新启动 Firefox；
4. 再检查 /proc/net/unix。

## 仓库工具

本仓库提供：

~~~text
win-git/firefox_remote_debug.py
~~~

它直接实现 Firefox Remote Debugging Protocol 的 length-prefixed packet 通信，不依赖额外 Python 包。

列出标签页：

~~~bash
python3 ~/sh/win-git/firefox_remote_debug.py tabs
~~~

执行 JavaScript：

~~~bash
python3 ~/sh/win-git/firefox_remote_debug.py eval 'document.title'
~~~

指定标签页：

~~~bash
python3 ~/sh/win-git/firefox_remote_debug.py eval --tab 1 'location.href'
~~~

查询 DOM：

~~~bash
python3 ~/sh/win-git/firefox_remote_debug.py query 'main'
python3 ~/sh/win-git/firefox_remote_debug.py query '[data-testid="example"]'
~~~

读取局部 HTML：

~~~bash
python3 ~/sh/win-git/firefox_remote_debug.py html --selector 'main'
~~~

大型页面不要默认抓整个 documentElement。应先定位局部 selector，避免输出过大和不必要地暴露页面内容。

## Firefox RDP 基本流程

连接后服务端先返回 root actor 握手。典型流程：

~~~text
root -> listTabs
tabDescriptor -> getTarget
windowGlobalTarget -> consoleActor
consoleActor -> evaluateJSAsync -> evaluationResult
~~~

Firefox 会在请求/响应之间穿插 frameUpdate 等异步事件，因此客户端不能假定“下一包就是响应”，必须按 from actor 过滤。

## longString

Firefox RDP 对较长字符串不会一次返回全部内容，而会给 longString grip。客户端需要向该 actor 继续请求 substring(start, end)。

仓库脚本已处理常见 longString，所以读取较长 DOM 文本时不会只得到前缀。

## MCP/Agent 调试建议

推荐顺序：
1. tabs 确认目标页面；
2. eval document.title 做最小连通性验证；
3. 用 query 从稳定 selector 开始；
4. 逐层查看目标组件，而不是全页抓取；
5. 必要时用 eval 查询 computed style、属性和父链；
6. 修改扩展或页面脚本后再次读取真实 DOM 验证。

例如查询元素可见性：

~~~bash
python3 ~/sh/win-git/firefox_remote_debug.py eval '(() => { const e=document.querySelector("main"); if(!e) return null; const s=getComputedStyle(e); return JSON.stringify({display:s.display,visibility:s.visibility,opacity:s.opacity}); })()'
~~~

## 与 ADB 的关系

同机 chroot 场景的链路是：

~~~text
chroot MCP -> Android abstract Unix socket -> Firefox
~~~

这条链路不依赖 ADB。

如果 adb devices 只能看到 offline 或看不到设备，也不代表 Firefox DOM 调试不可用。ADB 与 Firefox debugger socket 是两条独立链路。

只有在这些情况才优先考虑 ADB：
- 调试另一台 Android 设备；
- 当前 chroot 无权访问目标 abstract socket；
- 需要 web-ext 做扩展临时安装；
- 需要 Android shell、安装 APK 或端口转发。

## 安全边界

这个能力等同于浏览器开发者工具权限：
- 默认只做用户明确要求的页面调试；
- 不主动读取 Cookie、认证 Token、密码字段或账号隐私；
- 不把网页正文、URL、DOM dump 写进公开仓库；
- 调试脚本保持通用，不内置私人站点或账户信息；
- 对提交、删除、购买等网页操作，先确认用户意图。

## 验证清单

每次修改调试工具后至少执行：

~~~bash
python3 win-git/firefox_remote_debug.py tabs
python3 win-git/firefox_remote_debug.py eval 'document.title'
python3 win-git/firefox_remote_debug.py query 'title'
git diff --check
~~~

验证时不要把实际标签页 URL、页面正文等输出复制进提交说明或 Skill。
