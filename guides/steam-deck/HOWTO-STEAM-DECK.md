# Rio Lab — Steam Deck Guide

Run a local LLM + OpenCode + Chat UI entirely on your Steam Deck. Fully offline, no cloud, no subscription.

## What to Expect

- **Performance**: Qwen2.5-Coder-7B runs at ~5-10 tokens/second on Steam Deck APU
- **Memory**: Uses ~5 GB of RAM, leaving the rest for games
- **Storage**: Models are ~4-5 GB each
- **Battery**: Running inference draws ~15-20W

## Quick Install

From Desktop Mode:

```bash
# Open Konsole (terminal)
git clone https://github.com/riolab/rio-lab.git
cd rio-lab

# Run the installer
bash install.sh
```

The installer will:
1. Detect SteamOS and fix the pacman keyring if needed
2. Install Vulkan drivers
3. Recommend Qwen2.5-Coder-7B (fits Steam Deck's 16 GB RAM)
4. Install llama.cpp, download the model, install OpenCode
5. Generate a Steam Gaming Mode launcher

## Step-by-Step Manual Install

### 1. Enter Desktop Mode

Hold the **Power** button → Switch to Desktop Mode.

### 2. Open Konsole

Click the **Konsole** icon on the taskbar (or search for it).

### 3. Fix Pacman Keyring (Fresh SteamOS Only)

Skip this if you've already installed packages in Desktop Mode.

```bash
sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -S --noconfirm archlinux-keyring
```

### 4. Install Dependencies

```bash
sudo pacman -S --noconfirm \
  cmake git curl \
  vulkan-radeon vulkan-icd-loader vulkan-tools \
  base-devel
```

### 5. Install llama.cpp

```bash
mkdir -p ~/rio-lab
cd ~/rio-lab

# Build from source (optimized for Steam Deck's AMD APU)
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)
```

This takes ~5 minutes on Steam Deck.

### 6. Download a Model

```bash
mkdir -p ~/rio-lab/models
cd ~/rio-lab/models

# Recommended: 3B model (faster, less RAM)
curl -fSL https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf \
  -o qwen2.5-coder-3b-instruct-q4_k_m.gguf

# Or 7B model (smarter, uses more RAM)
# curl -fSL https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
#   -o qwen2.5-coder-7b-instruct-q4_k_m.gguf
```

### 7. Test the Server

```bash
~/rio-lab/llama.cpp/build/bin/llama-server \
  --model ~/rio-lab/models/qwen2.5-coder-3b-instruct-q4_k_m.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --n-gpu-layers 999 \
  --ctx-size 4096
```

Wait for `llama.cpp server listening on http://127.0.0.1:8080`.

Open a browser and go to http://127.0.0.1:8080 — you should see the chat UI.

### 8. Install OpenCode

```bash
curl -fsSL https://opencode.ai/install | bash
```

### 9. Configure OpenCode

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
        "qwen2.5-coder-3b-instruct-q4_k_m": { "tools": true }
      }
    }
  },
  "agents": {
    "coder": {
      "model": "local.qwen2.5-coder-3b-instruct-q4_k_m",
      "maxTokens": 4096
    },
    "task": {
      "model": "local.qwen2.5-coder-3b-instruct-q4_k_m",
      "maxTokens": 2048
    },
    "title": {
      "model": "local.qwen2.5-coder-3b-instruct-q4_k_m",
      "maxTokens": 80
    }
  }
}
CONFIG
```

## Gaming Mode Setup

Add Rio Lab to your Steam library for use in Gaming Mode:

```bash
bash ~/rio-lab/scripts/create-steam-launcher.sh
```

Then in Desktop Mode:
1. Open **Steam**
2. Click **Games → Add a Non-Steam Game to My Library**
3. Browse to `~/rio-lab/rio-steam.sh` and add it
4. Find "rio-steam.sh" in your library → **Properties**
5. **Target**: `/usr/bin/konsole`
6. **Launch Options**: `--hold -e bash ~/rio-lab/rio-steam.sh`
7. **Proton**: OFF

Now you can launch Rio Lab from Gaming Mode. The server starts, you can use OpenCode, and it auto-shuts down when you close the terminal.

## After a SteamOS Update

SteamOS updates can break things. Run the fix script:

```bash
bash ~/rio-lab/fix-after-update.sh
```

This reinitializes the pacman keyring, reinstalls Vulkan drivers, and rebuilds llama.cpp if needed.

## Tips

- **Use the 3B model in Gaming Mode** — it's faster and uses less RAM
- **Use the 7B model in Desktop Mode** — when you have more RAM available
- **Close other apps** when running the 7B model
- **Plug in** — inference drains the battery faster than gaming

## Troubleshooting

### "Failed to initialize Vulkan"
```bash
sudo pacman -S vulkan-radeon vulkan-icd-loader
```

### "Out of memory" with 7B model
Switch to the 3B model, or use Q3_K_M quantization.

### Server won't start after SteamOS update
```bash
bash ~/rio-lab/fix-after-update.sh
```

### Steam Gaming Mode launcher doesn't work
Make sure **Proton is OFF** in the Steam properties. The launcher is a native shell script, not a Windows game.
