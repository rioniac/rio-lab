# Model Recommendations

The installer automatically suggests a model based on your detected hardware. This guide explains the recommendations.

## How Recommendations Work

The installer detects:
1. **GPU vendor** — AMD, NVIDIA, Intel, Apple, or none
2. **VRAM** — Dedicated GPU memory (or unified memory for Apple/iGPUs)
3. **System RAM** — Fallback if no GPU detected

Then recommends a model size and quantization that fits comfortably in available memory.

## Recommendation Table

### Dedicated GPU (NVIDIA / AMD / Intel)

| VRAM | Recommended Model | Quant | Memory Used | Quality |
|---|---|---|---|---|
| < 4 GB | Qwen2.5-Coder-1.5B | Q4_K_M | ~1 GB | Basic coding |
| 4-6 GB | Qwen2.5-Coder-3B | Q4_K_M | ~2 GB | Good coding |
| 6-8 GB | Qwen2.5-Coder-7B | Q4_K_M | ~5 GB | Better coding |
| 8-12 GB | Qwen2.5-Coder-7B or CodeGemma-7B | Q4_K_M | ~5 GB | Great coding |
| 12-16 GB | DeepSeek-Coder-V2-Lite | Q4_K_M | ~8 GB | Expert coding |
| 16-24 GB | Qwen2.5-Coder-14B | Q4_K_M | ~9 GB | Excellent coding |
| 24+ GB | Qwen2.5-Coder-32B | Q4_K_M | ~18 GB | State-of-the-art |

### Integrated GPU / APU (shared memory)

| System RAM | Recommended Model | Quant | Memory Used |
|---|---|---|---|
| 8 GB | Qwen2.5-Coder-1.5B | Q4_K_M | ~1 GB |
| 16 GB | Qwen2.5-Coder-3B or Qwen2.5-Coder-7B | Q4_K_M | ~2-5 GB |
| 32+ GB | Qwen2.5-Coder-7B | Q4_K_M | ~5 GB |

### CPU-only (no GPU)

| System RAM | Recommended Model | Quant | Memory Used |
|---|---|---|---|
| 8 GB | Qwen2.5-Coder-1.5B | Q4_K_M | ~1 GB |
| 16 GB | Qwen2.5-Coder-3B | Q4_K_M | ~2 GB |
| 32 GB | Qwen2.5-Coder-7B | Q4_K_M | ~5 GB |
| 64 GB | DeepSeek-Coder-V2-Lite | Q4_K_M | ~8 GB |

### Apple Silicon (unified memory)

| Unified RAM | Recommended Model | Quant | Memory Used |
|---|---|---|---|
| 8 GB | Qwen2.5-Coder-3B | Q4_K_M | ~2 GB |
| 16 GB | Qwen2.5-Coder-7B | Q4_K_M | ~5 GB |
| 24 GB | Qwen2.5-Coder-14B | Q4_K_M | ~9 GB |
| 32+ GB | DeepSeek-Coder-V2-Lite | Q4_K_M | ~8 GB |

## Quantization Guide

| Quant | Size vs FP16 | Quality | Use Case |
|---|---|---|---|
| Q2_K | ~25% | Lowest | Very tight memory |
| Q3_K_M | ~33% | Low | Tight memory |
| Q4_K_M | ~45% | Good | **Recommended balance** |
| Q5_K_M | ~55% | Better | Have extra memory |
| Q6_K | ~65% | Great | Quality priority |
| Q8_0 | ~80% | Excellent | Lots of memory |
| F16 | 100% | Best | Research/benchmarking |

**Q4_K_M is the default recommendation** — it's the sweet spot for quality vs. memory.

## Hardware Limits

### Steam Deck (SteamOS)

- **GPU**: AMD Vanilla Gogh (RDNA 2, 8 CUs) or Sephiroth (RDNA 3, 12 CUs)
- **VRAM**: Shared with system — typically 12-14 GB available (out of 16 GB total)
- **Recommended**: Qwen2.5-Coder-7B Q4_K_M (~5 GB leaves 7+ GB for games/desktop)
- **Fallback**: Qwen2.5-Coder-3B Q4_K_M (~2 GB)

### Bazzite / CachyOS / Arch

- Same detection logic applies
- Ensure `vulkan-loader` and `vulkan-radeon` / `vulkan-intel` / `vulkan-nvidia` packages are installed

## Download Sources

All models are downloaded from HuggingFace:

| Model | HuggingFace Repo |
|---|---|
| Qwen2.5-Coder-1.5B | `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF` |
| Qwen2.5-Coder-3B | `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF` |
| Qwen2.5-Coder-7B | `Qwen/Qwen2.5-Coder-7B-Instruct-GGUF` |
| Qwen2.5-Coder-14B | `Qwen/Qwen2.5-Coder-14B-Instruct-GGUF` |
| Qwen2.5-Coder-32B | `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF` |
| DeepSeek-Coder-V2-Lite | `deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct-GGUF` |
| CodeGemma-7B | `google/codegemma-7b-it-GGUF` |

> **Note**: GGUF availability varies. Always verify the exact filename on HuggingFace before downloading. The installer queries the HuggingFace API to list available files.
