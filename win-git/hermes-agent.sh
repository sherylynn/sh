#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
source "$(dirname "$0")/toolsinit.sh"

# --- 配置 ---
HERMES_VERSION="main"
HERMES_REPO="https://github.com/NousResearch/hermes-agent.git"
HERMES_INSTALL_DIR="$HOME/.hermes"
HERMES_HOME="$HOME/.hermes"  # 配置目录，不是安装目录

# --- 脚本主体 ---

echo "准备安装 Hermes Agent..."

# 1. 检查依赖
echo "检查依赖..."

# Git
if command -v git >/dev/null 2>&1; then
  echo "✓ Git $(git --version | awk '{print $3}') found"
else
  echo "✗ Git not found, installing..."
  sudo apt update && sudo apt install -y git
fi

# Python 3.11+
PYTHON_CMD=""
if command -v python3.11 >/dev/null 2>&1; then
  PYTHON_CMD="python3.11"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_VER=$(python3 --version 2>&1 | awk '{print $2}')
  if [[ "$PYTHON_VER" == 3.11* ]] || [[ "$PYTHON_VER" == 3.12* ]] || [[ "$PYTHON_VER" == 3.13* ]]; then
    PYTHON_CMD="python3"
  fi
fi

if [[ -n "$PYTHON_CMD" ]]; then
  echo "✓ Python $(${PYTHON_CMD} --version 2>&1) found"
else
  echo "✗ Python 3.11+ not found"
fi

# uv
if command -v uv >/dev/null 2>&1; then
  echo "✓ uv $(uv --version) found"
else
  echo "→ Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "✓ uv installed"
fi

# Node.js
if command -v node >/dev/null 2>&1; then
  echo "✓ Node.js $(node --version) found"
else
  echo "⚠ Node.js not found (required for browser tools & WhatsApp bridge)"
fi

# ripgrep
if command -v rg >/dev/null 2>&1; then
  echo "✓ ripgrep $(rg --version | head -1 | awk '{print $2}') found"
fi

# ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
  echo "✓ ffmpeg $(ffmpeg -version | head -1 | awk '{print $3}') found"
fi

echo ""

# 2. 克隆仓库
echo "→ Installing to ${HERMES_INSTALL_DIR}..."
if [[ -d "$HERMES_HOME" ]]; then
  echo "→ Updating existing installation..."
  git -C "$HERMES_HOME" pull --recurse-submodules
else
  mkdir -p "$HERMES_INSTALL_DIR"
  echo "→ Cloning repository..."
  git clone --recurse-submodules --branch "${HERMES_VERSION}" --depth 1 "$HERMES_REPO" "$HERMES_HOME"
  if [[ $? -ne 0 ]]; then
    echo "→ SSH failed, trying HTTPS..."
    rm -rf "$HERMES_HOME"
    git clone --recurse-submodules --branch "${HERMES_VERSION}" "$HERMES_REPO" "$HERMES_HOME"
  fi
fi

echo "✓ Repository ready"

# 3. 创建虚拟环境
echo "→ Creating virtual environment..."
cd "$HERMES_HOME"
uv venv --python 3.11
echo "✓ Virtual environment ready"

# 4. 安装 Python 依赖
echo "→ Installing Python dependencies..."
uv pip install -e .
echo "✓ Python dependencies installed"

# 5. 安装 Node.js 依赖
echo "→ Installing Node.js dependencies (browser tools)..."
npm install
echo "✓ Node.js dependencies installed"

# 6. 创建便捷启动脚本
HERMES_BIN_DIR="$HOME/.local/bin"
mkdir -p "$HERMES_BIN_DIR"
cat > "$HERMES_BIN_DIR/hermes" <<'BINSCRIPT'
#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"
cd "$HOME/.hermes/hermes-agent"
if [ -d ".venv" ]; then
  source "$HOME/.hermes/hermes-agent/.venv/bin/activate"
else
  source "$HOME/.hermes/hermes-agent/venv/bin/activate"
fi
exec python "$HOME/.hermes/hermes-agent/cli.py" "$@"
BINSCRIPT
chmod +x "$HERMES_BIN_DIR/hermes"

# 7. 配置环境变量 (使用标准 toolsRC 机制)
echo ""
echo "→ 正在配置环境变量..."
TOOLSRC_FILE=$(toolsRC "hermesrc")

cat > "$TOOLSRC_FILE" <<'EOF'
# Hermes Agent environment variables
# This file is managed by toolsRC. Do not edit manually.

export HERMES_HOME="$HOME/.hermes"
export PATH="$HOME/.local/bin:$HOME/.hermes/hermes-agent/venv/bin:$PATH"
# Clear stale Anthropic env vars (use OpenRouter instead)
unset ANTHROPIC_API_KEY
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_TOKEN
EOF

echo ""
# 8. 创建 .env 配置文件（从 OpenClaw 复制 API Keys，已有则跳过）
HERMES_ENV="$HERMES_HOME/.env"
if [[ -f "$HERMES_ENV" ]]; then
  echo "→ .env 已存在，跳过（如需重新生成请手动删除）"
else
  echo "→ 配置 API Keys..."

  # 从 OpenClaw 的 auth-profiles.json 提取 OpenRouter key
  OPENROUTER_KEY=""
  if [[ -f "$HOME/.openclaw/agents/main/agent/auth-profiles.json" ]]; then
    OPENROUTER_KEY=$(python3 -c "import json; d=json.load(open('$HOME/.openclaw/agents/main/agent/auth-profiles.json')); print(d.get('profiles',{}).get('openrouter:default',{}).get('key',''))" 2>/dev/null)
  fi

  # 从 OpenClaw 配置提取 Xiaomi key
  XIAOMI_KEY=""
  if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
    XIAOMI_KEY=$(python3 -c "import json; d=json.load(open('$HOME/.openclaw/openclaw.json')); print(d.get('env',{}).get('XIAOMI_API_KEY',''))" 2>/dev/null)
  fi

  cat > "$HERMES_ENV" <<ENVEOF
# Hermes Agent Environment Configuration
# Auto-configured from OpenClaw

# OpenRouter (primary LLM provider)
OPENROUTER_API_KEY=$OPENROUTER_KEY

# Clear stale Anthropic env vars inherited from parent process
ANTHROPIC_API_KEY=
ANTHROPIC_BASE_URL=
ANTHROPIC_TOKEN=

# Xiaomi (for MiMo models)
XIAOMI_API_KEY=$XIAOMI_KEY
ENVEOF
  echo "✓ .env created"
fi

# 9. 创建 config.yaml（已有则跳过）
HERMES_YAML="$HERMES_HOME/config.yaml"
if [[ -f "$HERMES_YAML" ]]; then
  echo "→ config.yaml 已存在，跳过（如需重新生成请手动删除）"
else
  echo "→ 配置默认模型..."
  cat > "$HERMES_YAML" <<'YAMLEOF'
# Hermes Agent Configuration
# Model: Xiaomi MiMo V2 Omni (same as OpenClaw)

model:
  default: xiaomi/mimo-v2-omni
  provider: custom
  base_url: https://token-plan-cn.xiaomimimo.com/v1
  api_key: ${XIAOMI_API_KEY}

gateway:
  enabled: false

tools:
  enabled: true
YAMLEOF
  echo "✓ config.yaml created"
fi

# 10. 清理 auth.json 中残留的 Anthropic 引用
if [[ -f "$HERMES_HOME/auth.json" ]]; then
  python3 -c "
import json
with open('$HERMES_HOME/auth.json') as f:
    data = json.load(f)
# Remove stale Anthropic entries
if 'credential_pool' in data and 'anthropic' in data['credential_pool']:
    del data['credential_pool']['anthropic']
with open('$HERMES_HOME/auth.json', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
  echo "✓ auth.json cleaned"
fi

echo ""
echo "✅ Hermes Agent 安装并配置完成！"
echo "请重启您的终端或运行 'source ~/.zshrc' 来使配置生效。"
echo ""
echo "常用命令："
echo "  hermes            - 启动 Hermes Agent"
echo "  hermes --query '问题'  - 单次查询"
echo "  hermes model      - 切换模型"
echo "  hermes gateway    - 配置消息平台"
echo ""
echo "默认模型: stepfun/step-3.5-flash:free (OpenRouter 免费)"
echo "如需切换，在 $HERMES_HOME/config.yaml 修改 model.default"
echo ""
