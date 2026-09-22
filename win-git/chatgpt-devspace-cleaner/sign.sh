#!/usr/bin/env bash

# sign.sh —— 给 chatgpt-devspace-cleaner 做 AMO 自发行（unlisted）签名，产出可**永久安装**的 .xpi。
#
# 为什么需要它：
#   about:debugging 的“临时载入附加组件”是内存态，Firefox 一关就没了（这是设计行为，不是 bug）。
#   要在 Release 版 Firefox 上永久安装，XPI 必须带 Mozilla 签名。unlisted 签名 = 签名但不上架，
#   走自动审核，团队内部用完全够。
#
# 用法：
#   ./sign.sh              # lint + 用当前 manifest version 签名
#   ./sign.sh -b           # 先把 patch 版本 +1 再签名（AMO 拒绝同一 id 的重复版本号）
#   ./sign.sh -s           # 查 AMO 上该 id 已有版本 / file.status / 下载地址（不签名）
#   ./sign.sh -f           # 把当前 manifest version 在 AMO 上**已签名**的 xpi 取回 web-ext-artifacts/
#   ./sign.sh -f 0.1.0     # 指定版本取回（manifest 已经 bump 过时用这个）
#   ./sign.sh -l           # 只跑本地 lint，不联网、不消耗 AMO 配额
#   ./sign.sh -c listed    # 改用 listed（公开上架）通道
#   ./sign.sh -h           # 帮助
#
# ⚠ 最重要的一条经验：
#   AMO 的签名是**异步**的。web-ext 上传后会一直打印 “Waiting for approval...”，
#   轮询 file.status 变成 public 才下载。实测这里可能要几分钟——期间**千万不要 Ctrl-C**。
#   一旦中断，AMO 侧通常已经收下并签好了，只是你本地没拿到；此时重跑会因为
#   版本号已存在而被拒（错误：This upload has already been submitted）。
#   正确处置：先 ./sign.sh -s 看状态，再 ./sign.sh -f 把签名包取回来。
#   注：web-ext 的 .amo-upload-uuid 续传机制在本机**不可靠**——它的打包顺序不稳定，
#   同一份源码两次构建的 zip 哈希都不同，所以它永远走重传分支，等于没有续传。
#
# 凭据（二选一）：
#   1) export AMO_API_KEY='user:xxxxx:yy' AMO_API_SECRET='...'
#   2) 写进 $AMO_ENV_FILE（默认 ~/.config/amo/devspace-cleaner.env）：
#        AMO_API_KEY=user:xxxxx:yy
#        AMO_API_SECRET=xxxxxxxx
#   凭据申请：https://addons.mozilla.org/developers/addon/api/key/   （JWT 有效期仅 60 秒，脚本每次现签）
#
# 环境变量：
#   AMO_API_KEY / AMO_API_SECRET   签名凭据
#   AMO_ENV_FILE                   凭据文件路径（默认 ~/.config/amo/devspace-cleaner.env）
#   AMO_BASE_URL                   AMO 站点（默认 https://addons.mozilla.org）
#   AMO_ARTIFACTS_DIR              产物目录（默认 ~/my_keys，刻意放在仓库外）
#   WEB_EXT / WEB_EXT_NPM_CACHE / WEB_EXT_NODE_BIN_DIR
#                                  指定 web-ext、npx 缓存、前置到 PATH 的 node 目录
#   NODE / PYTHON                  指定 node / python3 可执行文件
#   SIGN_CHANNEL                   unlisted | listed（默认 unlisted）
#
# 产物：~/my_keys/*.xpi（私有库，随该仓库同步，方便多机安装测试；主仓库 public，不接收产物）
# 安装：about:addons -> 齿轮 -> “从文件安装附加组件” -> 选该 xpi（Release 版也永久生效）

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

CHANNEL="${SIGN_CHANNEL:-unlisted}"
ENV_FILE="${AMO_ENV_FILE:-$HOME/.config/amo/devspace-cleaner.env}"
AMO_BASE="${AMO_BASE_URL:-https://addons.mozilla.org}"
# 产物默认放 ~/my_keys：那是私有密钥仓库，签名包随它同步，换机器 pull 下来就能直接安装测试。
# 注意主仓库 sherylynn/sh 是 **public**，编译产物绝不能落在它里面（下方有告警）。
ARTIFACTS_DIR="${AMO_ARTIFACTS_DIR:-$HOME/my_keys}"
case "${ARTIFACTS_DIR}" in
  "${DIR}"/*)
    echo "⚠ 产物目录在仓库内（${ARTIFACTS_DIR}）。" >&2
    echo "  确认它被 .gitignore 忽略，否则编译产物会被 commit 上去。" >&2 ;;
esac
BUMP=0
LINT_ONLY=0
DO_STATUS=0
DO_FETCH=0

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/amo-sign.XXXXXX")"
cleanup() { rm -rf "${TMPD}"; }
trap cleanup EXIT HUP INT TERM

usage() {
  awk 'NR==1{next} /^[^#]/{exit} NR>2{sub(/^# ?/,"");print}' "${BASH_SOURCE[0]}"
  exit 0
}

while getopts "blsfc:h" opt; do
  case "${opt}" in
    b) BUMP=1 ;;
    l) LINT_ONLY=1 ;;
    s) DO_STATUS=1 ;;
    f) DO_FETCH=1 ;;
    c) CHANNEL="${OPTARG}" ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift "$((OPTIND - 1))" || true
FETCH_VERSION="${1:-}"

# ---------- 运行时定位 ----------
if [ -n "${WEB_EXT_NODE_BIN_DIR:-}" ]; then
  PATH="${WEB_EXT_NODE_BIN_DIR}:${PATH}"
  export PATH
fi

PYTHON_BIN="${PYTHON:-python3}"
if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "✗ 需要 python3（读写 manifest.json、解析 AMO 返回）" >&2
  exit 1
fi
NODE_BIN="${NODE:-node}"

WEB_EXT_CMD=""
if [ -n "${WEB_EXT:-}" ]; then
  [ -x "${WEB_EXT}" ] || { echo "✗ WEB_EXT 指向的文件不可执行：${WEB_EXT}" >&2; exit 1; }
  WEB_EXT_CMD="${WEB_EXT}"
elif command -v web-ext >/dev/null 2>&1; then
  WEB_EXT_CMD="$(command -v web-ext)"
elif command -v npx >/dev/null 2>&1; then
  export npm_config_cache="${WEB_EXT_NPM_CACHE:-$HOME/.cache/web-ext-npm}"
  web_ext() { npx --yes web-ext@8 "$@"; }
  echo "· 未找到全局 web-ext，改用 npx web-ext@8（缓存 ${npm_config_cache}）"
else
  echo "✗ 既没有 web-ext 也没有 npx。装一个：npm i -g web-ext  或  brew install web-ext" >&2
  exit 1
fi

if ! declare -F web_ext >/dev/null 2>&1; then
  web_ext() { "${WEB_EXT_CMD}" "$@"; }
fi

MANIFEST="${DIR}/manifest.json"
[ -f "${MANIFEST}" ] || { echo "✗ 找不到 ${MANIFEST}" >&2; exit 1; }

# 打包时排除的东西。注意用**裸目录名**：光写 "distribution/**" 会漏掉目录条目本身，
# 结果是空目录被打进包（AMO 上传包里就出现过 distribution/ 和 web-ext-artifacts/）。
IGNORES=(
  --ignore-files "sign.sh"
  --ignore-files "distribution"
  --ignore-files "web-ext-artifacts"
  --ignore-files ".DS_Store"
  --ignore-files ".amo-upload-uuid"
)

# ---------- manifest 前置校验（AMO 会因为这些直接拒签） ----------
read_manifest_field() {
  "${PYTHON_BIN}" - "${MANIFEST}" "$1" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
gecko = (m.get("browser_specific_settings") or {}).get("gecko") or {}
path = sys.argv[2]
if path == "version":
    print(m.get("version", ""))
elif path == "id":
    print(gecko.get("id", ""))
elif path == "dcp":
    print("yes" if gecko.get("data_collection_permissions") else "no")
elif path == "min":
    print(gecko.get("strict_min_version", ""))
PY
}

MANIFEST_ID="$(read_manifest_field id)"
MANIFEST_VERSION="$(read_manifest_field version)"
MIN_FIREFOX="$(read_manifest_field min)"

[ -n "${MANIFEST_ID}" ] || { echo "✗ manifest 缺少 browser_specific_settings.gecko.id（MV3 签名必需）" >&2; exit 1; }
if [ "$(read_manifest_field dcp)" != "yes" ]; then
  echo "✗ manifest 缺少 browser_specific_settings.gecko.data_collection_permissions。" >&2
  echo "  2025-11-03 起 AMO 对新提交的扩展强制要求该字段，缺失会被**直接拒绝签名**。" >&2
  echo "  不收集数据就写：\"data_collection_permissions\": { \"required\": [\"none\"] }" >&2
  exit 1
fi
case "${MANIFEST_ID}" in
  *@*@*) echo "✗ gecko.id 含多个 @，AMO 会拒绝：${MANIFEST_ID}" >&2; exit 1 ;;
  *@*) ;;
  \{*\}) ;;
  *) echo "✗ gecko.id 既不是邮箱形式也不是 GUID 形式，AMO 会拒绝：${MANIFEST_ID}" >&2; exit 1 ;;
esac
case "${MANIFEST_ID}" in
  *@example.invalid|*@example.com|*@example.org)
    echo "⚠ gecko.id 用的是保留示例域名：${MANIFEST_ID}"
    echo "  id 是扩展的永久身份，签名后无法更改（改 id = 用户要重装一次）。" ;;
esac
case "${MIN_FIREFOX}" in
  ""|1[0-3][0-9]*|9*|10*|11*|12*|13[0-9])
    echo "⚠ strict_min_version=${MIN_FIREFOX} 覆盖了 Firefox < 140。" >&2
    echo "  按 Mozilla 的数据披露政策，支持 <140 的扩展需要在安装后自行提供数据收集开关。" >&2
    echo "  本扩展声明 required=[none]，最省事的做法是把 strict_min_version 提到 140.0。" >&2 ;;
esac

echo "· 扩展 ${MANIFEST_ID} v${MANIFEST_VERSION}（channel=${CHANNEL}，min Firefox ${MIN_FIREFOX}）"

# ---------- 凭据（按需加载；-l 不需要） ----------
if [ -z "${AMO_API_KEY:-}" ] || [ -z "${AMO_API_SECRET:-}" ]; then
  if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "${ENV_FILE}"
    set +a
    echo "· 已从 ${ENV_FILE} 读取凭据"
  fi
fi
require_creds() {
  if [ -z "${AMO_API_KEY:-}" ] || [ -z "${AMO_API_SECRET:-}" ]; then
    echo "✗ 缺少 AMO_API_KEY / AMO_API_SECRET。" >&2
    echo "  1) 到 https://addons.mozilla.org/developers/addon/api/key/ 生成 JWT issuer / secret" >&2
    echo "  2) mkdir -p \"$(dirname "${ENV_FILE}")\" 并写入：AMO_API_KEY=... / AMO_API_SECRET=..." >&2
    exit 1
  fi
}

# ---------- AMO 只读接口（JWT 走 curl 配置文件，避免出现在命令行/ps 里） ----------
urlenc() {
  "${PYTHON_BIN}" -c 'import sys,urllib.parse as u; print(u.quote(sys.argv[1], safe=""))' "$1"
}

make_jwt() {
  command -v "${NODE_BIN}" >/dev/null 2>&1 || { echo "✗ 需要 node 生成 AMO JWT（HMAC-SHA256）" >&2; return 1; }
  local helper="${TMPD}/jwt.mjs"
  cat > "${helper}" <<'JS'
import crypto from 'node:crypto';
const { AMO_API_KEY: key, AMO_API_SECRET: secret } = process.env;
if (!key || !secret) { console.error('缺少 AMO_API_KEY / AMO_API_SECRET'); process.exit(1); }
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const iat = Math.floor(Date.now() / 1000);
const head = b64({ alg: 'HS256', typ: 'JWT' });
const body = b64({ iss: key, jti: crypto.randomUUID(), iat, exp: iat + 55 });
process.stdout.write(`${head}.${body}.` + crypto.createHmac('sha256', secret).update(`${head}.${body}`).digest('base64url'));
JS
  AMO_API_KEY="${AMO_API_KEY}" AMO_API_SECRET="${AMO_API_SECRET}" "${NODE_BIN}" "${helper}"
}

amo_get() {
  local jwt cfg out
  jwt="$(make_jwt)" || return 1
  cfg="${TMPD}/curl.cfg"
  ( umask 077; printf 'header = "Accept: application/json"\nheader = "Authorization: JWT %s"\n' "${jwt}" > "${cfg}" )
  out="$(curl -sS -K "${cfg}" "${AMO_BASE}$1")"
  rm -f "${cfg}"
  printf '%s' "${out}"
}

cmd_status() {
  require_creds
  echo "· 查询 ${AMO_BASE} 上 ${MANIFEST_ID} 的版本"
  amo_get "/api/v5/addons/addon/$(urlenc "${MANIFEST_ID}")/versions/?filter=all_with_unlisted&page_size=20" > "${TMPD}/ver.json" || exit 1
  "${PYTHON_BIN}" - "${TMPD}/ver.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    print("✗ 解析 AMO 返回失败：", e); sys.exit(1)
if "results" not in d:
    print("✗ AMO 返回：", json.dumps(d, ensure_ascii=False)[:400]); sys.exit(1)
if not d.get("count"):
    print("  AMO 上还没有任何版本（全新 id，或者上传都失败了）"); sys.exit(0)
for v in d["results"]:
    f = v.get("file") or {}
    st = str(f.get("status"))
    note = ""
    if st == "public":
        note = "  <- 已签完，可直接取"
    elif st == "unreviewed":
        note = "  <- 还只是原始包（AMO 尚未签完，等几分钟）"
    print(f"  v{str(v.get('version')):<12} status={st:<12} size={f.get('size')}{note}")
    print(f"      {f.get('url')}")
PY
  echo
  echo "  取当前 manifest 版本（v${MANIFEST_VERSION}）的已签名包：./sign.sh -f"
}

cmd_fetch() {
  require_creds
  local ver="${1:-${MANIFEST_VERSION}}" url out
  echo "· 从 AMO 取 v${ver} 的已签名包"
  amo_get "/api/v5/addons/addon/$(urlenc "${MANIFEST_ID}")/versions/${ver}/" > "${TMPD}/v.json" || exit 1
  url="$("${PYTHON_BIN}" - "${TMPD}/v.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
f = d.get("file") or {}
print(f.get("url") or "")
PY
)"
  if [ -z "${url}" ]; then
    echo "✗ AMO 上没有 v${ver}。先 ./sign.sh -s 看看有哪些版本；" >&2
    echo "  如果版本号已经被 bump 过，指定要取的版本：./sign.sh -f 0.1.0" >&2
    exit 1
  fi
  mkdir -p "${ARTIFACTS_DIR}"
  out="${ARTIFACTS_DIR}/chatgpt-devspace-cleaner-${ver}-signed.xpi"
  local jwt cfg
  jwt="$(make_jwt)" || exit 1
  cfg="${TMPD}/curl.cfg"
  ( umask 077; printf 'header = "Authorization: JWT %s"\n' "${jwt}" > "${cfg}" )
  if ! curl -sS -K "${cfg}" -o "${out}.part" "${url}"; then
    rm -f "${cfg}" "${out}.part"
    echo "✗ 下载失败（网络抖动 / CDN 超时），重试即可：./sign.sh -f ${ver}" >&2
    exit 1
  fi
  rm -f "${cfg}"
  # 未签完时 AMO 给的是原始 zip（里面没有 META-INF），用这个判据避免把半成品发给团队
  if LC_ALL=C grep -aq 'META-INF/mozilla.rsa' "${out}.part"; then
    mv "${out}.part" "${out}"
    echo "✓ 已取回签名包：${out}"
    echo "  sha256: $(hash_file "${out}")"
  else
    rm -f "${out}.part"
    echo "✗ 取到的还是**未签名**的原始包（AMO 尚未签完）。" >&2
    echo "  这不是失败，只是还没到：等几分钟再执行 ./sign.sh -s 看 status 是否变 public，然后 ./sign.sh -f" >&2
    exit 1
  fi
}

hash_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else echo "(无 shasum/sha256sum)"; fi
}

if [ "${DO_STATUS}" -eq 1 ]; then cmd_status; exit 0; fi
if [ "${DO_FETCH}" -eq 1 ]; then cmd_fetch "${FETCH_VERSION:-${MANIFEST_VERSION}}"; exit 0; fi

# ---------- 版本号 +1（AMO 对同一 id 的重复版本号会报错） ----------
if [ "${BUMP}" -eq 1 ]; then
  NEW_VERSION="$("${PYTHON_BIN}" - "${MANIFEST}" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
parts = m["version"].split(".")
while len(parts) < 3:
    parts.append("0")
parts[2] = str(int(parts[2]) + 1)
m["version"] = ".".join(parts[:3])
json.dump(m, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(p, "a", encoding="utf-8").write("\n")
print(m["version"])
PY
)"
  echo "· 版本号 ${MANIFEST_VERSION} -> ${NEW_VERSION}（记得连同代码一起提交）"
  MANIFEST_VERSION="${NEW_VERSION}"
fi

# ---------- lint ----------
echo "· web-ext lint"
set +e
web_ext lint --source-dir "${DIR}" "${IGNORES[@]}" --output json > "${TMPD}/lint.json" 2> "${TMPD}/lint.err"
LINT_RC=$?
set -e
if [ "${LINT_RC}" -ne 0 ]; then
  echo "✗ lint 失败（AMO 也会拒）：" >&2
  cat "${TMPD}/lint.json" "${TMPD}/lint.err" >&2
  exit 1
fi
"${PYTHON_BIN}" - "${TMPD}/lint.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
s = d.get("summary", {})
print(f"  lint: {s.get('errors',0)} error / {s.get('warnings',0)} warning / {s.get('notices',0)} notice")
for e in d.get("errors", []):
    print("  E:", e.get("message"))
for w in d.get("warnings", []):
    print("  W:", w.get("message"))
PY

if [ "${LINT_ONLY}" -eq 1 ]; then
  echo "· 仅 lint，未签名。"
  exit 0
fi

require_creds
mkdir -p "${ARTIFACTS_DIR}"

# ---------- 签名 ----------
echo "· web-ext sign（channel=${CHANNEL}）"
echo "  上传后会停在 “Waiting for approval...”，那是 AMO 在异步签名，可能几分钟。"
echo "  ⚠ 不要 Ctrl-C：中断后 AMO 侧往往已经签好，重跑会因版本号已存在被拒。"
set +e
web_ext sign \
  --source-dir "${DIR}" \
  --artifacts-dir "${ARTIFACTS_DIR}" \
  --channel "${CHANNEL}" \
  "${IGNORES[@]}" \
  --api-key "${AMO_API_KEY}" \
  --api-secret "${AMO_API_SECRET}" 2>&1 | tee "${TMPD}/sign.log"
SIGN_RC="${PIPESTATUS[0]}"
set -e
SIGN_OUT="$(cat "${TMPD}/sign.log" 2>/dev/null || true)"

if [ "${SIGN_RC}" -ne 0 ]; then
  case "${SIGN_OUT}" in
    *"already been submitted"*|*"already exists"*)
      echo >&2
      echo "✗ AMO 拒绝：v${MANIFEST_VERSION} 这个版本号在 AMO 上**已经存在**。" >&2
      echo "  最常见的原因：上一轮签名卡在 “Waiting for approval...” 时被中断了——" >&2
      echo "  那一轮 AMO 其实已经收下并签好，只是本地没下载。**不要重跑**，先看状态：" >&2
      echo "      ./sign.sh -s      # 看各版本的 file.status（public = 已签完）" >&2
      echo "      ./sign.sh -f      # 把当前版本的已签名 xpi 取回来" >&2
      echo "  如果确实是改了代码要发新版本：" >&2
      echo "      ./sign.sh -b      # patch 版本 +1 后再签" >&2
      exit 1 ;;
  esac
  echo "✗ 签名失败（web-ext 退出码 ${SIGN_RC}）" >&2
  exit 1
fi

XPI="$(ls -t "${ARTIFACTS_DIR}"/*.xpi 2>/dev/null | head -1 || true)"
if [ -z "${XPI}" ]; then
  echo "✗ 签名命令成功但没找到 .xpi（看看 ${ARTIFACTS_DIR}）" >&2
  exit 1
fi

if LC_ALL=C grep -aq 'META-INF/mozilla.rsa' "${XPI}"; then
  echo
  echo "✓ 已签名（含 Mozilla 签名，可永久安装）：${XPI}"
  echo "  sha256: $(hash_file "${XPI}")"
else
  echo
  echo "⚠ 这个 xpi 里没有签名段，别拿去装：${XPI}" >&2
  echo "  用 ./sign.sh -s 看 AMO 侧状态，必要时 ./sign.sh -f 取签名包。" >&2
  exit 1
fi
echo "  1) Firefox 打开 about:addons -> 齿轮 -> “从文件安装附加组件”"
echo "  2) 选上面这个 .xpi，安装后**永久生效**，重启不再丢"
echo "  3) 团队成员装同一个 .xpi 即可，无需 developer edition / about:debugging"
echo
echo "  注意：自发行（unlisted）不会自动更新。发新版后让大家重装，"
echo "        或在 manifest 里加 gecko.update_url 指向自建 HTTPS 更新清单。"
