#!/usr/bin/env bash
# Rio Lab — install-opencode.sh
# Installs OpenCode CLI
# Uses platform-appropriate method

set -euo pipefail

install_opencode() {
  log_step "Installing OpenCode CLI"

  # Check if already installed
  if command -v opencode &>/dev/null; then
    local current_version
    current_version=$(opencode --version 2>/dev/null || echo "unknown")
    log_info "OpenCode already installed: $current_version"
    if confirm "Would you like to update/reinstall?"; then
      do_install_opencode
    else
      log_info "Skipping OpenCode installation"
      return 0
    fi
  else
    do_install_opencode
  fi

  # Verify
  if command -v opencode &>/dev/null; then
    local version
    version=$(opencode --version 2>/dev/null || echo "unknown")
    log_success "OpenCode installed: $version"
  else
    log_warning "OpenCode binary not found in PATH. You may need to add it manually."
    log_info "Try: export PATH=\$HOME/.local/bin:\$PATH"
  fi
}

do_install_opencode() {
  case "${RIO_OS:-linux}" in
    linux|wsl)
      install_opencode_linux
      ;;
    macos)
      install_opencode_macos
      ;;
    windows)
      install_opencode_windows
      ;;
    *)
      log_warning "Unknown OS, trying Linux method..."
      install_opencode_linux
      ;;
  esac
}

install_opencode_linux() {
  # Use install script as primary method, package managers as fallback
  log_info "Installing OpenCode via official install script..."

  # First try package manager for cleaner install
  case "${RIO_PKG_MGR:-unknown}" in
    pacman)
      if confirm "Install opencode via pacman (stable)?"; then
        sudo pacman -S --noconfirm opencode 2>/dev/null && return 0
      fi
      if confirm "Install opencode-bin from AUR (latest)?"; then
        if command -v paru &>/dev/null; then
          paru -S --noconfirm opencode-bin 2>/dev/null && return 0
        elif command -v yay &>/dev/null; then
          yay -S --noconfirm opencode-bin 2>/dev/null && return 0
        fi
        log_warning "No AUR helper found. Installing via npm instead."
      fi
      ;;
    dnf)
      if command -v npm &>/dev/null; then
        sudo npm install -g opencode-ai && return 0
      fi
      ;;
  esac

  # Fallback: curl install script
  if command -v curl &>/dev/null; then
    log_info "Running: curl -fsSL https://opencode.ai/install | bash"
    # SECURITY NOTE: piping curl to bash executes the remote script directly.
    # This is the official OpenCode install method. Review the script first at:
    #   curl -fsSL https://opencode.ai/install
    curl -fsSL https://opencode.ai/install | bash
    check_previous "OpenCode install script failed" "no-exit"

    # Ensure ~/.local/bin is in PATH
    if [[ -f "$HOME/.local/bin/opencode" ]]; then
      export PATH="$HOME/.local/bin:$PATH"
      if ! grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        log_info "Added ~/.local/bin to PATH in ~/.bashrc"
      fi
    fi
  elif command -v npm &>/dev/null; then
    log_info "Installing via npm..."
    npm install -g opencode-ai
  else
    log_error "Need curl or npm to install OpenCode"
    log_info "Install curl: sudo apt install curl  (or your distro's equivalent)"
    return 1
  fi
}

install_opencode_macos() {
  if command -v brew &>/dev/null; then
    log_info "Installing via Homebrew..."
    brew install anomalyco/tap/opencode
  elif command -v curl &>/dev/null; then
    log_info "Installing via install script..."
    # SECURITY NOTE: piping curl to bash — see comment in install_opencode_linux
    curl -fsSL https://opencode.ai/install | bash
  else
    log_error "Need brew or curl to install OpenCode on macOS"
    return 1
  fi
}

install_opencode_windows() {
  log_info "Windows OpenCode installation..."

  if command -v scoop &>/dev/null; then
    scoop install opencode
    return 0
  elif command -v choco &>/dev/null; then
    choco install opencode
    return 0
  elif command -v npm &>/dev/null; then
    npm install -g opencode-ai
    return 0
  else
    log_warning "No package manager found for Windows OpenCode install"
    log_info "Recommended: install WSL2 and run this script inside it"
    log_info "Or install scoop from https://scoop.sh and re-run"
    return 1
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
  install_opencode
fi
