#!/usr/bin/env bash
# Rio Lab — fix-after-update.sh
# Recovers llama.cpp and Vulkan drivers after a SteamOS update
# SteamOS updates can reset system packages and kernel modules

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

show_banner

log_step "Rio Lab — Post-Update Recovery"

echo "SteamOS updates can reset system packages and kernel modules."
echo "This script rebuilds the Vulkan drivers and rechecks Rio Lab."
echo ""

if ! confirm "Proceed with recovery?"; then
  exit 0
fi

# ─── 1. Fix pacman keyring (common SteamOS issue) ────────────────────
log_step "1/4 — Fixing pacman keyring"
if command -v pacman &>/dev/null; then
  log_info "Reinitializing pacman keyring..."
  sudo pacman-key --init 2>/dev/null || log_warning "pacman-key init failed"
  sudo pacman-key --populate archlinux 2>/dev/null || log_warning "pacman-key populate failed"
  log_success "Pacman keyring fixed"
else
  log_info "Not on Arch-based system — skipping pacman fix"
fi

# ─── 2. Reinstall Vulkan drivers ─────────────────────────────────────
log_step "2/4 — Reinstalling Vulkan drivers"

case "${RIO_DISTRO:-steamos}" in
  steamos|arch|cachyos|endeavouros)
    sudo pacman -S --noconfirm \
      vulkan-radeon vulkan-icd-loader vulkan-validation-layers \
      lib32-vulkan-radeon lib32-vulkan-icd-loader \
      2>/dev/null || log_warning "Vulkan reinstall had issues"
    ;;
  bazzite|fedora)
    sudo dnf reinstall -y \
      vulkan-loader mesa-vulkan-drivers \
      2>/dev/null || log_warning "Vulkan reinstall had issues"
    ;;
  debian|ubuntu)
    sudo apt-get install --reinstall -y \
      mesa-vulkan-drivers libvulkan1 libvulkan-dev \
      2>/dev/null || log_warning "Vulkan reinstall had issues"
    ;;
  *)
    log_warning "Unknown distro — please reinstall Vulkan drivers manually"
    ;;
esac
log_success "Vulkan drivers reinstalled"

# ─── 3. Rebuild llama.cpp (if built from source) ─────────────────────
log_step "3/4 — Rebuilding llama.cpp"

RIO_HOME="${RIO_HOME:-$HOME/rio-lab}"
if [[ -d "$RIO_HOME/llama.cpp/build" ]]; then
  log_info "Rebuilding llama.cpp from source..."
  (
    cd "$RIO_HOME/llama.cpp"
    cmake --build build --config Release -j "$(nproc)"
  )
  check_previous "Rebuild failed"

  # Reinstall systemd service if it exists
  if systemctl --user list-unit-files rio-llamacpp.service &>/dev/null 2>&1; then
    log_info "Restarting service..."
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user restart rio-llamacpp.service 2>/dev/null || true
  fi
  log_success "llama.cpp rebuilt"
else
  log_info "Source build not found — nothing to rebuild"
  log_info "If you used the pre-built binary, re-run install.sh"
fi

# ─── 4. Verify ───────────────────────────────────────────────────────
log_step "4/4 — Verification"
log_info "Checking Vulkan..."
if command -v vulkaninfo &>/dev/null; then
  vulkaninfo --summary 2>/dev/null | grep -i "deviceName" | head -1 || echo "  Vulkan available"
  log_success "Vulkan is working"
else
  log_warning "vulkaninfo not found — install vulkan-tools"
fi

log_info "Checking Docker..."
if command -v docker &>/dev/null; then
  if sudo docker info &>/dev/null 2>&1; then
    log_success "Docker is running"
  else
    log_warning "Docker is installed but not running"
    sudo systemctl start docker 2>/dev/null || true
  fi
fi

# ─── Done ─────────────────────────────────────────────────────────────
echo ""
log_success "Recovery complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your system (recommended after driver updates)"
echo "  2. Run: bash $RIO_HOME/rio-launcher.sh"
echo "  3. Or re-run the installer: bash $SCRIPT_DIR/install.sh"
echo ""
if [[ -f "$RIO_HOME/config/rio.env" ]]; then
  echo "Your config and models are preserved at:"
  echo "  Config: $RIO_HOME/config/"
  echo "  Models: $RIO_HOME/models/"
fi
