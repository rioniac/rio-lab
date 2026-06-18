#!/usr/bin/env bash
# Rio Lab — create-steam-launcher.sh
# Creates a Steam Gaming Mode launcher for Steam Deck / SteamOS

set -euo pipefail

create_steam_launcher() {
  local rio_home="${RIO_HOME:-$HOME/rio-lab}"
  local launcher="$rio_home/rio-launcher.sh"

  log_step "Creating Steam Gaming Mode Launcher"

  # Check if running on SteamOS
  if ! grep -q "SteamOS" /etc/os-release 2>/dev/null; then
    log_warning "Not running on SteamOS — Steam launcher may not work as expected"
    if ! confirm "Continue anyway?"; then
      return 1
    fi
  fi

  if [[ ! -f "$launcher" ]]; then
    log_warning "Launcher script not found at $launcher"
    log_info "Run the main installer first, or configure manually"
    return 1
  fi

  local steam_launcher="$rio_home/rio-steam.sh"

  cat > "$steam_launcher" << 'STEAM'
#!/usr/bin/env bash
# Rio Lab — Steam Gaming Mode Launcher
# Launch from Steam as a Non-Steam game

# Source config
RIO_HOME="{{RIO_HOME}}"
source "$RIO_HOME/config/rio.env" 2>/dev/null || true

# Set up terminal environment for Steam Deck
export DISPLAY=:0
export TERM=xterm-256color

# Steam Gaming Mode: ensure we stay in Gaming Mode
if pgrep -x gamescope > /dev/null 2>&1; then
  echo "Steam Gaming Mode detected"
fi

# Start the server
echo "Starting Rio Lab..."
bash "$RIO_HOME/rio-launcher.sh"

# Auto-shutdown when launcher exits
echo ""
echo "Rio Lab has stopped. You can close this window."
read -r -p "Press Enter to exit..."
STEAM

  # Replace placeholder
  sed -i "s|{{RIO_HOME}}|$rio_home|g" "$steam_launcher"
  chmod +x "$steam_launcher"

  log_success "Steam launcher created: $steam_launcher"
  echo ""
  echo -e "${RIO_BOLD}To add to Steam:${RIO_RESET}"
  echo "  1. Open Steam in Desktop Mode"
  echo "  2. Go to Games > Add a Non-Steam Game to My Library..."
  echo "  3. Click Browse and select: $steam_launcher"
  echo "  4. Find 'rio-steam.sh' in your library and add it"
  echo ""
  echo -e "${RIO_BOLD}Launcher properties:${RIO_RESET}"
  echo "  Target:        /usr/bin/konsole"
  echo "  Launch Options: --hold -e bash $steam_launcher"
  echo "  Proton:         OFF (not needed)"
  echo ""
  echo -e "${RIO_YELLOW}Tip:${RIO_RESET} Rename the shortcut to 'Rio Lab' in Steam"

  if confirm "Open Steam in Desktop Mode to add it now?"; then
    if command -v steam &>/dev/null; then
      steam &
      log_info "Steam opened. Follow the steps above to add the launcher."
    else
      log_warning "Steam command not found"
    fi
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dir=$(dirname "${BASH_SOURCE[0]}")
  source "$dir/common.sh"
  create_steam_launcher "$@"
fi
