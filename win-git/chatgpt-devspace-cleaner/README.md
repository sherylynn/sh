# ChatGPT DevSpace Card Cleaner

针对 ChatGPT 网页长时间使用 DevSpace/MCP 后工具卡片大量堆积的轻量浏览器扩展。

## 模式

- **Compact（默认）**：把匹配到的 DevSpace 工具卡片替换成一行轻量占位符。
- **Hide**：直接从 DOM 移除匹配卡片，内存/DOM 优化最激进。
- **Show**：停止处理；刷新页面可恢复此前被替换/移除的内容。

当前只匹配常见 DevSpace 工具状态文案与 `ui://devspace/` sandbox iframe，避免影响网页搜索等其他 ChatGPT 卡片。ChatGPT DOM 会更新，因此实现刻意避免依赖随机 CSS class，并提供调试日志。

## 为什么重启后扩展会消失

`about:debugging#/runtime/this-firefox` → “临时载入附加组件” 是**内存态**加载：Firefox 只在本次会话的临时作用域里注册它，既不写入 profile 的 `extensions/` 目录，也不落盘。Firefox 一关闭就卸载，重启必须重载——这是设计行为，不是 bug。

要让扩展**重启后仍在**，只有两条路：

1. **加载时以“永久安装”路径装入**（`about:addons` → 齿轮 → “从文件安装附加组件”，或企业策略预装）；
2. 而 Release / Beta 版 Firefox 的永久安装**强制要求 XPI 带 Mozilla 签名**。

所以“签名”确实是正解，但签名解决的是“能不能永久装”，而不是“临时扩展为什么不持久”。

## 方案 A：AMO 自发行签名（推荐）

unlisted = 有签名但**不上架**，走自动审核、不需要人工审核，团队内部使用完全够。

⚠ **AMO 的签名是异步的，实测要几分钟**（官方文档写的“数十秒”不可信：本项目 v0.1.0 从上传到 `file.status` 变 `public` 花了好几分钟）。web-ext 上传后会打印 `Waiting for approval...` 并轮询直到文件变 `public` 才下载，默认最长等 15 分钟（`approvalCheckTimeout = 900000`）。**这期间千万不要 Ctrl-C。**

```sh
cd win-git/chatgpt-devspace-cleaner

./sign.sh -l        # 1) 只做本地校验（不联网、不消耗 AMO 配额）
./sign.sh           # 2) 签名（默认 unlisted）
./sign.sh -b        # 3) 改了代码要发新版：先 bump patch 版本号再签
./sign.sh -s        # 4) 出问题先看 AMO 上的版本 / file.status / 下载地址
./sign.sh -f        # 5) 把当前 manifest 版本**已签名**的 xpi 取回本地
./sign.sh -f 0.1.0  #    指定版本取回（manifest 已经 bump 过时用这个）
```

首次使用先配凭据（在 AMO 后台生成：https://addons.mozilla.org/developers/addon/api/key/ ；JWT 有效期只有 60 秒，脚本每次请求现签）：

```sh
mkdir -p ~/.config/amo
printf 'AMO_API_KEY=user:xxxxx:yy\nAMO_API_SECRET=xxxxx\n' > ~/.config/amo/devspace-cleaner.env
```

产物在 **`~/my_keys/`** —— 你的**私有**密钥仓库（`sherylynn/my_keys`）。签名包就放那儿并随该仓库同步，换机器 `git pull` 后能直接拿来安装测试。注意本仓库 `sherylynn/sh` 是 **public**，所以编译产物一律不进这里（`.gitignore` 已挡 `*.xpi` / `web-ext-artifacts/`）。脚本还会校验产物里确实含 `META-INF/mozilla.rsa` 并打印 sha256 —— 避免把未签名的半成品发给团队。安装：`about:addons` → 齿轮 → “从文件安装附加组件” → 选该 xpi。这样装进去的扩展是**永久**的，Firefox 重启不会丢；团队成员装同一个 xpi 即可，不需要 developer edition。

要点：

- **`data_collection_permissions` 是硬要求**。2025-11-03 起，AMO 对新提交的扩展强制要求 `browser_specific_settings.gecko.data_collection_permissions`；缺失会被**直接拒绝签名**。本扩展不采集数据，声明 `{"required": ["none"]}`。一旦开始用这个字段，后续版本必须继续保留。
- **`gecko.id` 是永久身份**，签名后不能改（改 id 等于换一个扩展，用户需重装），且 AMO 首次签名会做唯一性检查。当前值固定为 `chatgpt-devspace-cleaner@sherylynn.win`，不要再动它（`distribution/policies.json` 里的策略 key 必须与该 id 严格一致）。
- **Android 侧下限要单独抬**。声明了 `data_collection_permissions` 后，AMO 会警告 `min Firefox for Android` 早于 142（`KEY_FIREFOX_ANDROID_UNSUPPORTED_BY_MIN_VERSION`）；已在 manifest 补了 `gecko_android.strict_min_version: "142.0"` 消掉这条。
- **自发行不自动更新**。unlisted xpi 没有 AMO 更新通道；想让 teammate 自动升级，需要在 manifest 加 `gecko.update_url` 指向自建 HTTPS 更新清单（JSON）。否则每次发版让大家重装。
- Firefox for Android 只允许安装 AMO **上架**的扩展，unlisted/自发行装不上；安卓端需要走 `-c listed`。
- 打包忽略规则要用**裸目录名**（`distribution`、`web-ext-artifacts`）。只写 `distribution/**` 会漏掉目录条目本身，结果是空目录被塞进 xpi —— AMO 上的上传包里就出现过 `distribution/` 和 `web-ext-artifacts/` 两个空目录。
- **编译产物一律不进本仓库（它是 public）**。`sign.sh` 的产物目录默认指向 `~/my_keys`（私有库，产物随它同步，方便多机安装测试），可用 `AMO_ARTIFACTS_DIR` 覆盖；如果被指回仓库内，脚本会告警。本仓库 `.gitignore` 另挡 `*.xpi` / `web-ext-artifacts/` / `.amo-upload-uuid` / `amo*.env` 作为第二道防线。

## 排查：`This upload has already been submitted.`

这是本项目实际踩过的坑，完整因果链：

1. web-ext 上传成功后进入 `Waiting for approval...` 轮询（默认最长 15 分钟）；
2. 在轮询期间按了 Ctrl-C —— **AMO 服务端其实已经把这个版本签好了**（`file.status` 已变 `public`、体积从 7256 涨到 15301 字节、URL 从 `.zip` 变 `.xpi`），只是本地没下载，产物目录是空的；
3. 重新跑 → web-ext 检查 `.amo-upload-uuid` 里存的 `xpiCrcHash`，决定“续传还是重传”；
4. **这个判据在本机永远不成立**：web-ext 打包顺序不稳定，同一份源码连续构建两次，zip 的 sha256 都不一样（实测 `050ba02a…` vs `47cd2d29…`），哈希必然漂移 → 它每次都走重传分支，所谓断点续传形同虚设；
5. AMO 不允许同一 id 的重复版本号 → `400 Bad Request: This upload has already been submitted.`

正确处置（**看到这个错先别重跑**）：

```sh
./sign.sh -s        # status=public 说明已签完，直接取；unreviewed 表示还没签完，等几分钟再看
./sign.sh -f        # 把已签名的 xpi 取回来
```

确实要发新代码，才用 `./sign.sh -b`。`.amo-upload-uuid` 是 web-ext 写的本地状态文件，因为哈希永远匹配不上、实际没有续传作用，已加入 `.gitignore`。

## 方案 B：零签名（开发者/内测）

不想配 AMO 账号时，用允许关闭签名强制的版本：

- Firefox **Developer Edition** / **Nightly** / **ESR** / 无品牌版
- `about:config` → `xpinstall.signatures.required` = `false`
- 然后 `about:addons` → 齿轮 → “从文件安装附加组件”，装入**未签名**的 xpi

限制：Release / Beta **硬性忽略**这个开关（Firefox 49 起），所以这条只在上述版本有效。另外 Firefox < 115 ESR 因 2025-03 根证书过期已无法校验扩展签名，太老的版本别用。

适用于本机开发调试；团队统一用还是走方案 A，避免有人装在 Release 上装不上。

## 方案 C：企业策略预装（团队批量）

把签名后的 xpi 放到内部 HTTP(S) 或固定路径，用 `distribution/policies.json` 的 `ExtensionSettings` 强制/自动安装，新 profile 也会自动装：

- macOS：`/Applications/Firefox.app/Contents/Resources/distribution/policies.json`
- Linux：`<Firefox 安装目录>/distribution/policies.json`
- Windows：`<Firefox 安装目录>\distribution\policies.json`

模板见 `distribution/policies.json`。三个注意点：`install_url` 必须是 **https://** 或 **file:/// 绝对路径**（不能是相对路径）；`force_installed` 下用户无法禁用/卸载，想允许禁用改成 `normal_installed`；Release 版仍要求 xpi 已签名，所以 C 通常和 A 组合使用（C 负责分发，A 负责签名）。

`distribution/` 只是本地留存模板，已被 `sign.sh` 排除出打包，不会进 xpi。

## Chromium 测试

打开 `chrome://extensions`，开启开发者模式，选择“加载已解压的扩展程序”，指向本目录。Chromium 里“加载已解压”本身就是持久的，没有 Firefox 这个坑。
