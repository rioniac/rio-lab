#!/usr/bin/env bash
# Rio Lab — common.sh
# Shared functions: logging, prompting, error handling, system helpers

set -euo pipefail

# ─── Colors ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RIO_RED='\033[0;31m'
  RIO_GREEN='\033[0;32m'
  RIO_YELLOW='\033[1;33m'
  RIO_BLUE='\033[0;34m'
  RIO_CYAN='\033[0;36m'
  RIO_MAGENTA='\033[0;35m'
  RIO_BOLD='\033[1m'
  RIO_RESET='\033[0m'
else
  RIO_RED= RIO_GREEN= RIO_YELLOW= RIO_BLUE=
  RIO_CYAN= RIO_MAGENTA= RIO_BOLD= RIO_RESET=
fi

# Export so sourced scripts can use them
export RIO_RED RIO_GREEN RIO_YELLOW RIO_BLUE
export RIO_CYAN RIO_MAGENTA RIO_BOLD RIO_RESET

# ─── Logging ────────────────────────────────────────────────────────────
log_info()    { echo -e "${RIO_BLUE}ℹ${RIO_RESET}  $*"; }
log_success() { echo -e "${RIO_GREEN}✔${RIO_RESET}  $*"; }
log_warning() { echo -e "${RIO_YELLOW}⚠${RIO_RESET}  $*"; }
log_error()   { echo -e "${RIO_RED}✘${RIO_RESET}  $*" >&2; }
log_step()    { echo -e "\n${RIO_BOLD}${RIO_MAGENTA}━━━ $* ━━━${RIO_RESET}"; }
log_debug()   { [[ -n "${RIO_DEBUG:-}" ]] && echo -e "${RIO_CYAN}🔍${RIO_RESET}  $*"; }

# ─── Error handling ────────────────────────────────────────────────────
check_previous() {
  local exit_code=$?
  local message="${1:-Previous command failed}"
  if [[ $exit_code -ne 0 ]]; then
    log_error "$message"
    exit "$exit_code"
  fi
}

trap_errors() {
  log_error "Script failed at line $1"
  exit 1
}
trap 'trap_errors $LINENO' ERR

# ─── Prerequisites ─────────────────────────────────────────────────────
check_command() {
  local cmd=$1
  local hint=${2:-"Install $cmd using your package manager"}
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Required command not found: ${RIO_BOLD}$cmd${RIO_RESET}"
    log_info "$hint"
    return 1
  fi
}

# ─── Platform helpers ──────────────────────────────────────────────────
is_root() { [[ $EUID -eq 0 ]]; }
is_linux() { [[ $(uname -s) == Linux ]]; }
is_macos() { [[ $(uname -s) == Darwin ]]; }
is_windows() { [[ $(uname -s) == MINGW* ]] || [[ $(uname -s) == MSYS* ]] || [[ -n "$WSLENV" ]]; }
is_wsl() { [[ -n "$WSLENV" ]] || [[ -n "$WSL_DISTRO_NAME" ]]; }

has_systemd() { command -v systemctl &>/dev/null; }

# ─── User prompts ──────────────────────────────────────────────────────
confirm() {
  local prompt="${1:-Continue?}"
  local default=${2:-y}
  local yn
  if [[ $default == y ]]; then
    prompt="$prompt [Y/n] "
  else
    prompt="$prompt [y/N] "
  fi
  read -r -p "$prompt" yn
  yn=${yn:-$default}
  [[ $yn == y ]] || [[ $yn == Y ]] || [[ $yn == yes ]] || [[ $yn == YES ]]
}

prompt_value() {
  local var_name=$1
  local prompt=$2
  local default=${3:-}
  local val
  if [[ -n $default ]]; then
    read -r -p "$prompt [$default]: " val
    val=${val:-$default}
  else
    read -r -p "$prompt: " val
  fi
  eval "$var_name=\$val"
}

# ─── System helpers ────────────────────────────────────────────────────
get_cpu_count() {
  if is_linux; then
    nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 4
  elif is_macos; then
    sysctl -n hw.ncpu 2>/dev/null || echo 4
  else
    echo 4
  fi
}

get_total_ram_mb() {
  if is_linux; then
    awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 4096
  elif is_macos; then
    sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1024/1024}' || echo 4096
  else
    echo 4096
  fi
}

get_arch() {
  uname -m
}

# ─── Download helpers ──────────────────────────────────────────────────
download_file() {
  local url=$1
  local dest=$2
  local description=${3:-file}
  log_info "Downloading $description..."
  if command -v curl &>/dev/null; then
    curl -#fSL "$url" -o "$dest"
  elif command -v wget &>/dev/null; then
    wget --show-progress -qO "$dest" "$url"
  else
    log_error "Neither curl nor wget found"
    return 1
  fi
  check_previous "Failed to download $description"
}

# ─── File helpers ──────────────────────────────────────────────────────
render_template() {
  local template=$1
  local output=$2
  shift 2
  local sed_expr=()
  while [[ $# -gt 0 ]]; do
    local key=$1
    local value=$2
    shift 2
    sed_expr+=(-e "s|{{${key}}}|${value}|g")
  done
  sed "${sed_expr[@]}" "$template" > "$output"
}

# ─── Header banner ────────────────────────────────────────────────────
show_banner() {
  echo -e "${RIO_MAGENTA}"
  echo '  ╔═══════════════════════════════════════════╗'
  echo '  ║          🤖  Rio Lab  🤖                  ║'
  echo '  ║   Local AI that never calls home.         ║'
  echo '  ╚═══════════════════════════════════════════╝'
  echo -e "${RIO_RESET}"
}

export -f log_info log_success log_warning log_error log_step log_debug
export -f check_previous check_command
export -f is_root is_linux is_macos is_windows is_wsl has_systemd
export -f confirm prompt_value
export -f get_cpu_count get_total_ram_mb get_arch
export -f download_file render_template
export -f show_banner
