# Rio Lab — Debian / Ubuntu / Pop!_OS Guide

*Also applies to: Linux Mint, Zorin OS, Elementary OS, and any Debian-based distribution.*

## Prerequisites

- Debian 12+ or Ubuntu 22.04+ (or derivative)
- Internet connection
- At least 8 GB free disk space
- Patience — model downloads are large

## Quick Install (One Command)

```bash
# Clone the repo
git clone https://github.com/riolab/rio-lab.git
cd rio-lab

# Run the installer
bash install.sh
```

The installer handles everything. For a manual approach, keep reading.

## Step-by-Step Manual Install

### 1. Install Dependencies

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake git curl wget \
  libvulkan-dev vulkan-validationlayers mesa-vulkan-drivers \
  pkg-config
```

**If you have an NVIDIA GPU:**
```bash
sudo apt install -y nvidia-driver-550 nvidia-cuda-toolkit
```

**If you have an Intel GPU:**
```bash
sudo apt install -y intel-vulkan-sdk
```

### 2. Install llama.cpp

```bash
# Option A: Pre-built binary (fast)
mkdir -p ~/rio-lab/llama.cpp
cd ~/rio-lab/llama.cpp
LATEST=$(curl -fsSL https://api.github.com/repos/ggml-org/llama.cpp/releases/latest | grep tag_name | cut -d'"' -f4)
curl -fsSL "https://github.com/ggml-org/llama.cpp/releases/download/$LATEST/llama.cpp-${LATEST}-linux-x64-vulkan.tar.xz" | tar -xJ

# Option B: Build from source (optimized)
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git ~/rio-lab/llama.cpp
cd ~/rio-lab/llama.cpp
cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)
```

### 3. Download a Model

```bash
mkdir -p ~/rio-lab/models

# Qwen2.5-Coder-7B — best for 8GB+ VRAM or 16GB+ RAM
curl -fSL https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  -o ~/rio-lab/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf
```

### 4. Start the Server

```bash
~/rio-lab/llama.cpp/build/bin/llama-server \
  --model ~/rio-lab/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --n-gpu-layers 999 \
  --ctx-size 8192 \
  --temp 0.6
```

Open http://127.0.0.1:8080 in your browser for the built-in chat UI.

### 5. Install OpenCode

```bash
curl -fsSL https://opencode.ai/install | bash
```

Or via npm:
```bash
sudo npm install -g opencode-ai
```

### 6. Configure OpenCode

```bash
export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"
echo 'export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"' >> ~/.bashrc

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

### 7. Verify

```bash
curl http://127.0.0.1:8080/v1/models
opencode run "Hello!"
```

## Troubleshooting

### Vulkan not found
```bash
sudo apt install mesa-vulkan-drivers libvulkan1
vulkaninfo --summary
```

### Model won't load (OOM)
Try a smaller quantization: Q3_K_M or Q2_K instead of Q4_K_M. Or use the 3B model.

---

*For systemd service setup, launcher creation, and Open WebUI setup, refer to the scripts in the `scripts/` directory.*
