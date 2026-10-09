#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const buildDir = process.argv[2];
const checkOnly = process.argv.includes("--check");
if (!buildDir) {
  throw new Error("usage: patch-chatgpt-chat-mcp-activity.mjs <webview-assets-dir> [--check]");
}

const jsFiles = fs.readdirSync(buildDir).filter((name) => name.endsWith(".js"));

function countOf(src, needle) {
  return src.split(needle).length - 1;
}

function findUniqueAsset(label, needle) {
  const hits = [];
  for (const name of jsFiles) {
    const file = path.join(buildDir, name);
    const src = fs.readFileSync(file, "utf8");
    const count = countOf(src, needle);
    if (count > 0) hits.push({ name, file, src, count });
  }
  const total = hits.reduce((sum, hit) => sum + hit.count, 0);
  if (total !== 1 || hits.length !== 1) {
    throw new Error(`${label}: expected exactly one anchor across webview assets, found ${total}`);
  }
  return hits[0];
}

function replaceUniqueAsset(label, oldText, newText) {
  const hit = findUniqueAsset(label, oldText);
  if (countOf(hit.src, newText) !== 0) {
    throw new Error(`${label}: patched marker already exists beside original anchor`);
  }
  const patched = hit.src.replace(oldText, newText);
  if (countOf(patched, oldText) !== 0 || countOf(patched, newText) !== 1) {
    throw new Error(`${label}: replacement verification failed`);
  }
  if (!checkOnly) fs.writeFileSync(hit.file, patched);
  return hit.name;
}

// 1) 普通 Chat 的 activity 列表不挂载工具展示卡。
// 这只处理展示层；工具执行、模型结果和审批状态机在上游，不在这里删除。
const conversationFiles = jsFiles.filter((name) => /^chatgpt-conversation-turn-content-.*\.js$/.test(name));
if (conversationFiles.length !== 1) {
  throw new Error(`expected exactly one conversation turn bundle, found ${conversationFiles.length}`);
}
const conversationFile = path.join(buildDir, conversationFiles[0]);
let conversationSrc = fs.readFileSync(conversationFile, "utf8");
// 26.1002.52244 的精确 Chat activity gate。保留完整旧串，未知版本直接失败，不能猜 offset。
const chatGateOld = 'if(l.type===`web-search`&&!(`chatGptWorkActivityId`in l)||l.type===`mcp-tool-call`&&l.mcpAppResourceUri==null&&(!a||!Pj(l,F))&&!(`chatGptWorkActivityId`in l)||l.type===`dynamic-tool-call`&&(u==null||l.tool!==`handoff`&&l.tool!==`continue_in_work`))continue;';
const chatGateNew = 'if(l.type===`web-search`&&!(`chatGptWorkActivityId`in l)||l.type===`mcp-tool-call`||l.type===`dynamic-tool-call`)continue;';
if (countOf(conversationSrc, chatGateOld) !== 1) {
  throw new Error("Chat tool activity gate anchor mismatch");
}
conversationSrc = conversationSrc.replace(chatGateOld, chatGateNew);

// Safety fallback：若 MCP item 绕过 activity gate 到达 generic renderer，也不再创建整棵 MCP item tree。
const mcpStart = 'if(S.type===`mcp-tool-call`){';
const dynamicStart = 'if(S.type===`dynamic-tool-call`){';
const start = conversationSrc.indexOf(mcpStart);
if (start < 0) throw new Error("MCP per-item renderer anchor missing");
const end = conversationSrc.indexOf(dynamicStart, start);
if (end < 0) throw new Error("dynamic tool renderer anchor missing after MCP renderer");
const oldMcpBranch = conversationSrc.slice(start, end);
if (!oldMcpBranch.includes("Vg") && !oldMcpBranch.includes("mcpAppResourceUri")) {
  throw new Error("unexpected MCP per-item renderer shape");
}
conversationSrc =
  conversationSrc.slice(0, start) +
  'if(S.type===`mcp-tool-call`)return J(null);' +
  conversationSrc.slice(end);

if (countOf(conversationSrc, chatGateNew) !== 1) {
  throw new Error("hidden Chat tool gate marker count mismatch");
}
if (conversationSrc.includes(oldMcpBranch)) {
  throw new Error("old MCP per-item renderer still present");
}
if (!checkOnly) fs.writeFileSync(conversationFile, conversationSrc);

// 2) 本地 Codex 线程有独立 activity 分组器。只过滤展示卡，不碰执行事件。
const agentFiles = jsFiles.filter((name) => /^agent-activity-item-.*\.js$/.test(name));
if (agentFiles.length !== 1) {
  throw new Error(`expected exactly one agent activity bundle, found ${agentFiles.length}`);
}
const agentFile = path.join(buildDir, agentFiles[0]);
let agentSrc = fs.readFileSync(agentFile, "utf8");
const localOld =
  'case`exec`:case`patch`:return $(fr(e),Rt(e)?`standalone`:`groupable`);case`mcp-tool-call`:return $(fr(e),ln({item:e,mcpServerStatuses:r})?`standalone`:`groupable`);';
const localNew =
  'case`exec`:case`mcp-tool-call`:return null;case`patch`:return $(fr(e),Rt(e)?`standalone`:`groupable`);';
if (countOf(agentSrc, localOld) !== 1) {
  throw new Error("local tool activity grouping anchor mismatch");
}
agentSrc = agentSrc.replace(localOld, localNew);
const dynamicOld =
  'case`dynamic-tool-call`:{let n=t??Z(e);return n?.hiddenInConversation===!0?null:$(e,n?.standaloneInConversation===!0?`standalone`:`groupable`)}';
if (countOf(agentSrc, dynamicOld) !== 1) {
  throw new Error("local dynamic tool grouping anchor mismatch");
}
agentSrc = agentSrc.replace(dynamicOld, 'case`dynamic-tool-call`:return null;');
if (!checkOnly) fs.writeFileSync(agentFile, agentSrc);

// 3) 真正的内存修复：普通 Chat 不再挂载 MCP ecosystem widget portal/sandbox。
// Work 保留官方 widget 路径。这个 gate 位于 widget bundle，早于 mcp-sandbox-element 创建 <webview>。
const widgetOld =
  'let yt;return t[144]!==U||t[145]!==W||t[146]!==G||t[147]!==J||t[148]!==Y||t[149]!==X?(yt=(0,Q.jsxs)(`div`,{ref:ot,className:U,"data-mcp-app-portal-target":`true`,children:[W,G,J,Y,X]}),t[144]=U,t[145]=W,t[146]=G,t[147]=J,t[148]=Y,t[149]=X,t[150]=yt):yt=t[150],yt}';
const widgetNew =
  'return A.get(Pe)===`work`?(0,Q.jsxs)(`div`,{ref:ot,className:U,"data-mcp-app-portal-target":`true`,children:[W,G,J,Y,X]}):null}';
const widgetAsset = replaceUniqueAsset("MCP widget mount", widgetOld, widgetNew);

// 4) 去掉 widget 截断后仍可能留下的 MCP App activity header：
// “正在打开 / 已打开 / 无法打开 mcp”。该函数是 MCP App 专用，不是审批/权限 item。
const headerOld = Buffer.from(
  "ZnVuY3Rpb24gY2EoZSl7bGV0IHQ9KDAsbGEuYykoMjQpLHttY3BBcHBJZDpuLG5hbWU6cixzdGF0dXM6aSxkaXNhYmxlZDphLGljb246byxhY2Nlc3Nvcnk6cyxjbGFzc05hbWU6YyxkaXNjbG9zdXJlOmx9PWUsdT1mdChLZSksZD0kZSgpLGY7dFswXSE9PWF8fHRbMV0hPT1sfHx0WzJdIT09bnx8dFszXSE9PXV8fHRbNF0hPT1pPyhmPWw/PyhpPT09YGNsb3NlZGAmJiFhP3tleHBhbmRlZDohMSxvblRvZ2dsZTooKT0+ZW4odSxuKX06dm9pZCAwKSx0WzBdPWEsdFsxXT1sLHRbMl09bix0WzNdPXUsdFs0XT1pLHRbNV09Zik6Zj10WzVdO2xldCBwPWYsbTt0WzZdIT09YXx8dFs3XSE9PW4/KG09KDAsdWEuanN4KShEcix7ZGlzYWJsZWQ6YSxtY3BBcHBJZDpufSksdFs2XT1hLHRbN109bix0WzhdPW0pOm09dFs4XTtsZXQgaDt0WzldIT09c3x8dFsxMF0hPT1tPyhoPSgwLHVhLmpzeHMpKHVhLkZyYWdtZW50LHtjaGlsZHJlbjpbbSxzXX0pLHRbOV09cyx0WzEwXT1tLHRbMTFdPWgpOmg9dFsxMV07bGV0IGc7dFsxMl0hPT1wfHx0WzEzXSE9PWQ/KGc9cD09bnVsbD92b2lkIDA6ey4uLnAsb25Ub2dnbGU6ZT0+e1FuKGUuY3VycmVudFRhcmdldCxkKSxwLm9uVG9nZ2xlKGUpfX0sdFsxMl09cCx0WzEzXT1kLHRbMTRdPWcpOmc9dFsxNF07bGV0IF87dFsxNV0hPT1yfHx0WzE2XSE9PWk/KF89KDAsdWEuanN4KShzYSx7bmFtZTpyLHN0YXR1czppfSksdFsxNV09cix0WzE2XT1pLHRbMTddPV8pOl89dFsxN107bGV0IHY7cmV0dXJuIHRbMThdIT09Y3x8dFsxOV0hPT1vfHx0WzIwXSE9PWh8fHRbMjFdIT09Z3x8dFsyMl0hPT1fPyh2PSgwLHVhLmpzeHMpKFhuLHtjbGFzc05hbWU6YyxhY2Nlc3Nvcnk6aCxkaXNjbG9zdXJlOmcsY2hpbGRyZW46W28sX119KSx0WzE4XT1jLHRbMTldPW8sdFsyMF09aCx0WzIxXT1nLHRbMjJdPV8sdFsyM109dik6dj10WzIzXSx2fQ==",
  "base64",
).toString("utf8");
const headerNew = "function ca(e){return null}";
const headerAsset = replaceUniqueAsset("MCP activity header", headerOld, headerNew);

console.log(
  `${checkOnly ? "validated" : "patched"} Chat/MCP render gates: ${conversationFiles[0]}, ${agentFiles[0]}, ${widgetAsset}, ${headerAsset}`,
);
