// 精确清理 ChatGPT 的 MCP 工具组件。
// 真实 DOM（Firefox 156 / ChatGPT 2026-09）：每次 MCP 调用由 div.contents 承载，
// 其中同时包含 span.group/tool-message、连接器按钮和一个昂贵的 iframe。
// 默认 compact 会把整个组件（包括 iframe）替换成轻量占位符。
(() => {
  const API = globalThis.browser ?? globalThis.chrome;
  const DEFAULTS = { mode: "compact", debug: false };
  let settings = { ...DEFAULTS };
  let timer = 0;

  const TOOL_TOGGLE = 'button[aria-label="打开工具调用列表"],button[aria-label="Open tool calls"]';

  function log(...args) {
    if (settings.debug) console.debug("[DevSpace Cleaner]", ...args);
  }

  function isDevSpaceIframe(iframe) {
    if (!iframe) return false;
    const src = iframe.getAttribute("src") || "";
    const title = (iframe.getAttribute("title") || "").trim();
    // ChatGPT 2026-09 的桌面版已把 title 从 ui://devspace/... 改成单纯 "mcp"，
    // 但 sandbox 仍位于 *.web-sandbox.oaiusercontent.com。
    return /(?:^|\.)web-sandbox\.oaiusercontent\.com/i.test(new URL(src, location.href).hostname)
      && (/^ui:\/\/devspace\//i.test(title) || /^mcp$/i.test(title));
  }

  function hasMcpChrome(node) {
    const text = (node.innerText || "").trim();
    if (/^mcp(?:\s|$)/i.test(text)) return true;
    return [...node.querySelectorAll("button")].some(b => {
      const aria = (b.getAttribute("aria-label") || "").trim();
      return /(?:打开.*应用|open.*app)/i.test(aria);
    });
  }

  function findIframeComponent(iframe) {
    // iframe 是当前最稳定的锚点。不要再依赖 div.contents：
    // 新桌面 DOM 的 contents 已经可能包住整段回复中的十几个 MCP iframe。
    // 从 iframe 向上取“最近的、只含一个 iframe 且有严格 mcp connector”的容器，
    // 能把单次工具卡精确切出来，同时避免误删 conversation turn。
    let node = iframe.parentElement;
    for (let i = 0; node && i < 10; i++, node = node.parentElement) {
      if (node.matches?.('[data-testid^="conversation-turn"]')) return null;
      if (node.querySelectorAll?.("iframe").length !== 1) continue;
      if (!hasMcpChrome(node)) continue;
      return node;
    }
    return null;
  }

  function findToggleComponent(toggle) {
    let node = toggle.parentElement;
    for (let i = 0; node && i < 10; i++, node = node.parentElement) {
      if (node.matches?.('[data-testid^="conversation-turn"]')) return null;
      if (node.querySelectorAll?.("iframe").length !== 1) continue;
      const iframe = [...node.querySelectorAll("iframe")].find(isDevSpaceIframe);
      if (iframe && hasMcpChrome(node)) return node;
    }
    return null;
  }

  function compact(component) {
    const iframeCount = component.querySelectorAll("iframe").length;
    const placeholder = document.createElement("div");
    placeholder.className = "dsc-placeholder";
    placeholder.dataset.dsc = "placeholder";
    placeholder.textContent = "MCP";
    log("detach MCP component", {
      iframeCount,
      html: component.outerHTML.slice(0, 1000)
    });
    component.replaceWith(placeholder);
  }

  function clean() {
    if (settings.mode === "show") return;
    const components = new Set();

    // 主路径：直接反向追踪 DevSpace sandbox iframe。
    // 流式工具调用即使尚未生成“打开工具调用列表”按钮，也能被及时清理。
    for (const iframe of document.querySelectorAll("iframe")) {
      if (!isDevSpaceIframe(iframe)) continue;
      const component = findIframeComponent(iframe);
      if (component) components.add(component);
    }

    // 后备路径：兼容历史工具调用 DOM。
    for (const toggle of document.querySelectorAll(TOOL_TOGGLE)) {
      if (toggle.closest("[data-dsc]")) continue;
      const component = findToggleComponent(toggle);
      if (component) components.add(component);
    }
    for (const component of components) {
      if (!component.isConnected) continue;
      if (settings.mode === "hide") {
        log("remove MCP component", { iframes: component.querySelectorAll("iframe").length });
        component.remove();
      } else {
        compact(component);
      }
    }
  }

  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(clean, 100);
  }

  API.storage.local.get(DEFAULTS, values => {
    settings = { ...DEFAULTS, ...values };
    clean();
    new MutationObserver(schedule).observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  });

  API.storage.onChanged.addListener(changes => {
    for (const [key, value] of Object.entries(changes)) settings[key] = value.newValue;
    clean();
  });
})();
