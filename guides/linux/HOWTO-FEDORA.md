# Rio Lab — Fedora / Bazzite / Nobara Guide

*Also applies to: RHEL, CentOS Stream, and any Fedora-based distribution.*

## Prerequisites

- Fedora 39+ (or derivative)
- Internet connection
- At least 8 GB free disk space

## Quick Install (One Command)

```bash
git clone https://github.com/riolab/rio-lab.git
cd rio-lab
bash install.sh
```

## Step-by-Step Manual Install

### 1. Install Dependencies

```bash
sudo dnf update
sudo dnf install -y \
  cmake gcc-c++ git curl \
  vulkan-loader-devel vulkan-headers vulkan-tools \
  mesa-vulkan-drivers
```

**NVIDIA GPU:**
```bash
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
```

**Intel GPU:**
```bash
sudo dnf install -y mesa-vulkan-drivers intel-media-driver
```

### 2. Install llama.cpp

```bash
# Build from source (recommended for Fedora)
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git ~/rio-lab/llama.cpp
cd ~/rio-lab/llama.cpp
cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)
```

### 3. Download & Run

```bash
mkdir -p ~/rio-lab/models
curl -fSL https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  -o ~/rio-lab/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf

~/rio-lab/llama.cpp/build/bin/llama-server \
  --model ~/rio-lab/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  --host 127.0.0.1 --port 8080 \
  --n-gpu-layers 999 --ctx-size 8192
```

### 4. Install OpenCode

```bash
curl -fsSL https://opencode.ai/install | bash
```

### 5. Configure

```bash
export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"
echo 'export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"' >> ~/.bashrc
```

Then create `~/.config/opencode/opencode.json` using the template from the repo.

---

**Note for Bazzite users**: Bazzite ships with most Vulkan and GPU drivers pre-installed. You can skip the dependency installation step and go straight to llama.cpp.
