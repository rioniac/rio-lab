#!/usr/bin/env bash
# Rio Lab — detect-platform.sh
# Detects OS, distribution, architecture, and package manager
# Usage: source scripts/detect-platform.sh
# Sets: RIO_OS, RIO_DISTRO, RIO_DISTRO_FAMILY, RIO_ARCH, RIO_PKG_MGR, RIO_INIT_SYSTEM

set -euo pipefail

detect_platform() {
  # ─── OS Detection ────────────────────────────────────────────────────
  local os
  os=$(uname -s)

  case "$os" in
    Linux)
      RIO_OS="linux"
      ;;
    Darwin)
      RIO_OS="macos"
      ;;
    MINGW*|MSYS*)
      RIO_OS="windows"
      ;;
    *)
      RIO_OS="unknown"
      ;;
  esac

  # WSL detection
  if [[ -n "${WSLENV:-}" ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    RIO_OS="wsl"
  fi

  # ─── Architecture ────────────────────────────────────────────────────
  RIO_ARCH=$(uname -m)

  # ─── Linux Distro Detection ───────────────────────────────────────────
  RIO_DISTRO="unknown"
  RIO_DISTRO_FAMILY="unknown"

  if [[ $RIO_OS == linux ]] || [[ $RIO_OS == wsl ]]; then
    if command -v lsb_release &>/dev/null; then
      RIO_DISTRO=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
    fi

    if [[ -f /etc/os-release ]]; then
      local id id_like
      id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
      id_like=$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"')
      [[ -z $RIO_DISTRO ]] && RIO_DISTRO=$id
      RIO_DISTRO_FAMILY=$id_like
    elif [[ -f /etc/arch-release ]]; then
      RIO_DISTRO="arch"
      RIO_DISTRO_FAMILY="arch"
    elif [[ -f /etc/debian_version ]]; then
      RIO_DISTRO="debian"
      RIO_DISTRO_FAMILY="debian"
    elif [[ -f /etc/fedora-release ]]; then
      RIO_DISTRO="fedora"
      RIO_DISTRO_FAMILY="fedora"
    elif [[ -f /etc/redhat-release ]]; then
      RIO_DISTRO="rhel"
      RIO_DISTRO_FAMILY="rhel"
    elif [[ -f /etc/SuSE-release ]]; then
      RIO_DISTRO="suse"
      RIO_DISTRO_FAMILY="suse"
    fi

    # Normalize distro name
    RIO_DISTRO=$(echo "$RIO_DISTRO" | tr '[:upper:]' '[:lower:]')
    RIO_DISTRO_FAMILY=$(echo "$RIO_DISTRO_FAMILY" | tr '[:upper:]' '[:lower:]')

    # Detect SteamOS specifically
    if grep -q "SteamOS" /etc/os-release 2>/dev/null; then
      RIO_DISTRO="steamos"
    fi

    # Detect Bazzite
    if grep -q "bazzite" /etc/os-release 2>/dev/null; then
      RIO_DISTRO="bazzite"
    fi

    # Detect CachyOS
    if grep -q "CachyOS" /etc/os-release 2>/dev/null; then
      RIO_DISTRO="cachyos"
    fi
  fi

  if [[ $RIO_OS == macos ]]; then
    RIO_DISTRO="macos"
    RIO_DISTRO_FAMILY="macos"
  fi

  if [[ $RIO_OS == windows ]]; then
    RIO_DISTRO="windows"
    RIO_DISTRO_FAMILY="windows"
  fi

  # ─── Package Manager Detection ─────────────────────────────────────
  RIO_PKG_MGR="unknown"

  if [[ $RIO_OS == linux ]] || [[ $RIO_OS == wsl ]]; then
    if command -v pacman &>/dev/null; then
      RIO_PKG_MGR="pacman"
    elif command -v apt &>/dev/null; then
      RIO_PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then
      RIO_PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then
      RIO_PKG_MGR="yum"
    elif command -v zypper &>/dev/null; then
      RIO_PKG_MGR="zypper"
    fi
  fi

  if [[ $RIO_OS == macos ]]; then
    if command -v brew &>/dev/null; then
      RIO_PKG_MGR="brew"
    elif command -v port &>/dev/null; then
      RIO_PKG_MGR="macports"
    fi
  fi

  if [[ $RIO_OS == windows ]]; then
    if command -v scoop &>/dev/null; then
      RIO_PKG_MGR="scoop"
    elif command -v choco &>/dev/null; then
      RIO_PKG_MGR="choco"
    elif command -v winget &>/dev/null; then
      RIO_PKG_MGR="winget"
    fi
  fi

  # ─── Init System Detection ─────────────────────────────────────────
  RIO_INIT_SYSTEM="unknown"
  if [[ $RIO_OS == linux ]] || [[ $RIO_OS == wsl ]]; then
    if command -v systemctl &>/dev/null && systemctl --version &>/dev/null 2>&1; then
      RIO_INIT_SYSTEM="systemd"
    elif command -v rc-status &>/dev/null; then
      RIO_INIT_SYSTEM="openrc"
    elif [[ -f /sbin/openrc-init ]] || [[ -f /usr/sbin/openrc-init ]]; then
      RIO_INIT_SYSTEM="openrc"
    fi
  fi

  # ─── Desktop Environment ──────────────────────────────────────────
  RIO_DE="unknown"
  if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    RIO_DE="$XDG_CURRENT_DESKTOP"
  elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
    RIO_DE="$DESKTOP_SESSION"
  elif [[ -n "${GNOME_DESKTOP_SESSION_ID:-}" ]]; then
    RIO_DE="gnome"
  elif [[ -n "${KDE_FULL_SESSION:-}" ]]; then
    RIO_DE="kde"
  fi

  # ─── Steam Deck Detection ──────────────────────────────────────────
  RIO_IS_STEAM_DECK=false
  if [[ $RIO_DISTRO == steamos ]]; then
    RIO_IS_STEAM_DECK=true
  fi

  export RIO_OS RIO_DISTRO RIO_DISTRO_FAMILY RIO_ARCH
  export RIO_PKG_MGR RIO_INIT_SYSTEM RIO_DE RIO_IS_STEAM_DECK
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  detect_platform
  echo "OS:           $RIO_OS"
  echo "Distro:       $RIO_DISTRO"
  echo "Family:       $RIO_DISTRO_FAMILY"
  echo "Arch:         $RIO_ARCH"
  echo "Package Mgr:  $RIO_PKG_MGR"
  echo "Init System:  $RIO_INIT_SYSTEM"
  echo "Desktop Env:  $RIO_DE"
  echo "Steam Deck:   $RIO_IS_STEAM_DECK"
fi
