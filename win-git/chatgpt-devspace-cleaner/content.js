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

  function findComponent(toggle) {
    // 实测层级：toggle -> div -> button -> div -> span -> span.group/tool-message
    // -> div.contents（这个 div 同时拥有 MCP connector UI + iframe）。
    let node = toggle;
    for (let i = 0; node && i < 9; i++, node = node.parentElement) {
      if (node.matches?.('[data-testid^="conversation-turn"]')) return null;
      if (!node.matches?.("div.contents")) continue;

      const hasToolMessage = !!node.querySelector('span[class*="group/tool-message"]');
      const iframe = node.querySelector("iframe");
      const connector = [...node.querySelectorAll("button")].some(
        b => /^mcp$/i.test((b.textContent || "").trim())
      );
      if (hasToolMessage && iframe && connector) return node;
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
    const toggles = document.querySelectorAll(TOOL_TOGGLE);
    const components = new Set();
    for (const toggle of toggles) {
      if (toggle.closest("[data-dsc]")) continue;
      const component = findComponent(toggle);
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
