#!/usr/bin/env bash
# Rio Lab — configure.sh
# Generates config files, launcher scripts, and environment setup

set -euo pipefail

configure() {
  local rio_home="${RIO_HOME:-$HOME/rio-lab}"
  local config_dir="${RIO_CONFIG_DIR:-$rio_home/config}"
  local models_dir="${RIO_MODELS_DIR:-$rio_home/models}"
  local model_path="${RIO_MODEL_PATH:-}"
  local model_id="${RIO_MODEL_ID:-}"
  local llama_server="${RIO_LLAMA_SERVER:-}"
  local host="${RIO_HOST:-127.0.0.1}"
  local port="${RIO_PORT:-8080}"
  local endpoint="http://${host}:${port}/v1"

  log_step "Configuring Rio Lab"

  mkdir -p "$config_dir" "$models_dir"

  # ─── opencode.json ─────────────────────────────────────────────────
  if [[ -f "$rio_home/../configs/opencode.json.template" ]]; then
    local template="$rio_home/../configs/opencode.json.template"
  elif [[ -f "configs/opencode.json.template" ]]; then
    local template="configs/opencode.json.template"
  else
    local template=""
  fi

  if [[ -n $template ]] && [[ -f $template ]]; then
    log_info "Generating opencode.json..."
    render_template "$template" "$config_dir/opencode.json" \
      "LOCAL_ENDPOINT" "$endpoint" \
      "MODEL_ID" "$model_id"
    log_success "Created: $config_dir/opencode.json"
  fi

  # ─── rio.env ───────────────────────────────────────────────────────
  log_info "Generating environment config..."
  cat > "$config_dir/rio.env" << ENVEOF
# Rio Lab Configuration
# Source this file in your shell: source $config_dir/rio.env

RIO_HOME="$rio_home"
RIO_MODELS_DIR="$models_dir"
RIO_CONFIG_DIR="$config_dir"
RIO_MODEL_PATH="$model_path"
RIO_MODEL_ID="$model_id"
RIO_LLAMA_SERVER="$llama_server"
RIO_HOST="$host"
RIO_PORT="$port"

# OpenCode endpoint
LOCAL_ENDPOINT="$endpoint"
export LOCAL_ENDPOINT
ENVEOF
  log_success "Created: $config_dir/rio.env"

  # ─── Launcher Script ──────────────────────────────────────────────
  log_info "Generating launcher script..."
  cat > "$rio_home/rio-launcher.sh" << LAUNCHER
#!/usr/bin/env bash
# Rio Lab Launcher
# Starts llama-server and opens the web UI / OpenCode

RIO_HOME="$rio_home"
source "\$RIO_HOME/config/rio.env"

cleanup() {
  echo ""
  echo "Shutting down llama-server..."
  if [[ -n \${RIO_SERVER_PID:-} ]]; then
    kill "\$RIO_SERVER_PID" 2>/dev/null || true
    wait "\$RIO_SERVER_PID" 2>/dev/null || true
  fi
  echo "Rio Lab stopped."
}
trap cleanup EXIT INT TERM

# Start llama-server
echo "Starting llama-server..."
echo "Model: \$RIO_MODEL_PATH"
echo "Endpoint: \$LOCAL_ENDPOINT"
echo ""

${llama_server} \\
  --model "\$RIO_MODEL_PATH" \\
  --host "${host}" \\
  --port "${port}" \\
  --n-gpu-layers 999 \\
  --ctx-size 8192 \\
  --temp 0.6 \\
  --top-p 0.95 \\
  --top-k 40 \\
  --threads $(get_cpu_count) &
RIO_SERVER_PID=\$!

# Wait for server to be ready
echo -n "Waiting for server"
for i in \$(seq 1 30); do
  if curl -sf "\$LOCAL_ENDPOINT/models" > /dev/null 2>&1; then
    echo " READY!"
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  Rio Lab is running!                     ║"
    echo "║                                          ║"
    echo "║  Chat UI:  http://${host}:${port}        ║"
    echo "║  API:      \$LOCAL_ENDPOINT               ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "Press Ctrl+C to stop."
    break
  fi
  echo -n "."
  sleep 1
done

# Wait for server process
wait \$RIO_SERVER_PID
LAUNCHER
  chmod +x "$rio_home/rio-launcher.sh"
  log_success "Created: $rio_home/rio-launcher.sh"

  # ─── Shell Integration ─────────────────────────────────────────────
  local rc_file=""
  if [[ -n "${BASH_VERSION:-}" ]]; then
    rc_file="$HOME/.bashrc"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    rc_file="$HOME/.zshrc"
  fi

  if [[ -n $rc_file ]] && [[ -f $rc_file ]]; then
    if ! grep -q "rio.env" "$rc_file" 2>/dev/null; then
      echo "" >> "$rc_file"
      echo "# Rio Lab" >> "$rc_file"
      echo "export LOCAL_ENDPOINT=\"$endpoint\"" >> "$rc_file"
      echo "source $config_dir/rio.env" >> "$rc_file"
      log_info "Added Rio Lab config to $rc_file"
    fi
  fi

  log_success "Configuration complete!"
  log_info "Config directory: $config_dir"
  log_info "Launcher: $rio_home/rio-launcher.sh"
  log_info "Run it with: bash $rio_home/rio-launcher.sh"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dir=$(dirname "${BASH_SOURCE[0]}")
  source "$dir/common.sh"

  if [[ -z "${RIO_MODEL_ID:-}" ]]; then
    source "$dir/detect-gpu.sh"
    source "$dir/suggest-model.sh"
    detect_gpu
    suggest_model
  fi

  configure "$@"
fi
