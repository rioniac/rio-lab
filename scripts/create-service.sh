#!/usr/bin/env bash
# Rio Lab — create-service.sh
# Creates a systemd service to auto-start llama-server on boot

set -euo pipefail

create_service() {
  local rio_home="${RIO_HOME:-$HOME/rio-lab}"
  local model_path="${RIO_MODEL_PATH:-}"
  local llama_server="${RIO_LLAMA_SERVER:-}"
  local host="${RIO_HOST:-127.0.0.1}"
  local port="${RIO_PORT:-8080}"

  log_step "Creating systemd service for llama-server"

  if ! has_systemd; then
    log_warning "systemd not detected — skipping service creation"
    log_info "You can start llama-server manually with:"
    log_info "  bash $rio_home/rio-launcher.sh"
    return 1
  fi

  if [[ ! -f "$llama_server" ]] && [[ $llama_server != "llama-server" ]]; then
    log_warning "llama-server not found at: $llama_server"
    log_info "Please install llama.cpp first"
    return 1
  fi

  if [[ ! -f "$model_path" ]]; then
    log_warning "Model not found at: $model_path"
    log_info "Please download a model first"
    return 1
  fi

  local threads
  threads=$(get_cpu_count)

  local unit_path="$HOME/.config/systemd/user/rio-llamacpp.service"
  mkdir -p "$(dirname "$unit_path")"

  if [[ -f "configs/llamacpp.service.template" ]]; then
    render_template "configs/llamacpp.service.template" "$unit_path" \
      "LLAMA_SERVER_PATH" "$llama_server" \
      "MODEL_PATH" "$model_path" \
      "HOST" "$host" \
      "PORT" "$port" \
      "THREADS" "$threads"
  else
    cat > "$unit_path" << UNIT
[Unit]
Description=llama.cpp LLM Server (Rio Lab)
After=network.target

[Service]
Type=simple
ExecStart=$llama_server \\
  --model $model_path \\
  --host $host \\
  --port $port \\
  --n-gpu-layers 999 \\
  --ctx-size 8192 \\
  --temp 0.6 \\
  --top-p 0.95 \\
  --top-k 40 \\
  --threads $threads
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT
  fi

  log_success "Service file created: $unit_path"

  # Reload and enable
  systemctl --user daemon-reload 2>/dev/null || true

  if confirm "Enable llama-server to start on boot?"; then
    systemctl --user enable rio-llamacpp.service
    log_success "Service enabled — llama-server will start automatically on boot"
  fi

  if confirm "Start llama-server now?"; then
    systemctl --user start rio-llamacpp.service
    log_success "llama-server started!"
    log_info "Check status: systemctl --user status rio-llamacpp.service"
    log_info "View logs: journalctl --user -u rio-llamacpp.service -f"
  else
    log_info "Service created but not started. Start it with:"
    log_info "  systemctl --user start rio-llamacpp.service"
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dir=$(dirname "${BASH_SOURCE[0]}")
  source "$dir/common.sh"

  if [[ -z "${RIO_MODEL_PATH:-}" ]]; then
    source "$RIO_HOME/config/rio.env" 2>/dev/null || true
  fi

  create_service "$@"
fi
