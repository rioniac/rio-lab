#!/usr/bin/env bash
# Rio Lab — verify.sh
# Tests that the LLM server is running and OpenCode can connect

set -euo pipefail

verify() {
  local endpoint="${1:-${LOCAL_ENDPOINT:-http://127.0.0.1:8080/v1}}"
  local host="${RIO_HOST:-127.0.0.1}"
  local port="${RIO_PORT:-8080}"
  local base="http://${host}:${port}"

  log_step "Verifying Rio Lab Setup"

  local all_good=true

  # ─── 1. Check llama-server is running ──────────────────────────────
  echo -n "Checking llama-server... "
  if curl -sf "$base/v1/models" > /dev/null 2>&1; then
    echo -e "${RIO_GREEN}RUNNING${RIO_RESET}"

    local models
    models=$(curl -sf "$base/v1/models" 2>/dev/null | python3 -m json.tool 2>/dev/null || curl -sf "$base/v1/models" 2>/dev/null || echo "{}")
    echo "  Models available:"
    echo "  $models" | grep -o '"id"[^,]*' | head -5 | sed 's/^/    /'
  else
    echo -e "${RIO_RED}NOT RESPONDING${RIO_RESET}"
    all_good=false
  fi

  # ─── 2. Test chat completion ────────────────────────────────────────
  echo -n "Testing chat completion... "
  local response
  response=$(curl -sf "$endpoint/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "gpt-3.5-turbo",
      "messages": [{"role": "user", "content": "Say hello in one word"}],
      "max_tokens": 10,
      "temperature": 0.0
    }' 2>/dev/null || echo "")

  if [[ -n $response ]]; then
    local content
    content=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null || echo "response received")
    echo -e "${RIO_GREEN}OK${RIO_RESET}"
    echo "  Response: $content"
  else
    echo -e "${RIO_YELLOW}SKIPPED${RIO_RESET}"
    echo "  (model may need more time to load)"
  fi

  # ─── 3. Check OpenCode ─────────────────────────────────────────────
  echo -n "Checking OpenCode CLI... "
  if command -v opencode &>/dev/null; then
    local version
    version=$(opencode --version 2>/dev/null || echo "installed")
    echo -e "${RIO_GREEN}$version${RIO_RESET}"
  else
    echo -e "${RIO_YELLOW}NOT FOUND${RIO_RESET}"
    echo "  Install with: curl -fsSL https://opencode.ai/install | bash"
    all_good=false
  fi

  # ─── 4. Check config ───────────────────────────────────────────────
  echo -n "Checking OpenCode config... "
  local config_paths=(
    "./opencode.json"
    "$HOME/.config/opencode/opencode.json"
    "$HOME/.opencode.json"
  )

  local found_config=""
  for p in "${config_paths[@]}"; do
    if [[ -f "$p" ]]; then
      found_config="$p"
      break
    fi
  done

  if [[ -n $found_config ]]; then
    echo -e "${RIO_GREEN}FOUND${RIO_RESET}"
    echo "  Config: $found_config"

    # Check if LOCAL_ENDPOINT is set in env
    if [[ -n "${LOCAL_ENDPOINT:-}" ]]; then
      echo "  LOCAL_ENDPOINT: $LOCAL_ENDPOINT"
    else
      echo -e "  LOCAL_ENDPOINT: ${RIO_YELLOW}NOT SET${RIO_RESET}"
      echo "  Set with: export LOCAL_ENDPOINT=$endpoint"
    fi
  else
    echo -e "${RIO_YELLOW}NOT FOUND${RIO_RESET}"
  fi

  # ─── 5. Check model file ───────────────────────────────────────────
  if [[ -n "${RIO_MODEL_PATH:-}" ]] && [[ -f "$RIO_MODEL_PATH" ]]; then
    local size
    size=$(du -h "$RIO_MODEL_PATH" | cut -f1)
    echo "  Model file: $RIO_MODEL_PATH ($size)"
  fi

  # ─── Summary ──────────────────────────────────────────────────────
  echo ""
  if $all_good; then
    log_success "All checks passed! Rio Lab is ready."
    echo ""
    echo "  Chat UI:  $base"
    echo "  API:      $endpoint"
    echo "  OpenCode: opencode"
  else
    log_warning "Some checks failed — see above for details"
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dir=$(dirname "${BASH_SOURCE[0]}")
  source "$dir/common.sh"
  verify "$@"
fi
