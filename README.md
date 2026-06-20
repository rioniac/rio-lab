# 🤖 Rio Lab — Local AI Lab for Your Machine

> *"Local AI that never calls home. No subscription. No cloud. Forever."*

**By [u/Kingspoken](https://reddit.com/u/Kingspoken)**

---

## 🎯 What Is This?

This is a collection of **step-by-step guides, install scripts, and config templates** for running a local LLM entirely offline on your own hardware — and connecting it to an AI coding agent (OpenCode) plus a web chat UI.

No API keys. No cloud dependency. No data leaving your machine. Just you and a powerful local AI — forever.

Every guide here is built around:

- ✅ **llama.cpp** — the gold-standard open-source LLM inference engine
- ✅ **Vulkan GPU backend** — works on AMD, NVIDIA, Intel, and integrated GPUs
- ✅ **OpenCode** — open-source AI coding agent for your terminal
- ✅ **Built-in web UI** — llama-server ships a chat UI at `http://localhost:8080` (auto-selects free port if 8080 is in use)
- ✅ **Optional: Open WebUI** — feature-rich Docker-based chat interface
- ✅ **Dad-friendly** — written for people who love AI, not just developers
- ✅ **One command install** — `install.sh` handles everything
- ✅ **Any shell** — works from bash, fish, zsh, or any terminal

---

## 🌍 The Story

I'm a dad who grew up on MMOs. After discovering [Dad's MMO Lab](https://github.com/DadsMmoLab/dads-mmo-lab) to keep classic game servers alive offline, I started wondering:

*What if I could do the same for AI?*

Cloud AI is powerful, but it costs money, requires internet, and your data leaves your machine. What if you could run a capable coding assistant entirely locally? On an old laptop? On anything with a GPU?

Turns out — you can. llama.cpp is an engineering marvel that runs on anything from a Raspberry Pi to a Threadripper. Pair it with OpenCode and you've got a fully local AI coding buddy that never phones home.

**This is not a replacement for Claude or GPT.** It's a privacy-first, offline-capable alternative that runs on *your* hardware, *your* terms, forever.

---

## ✅ Currently Working

| Component | Engine | Status |
|---|---|---|
| ⚡ **Core: Local LLM Server** | llama.cpp + Vulkan (universal GPU) | ✅ Complete |
| 🤖 **Coding Agent** | OpenCode CLI → local LLM | ✅ Complete |
| 💬 **Chat UI (built-in)** | llama-server web UI (port auto-selected) | ✅ Complete |
| 🖥️ **Open WebUI** | Docker container → llama-server | ✅ Complete |
| 🤖 **Qwen2.5-Coder model** | GGUF from HuggingFace | ✅ Complete |
| 🤖 **DeepSeek-Coder model** | GGUF from HuggingFace | ✅ Complete |
| 🤖 **CodeGemma model** | GGUF from HuggingFace | ✅ Complete |

### 📋 Planned

| Component | Notes |
|---|---|
| 🐳 **Docker-based install** | Pre-built llama.cpp Docker image |
| 🔄 **Multi-model switching** | Swap models without reconfiguring |
| 📊 **Model benchmark script** | Measure tokens/sec on your hardware |

---

## 📦 What's In This Repo

### Core (`scripts/`)

| File | What it does |
|---|---|
| `install.sh` | Full automated installer — one command does everything |
| `install.ps1` | Windows PowerShell installer |
| `uninstall.sh` | Clean removal |

### Detection (`scripts/`)

| File | What it does |
|---|---|
| `common.sh` | Shared helpers (colors, logging, error handling) |
| `detect-platform.sh` | OS, distro, arch, package manager detection |
| `detect-gpu.sh` | GPU vendor, VRAM, driver detection |
| `suggest-model.sh` | Hardware → recommended model + quant |

### Installation (`scripts/`)

| File | What it does |
|---|---|
| `install-llamacpp.sh` | llama.cpp binary download / source build / Docker |
| `install-opencode.sh` | OpenCode CLI installation |
| `download-model.sh` | Download GGUF from HuggingFace |
| `configure.sh` | Generate opencode.json, launchers, env |
| `create-service.sh` | systemd / launchd service templates |
| `create-steam-launcher.sh` | Steam Gaming Mode integration |
| `setup-webui.sh` | Optional Open WebUI via Docker |
| `verify.sh` | Test endpoint + opencode smoke test |

### Configs (`configs/`)

| File | What it does |
|---|---|
| `opencode.json.template` | OpenCode config with `{{placeholders}}` |
| `llamacpp.service.template` | systemd unit for auto-starting server |
| `rio.env.template` | Environment variable template |

### Guides (`guides/`)

| Guide | Platform |
|---|---|
| `linux/HOWTO-ARCH.md` | Arch Linux, CachyOS |
| `linux/HOWTO-DEBIAN.md` | Debian, Ubuntu, Pop!_OS |
| `linux/HOWTO-FEDORA.md` | Fedora, Nobara |
| `windows/HOWTO-WINDOWS.md` | Windows (native + WSL2) |
| `opencode/HOWTO-OPENCODE.md` | OpenCode reference guide |

---

## 🚀 Quick Start

```bash
curl -fsSL https://rio-lab.dev/install | bash
```

Or, if you've cloned the repo:

```bash
bash install.sh
```

The installer will:

1. ✅ Detect your OS and hardware
2. ✅ Detect your GPU and recommend a model
3. ✅ Let you choose from Qwen2.5-Coder, DeepSeek-Coder, or CodeGemma
4. ✅ Install llama.cpp with Vulkan GPU acceleration
5. ✅ Download your chosen model
6. ✅ Install OpenCode
7. ✅ Generate config files
8. ✅ Verify everything works
9. ✅ Print your endpoint URL and next steps

**New to Linux?** Read the HOWTO guide for your platform first — every step explained in plain English.

---

## 🔧 How It Works

```
Terminal / TUI
      │
      ▼
   OpenCode CLI              ───  "Your AI coding agent"
      │
      ▼  LOCAL_ENDPOINT=http://localhost:PORT/v1
   llama.cpp (llama-server)  ───  "The LLM inference engine"
      │
      ├── GGUF model file    ───  "The AI brain"
      └── Vulkan GPU backend ───  "Hardware acceleration"

   Web Browser
      │
      ▼
   http://localhost:PORT      ───  "Built-in chat UI"
   (or Open WebUI on :3000)
```

*(PORT defaults to 8080 but auto-switches if occupied. Open WebUI runs in Docker and connects to the same llama-server endpoint.)*

---

## 🤖 Model Options

All models are GGUF-quantized from HuggingFace. The installer downloads them for you.

| Model | Recommended VRAM | Quality | Speed |
|---|---|---|---|
| **Qwen2.5-Coder-3B** Q4_K_M | 2-4 GB | Good coding | Fastest |
| **Qwen2.5-Coder-7B** Q4_K_M | 4-8 GB | Better coding | Fast |
| **DeepSeek-Coder-V2-Lite** Q4_K_M | 6-10 GB | Great coding | Medium |
| **CodeGemma-7B** Q4_K_M | 4-8 GB | Good coding + chat | Fast |
| **Qwen2.5-Coder-14B** Q4_K_M | 8-16 GB | Excellent coding | Medium |
| **Qwen2.5-Coder-32B** Q4_K_M | 16-24 GB | State-of-the-art | Slower |

The installer automatically recommends a model based on your detected VRAM.

---

## ⚠️ Legal & Ethical Notes

Rio Lab is not affiliated with, endorsed by, or associated with any of the referenced open-source projects.

- ✅ Uses **only open-source tools** (llama.cpp, OpenCode, Open WebUI)
- ✅ Does **not** distribute model weights — downloads from HuggingFace
- ✅ Uses **GGUF-quantized models** from authorized HuggingFace repos
- ✅ Is intended for **personal, offline, single-user use**
- ❌ Does **not** include copyrighted model training data
- ❌ Does **not** operate any cloud services
- ❌ Does **not** collect telemetry or user data

Huge credit to the communities that make this possible:

- **[llama.cpp](https://github.com/ggml-org/llama.cpp)** — the incredible C++ inference engine
- **[OpenCode](https://github.com/anomalyco/opencode)** — the open-source AI coding agent
- **[Open WebUI](https://github.com/open-webui/open-webui)** — the feature-rich chat interface
- **[Qwen](https://github.com/QwenLM/Qwen)** — Qwen2.5-Coder models
- **[DeepSeek](https://github.com/deepseek-ai/DeepSeek-Coder-V2)** — DeepSeek-Coder models
- **[Gemma](https://github.com/google-deepmind/gemma)** — CodeGemma models

Go give them a star. They deserve it.

> *"This is preservation, not piracy."*

---

## 🤝 Contributing

Found a bug? Got a component working that's not listed? PRs are welcome!

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting.

---

## ☕ Support the Project

This project is free and always will be.

- ⭐ **Star this repo** — helps more people find it
- 📢 **Share it** with other dads who want local AI
- 💬 **Open an issue** with feedback

---

## 📜 License

Installer scripts and guides are released under the [MIT License](LICENSE).

llama.cpp is MIT licensed. OpenCode is Apache 2.0 licensed. Open WebUI is MIT licensed. Model licenses vary — see each model's HuggingFace page for details.

---

*Built with love by a dad who just wanted to code with AI — without the cloud.*

*And then things got out of hand.* 😄

*We're just getting started.* 🤖
