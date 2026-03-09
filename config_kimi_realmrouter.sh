#!/usr/bin/env bash
set -euo pipefail

# Configure an existing Kimi CLI installation to use RealmRouter on macOS.
# This script does NOT install Kimi CLI. It only configures it.
#
# Local usage:
#   bash config_kimi_realmrouter.sh
#
# Remote one-liner after hosting this file:
#   curl -fsSL <RAW_SCRIPT_URL> | bash

MODEL_NAME="moonshotai/Kimi-K2.5"
BASE_URL="https://realmrouter.cn/v1"
PROVIDER_NAME="realmrouter"
PROVIDER_TYPE="openai_responses"
CONFIG_DIR="${HOME}/.kimi"
CONFIG_FILE="${CONFIG_DIR}/config.toml"
KEYCHAIN_SERVICE="kimi-cli-realmrouter-openai"
WRAPPER_PATH="${HOME}/.local/bin/kimi-rr"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This configurator is for macOS only."
  exit 1
fi

if ! command -v KIMI >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/KIMI" ]]; then
  echo "Kimi CLI is not installed. Please install Kimi CLI first, then run this script again."
  exit 1
fi

read_api_key() {
  local input=""
  printf 'Enter your RealmRouter API key: ' >&2
  stty -echo
  IFS= read -r input
  stty echo
  printf '\n' >&2

  if [[ -z "$input" ]]; then
    echo "API key cannot be empty."
    exit 1
  fi

  printf '%s' "$input"
}

store_api_key_in_keychain() {
  local api_key="$1"
  echo "[1/4] Storing API key in macOS Keychain..."
  security add-generic-password \
    -a "$USER" \
    -s "$KEYCHAIN_SERVICE" \
    -w "$api_key" \
    -U >/dev/null
}

write_kimi_config() {
  echo "[2/4] Writing ~/.kimi/config.toml ..."
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
default_model = "${MODEL_NAME}"
default_thinking = true
default_yolo = false

[models."${MODEL_NAME}"]
provider = "${PROVIDER_NAME}"
model = "${MODEL_NAME}"
max_context_size = 262144
capabilities = ["video_in", "image_in", "thinking"]

[providers."${PROVIDER_NAME}"]
type = "${PROVIDER_TYPE}"
base_url = "${BASE_URL}"
api_key = ""

[models."kimi-code/kimi-for-coding"]
provider = "managed:kimi-code"
model = "kimi-for-coding"
max_context_size = 262144
capabilities = ["video_in", "image_in", "thinking"]

[providers."managed:kimi-code"]
type = "kimi"
base_url = "https://api.kimi.com/coding/v1"
api_key = ""

[providers."managed:kimi-code".oauth]
storage = "file"
key = "oauth/kimi-code"

[loop_control]
max_steps_per_turn = 100
max_retries_per_step = 3
max_ralph_iterations = 0
reserved_context_size = 50000

[services.moonshot_search]
base_url = "https://api.kimi.com/coding/v1/search"
api_key = ""

[services.moonshot_search.oauth]
storage = "file"
key = "oauth/kimi-code"

[services.moonshot_fetch]
base_url = "https://api.kimi.com/coding/v1/fetch"
api_key = ""

[services.moonshot_fetch.oauth]
storage = "file"
key = "oauth/kimi-code"

[mcp.client]
tool_call_timeout_ms = 60000
EOF
}

write_wrapper() {
  echo "[3/4] Writing secure launcher..."
  mkdir -p "$(dirname "$WRAPPER_PATH")"
  cat > "$WRAPPER_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export OPENAI_BASE_URL="https://realmrouter.cn/v1"
export OPENAI_API_KEY="$(security find-generic-password -a "$USER" -s "kimi-cli-realmrouter-openai" -w)"
exec "$HOME/.local/bin/KIMI" "$@"
EOF
  chmod +x "$WRAPPER_PATH"

  python3 - <<'PY'
from pathlib import Path
p = Path.home() / '.zshrc'
start = '# >>> kimi-realmrouter >>>'
end = '# <<< kimi-realmrouter <<<'
block = '''# >>> kimi-realmrouter >>>
alias KIMI='$HOME/.local/bin/kimi-rr'
# <<< kimi-realmrouter <<<
'''
text = p.read_text() if p.exists() else ''
if start in text and end in text:
    before = text.split(start, 1)[0]
    after = text.split(end, 1)[1]
    text = before + block + after
else:
    if text and not text.endswith('\n'):
        text += '\n'
    text += '\n' + block
p.write_text(text)
PY
}

verify_config() {
  echo "[4/4] Verifying configuration..."
  export OPENAI_BASE_URL="$BASE_URL"
  export OPENAI_API_KEY="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w)"
  local result
  result="$(KIMI --print --final-message-only -p '回复：配置校验通过' 2>/dev/null || true)"
  if [[ "$result" == *"配置校验通过"* ]]; then
    echo "Success: Kimi CLI has been configured for RealmRouter."
    echo "$result"
  else
    echo "Configuration was written, but online verification did not return the expected text."
    echo "Please run KIMI manually and inspect the output."
  fi
}

API_KEY="$(read_api_key)"
store_api_key_in_keychain "$API_KEY"
write_kimi_config
write_wrapper
verify_config

echo
echo "Done."
echo "Open a new terminal, then run: KIMI"
echo "If current shell doesn't pick up the alias yet, run: source ~/.zshrc"
