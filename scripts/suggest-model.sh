#!/usr/bin/env bash
# Rio Lab — suggest-model.sh
# Recommends a model based on detected hardware
# Usage: source scripts/suggest-model.sh
# Requires: RIO_GPU_VRAM_MB, RIO_GPU_VENDOR from detect-gpu.sh
# Sets: RIO_SUGGESTED_MODEL, RIO_SUGGESTED_MODEL_NAME, RIO_SUGGESTED_QUANT
#       RIO_AVAILABLE_MODELS (array of choices)

set -euo pipefail

suggest_model() {
  local vram_mb=${RIO_GPU_VRAM_MB:-4096}
  local vendor=${RIO_GPU_VENDOR:-unknown}
  local vram_gb
  vram_gb=$(awk "BEGIN { printf \"%.1f\", $vram_mb / 1024 }")

  # Default to CPU mode if no GPU detected with meaningful memory
  local mode="cpu"
  if [[ $vendor != "unknown" ]] && [[ $vram_mb -ge 2048 ]]; then
    mode="gpu"
  fi

  # ─── Model definitions ──────────────────────────────────────────────
  # Each model: "hf_repo:filename:display_name:min_vram_mb:tools_support"
  # Tools support: models known to work well with function calling / tool use

  RIO_MODEL_DB=(
    "Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:qwen2.5-coder-1.5b-instruct-q4_k_m.gguf:Qwen2.5-Coder-1.5B (Q4_K_M):2048:yes"
    "Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:qwen2.5-coder-3b-instruct-q4_k_m.gguf:Qwen2.5-Coder-3B (Q4_K_M):4096:yes"
    "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF:qwen2.5-coder-7b-instruct-q4_k_m.gguf:Qwen2.5-Coder-7B (Q4_K_M):6144:yes"
    "Qwen/Qwen2.5-Coder-14B-Instruct-GGUF:qwen2.5-coder-14b-instruct-q4_k_m.gguf:Qwen2.5-Coder-14B (Q4_K_M):12288:yes"
    "Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:qwen2.5-coder-32b-instruct-q4_k_m.gguf:Qwen2.5-Coder-32B (Q4_K_M):24576:yes"
    "deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct-GGUF:deepseek-coder-v2-lite-instruct-q4_k_m.gguf:DeepSeek-Coder-V2-Lite (Q4_K_M):8192:yes"
    "google/codegemma-7b-it-GGUF:codegemma-7b-it-q4_k_m.gguf:CodeGemma-7B (Q4_K_M):6144:yes"
  )

  # ─── Pick best model ──────────────────────────────────────────────
  local best_model=""
  local best_model_name=""
  local best_quant="Q4_K_M"
  local best_hf_repo=""
  local best_filename=""

  for entry in "${RIO_MODEL_DB[@]}"; do
    local hf_repo filename display_name min_vram tools
    IFS=':' read -r hf_repo filename display_name min_vram tools <<< "$entry"

    if [[ $vram_mb -ge $min_vram ]]; then
      best_model="$display_name"
      best_hf_repo="$hf_repo"
      best_filename="$filename"
      best_model_name="$display_name"
    fi
  done

  # Fallback if no model fits
  if [[ -z $best_hf_repo ]]; then
    best_hf_repo="Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF"
    best_filename="qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
    best_model_name="Qwen2.5-Coder-1.5B (Q4_K_M)"
    best_model="Qwen2.5-Coder-1.5B (Q4_K_M)"
  fi

  # ─── Export results ───────────────────────────────────────────────
  RIO_SUGGESTED_HF_REPO="$best_hf_repo"
  RIO_SUGGESTED_FILENAME="$best_filename"
  RIO_SUGGESTED_MODEL_NAME="$best_model_name"
  RIO_SUGGESTED_MODEL="$best_model"
  RIO_SUGGESTED_MODEL_ID="${best_filename%.gguf}"

  # For OpenCode config
  RIO_MODEL_ID="$RIO_SUGGESTED_MODEL_ID"

  # Build available models list (all that fit)
  RIO_AVAILABLE_MODELS=()
  RIO_AVAILABLE_HF_REPOS=()
  RIO_AVAILABLE_FILENAMES=()
  for entry in "${RIO_MODEL_DB[@]}"; do
    local hf_repo2 filename2 display_name2 min_vram2 tools2
    IFS=':' read -r hf_repo2 filename2 display_name2 min_vram2 tools2 <<< "$entry"
    if [[ $vram_mb -ge $min_vram2 ]]; then
      RIO_AVAILABLE_MODELS+=("$display_name2")
      RIO_AVAILABLE_HF_REPOS+=("$hf_repo2")
      RIO_AVAILABLE_FILENAMES+=("$filename2")
    fi
  done

  export RIO_SUGGESTED_HF_REPO RIO_SUGGESTED_FILENAME RIO_SUGGESTED_MODEL_NAME
  export RIO_SUGGESTED_MODEL RIO_SUGGESTED_MODEL_ID RIO_MODEL_ID
  export RIO_AVAILABLE_MODELS RIO_AVAILABLE_HF_REPOS RIO_AVAILABLE_FILENAMES
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Source prerequisites if running standalone
  if [[ -z "${RIO_GPU_VRAM_MB:-}" ]]; then
    dir=$(dirname "${BASH_SOURCE[0]}")
    source "$dir/detect-gpu.sh"
    detect_gpu
  fi
  suggest_model
  echo "Suggested Model:  $RIO_SUGGESTED_MODEL_NAME"
  echo "HF Repo:          $RIO_SUGGESTED_HF_REPO"
  echo "Filename:         $RIO_SUGGESTED_FILENAME"
  echo "Model ID:         $RIO_MODEL_ID"
  echo ""
  echo "Available models that fit your hardware:"
  for i in "${!RIO_AVAILABLE_MODELS[@]}"; do
    echo "  $((i+1)). ${RIO_AVAILABLE_MODELS[$i]}"
  done
fi
