#!/usr/bin/env bash
# Rio Lab — uninstall.sh
# Clean removal of all Rio Lab components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

show_banner

log_step "Rio Lab — Uninstall"

RIO_HOME="${RIO_HOME:-$HOME/rio-lab}"

log_warning "This will remove all Rio Lab components:"
echo "  • llama.cpp installation ($RIO_HOME/llama.cpp)"
echo "  • Downloaded models ($RIO_HOME/models)"
echo "  • Configuration files ($RIO_HOME/config)"
echo "  • Launcher scripts ($RIO_HOME/)"
echo "  • Open WebUI data ($RIO_HOME/webui)"
echo "  • systemd services"
echo ""

if ! confirm "Are you sure you want to uninstall?" "n"; then
  log_info "Uninstall cancelled."
  exit 0
fi

# ─── Stop services ──────────────────────────────────────────────────
log_step "Stopping services"

# Stop systemd service
if systemctl --user list-unit-files rio-llamacpp.service &>/dev/null 2>&1; then
  log_info "Stopping Rio Lab service..."
  systemctl --user stop rio-llamacpp.service 2>/dev/null || true
  systemctl --user disable rio-llamacpp.service 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/rio-llamacpp.service"
  systemctl --user daemon-reload 2>/dev/null || true
fi

# Stop Open WebUI
if [[ -f "$RIO_HOME/webui/docker-compose.yml" ]]; then
  log_info "Stopping Open WebUI..."
  docker compose -f "$RIO_HOME/webui/docker-compose.yml" down 2>/dev/null || true
fi

# Stop any running llama-server
pkill -f "llama-server" 2>/dev/null || true

# ─── Remove Rio Lab directory ────────────────────────────────────────
log_step "Removing Rio Lab files"

if [[ -d "$RIO_HOME" ]]; then
  # Confirm model deletion separately (they're large downloads)
  if [[ -d "$RIO_HOME/models" ]] && [[ -n "$(ls -A "$RIO_HOME/models" 2>/dev/null)" ]]; then
    log_warning "Model files found in $RIO_HOME/models (may be several GB)"
    if confirm "Remove downloaded models?" "n"; then
      rm -rf "$RIO_HOME/models"
      log_info "Models removed"
    else
      log_info "Models preserved at $RIO_HOME/models"
    fi
  fi

  if confirm "Remove remaining Rio Lab files ($RIO_HOME)?"; then
    rm -rf "$RIO_HOME"
    log_info "Rio Lab directory removed"
  else
    log_info "Rio Lab files preserved at $RIO_HOME"
  fi
fi

# ─── Remove shell integration ────────────────────────────────────────
log_step "Cleaning shell configuration"

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [[ -f "$rc" ]]; then
    # Remove Rio Lab env sourcing
    sed -i '/# Rio Lab/d' "$rc" 2>/dev/null || true
    sed -i '/rio.env/d' "$rc" 2>/dev/null || true
    sed -i '/LOCAL_ENDPOINT/d' "$rc" 2>/dev/null || true
  fi
done

# Remove opencode config
for cfg in "$HOME/.config/opencode/opencode.json" "$HOME/.opencode.json"; do
  if [[ -f "$cfg" ]] && grep -q "rio-lab\|localhost:8080" "$cfg" 2>/dev/null; then
    if confirm "Remove OpenCode config ($cfg)?"; then
      rm -f "$cfg"
    fi
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────
echo ""
log_success "Rio Lab uninstalled!"
echo ""
echo "What was removed:"
echo "  ✅ Rio Lab files:      $RIO_HOME"
echo "  ✅ systemd service:    rio-llamacpp.service"
echo "  ✅ Shell integration:  deleted from bashrc/zshrc"
echo ""
echo "What's still installed (not removed):"
echo "  • OpenCode CLI — remove with: npm uninstall -g opencode-ai"
echo "  • Docker — remove with: sudo apt remove docker"
echo "  • llama.cpp system packages (vulkan, cmake, etc.)"
echo ""
echo "Thanks for trying Rio Lab! 🤖"
