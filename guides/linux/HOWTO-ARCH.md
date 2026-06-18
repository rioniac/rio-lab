# Rio Lab — Arch Linux / SteamOS / CachyOS Guide

*Also applies to: EndeavourOS, Manjaro, Garuda, and any Arch-based distribution.*

## Prerequisites

- Arch Linux (or derivative) installed and updated
- Internet connection (for downloads)
- At least 8 GB of free disk space
- Patience — model downloads are large

## Quick Install (One Command)

```bash
# Clone the repo
git clone https://github.com/riolab/rio-lab.git
cd rio-lab

# Run the installer
bash install.sh
```

The installer will handle everything automatically. If you prefer doing things step by step, read below.

## Step-by-Step Manual Install

### 1. Install Dependencies

```bash
sudo pacman -Syu
sudo pacman -S --noconfirm \
  cmake curl git \
  vulkan-radeon vulkan-icd-loader vulkan-tools \
  base-devel
```

**If you have an NVIDIA GPU:**
```bash
sudo pacman -S --noconfirm nvidia-dkms cuda vulkan-nvidia
```

**If you have an Intel GPU:**
```bash
sudo pacman -S --noconfirm vulkan-intel
```

### 2. Install llama.cpp

```bash
# Option A: Pre-built binary (fast)
mkdir -p ~/rio-lab/llama.cpp
cd ~/rio-lab/llama.cpp
curl -fsSL "https://github.com/ggml-org/llama.cpp/releases/latest/download/llama.cpp-$(curl -fsSL https://api.github.com/repos/ggml-org/llama.cpp/releases/latest | grep tag_name | cut -d'"' -f4)-linux-x64-vulkan.tar.xz" | tar -xJ

# Option B: Build from source (optimized)
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git ~/rio-lab/llama.cpp
cd ~/rio-lab/llama.cpp
cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)
```

### 3. Download a Model

```bash
mkdir -p ~/rio-lab/models

# Recommended: Qwen2.5-Coder-7B (fits 8GB VRAM / 16GB RAM)
curl -fSL https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  -o ~/rio-lab/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf

# Or DeepSeek-Coder-V2-Lite (larger, needs 12GB+ VRAM)
# curl -fSL https://huggingface.co/deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct-GGUF/resolve/main/deepseek-coder-v2-lite-instruct-q4_k_m.gguf \
#   -o ~/rio-lab/models/deepseek-coder-v2-lite-instruct-q4_k_m.gguf
```

### 4. Start the LLM Server

```bash
# Start llama-server with your model
~/rio-lab/llama.cpp/build/bin/llama-server \
  --model ~/rio-lab/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --n-gpu-layers 999 \
  --ctx-size 8192 \
  --temp 0.6
```

You should see: `llama.cpp server listening on http://127.0.0.1:8080`

Open http://127.0.0.1:8080 in your browser to use the built-in chat UI.

### 5. Install OpenCode

```bash
# From Arch repos (stable)
sudo pacman -S opencode

# Or from AUR (latest)
# paru -S opencode-bin

# Or via install script (works on any Linux)
curl -fsSL https://opencode.ai/install | bash
```

### 6. Configure OpenCode

```bash
# Set the local endpoint
export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"

# Make it permanent
echo 'export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"' >> ~/.bashrc

# Create config
mkdir -p ~/.config/opencode
cat > ~/.config/opencode/opencode.json << 'CONFIG'
{
  "$schema": "https://opencode.ai/config.json",
  "providers": {
    "local": {
      "baseURL": "http://127.0.0.1:8080/v1",
      "models": {
        "qwen2.5-coder-7b-instruct-q4_k_m": { "tools": true }
      }
    }
  },
  "agents": {
    "coder": {
      "model": "local.qwen2.5-coder-7b-instruct-q4_k_m",
      "maxTokens": 8192
    },
    "task": {
      "model": "local.qwen2.5-coder-7b-instruct-q4_k_m",
      "maxTokens": 4096
    },
    "title": {
      "model": "local.qwen2.5-coder-7b-instruct-q4_k_m",
      "maxTokens": 80
    }
  }
}
CONFIG
```

### 7. Verify It Works

```bash
# Test the API
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Say hello"}],"max_tokens":10}'

# Test OpenCode
opencode run "What model are you running?"
```

## Running as a Service

To have llama-server start automatically when you log in:

```bash
bash ~/rio-lab/scripts/create-service.sh
```

## Systemd Service (Manual)

```ini
# ~/.config/systemd/user/rio-llamacpp.service
[Unit]
Description=llama.cpp LLM Server (Rio Lab)
After=network.target

[Service]
Type=simple
ExecStart=%h/rio-lab/llama.cpp/build/bin/llama-server \
  --model %h/rio-lab/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  --host 127.0.0.1 --port 8080 \
  --n-gpu-layers 999 --ctx-size 8192

Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now rio-llamacpp.service
```

## Troubleshooting

### Vulkan not found
```bash
sudo pacman -S vulkan-radeon vulkan-icd-loader vulkan-tools
vulkaninfo --summary
```

### GPU not detected in llama.cpp
```bash
# Check Vulkan devices
vulkaninfo --summary | grep deviceName

# Run with GPU layers specified
./llama-server --model model.gguf --n-gpu-layers 999 --verbose
```

### "Out of memory" when loading model
Try a smaller model or a more aggressive quantization (Q3_K_M or Q2_K).

### SteamOS after-system-update issues
Run the fix script:
```bash
bash ~/rio-lab/fix-after-update.sh
```

## Next Steps

- Set up the Steam Gaming Mode launcher: `bash ~/rio-lab/scripts/create-steam-launcher.sh`
- Set up Open WebUI for a richer chat experience: `bash ~/rio-lab/scripts/setup-webui.sh`
- Read the OpenCode guide: `guides/opencode/HOWTO-OPENCODE.md`
