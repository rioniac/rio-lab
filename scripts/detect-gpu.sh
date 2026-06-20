#!/usr/bin/env bash
# Rio Lab — detect-gpu.sh
# Detects GPU vendor, VRAM, and driver availability
# Usage: source scripts/detect-gpu.sh
# Sets: RIO_GPU_VENDOR, RIO_GPU_VRAM_MB, RIO_GPU_DRIVER, RIO_GPU_NAME, RIO_GPU_BACKEND

set -euo pipefail

detect_gpu() {
  RIO_GPU_VENDOR="unknown"
  RIO_GPU_VRAM_MB=0
  RIO_GPU_DRIVER="none"
  RIO_GPU_NAME="Unknown GPU"
  RIO_GPU_BACKEND="cpu"

  local os arch
  os=$(uname -s)
  arch=$(uname -m)

  # ─── NVIDIA Detection ──────────────────────────────────────────────
  if command -v nvidia-smi &>/dev/null; then
    RIO_GPU_VENDOR="nvidia"
    RIO_GPU_DRIVER="cuda"
    RIO_GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "NVIDIA GPU")
    RIO_GPU_VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo 0)
    RIO_GPU_VRAM_MB=${RIO_GPU_VRAM_MB%.*}
    RIO_GPU_BACKEND="vulkan"
    return 0
  fi

  # ─── AMD ROCm Detection ────────────────────────────────────────────
  if command -v rocm-smi &>/dev/null; then
    RIO_GPU_VENDOR="amd"
    RIO_GPU_DRIVER="rocm"
    RIO_GPU_NAME=$(rocm-smi --showproductname 2>/dev/null | grep "GPU" | head -1 | sed 's/.*://' | xargs || echo "AMD GPU")
    RIO_GPU_VRAM_MB=$(rocm-smi --showmeminfo vram 2>/dev/null | grep "VRAM" | head -1 | awk '{print $NF}' || echo 0)
    RIO_GPU_VRAM_MB=${RIO_GPU_VRAM_MB%.*}
    RIO_GPU_BACKEND="vulkan"
    return 0
  fi

  # ─── AMD GPU via sysfs (Linux, no ROCm) ────────────────────────────
  if [[ $os == Linux ]]; then
    for gpu in /sys/class/drm/card*/device; do
      if [[ -f "$gpu/vendor" ]]; then
        local vendor
        vendor=$(cat "$gpu/vendor" 2>/dev/null || true)
        if [[ $vendor == "0x1002" ]]; then
          RIO_GPU_VENDOR="amd"
          RIO_GPU_DRIVER="amdgpu"
          RIO_GPU_BACKEND="vulkan"
          if [[ -f "$gpu/vram_size" ]]; then
            RIO_GPU_VRAM_MB=$(cat "$gpu/vram_size" 2>/dev/null | awk '{printf "%d", $1/1024/1024}' || echo 0)
          fi
          if [[ -f "$gpu/gpu_name" ]]; then
            RIO_GPU_NAME=$(cat "$gpu/gpu_name" 2>/dev/null || echo "AMD GPU")
          fi
          break
        fi
      fi
    done
    if [[ $RIO_GPU_VENDOR == "amd" ]]; then
      return 0
    fi
  fi

  # ─── Intel GPU Detection ───────────────────────────────────────────
  if [[ $os == Linux ]]; then
    for gpu in /sys/class/drm/card*/device; do
      if [[ -f "$gpu/vendor" ]]; then
        local vendor
        vendor=$(cat "$gpu/vendor" 2>/dev/null || true)
        if [[ $vendor == "0x8086" ]]; then
          RIO_GPU_VENDOR="intel"
          RIO_GPU_DRIVER="i915"
          RIO_GPU_BACKEND="vulkan"
          if [[ -f "$gpu/vram_size" ]]; then
            RIO_GPU_VRAM_MB=$(cat "$gpu/vram_size" 2>/dev/null | awk '{printf "%d", $1/1024/1024}' || echo 0)
          fi
          if [[ -f "$gpu/gpu_name" ]]; then
            RIO_GPU_NAME=$(cat "$gpu/gpu_name" 2>/dev/null || echo "Intel GPU")
          fi
          break
        fi
      fi
    done
    if [[ $RIO_GPU_VENDOR == "intel" ]]; then
      return 0
    fi
  fi

  # ─── Apple Silicon ──────────────────────────────────────────────────
  if [[ $os == Darwin ]]; then
    local cpu_brand
    cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")
    if echo "$cpu_brand" | grep -qi "Apple"; then
      RIO_GPU_VENDOR="apple"
      RIO_GPU_DRIVER="metal"
      RIO_GPU_BACKEND="metal"
      RIO_GPU_NAME="Apple Silicon"
      RIO_GPU_VRAM_MB=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1024/1024}' || echo 0)
      return 0
    fi
    # Intel Mac
    RIO_GPU_VENDOR="intel"
    RIO_GPU_DRIVER="metal"
    RIO_GPU_BACKEND="metal"
    RIO_GPU_NAME="Intel Mac GPU"
    RIO_GPU_VRAM_MB=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1024/1024}' || echo 0)
    return 0
  fi

  # ─── Vulkan Detection (cross-platform capability check) ────────────
  if command -v vulkaninfo &>/dev/null; then
    local vulkan_gpus
    vulkan_gpus=$(vulkaninfo --summary 2>/dev/null | grep -i "deviceName" | head -1 | cut -d= -f2 | xargs || true)
    if [[ -n $vulkan_gpus ]]; then
      RIO_GPU_NAME="$vulkan_gpus"
      if command -v glxinfo &>/dev/null; then
        local renderer
        renderer=$(glxinfo -B 2>/dev/null | grep "OpenGL renderer" | head -1 | sed 's/.*: //' || true)
        if echo "$renderer" | grep -qi "amd"; then
          RIO_GPU_VENDOR="amd"
        elif echo "$renderer" | grep -qi "nvidia"; then
          RIO_GPU_VENDOR="nvidia"
        elif echo "$renderer" | grep -qi "intel"; then
          RIO_GPU_VENDOR="intel"
        fi
      fi
    fi
  fi

  # ─── Fallback: GPU memory estimation ────────────────────────────────
  if [[ $RIO_GPU_VRAM_MB -eq 0 ]]; then
    # For integrated GPUs, estimate shared memory as ~75% of total RAM
    local total_ram_mb
    if [[ $os == Linux ]]; then
      total_ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 4096)
    elif [[ $os == Darwin ]]; then
      total_ram_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1024/1024}' || echo 4096)
    else
      total_ram_mb=4096
    fi

    if { [[ $RIO_GPU_VENDOR == "amd" ]] || [[ $RIO_GPU_VENDOR == "intel" ]]; } && [[ $RIO_GPU_DRIVER != "none" ]]; then
      # Integrated GPU — use 75% of system RAM as usable
      RIO_GPU_VRAM_MB=$(( total_ram_mb * 75 / 100 ))
    else
      RIO_GPU_VRAM_MB=$total_ram_mb
    fi
  fi

  # ─── Vulkan driver check ────────────────────────────────────────────
  if command -v vulkaninfo &>/dev/null; then
    if [[ $RIO_GPU_DRIVER == "none" ]]; then
      RIO_GPU_DRIVER="vulkan"
      RIO_GPU_BACKEND="vulkan"
    fi
  fi

  export RIO_GPU_VENDOR RIO_GPU_VRAM_MB RIO_GPU_DRIVER RIO_GPU_NAME RIO_GPU_BACKEND
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  detect_gpu
  echo "GPU Vendor:  $RIO_GPU_VENDOR"
  echo "GPU Name:    $RIO_GPU_NAME"
  echo "VRAM (MB):   $RIO_GPU_VRAM_MB"
  echo "Driver:      $RIO_GPU_DRIVER"
  echo "Backend:     $RIO_GPU_BACKEND"
fi
