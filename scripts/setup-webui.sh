#!/usr/bin/env bash
# Rio Lab — setup-webui.sh
# Sets up Open WebUI as a Docker container pointing at llama-server

set -euo pipefail

setup_webui() {
  local rio_home="${RIO_HOME:-$HOME/rio-lab}"
  local llm_endpoint="${1:-http://host.docker.internal:8080}"

  log_step "Setting up Open WebUI"

  # Check Docker
  if ! command -v docker &>/dev/null; then
    log_warning "Docker is required for Open WebUI"
    log_info "Install Docker first, then re-run this script"
    log_info "  curl -fsSL https://get.docker.com | sh"
    if confirm "Install Docker now?"; then
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker "$USER" 2>/dev/null || true
      log_warning "You may need to log out and back in for Docker group changes"
    else
      return 1
    fi
  fi

  # Determine endpoint
  if [[ $RIO_OS == linux ]] || [[ $RIO_OS == wsl ]]; then
    llm_endpoint="http://host.docker.internal:8080"
  elif [[ $RIO_OS == macos ]]; then
    llm_endpoint="http://host.docker.internal:8080"
  elif [[ $RIO_OS == windows ]]; then
    llm_endpoint="http://host.docker.internal:8080"
  fi

  if [[ -n "${RIO_PORT:-}" ]]; then
    llm_endpoint="http://host.docker.internal:${RIO_PORT}"
  fi

  # Create docker-compose for WebUI
  local compose_file="$rio_home/webui/docker-compose.yml"
  mkdir -p "$rio_home/webui"

  cat > "$compose_file" << COMPOSE
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: rio-webui
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - OPENAI_API_BASE_URL=${llm_endpoint}
      - WEBUI_NAME=Rio Lab
      - ENABLE_SIGNUP=false
      - DEFAULT_MODELS=${RIO_MODEL_ID:-qwen2.5-coder-7b-q4_k_m}
    volumes:
      - ./data:/app/backend/data
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
COMPOSE

  log_success "Open WebUI compose file created: $compose_file"
  log_info "To start: docker compose -f $compose_file up -d"
  log_info "Open WebUI will be at: http://localhost:3000"
  log_info ""
  log_info "Note: First run requires creating an admin account."
  log_info "Open WebUI connects to your local llama-server at: $llm_endpoint"

  # Offer to start now
  if confirm "Start Open WebUI now?"; then
    log_info "Starting Open WebUI..."
    docker compose -f "$compose_file" up -d
    check_previous "Failed to start Open WebUI"

    log_success "Open WebUI started!"
    log_info "Open http://localhost:3000 in your browser"
    log_info "Create your admin account on first visit"
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dir=$(dirname "${BASH_SOURCE[0]}")
  source "$dir/common.sh"

  if [[ -z "${RIO_OS:-}" ]]; then
    source "$dir/detect-platform.sh"
    detect_platform
  fi

  setup_webui "$@"
fi
