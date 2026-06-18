#!/usr/bin/env bash
# Rio Lab — install-llamacpp.sh
# Installs llama.cpp with Vulkan GPU support
# Supports: pre-built binary (fast), source build (optimized), Docker (isolated)

set -euo pipefail

install_llamacpp() {
  local install_dir="${1:-$HOME/rio-lab/llama.cpp}"
  local method="${2:-binary}"  # binary | source | docker
  local backend="${RIO_GPU_BACKEND:-cpu}"

  log_step "Installing llama.cpp"

  mkdir -p "$install_dir"

  case "$method" in
    binary)
      install_llamacpp_binary "$install_dir"
      ;;
    source)
      install_llamacpp_source "$install_dir"
      ;;
    docker)
      install_llamacpp_docker "$install_dir"
      ;;
    *)
      log_error "Unknown install method: $method"
      log_info "Valid options: binary, source, docker"
      return 1
      ;;
  esac

  # Verify installation
  if [[ -f "$install_dir/llama-server" ]]; then
    RIO_LLAMA_SERVER="$install_dir/llama-server"
  elif [[ -f "$install_dir/build/bin/llama-server" ]]; then
    RIO_LLAMA_SERVER="$install_dir/build/bin/llama-server"
  elif command -v llama-server &>/dev/null; then
    RIO_LLAMA_SERVER="llama-server"
  else
    log_error "llama-server not found after installation"
    return 1
  fi

  log_success "llama.cpp installed: $RIO_LLAMA_SERVER"
  export RIO_LLAMA_SERVER
}

# ─── Pre-built Binary (Vulkan-enabled) ──────────────────────────────────
install_llamacpp_binary() {
  local install_dir=$1
  local repo="ggml-org/llama.cpp"
  local arch
  arch=$(uname -m)

  log_info "Downloading pre-built llama.cpp binary (Vulkan-enabled)..."

  # Map arch to GitHub release asset suffix
  local asset_suffix=""
  case "$arch" in
    x86_64)  asset_suffix="linux-x64" ;;
    aarch64) asset_suffix="linux-aarch64" ;;
    arm64)   asset_suffix="macos-arm64" ;;
    *)       log_warning "No pre-built binary for $arch, falling back to source build"
             install_llamacpp_source "$install_dir"
             return
             ;;
  esac

  # Get latest release tag
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | cut -d'"' -f4 || echo "master")
  log_debug "Latest release: $tag"

  local filename
  filename="llama.cpp-${tag}-${asset_suffix}-vulkan.tar.xz"
  local url="https://github.com/$repo/releases/download/$tag/$filename"

  # Fallback to different naming conventions
  local tmpdir
  tmpdir=$(mktemp -d)
  if ! download_file "$url" "$tmpdir/llama.tar.xz" "llama.cpp binary" 2>/dev/null; then
    # Try alternate filename pattern
    filename="llama-${tag}-${asset_suffix}-vulkan.tar.xz"
    url="https://github.com/$repo/releases/download/$tag/$filename"
    if ! download_file "$url" "$tmpdir/llama.tar.xz" "llama.cpp binary" 2>/dev/null; then
      log_warning "Binary download failed, falling back to source build"
      rm -rf "$tmpdir"
      install_llamacpp_source "$install_dir"
      return
    fi
  fi

  tar -xJf "$tmpdir/llama.tar.xz" -C "$tmpdir"
  cp "$tmpdir"/llama-server "$install_dir/" 2>/dev/null || true
  cp "$tmpdir"/llama-cli "$install_dir/" 2>/dev/null || true
  chmod +x "$install_dir"/llama-* 2>/dev/null || true
  rm -rf "$tmpdir"

  if [[ ! -f "$install_dir/llama-server" ]]; then
    log_warning "Binary extraction incomplete, falling back to source build"
    install_llamacpp_source "$install_dir"
    return
  fi
}

# ─── Build from Source ──────────────────────────────────────────────────
install_llamacpp_source() {
  local install_dir=$1
  local build_dir="$install_dir/build"
  local repo_url="https://github.com/ggml-org/llama.cpp.git"

  log_info "Building llama.cpp from source..."
  log_info "Backend: $backend, Cores: $(get_cpu_count)"

  # Install build dependencies
  install_build_deps

  # Clone or update
  if [[ -d "$install_dir/.git" ]]; then
    log_info "Updating existing clone..."
    git -C "$install_dir" pull --ff-only 2>/dev/null || true
  else
    log_info "Cloning llama.cpp..."
    git clone --depth 1 "$repo_url" "$install_dir"
    check_previous "Failed to clone llama.cpp"
  fi

  # Configure with CMake
  mkdir -p "$build_dir"
  log_info "Configuring CMake..."

  local cmake_opts=(
    -DCMAKE_BUILD_TYPE=Release
    -DLLAMA_CURL=ON
  )

  # Add GPU backend flags
  case "$backend" in
    vulkan)
      cmake_opts+=(-DGGML_VULKAN=ON)
      log_info "GPU backend: Vulkan (universal)"
      ;;
    cuda)
      cmake_opts+=(-DGGML_CUDA=ON)
      log_info "GPU backend: CUDA (NVIDIA)"
      ;;
    rocm)
      cmake_opts+=(-DGGML_HIP=ON)
      log_info "GPU backend: ROCm (AMD)"
      ;;
    metal)
      cmake_opts+=(-DGGML_METAL=ON)
      log_info "GPU backend: Metal (Apple)"
      ;;
    sycl)
      cmake_opts+=(-DGGML_SYCL=ON)
      log_info "GPU backend: SYCL (Intel)"
      ;;
    *)
      log_info "GPU backend: CPU only"
      ;;
  esac

  cmake -S "$install_dir" -B "$build_dir" "${cmake_opts[@]}"
  check_previous "CMake configuration failed"

  # Build
  local cpus
  cpus=$(get_cpu_count)
  log_info "Building with $cpus threads (this may take a while)..."
  cmake --build "$build_dir" --config Release -j "$cpus"
  check_previous "Build failed"
}

# ─── Build Dependencies ─────────────────────────────────────────────────
install_build_deps() {
  log_info "Checking build dependencies..."

  case "${RIO_PKG_MGR:-unknown}" in
    apt)
      sudo apt-get update -qq
      sudo apt-get install -y -qq \
        build-essential cmake git curl \
        libvulkan-dev vulkan-validationlayers \
        2>/dev/null || true
      ;;
    dnf)
      sudo dnf install -y \
        gcc-c++ cmake git curl \
        vulkan-loader-devel vulkan-headers \
        2>/dev/null || true
      ;;
    pacman)
      sudo pacman -S --noconfirm \
        base-devel cmake git curl \
        vulkan-devel \
        2>/dev/null || true
      ;;
    brew)
      brew install cmake git curl vulkan-headers 2>/dev/null || true
      ;;
    *)
      log_warning "Unknown package manager — please install build deps manually"
      log_info "Required: cmake, git, curl, vulkan headers"
      ;;
  esac
}

# ─── Docker Installation ────────────────────────────────────────────────
install_llamacpp_docker() {
  local install_dir=$1

  log_info "Setting up llama.cpp via Docker..."

  if ! command -v docker &>/dev/null; then
    log_warning "Docker not found"
    log_info "Installing Docker..."

    case "${RIO_PKG_MGR:-unknown}" in
      apt)
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker.io docker-compose-v2
        ;;
      dnf)
        sudo dnf install -y docker docker-compose
        ;;
      pacman)
        sudo pacman -S --noconfirm docker docker-compose
        ;;
      brew)
        brew install --cask docker
        ;;
    esac

    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    log_warning "You may need to log out and back in for Docker group changes"
  fi

  # Create docker-compose file
  cat > "$install_dir/docker-compose.yml" << 'COMPOSE'
services:
  llamacpp:
    image: ghcr.io/ggml-org/llama.cpp:full
    command: >
      --model /models/${RIO_MODEL_FILENAME:-model.gguf}
      --host 0.0.0.0 --port 8080
      --n-gpu-layers 999
      --ctx-size 8192
      --temp 0.6 --top-p 0.95 --top-k 40
    ports:
      - "8080:8080"
    volumes:
      - ./models:/models
      - /dev/dri:/dev/dri:ro
    devices:
      - /dev/kfd:/dev/kfd
    group_add:
      - video
      - render
    deploy:
      resources:
        reservations:
          devices:
            - driver: vulkan
              count: all
              capabilities: [gpu]
COMPOSE

  RIO_LLAMA_SERVER="docker"
  cat > "$install_dir/llama-server" << 'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")"
docker compose up --build -d
SCRIPT
  chmod +x "$install_dir/llama-server"

  log_success "Docker compose file created at $install_dir/docker-compose.yml"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dir=$(dirname "${BASH_SOURCE[0]}")
  source "$dir/common.sh"

  install_dir="${1:-$HOME/rio-lab/llama.cpp}"
  method="${2:-binary}"

  # Source detection if not already loaded
  if [[ -z "${RIO_GPU_BACKEND:-}" ]]; then
    source "$dir/detect-platform.sh"
    source "$dir/detect-gpu.sh"
    detect_platform
    detect_gpu
  fi

  install_llamacpp "$install_dir" "$method"
fi
