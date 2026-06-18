#!/usr/bin/env bash
# Rio Lab — download-model.sh
# Downloads a GGUF model from HuggingFace
# Supports: direct curl download, HuggingFace Hub API, or llama.cpp -hf flag

set -euo pipefail

download_model() {
  local hf_repo="${1:-${RIO_SUGGESTED_HF_REPO:-}}"
  local filename="${2:-${RIO_SUGGESTED_FILENAME:-}}"
  local dest_dir="${3:-${RIO_MODELS_DIR:-$HOME/rio-lab/models}}"

  if [[ -z $hf_repo ]] || [[ -z $filename ]]; then
    log_error "Missing required parameters: hf_repo and filename"
    log_info "Usage: download_model <hf_repo> <filename> [dest_dir]"
    return 1
  fi

  log_step "Downloading model"

  mkdir -p "$dest_dir"
  local dest_path="$dest_dir/$filename"

  # Check if already downloaded
  if [[ -f "$dest_path" ]]; then
    local size
    size=$(du -h "$dest_path" | cut -f1)
    log_info "Model already exists: $dest_path ($size)"
    if confirm "Redownload?" "n"; then
      rm -f "$dest_path"
    else
      RIO_MODEL_PATH="$dest_path"
      export RIO_MODEL_PATH
      return 0
    fi
  fi

  local url="https://huggingface.co/$hf_repo/resolve/main/$filename"

  log_info "Downloading $RIO_SUGGESTED_MODEL_NAME..."
  log_info "From: $url"
  log_info "To:   $dest_path"

  # Get file size for progress
  local total_size
  if command -v curl &>/dev/null; then
    total_size=$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r' || echo "")
    if [[ -n $total_size ]]; then
      local total_size_mb
      total_size_mb=$(awk "BEGIN { printf \"%.0f\", $total_size / 1024 / 1024 }")
      log_info "Size: ~${total_size_mb} MB"
    fi

    log_info "Downloading with progress..."
    if [[ -n ${total_size:-} ]]; then
      curl -#fL "$url" -o "$dest_path"
    else
      curl -#fL "$url" -o "$dest_path"
    fi
  elif command -v wget &>/dev/null; then
    wget --show-progress -qO "$dest_path" "$url"
  else
    log_error "Neither curl nor wget available for download"
    return 1
  fi

  # Verify
  if [[ -f "$dest_path" ]]; then
    local actual_size
    actual_size=$(du -h "$dest_path" | cut -f1)
    log_success "Model downloaded: $dest_path ($actual_size)"

    # Quick integrity check — first 4 bytes should be GGUF magic
    local magic
    magic=$(xxd -l 4 -p "$dest_path" 2>/dev/null || od -A n -t x1 -N 4 "$dest_path" 2>/dev/null | tr -d ' \n' || echo "skip")
    if [[ $magic != "67677566" ]] && [[ $magic != "skip" ]]; then
      log_warning "File doesn't start with GGUF magic (expected: 67677566, got: $magic)"
      log_warning "The download may be corrupted"
      if confirm "Delete and retry?"; then
        rm -f "$dest_path"
        return 1
      fi
    else
      log_success "GGUF header verified"
    fi
  else
    log_error "Download failed — file not found at destination"
    return 1
  fi

  RIO_MODEL_PATH="$dest_path"
  export RIO_MODEL_PATH
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dir=$(dirname "${BASH_SOURCE[0]}")
  source "$dir/common.sh"

  # Source detection if not loaded
  if [[ -z "${RIO_SUGGESTED_HF_REPO:-}" ]]; then
    source "$dir/detect-gpu.sh"
    source "$dir/suggest-model.sh"
    detect_gpu
    suggest_model
  fi

  download_model "$@"
  echo ""
  echo "Model path: $RIO_MODEL_PATH"
fi
