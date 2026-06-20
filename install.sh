#!/usr/bin/env bash
# Rio Lab — Unified Installer
# One command to set up a local LLM + OpenCode + Web UI
# Usage: bash install.sh [--method binary|source|docker] [--no-webui] [--help]

# Ensure we're running in bash, even if sourced from fish/zsh/etc.
if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Re-execing in bash..." >&2
  exec bash "$0" "$@"
fi

set -euo pipefail

trap 'echo -e "${RIO_RED}✘ Script failed at line $LINENO${RIO_RESET}" >&2' ERR

# ─── Configuration ──────────────────────────────────────────────────────
RIO_HOME="${RIO_HOME:-$HOME/rio-lab}"
RIO_METHOD="${RIO_METHOD:-binary}"   # binary | source | docker
RIO_SKIP_WEBUI=false
RIO_SKIP_CONFIRM=false
RIO_DOWNLOAD_MODEL=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --method) RIO_METHOD="$2"; shift 2 ;;
    --no-webui) RIO_SKIP_WEBUI=true; shift ;;
    --no-model) RIO_DOWNLOAD_MODEL=false; shift ;;
    --yes) RIO_SKIP_CONFIRM=true; shift ;;
    --help|-h)
      echo "Rio Lab Installer"
      echo "Usage: bash install.sh [options]"
      echo ""
      echo "Options:"
      echo "  --method <binary|source|docker>  Install method (default: binary)"
      echo "  --no-webui                        Skip Open WebUI setup"
      echo "  --no-model                        Skip model download"
      echo "  --yes                             Skip all confirmations"
      echo "  --help                            Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Source Scripts ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

# Detect platform and hardware
source "$SCRIPT_DIR/scripts/detect-platform.sh"
source "$SCRIPT_DIR/scripts/detect-gpu.sh"
detect_platform
detect_gpu

# ─── Banner ─────────────────────────────────────────────────────────────
[[ -t 1 ]] && clear
show_banner

echo -e "${RIO_BOLD}Welcome to Rio Lab!${RIO_RESET}"
echo "This installer will set up a complete local AI lab on your machine:"
echo ""
echo "  🤖  llama.cpp  —  Local LLM inference engine (with Vulkan GPU)"
echo "  ⌨️   OpenCode   —  AI coding agent for your terminal"
echo "  💬  Web UI     —  Chat interface at http://localhost:8080"
echo ""
echo -e "${RIO_BOLD}Platform:${RIO_RESET}  $RIO_OS / $RIO_DISTRO ($RIO_ARCH)"
echo -e "${RIO_BOLD}GPU:${RIO_RESET}       $RIO_GPU_NAME ($RIO_GPU_VENDOR, ${RIO_GPU_VRAM_MB}MB VRAM)"
echo -e "${RIO_BOLD}Install:${RIO_RESET}   $RIO_HOME"
echo ""

if ! $RIO_SKIP_CONFIRM; then
  if ! confirm "Proceed with installation?"; then
    log_info "Installation cancelled."
    exit 0
  fi
fi

# ─── Step 1: System Prerequisites ───────────────────────────────────────
log_step "1/7 — System Prerequisites"

# Check for curl/wget (needed everywhere)
check_command curl "Install curl: sudo apt install curl (or your distro's equivalent)" || {
  check_command wget "Install wget: sudo apt install wget" || exit 1
}

# Check for git (needed for source builds and some package managers)
if [[ $RIO_METHOD == source ]]; then
  check_command git "Install git: sudo apt install git"
fi

# Check for Docker if requested
if [[ $RIO_METHOD == docker ]]; then
  if ! command -v docker &>/dev/null; then
    log_warning "Docker not found — I'll install it for you"
  fi
fi

log_success "Prerequisites check passed"

# ─── Step 2: Hardware Report & Model Selection ────────────────────────
log_step "2/7 — Hardware Report & Model Selection"

echo -e "${RIO_BOLD}Detected Hardware:${RIO_RESET}"
echo "  Operating System:  $RIO_OS ($RIO_DISTRO)"
echo "  Architecture:      $RIO_ARCH"
echo "  CPU Threads:       $(get_cpu_count)"
echo "  System RAM:        $(get_total_ram_mb) MB"
echo "  GPU Vendor:        $RIO_GPU_VENDOR"
echo "  GPU Name:          $RIO_GPU_NAME"
echo "  GPU VRAM:          $RIO_GPU_VRAM_MB MB"
echo "  GPU Backend:       $RIO_GPU_BACKEND"
echo ""

# Suggest model
source "$SCRIPT_DIR/scripts/suggest-model.sh"
suggest_model

echo -e "${RIO_BOLD}Recommended Model:${RIO_RESET} $RIO_SUGGESTED_MODEL_NAME"
echo ""

# Let user choose from available models
if ! $RIO_SKIP_CONFIRM && [[ ${#RIO_AVAILABLE_MODELS[@]} -gt 1 ]]; then
  echo "Available models that fit your hardware:"
  for i in "${!RIO_AVAILABLE_MODELS[@]}"; do
    echo "  $((i+1)). ${RIO_AVAILABLE_MODELS[$i]}"
  done
  echo ""

  if ! confirm "Use recommended model: $RIO_SUGGESTED_MODEL_NAME?"; then
    echo ""
    prompt_value RIO_MODEL_CHOICE "Enter model number" "1"
    idx=$((RIO_MODEL_CHOICE - 1))
    if [[ $idx -ge 0 ]] && [[ $idx -lt ${#RIO_AVAILABLE_MODELS[@]} ]]; then
      RIO_SUGGESTED_HF_REPO="${RIO_AVAILABLE_HF_REPOS[$idx]}"
      RIO_SUGGESTED_FILENAME="${RIO_AVAILABLE_FILENAMES[$idx]}"
      RIO_SUGGESTED_MODEL_NAME="${RIO_AVAILABLE_MODELS[$idx]}"
      RIO_MODEL_ID="${RIO_SUGGESTED_FILENAME%.gguf}"
      log_info "Selected: $RIO_SUGGESTED_MODEL_NAME"
    else
      log_warning "Invalid choice, using recommended model"
    fi
  fi
fi

export RIO_MODEL_ID

# ─── Step 3: Install llama.cpp ───────────────────────────────────────
log_step "3/7 — Installing llama.cpp"

# Let user choose install method if not specified
if [[ -z "${RIO_METHOD_FORCED:-}" ]]; then
  if $RIO_SKIP_CONFIRM; then
    : # Use default
  elif [[ $RIO_METHOD == binary ]]; then
    echo "Install methods:"
    echo "  1. Pre-built binary (fast, Vulkan GPU support)"
    echo "  2. Build from source (optimized for your CPU, best performance)"
    echo "  3. Docker (isolated, cleanest)"
    echo ""
    if ! confirm "Use pre-built binary? [1]" "y"; then
      echo "  Choose install method:"
      echo "    1 = Binary (fast, default)"
      echo "    2 = Source (optimized)"
      echo "    3 = Docker (isolated)"
      prompt_value RIO_METHOD_CHOICE "Enter method number" "1"
      case "$RIO_METHOD_CHOICE" in
        2) RIO_METHOD="source" ;;
        3) RIO_METHOD="docker" ;;
        *) RIO_METHOD="binary" ;;
      esac
    fi
  fi
fi

source "$SCRIPT_DIR/scripts/install-llamacpp.sh"
install_llamacpp "$RIO_HOME/llama.cpp" "$RIO_METHOD"
log_success "llama.cpp installed"

# ─── Step 4: Download Model ──────────────────────────────────────────
if $RIO_DOWNLOAD_MODEL; then
  log_step "4/7 — Downloading Model ($RIO_SUGGESTED_MODEL_NAME)"

  RIO_MODELS_DIR="$RIO_HOME/models"
  source "$SCRIPT_DIR/scripts/download-model.sh"
  download_model "$RIO_SUGGESTED_HF_REPO" "$RIO_SUGGESTED_FILENAME" "$RIO_MODELS_DIR"
  log_success "Model downloaded"
else
  log_step "4/7 — Downloading Model"
  log_info "Skipped (--no-model flag)"
  RIO_MODEL_PATH=""
fi

# ─── Step 5: Install OpenCode ────────────────────────────────────────
log_step "5/7 — Installing OpenCode CLI"

source "$SCRIPT_DIR/scripts/install-opencode.sh"
install_opencode
log_success "OpenCode setup complete"

# ─── Step 6: Configuration & Launcher ─────────────────────────────────
log_step "6/7 — Configuration"

source "$SCRIPT_DIR/scripts/configure.sh"
configure
log_success "Configuration complete"

# ─── Step 7: Optional Open WebUI ─────────────────────────────────────
if ! $RIO_SKIP_WEBUI; then
  log_step "7/7 — Optional: Open WebUI Chat Interface"

  echo "Open WebUI is a feature-rich chat interface that runs in Docker."
  echo "It connects to your local llama-server for inference."
  echo ""

  if confirm "Would you like to set up Open WebUI?"; then
    log_info "Running Open WebUI setup..."
    bash "$SCRIPT_DIR/scripts/setup-webui.sh"
    log_success "Open WebUI setup complete"
  else
    log_info "Skipping Open WebUI. You can set it up later with:"
    log_info "  bash scripts/setup-webui.sh"
  fi
fi

# ─── Verify Setup ─────────────────────────────────────────────────────
log_step "Verification"

# Check for port conflicts and find a free port
RIO_PORT="${RIO_PORT:-8080}"
if port_in_use "$RIO_PORT"; then
  log_warning "Port $RIO_PORT is already in use"
  new_port=$(find_free_port "$RIO_PORT" 9000) || {
    log_error "No free port available"
    exit 1
  }
  log_info "Switching to port $new_port"
  RIO_PORT="$new_port"
  export RIO_PORT
  # Update config files with new port
  sed -i "s|RIO_PORT=.*|RIO_PORT=\"$RIO_PORT\"|" "$RIO_HOME/config/rio.env" 2>/dev/null || true
  sed -i "s|LOCAL_ENDPOINT=.*|LOCAL_ENDPOINT=\"http://127.0.0.1:$RIO_PORT/v1\"|" "$RIO_HOME/config/rio.env" 2>/dev/null || true
fi

if [[ -n "${RIO_MODEL_PATH:-}" ]] && [[ -f "$RIO_MODEL_PATH" ]]; then
  log_info "Starting llama-server to verify setup..."
  "$RIO_LLAMA_SERVER" --model "$RIO_MODEL_PATH" \
    --host 127.0.0.1 --port "$RIO_PORT" \
    --n-gpu-layers 999 \
    --ctx-size 2048 \
    --temp 0.6 \
    &>/dev/null &
  server_pid=$!

  sleep 2
  if curl -sf "http://127.0.0.1:$RIO_PORT/v1/models" > /dev/null 2>&1; then
    log_success "llama-server is running and responding on port $RIO_PORT!"

    if command -v opencode &>/dev/null; then
      log_info "Testing OpenCode connection..."
      if opencode --version &>/dev/null 2>&1; then
        log_success "OpenCode is ready!"
      fi
    fi
  else
    log_warning "llama-server started but didn't respond in time"
    log_info "Check the logs: $RIO_HOME/llama.cpp/build/bin/"
  fi

  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
else
  log_info "Skipping server verification (no model downloaded)"
fi

# ─── Success ──────────────────────────────────────────────────────────
echo ""
echo -e "${RIO_GREEN}${RIO_BOLD}╔════════════════════════════════════════════════════╗${RIO_RESET}"
echo -e "${RIO_GREEN}${RIO_BOLD}║        🎉  Rio Lab Installation Complete!  🎉       ║${RIO_RESET}"
echo -e "${RIO_GREEN}${RIO_BOLD}╚════════════════════════════════════════════════════╝${RIO_RESET}"
echo ""
echo -e "${RIO_BOLD}Your local AI lab is ready!${RIO_RESET}"
echo ""
echo "  📍  llama-server endpoint: http://127.0.0.1:8080/v1"
echo "  💬  Chat UI:               http://127.0.0.1:$RIO_PORT"
echo "  🤖  Model:                 $RIO_SUGGESTED_MODEL_NAME"
echo "  ⌨️   OpenCode:             $(opencode --version 2>/dev/null || echo 'installed')"
echo ""
echo -e "${RIO_BOLD}Quick start:${RIO_RESET}"
echo "  1. Start the server:"
echo "     bash $RIO_HOME/rio-launcher.sh &"
echo ""
echo "  2. Use OpenCode:"
echo "     opencode"
echo ""
echo "  3. Use the web UI:"
echo "     Open http://127.0.0.1:$RIO_PORT in your browser"
echo ""
if [[ -d "$RIO_HOME/webui" ]]; then
  echo "  4. Open WebUI:"
  echo "     Open http://localhost:3000 in your browser"
  echo ""
fi
echo -e "${RIO_BOLD}Model: $RIO_MODEL_PATH${RIO_RESET}"
echo ""
echo "  📖  Read the guides: $SCRIPT_DIR/guides/"
echo "  📝  Config:          $RIO_HOME/config/"
echo "  🗑️   Uninstall:      bash $SCRIPT_DIR/uninstall.sh"
echo ""
echo -e "${RIO_GREEN}Enjoy your local AI! 🤖${RIO_RESET}"
