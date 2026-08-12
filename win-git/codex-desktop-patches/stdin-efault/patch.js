"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { extractedAppPatch } = require("../../../../descriptor.js");

const NEEDLE = "t.closeStdin?n.end(e,a):n.write(e,a)";
const REPLACEMENT = "t.closeStdin?n.end(a):n.write(e,a)";

function patchLinuxStdinEfault(extractedDir) {
  const buildDir = path.join(extractedDir, ".vite", "build");
  if (!fs.existsSync(buildDir)) {
    return { matched: 0, changed: 0, reason: "build directory not found" };
  }

  let matched = 0;
  let changed = 0;
  for (const name of fs.readdirSync(buildDir).filter((entry) => entry.endsWith(".js"))) {
    const filePath = path.join(buildDir, name);
    const source = fs.readFileSync(filePath, "utf8");
    const occurrences = source.split(NEEDLE).length - 1;
    if (occurrences === 0) continue;
    matched += occurrences;
    const patched = source.split(NEEDLE).join(REPLACEMENT);
    if (patched !== source) {
      fs.writeFileSync(filePath, patched, "utf8");
      changed += occurrences;
    }
  }

  return {
    matched,
    changed,
    reason: matched === 0 ? "closeStdin write pattern not found" : null,
  };
}

module.exports = extractedAppPatch({
  id: "linux-stdin-close-efault",
  phase: "extracted-app:pre-webview",
  order: 135,
  ciPolicy: "optional",
  apply: patchLinuxStdinEfault,
});

