#!/usr/bin/env node
/**
 * Firefox WebDriver BiDi 轻量 Computer Use 工具。
 *
 * 只依赖 Node 22+ 内置 WebSocket，连接 Firefox:
 *   firefox --remote-debugging-port 9222
 *
 * 设计目标：snapshot -> ref -> act -> verify。
 * 每次命令都是独立 BiDi session；ref 由稳定的 DOM selector 表示，因此页面明显变化后应重新 snapshot。
 */

const endpoint = process.env.FIREFOX_BIDI_URL || "ws://127.0.0.1:9222/session";
const argv = process.argv.slice(2);
const command = argv.shift() || "help";

function usage(exitCode = 0) {
  console.log(`用法:
  firefox_bidi.js tabs
  firefox_bidi.js snapshot [--url <片段>] [--context <id>] [--limit 80]
  firefox_bidi.js click <eN|selector> [--url <片段>] [--context <id>]
  firefox_bidi.js fill <eN|selector> <text> [--url <片段>] [--context <id>]
  firefox_bidi.js press <key> [--url <片段>] [--context <id>]
  firefox_bidi.js scroll <dx> <dy> [--url <片段>] [--context <id>]
  firefox_bidi.js screenshot <file.png> [--url <片段>] [--context <id>]
  firefox_bidi.js eval <javascript> [--url <片段>] [--context <id>]

环境变量:
  FIREFOX_BIDI_URL  默认 ws://127.0.0.1:9222/session

说明:
  eN ref 来自最近一次 snapshot，并缓存到 /tmp/firefox-bidi-refs.json。
  页面导航或 DOM 大幅变化后请重新 snapshot。
`);
  process.exit(exitCode);
}

function parseOptions(args) {
  const options = {};
  const positional = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--url") options.url = args[++i];
    else if (args[i] === "--context") options.context = args[++i];
    else if (args[i] === "--limit") options.limit = Number(args[++i]);
    else positional.push(args[i]);
  }
  return { options, positional };
}

class Bidi {
  constructor(url) {
    this.url = url;
    this.nextId = 1;
    this.pending = new Map();
  }

  async connect() {
    this.ws = new WebSocket(this.url);
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`连接 Firefox BiDi 超时: ${this.url}`)), 5000);
      this.ws.addEventListener("open", () => { clearTimeout(timer); resolve(); }, { once: true });
      this.ws.addEventListener("error", () => { clearTimeout(timer); reject(new Error(`无法连接 Firefox BiDi: ${this.url}`)); }, { once: true });
    });
    this.ws.addEventListener("message", event => {
      let msg;
      try { msg = JSON.parse(event.data); } catch { return; }
      if (!msg.id || !this.pending.has(msg.id)) return;
      const { resolve, reject } = this.pending.get(msg.id);
      this.pending.delete(msg.id);
      if (msg.type === "error" || msg.error) reject(new Error(`${msg.error || "BiDi error"}: ${msg.message || ""}`));
      else resolve(msg.result);
    });
    await this.send("session.new", { capabilities: {} });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
      setTimeout(() => {
        if (this.pending.delete(id)) reject(new Error(`BiDi 命令超时: ${method}`));
      }, 10000);
    });
  }

  async close() {
    try { await this.send("session.end", {}); } catch {}
    try { this.ws.close(); } catch {}
  }
}

function flattenContexts(nodes, depth = 0, out = []) {
  for (const node of nodes || []) {
    out.push({ context: node.context, url: node.url, depth });
    flattenContexts(node.children, depth + 1, out);
  }
  return out;
}

async function selectContext(bidi, options) {
  const tree = await bidi.send("browsingContext.getTree", {});
  const contexts = flattenContexts(tree.contexts);
  if (options.context) {
    const found = contexts.find(x => x.context === options.context);
    if (!found) throw new Error(`找不到 context: ${options.context}`);
    return found;
  }
  if (options.url) {
    const found = contexts.find(x => (x.url || "").includes(options.url));
    if (!found) throw new Error(`找不到 URL 包含 "${options.url}" 的标签页`);
    return found;
  }
  const usable = contexts.filter(x => /^https?:|^file:/.test(x.url || ""));
  if (usable.length === 1) return usable[0];
  if (usable.length > 1) {
    throw new Error("当前有多个网页标签页，请用 --url <片段> 或 --context <id> 指定目标。\n" +
      usable.map(x => `${x.context}  ${x.url}`).join("\n"));
  }
  if (contexts.length) return contexts[0];
  throw new Error("Firefox 当前没有 browsing context");
}

function remoteValue(result) {
  const v = result?.result;
  if (!v) return undefined;
  if ("value" in v) return v.value;
  return v;
}

async function evaluate(bidi, context, expression, awaitPromise = true) {
  const result = await bidi.send("script.evaluate", {
    expression,
    target: { context },
    awaitPromise,
    resultOwnership: "none",
    userActivation: true,
  });
  if (result.type === "exception") throw new Error(result.exceptionDetails?.text || "页面脚本执行失败");
  return remoteValue(result);
}

const snapshotExpression = `(() => {
  const visible = el => {
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none";
  };
  const esc = s => CSS.escape(String(s));
  const selectorFor = el => {
    if (el.id) return "#" + esc(el.id);
    const testid = el.getAttribute("data-testid");
    if (testid) return '[data-testid="' + String(testid).replaceAll('"', '\\"') + '"]';
    const aria = el.getAttribute("aria-label");
    if (aria) {
      const q = el.tagName.toLowerCase() + '[aria-label="' + String(aria).replaceAll('"', '\\"') + '"]';
      if (document.querySelectorAll(q).length === 1) return q;
    }
    const parts = [];
    let n = el;
    while (n && n.nodeType === 1 && n !== document.documentElement) {
      let p = n.tagName.toLowerCase();
      const parent = n.parentElement;
      if (parent) {
        const same = [...parent.children].filter(x => x.tagName === n.tagName);
        if (same.length > 1) p += ':nth-of-type(' + (same.indexOf(n) + 1) + ')';
      }
      parts.unshift(p);
      const q = parts.join(' > ');
      try { if (document.querySelectorAll(q).length === 1) return q; } catch {}
      n = parent;
    }
    return parts.join(' > ');
  };
  const query = [
    'a[href]', 'button', 'input:not([type="hidden"])', 'textarea', 'select',
    '[role="button"]', '[role="link"]', '[role="checkbox"]', '[role="radio"]',
    '[role="tab"]', '[role="menuitem"]', '[contenteditable="true"]'
  ].join(',');
  return [...document.querySelectorAll(query)].filter(visible).map(el => {
    const r = el.getBoundingClientRect();
    return {
      tag: el.tagName.toLowerCase(),
      role: el.getAttribute('role') || '',
      type: el.getAttribute('type') || '',
      text: (el.innerText || el.value || el.getAttribute('aria-label') || el.getAttribute('title') || '').trim().replace(/\\s+/g, ' ').slice(0, 160),
      aria: el.getAttribute('aria-label') || '',
      disabled: !!el.disabled || el.getAttribute('aria-disabled') === 'true',
      selector: selectorFor(el),
      rect: {x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height)}
    };
  });
})()`;

async function snapshot(bidi, context, limit) {
  const items = await evaluate(bidi, context, snapshotExpression);
  const clipped = (items || []).slice(0, limit || 80).map((x, i) => ({ ref: `e${i + 1}`, ...x }));
  const cache = { context, createdAt: new Date().toISOString(), refs: Object.fromEntries(clipped.map(x => [x.ref, x.selector])) };
  require("fs").writeFileSync("/tmp/firefox-bidi-refs.json", JSON.stringify(cache, null, 2));
  return clipped;
}

function resolveTarget(target) {
  if (!/^e\d+$/.test(target)) return target;
  try {
    const cache = JSON.parse(require("fs").readFileSync("/tmp/firefox-bidi-refs.json", "utf8"));
    if (!cache.refs?.[target]) throw new Error();
    return cache.refs[target];
  } catch {
    throw new Error(`ref ${target} 不存在或已失效，请重新执行 snapshot`);
  }
}

function jsString(value) { return JSON.stringify(String(value)); }

async function main() {
  if (command === "help" || command === "--help" || command === "-h") usage(0);
  const { options, positional } = parseOptions(argv);
  const bidi = new Bidi(endpoint);
  await bidi.connect();
  try {
    if (command === "tabs") {
      const tree = await bidi.send("browsingContext.getTree", {});
      for (const x of flattenContexts(tree.contexts)) console.log(`${"  ".repeat(x.depth)}${x.context}  ${x.url}`);
      return;
    }

    const selected = await selectContext(bidi, options);
    const context = selected.context;

    if (command === "snapshot") {
      const items = await snapshot(bidi, context, options.limit || 80);
      console.log(`context=${context}\nurl=${selected.url}\n`);
      for (const x of items) {
        const meta = [x.tag, x.role && `role=${x.role}`, x.type && `type=${x.type}`, x.disabled && "disabled"].filter(Boolean).join(" ");
        console.log(`[${x.ref}] ${meta} ${JSON.stringify(x.text)} @ ${x.rect.x},${x.rect.y} ${x.rect.width}x${x.rect.height}`);
      }
      return;
    }

    if (command === "eval") {
      if (!positional.length) throw new Error("eval 缺少 JavaScript");
      console.log(JSON.stringify(await evaluate(bidi, context, positional.join(" ")), null, 2));
      return;
    }

    if (command === "click") {
      if (!positional[0]) throw new Error("click 缺少 eN 或 selector");
      const selector = resolveTarget(positional[0]);
      const rect = await evaluate(bidi, context, `(() => { const e=document.querySelector(${jsString(selector)}); if(!e) throw new Error("target not found"); e.scrollIntoView({block:"center",inline:"center"}); const r=e.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2}; })()`);
      await bidi.send("input.performActions", { context, actions: [{ type: "pointer", id: "mouse", parameters: { pointerType: "mouse" }, actions: [
        { type: "pointerMove", x: Math.round(rect.x), y: Math.round(rect.y), duration: 0, origin: "viewport" },
        { type: "pointerDown", button: 0 },
        { type: "pointerUp", button: 0 }
      ]}]});
      console.log(`clicked ${positional[0]} -> ${selector}`);
      return;
    }

    if (command === "fill") {
      if (positional.length < 2) throw new Error("fill 需要 <eN|selector> <text>");
      const selector = resolveTarget(positional[0]);
      const text = positional.slice(1).join(" ");
      await evaluate(bidi, context, `(() => { const e=document.querySelector(${jsString(selector)}); if(!e) throw new Error("target not found"); e.scrollIntoView({block:"center"}); e.focus(); if("value" in e) { const p=Object.getPrototypeOf(e); const d=Object.getOwnPropertyDescriptor(p,"value"); if(d&&d.set)d.set.call(e,""); else e.value=""; e.dispatchEvent(new Event("input",{bubbles:true})); } else if(e.isContentEditable) { e.textContent=""; e.dispatchEvent(new InputEvent("input",{bubbles:true,inputType:"deleteContentBackward"})); } return true; })()`);
      const actions = [];
      for (const ch of text) {
        actions.push({ type: "keyDown", value: ch }, { type: "keyUp", value: ch });
      }
      await bidi.send("input.performActions", { context, actions: [{ type: "key", id: "keyboard", actions }] });
      console.log(`filled ${positional[0]} (${text.length} chars)`);
      return;
    }

    if (command === "press") {
      if (!positional[0]) throw new Error("press 缺少按键");
      const keys = { Enter: "\uE007", Tab: "\uE004", Escape: "\uE00C", Backspace: "\uE003", Delete: "\uE017", ArrowUp: "\uE013", ArrowDown: "\uE015", ArrowLeft: "\uE012", ArrowRight: "\uE014" };
      const value = keys[positional[0]] || positional[0];
      await bidi.send("input.performActions", { context, actions: [{ type: "key", id: "keyboard", actions: [{ type: "keyDown", value }, { type: "keyUp", value }] }] });
      console.log(`pressed ${positional[0]}`);
      return;
    }

    if (command === "scroll") {
      const dx = Number(positional[0] || 0), dy = Number(positional[1] || 0);
      await bidi.send("input.performActions", { context, actions: [{ type: "wheel", id: "wheel", actions: [{ type: "scroll", x: 0, y: 0, deltaX: dx, deltaY: dy, duration: 0, origin: "viewport" }] }] });
      console.log(`scrolled ${dx},${dy}`);
      return;
    }

    if (command === "screenshot") {
      if (!positional[0]) throw new Error("screenshot 缺少输出文件");
      const result = await bidi.send("browsingContext.captureScreenshot", { context, origin: "viewport" });
      require("fs").writeFileSync(positional[0], Buffer.from(result.data, "base64"));
      console.log(positional[0]);
      return;
    }

    throw new Error(`未知命令: ${command}`);
  } finally {
    await bidi.close();
  }
}

main().catch(err => {
  console.error("ERROR:", err.message);
  process.exit(1);
});
