# Rio Lab — Windows Guide

There are two ways to run Rio Lab on Windows:

1. **WSL2 (Recommended)** — Best performance, full feature support
2. **Native Windows** — Quicker setup, may have some limitations

---

## Method 1: WSL2 (Recommended)

WSL2 provides a full Linux environment inside Windows. Everything works as documented in the Linux guides.

### 1. Install WSL2

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

Restart your computer when prompted.

### 2. Install Git in WSL

Open the "Ubuntu" app from your Start menu and run:

```bash
sudo apt update && sudo apt install -y git
```

### 3. Install Rio Lab

```bash
git clone https://github.com/riolab/rio-lab.git
cd rio-lab
bash install.sh
```

That's it. Inside WSL, everything works exactly like on Linux.

### GPU Acceleration in WSL2

WSL2 supports GPU passthrough:
- **NVIDIA**: Automatically works with NVIDIA drivers on Windows
- **AMD**: Works with AMD drivers on Windows (requires latest drivers)
- **Intel**: Works with Intel drivers on Windows

To verify GPU support in WSL:
```bash
vulkaninfo --summary
```

## Method 2: Native Windows

### 1. Install Dependencies

First, install a package manager:

**Scoop (Recommended):**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
scoop install git curl
```

**Or Chocolatey:**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install git curl
```

### 2. Run the Rio Lab Installer

```powershell
git clone https://github.com/riolab/rio-lab.git
cd rio-lab
.\install.ps1
```

The installer will:
1. Detect your GPU
2. Recommend a model
3. Download llama.cpp binary for Windows
4. Download your chosen model from HuggingFace
5. Install OpenCode via Scoop or npm
6. Generate configuration files and a launcher script

### 3. Start the Server

```powershell
.\rio-lab\rio-launcher.ps1
```

### 4. Use OpenCode

Open a separate terminal:

```powershell
opencode
```

Or use the built-in web UI at http://127.0.0.1:8080.

### 5. Open WebUI (Optional)

If you have Docker Desktop installed:

```powershell
cd ~/rio-lab/webui
docker compose up -d
```

Open http://localhost:3000 in your browser.

---

## Troubleshooting

### "Access denied" running PowerShell scripts
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "llama-server.exe is not recognized"
Make sure the install script found the binary. Check `~/rio-lab/llama.cpp/` for `llama-server.exe`.

### GPU not detected
Native Windows GPU support requires the Vulkan loader. Install from:
https://vulkan.lunarg.com/sdk/home

### OpenCode not found
Install via Scoop:
```powershell
scoop install opencode
```

### Better to use WSL?
If you're hitting Windows-specific issues, the WSL2 route is smoother and better supported.

---

## Next Steps

- Read the OpenCode guide at `guides/opencode/HOWTO-OPENCODE.md`
- Check model recommendations at `models/MODEL-RECOMMENDATIONS.md`
