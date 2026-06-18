<#
.SYNOPSIS
    Rio Lab — Windows Unified Installer
.DESCRIPTION
    Sets up a local LLM (llama.cpp) + OpenCode + Web UI on Windows.
    Supports native Windows and WSL2 modes.
.PARAMETER Method
    Install method: binary, wsl (default: binary)
.PARAMETER NoWebUI
    Skip Open WebUI setup
.PARAMETER NoModel
    Skip model download
.PARAMETER Yes
    Skip all confirmations
#>

param(
    [ValidateSet("binary", "wsl")]
    [string]$Method = "binary",
    [switch]$NoWebUI,
    [switch]$NoModel,
    [switch]$Yes
)

$RIOHome = if ($env:RIO_HOME) { $env:RIO_HOME } else { "$env:USERPROFILE\rio-lab" }

# ─── Colors ──────────────────────────────────────────────────────────
$Host.UI.RawUI.ForegroundColor = "White"
function Write-Info  { Write-Host "ℹ " -NoNewline -ForegroundColor Blue; Write-Host "$args" }
function Write-Step { Write-Host "`n━━━ $args ━━━" -ForegroundColor Magenta }
function Write-Done { Write-Host "✔ " -NoNewline -ForegroundColor Green; Write-Host "$args" }
function Write-Warn { Write-Host "⚠ " -NoNewline -ForegroundColor Yellow; Write-Host "$args" }
function Write-Err  { Write-Host "✘ " -NoNewline -ForegroundColor Red; Write-Host "$args" }

function Confirm-Prompt {
    param([string]$Prompt = "Continue?", [string]$Default = "y")
    if ($Yes) { return $true }
    $defaultChar = if ($Default -eq "y") { "Y/n" } else { "y/N" }
    $response = Read-Host "$Prompt [$defaultChar]"
    if ($response -eq "") { $response = $Default }
    return $response -match "^(y|yes)$"
}

# ─── Banner ──────────────────────────────────────────────────────────
Clear-Host
Write-Host @"

  ╔═══════════════════════════════════════════╗
  ║          🤖  Rio Lab  🤖                  ║
  ║   Local AI that never calls home.         ║
  ╚═══════════════════════════════════════════╝

"@ -ForegroundColor Magenta

Write-Host "Welcome to Rio Lab!" -ForegroundColor White
Write-Info "This installer sets up a complete local AI lab on your machine."

# ─── WSL Detection ───────────────────────────────────────────────────
$inWSL = $false
if (Test-Path "/proc/version") {
    $procVersion = Get-Content "/proc/version" -ErrorAction SilentlyContinue
    if ($procVersion -match "microsoft|wsl") { $inWSL = $true }
}
if ($env:WSLENV) { $inWSL = $true }

if ($inWSL) {
    Write-Info "WSL2 detected — delegating to Linux installer..."
    $scriptDir = Split-Path -Parent $PSCommandPath
    $installSh = Join-Path $scriptDir "install.sh"
    if (Test-Path $installSh) {
        bash "$installSh" @args
        exit $LASTEXITCODE
    } else {
        Write-Err "install.sh not found alongside install.ps1"
        exit 1
    }
}

# ─── Platform Info ───────────────────────────────────────────────────
Write-Step "1/7 — Platform & Hardware Detection"
$arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "x86" }
Write-Info "Architecture: $arch"
Write-Info "Install dir:  $RIOHome"

# GPU detection via PowerShell
$gpuInfo = Get-WmiObject Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
$gpuVendor = "unknown"
$gpuName = "Unknown"
$vramMB = 0
if ($gpuInfo) {
    $gpuName = $gpuInfo.Name
    $gpuVendor = if ($gpuInfo.Name -match "NVIDIA") { "nvidia" }
                 elseif ($gpuInfo.Name -match "AMD|Radeon") { "amd" }
                 elseif ($gpuInfo.Name -match "Intel") { "intel" }
                 else { "unknown" }
    $vramMB = [math]::Round($gpuInfo.AdapterRAM / 1MB, 0)
    Write-Info "GPU: $gpuName ($gpuVendor, ${vramMB}MB)"
} else {
    Write-Warn "No GPU detected — will use CPU only"
    $vramMB = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB
}

# ─── Model Suggestion ───────────────────────────────────────────────
Write-Step "2/7 — Model Selection"
$models = @(
    @{ Name = "Qwen2.5-Coder-1.5B (Q4_K_M)"; MinVRAM = 2048; HF = "Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF"; File = "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf" }
    @{ Name = "Qwen2.5-Coder-3B (Q4_K_M)";   MinVRAM = 4096; HF = "Qwen/Qwen2.5-Coder-3B-Instruct-GGUF";   File = "qwen2.5-coder-3b-instruct-q4_k_m.gguf" }
    @{ Name = "Qwen2.5-Coder-7B (Q4_K_M)";   MinVRAM = 6144; HF = "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF";   File = "qwen2.5-coder-7b-instruct-q4_k_m.gguf" }
)

$selectedModel = $models[0]
foreach ($m in $models) {
    if ($vramMB -ge $m.MinVRAM) { $selectedModel = $m }
}

Write-Info "Recommended: $($selectedModel.Name)"
Write-Host ""

# Allow model selection
if (-not $Yes) {
    Write-Host "Available models:"
    for ($i = 0; $i -lt $models.Count; $i++) {
        $ok = if ($vramMB -ge $models[$i].MinVRAM) { "✓" } else { " " }
        Write-Host "  $($i+1). $ok $($models[$i].Name)"
    }
    if (-not (Confirm-Prompt "Use default model: $($selectedModel.Name)?")) {
        $choice = Read-Host "Enter model number"
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $models.Count) { $selectedModel = $models[$idx] }
    }
}

$modelId = $selectedModel.File -replace '\.gguf$', ''
$modelDir = "$RIOHome\models"
$modelPath = "$modelDir\$($selectedModel.File)"
Write-Info "Selected: $($selectedModel.Name)"
Write-Info "Model ID: $modelId"

# ─── Step 3: Install llama.cpp ──────────────────────────────────────
Write-Step "3/7 — Installing llama.cpp"
New-Item -ItemType Directory -Force -Path "$RIOHome\llama.cpp" | Out-Null

$llamaServer = "$RIOHome\llama.cpp\llama-server.exe"
if (-not (Test-Path $llamaServer)) {
    Write-Info "Downloading llama.cpp binary (Vulkan-enabled)..."
    $repo = "ggml-org/llama.cpp"
    $tag = (Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -ErrorAction SilentlyContinue).tag_name
    if (-not $tag) { $tag = "master" }

    $url = "https://github.com/$repo/releases/download/$tag/llama.cpp-${tag}-win-x64-vulkan.zip"
    $zipPath = "$env:TEMP\llama.zip"
    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -ErrorAction Stop
        Expand-Archive -Path $zipPath -DestinationPath "$RIOHome\llama.cpp" -Force
        Remove-Item $zipPath -Force
        Write-Done "llama.cpp binary downloaded"
    } catch {
        Write-Warn "Binary download failed: $($_.Exception.Message)"
        Write-Warn "Please download manually from: $url"
    }
} else {
    Write-Info "llama.cpp already installed"
}

# Find llama-server.exe
$llamaServer = Get-ChildItem -Path "$RIOHome\llama.cpp" -Recurse -Filter "llama-server.exe" | Select-Object -First 1 -ExpandProperty FullName
if (-not $llamaServer) { $llamaServer = "$RIOHome\llama.cpp\llama-server.exe" }

# ─── Step 4: Download Model ─────────────────────────────────────────
if (-not $NoModel) {
    Write-Step "4/7 — Downloading Model ($($selectedModel.Name))"
    New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

    if (-not (Test-Path $modelPath)) {
        $modelUrl = "https://huggingface.co/$($selectedModel.HF)/resolve/main/$($selectedModel.File)"
        Write-Info "Downloading from HuggingFace..."
        Write-Info "  $modelUrl"
        try {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($modelUrl, $modelPath)
            $size = (Get-Item $modelPath).Length / 1MB
            Write-Done "Model downloaded: [math]::Round($size, 1) MB"
        } catch {
            Write-Err "Download failed: $($_.Exception.Message)"
        }
    } else {
        $size = (Get-Item $modelPath).Length / 1MB
        Write-Info "Model already exists: [math]::Round($size, 1) MB"
    }
}

# ─── Step 5: Install OpenCode ───────────────────────────────────────
Write-Step "5/7 — Installing OpenCode CLI"

$opencodeFound = (Get-Command "opencode" -ErrorAction SilentlyContinue) -ne $null
if (-not $opencodeFound) {
    if (Get-Command "scoop" -ErrorAction SilentlyContinue) {
        Write-Info "Installing via Scoop..."
        scoop install opencode
    } elseif (Get-Command "choco" -ErrorAction SilentlyContinue) {
        Write-Info "Installing via Chocolatey..."
        choco install opencode -y
    } elseif (Get-Command "npm" -ErrorAction SilentlyContinue) {
        Write-Info "Installing via npm..."
        npm install -g opencode-ai
    } else {
        Write-Warn "No package manager found. Scoop is recommended:"
        Write-Warn "  Install Scoop from https://scoop.sh, then run: scoop install opencode"
        Write-Warn "  Or open PowerShell and run:"
        Write-Warn "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        Write-Warn "    irm get.scoop.sh | iex"
        Write-Warn "    scoop install opencode"
    }
} else {
    Write-Info "OpenCode already installed"
}

# ─── Step 6: Configuration ──────────────────────────────────────────
Write-Step "6/7 — Configuration"
$configDir = "$RIOHome\config"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

# Environment config
@"
# Rio Lab Configuration — generated by install.ps1
`$env:RIO_HOME = "$RIOHome"
`$env:RIO_MODEL_PATH = "$modelPath"
`$env:RIO_MODEL_ID = "$modelId"
`$env:LOCAL_ENDPOINT = "http://127.0.0.1:8080/v1"

# Add OpenCode config path
if (Test-Path "$configDir\opencode.json") {
    `$env:OPENCODE_CONFIG = "$configDir\opencode.json"
}
"@ | Out-File -FilePath "$configDir\rio.ps1" -Encoding ASCII

# Launcher script
@"
# Rio Lab Launcher — Windows
`$RIOHome = "$RIOHome"
`$modelPath = "$modelPath"
`$llamaServer = "$llamaServer"

Write-Host "Starting llama-server..."
Write-Host "Model: `$modelPath"
Write-Host "Endpoint: http://127.0.0.1:8080/v1"
Write-Host ""

# Start llama-server
Start-Process -NoNewWindow -FilePath "`$llamaServer" -ArgumentList @(
    "--model", "`$modelPath",
    "--host", "127.0.0.1",
    "--port", "8080",
    "--n-gpu-layers", "999",
    "--ctx-size", "8192",
    "--temp", "0.6",
    "--top-p", "0.95",
    "--top-k", "40"
)

# Wait for server
Write-Host -NoNewline "Waiting for server"
for (`$i = 0; `$i -lt 30; `$i++) {
    try {
        `$null = Invoke-WebRequest -Uri "http://127.0.0.1:8080/v1/models" -Method Get -ErrorAction Stop
        Write-Host " READY!"
        Write-Host ""
        Write-Host "Rio Lab is running!"
        Write-Host "  Chat UI:  http://127.0.0.1:8080"
        Write-Host "  API:      http://127.0.0.1:8080/v1"
        break
    } catch {
        Write-Host -NoNewline "."
        Start-Sleep -Seconds 1
    }
}

Write-Host ""
Write-Host "Press Ctrl+C to stop."
Read-Host "Press Enter to shutdown..."

# Cleanup
Stop-Process -Name "llama-server" -Force -ErrorAction SilentlyContinue
Write-Host "Rio Lab stopped."
"@ | Out-File -FilePath "$RIOHome\rio-launcher.ps1" -Encoding ASCII

# OpenCode config
@"
{
  `"`$schema`": `"https://opencode.ai/config.json`",
  `"providers`": {
    `"local`": {
      `"baseURL`": `"http://127.0.0.1:8080/v1`",
      `"models`": {
        `"$modelId`": { `"tools`": true }
      }
    }
  },
  `"agents`": {
    `"coder`": { `"model`": `"local.$modelId`", `"maxTokens`": 8192 },
    `"task`":  { `"model`": `"local.$modelId`", `"maxTokens`": 4096 },
    `"title`": { `"model`": `"local.$modelId`", `"maxTokens`": 80 }
  }
}
"@ | Out-File -FilePath "$configDir\opencode.json" -Encoding ASCII

Write-Done "Configuration complete"
Write-Info "  Config:  $configDir"
Write-Info "  Launcher: $RIOHome\rio-launcher.ps1"

# ─── Step 7: Open WebUI (optional) ─────────────────────────────────
if (-not $NoWebUI) {
    Write-Step "7/7 — Optional: Open WebUI"
    if (Confirm-Prompt "Set up Open WebUI (Docker-based chat interface)?") {
        if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
            Write-Warn "Docker Desktop is required for Open WebUI"
            Write-Warn "Download from: https://www.docker.com/products/docker-desktop/"
        } else {
            $webuiDir = "$RIOHome\webui"
            New-Item -ItemType Directory -Force -Path $webuiDir | Out-Null

            # Generate secret key
            $secretKey = if (Get-Command "openssl" -ErrorAction SilentlyContinue) {
                openssl rand -hex 32
            } else {
                -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
            }

            # .env file
            @"
WEBUI_SECRET_KEY=$secretKey
WEBUI_NAME=Rio Lab
SCARF_NO_ANALYTICS=true
DO_NOT_TRACK=true
ANONYMIZED_TELEMETRY=false
ENABLE_SIGNUP=true
DEFAULT_LOCALE=en
DEFAULT_MODELS=$modelId
SAFE_MODE=true
"@ | Out-File -FilePath "$webuiDir\.env" -Encoding ASCII

            # docker-compose.yml
            @"
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: rio-webui
    restart: unless-stopped
    ports:
      - "3000:8080"
    env_file:
      - .env
    environment:
      OPENAI_API_BASE_URL: http://host.docker.internal:8080/v1
      OPENAI_API_KEY: ""
    volumes:
      - rio_webui_data:/app/backend/data
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8080/health || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 30s
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  rio_webui_data:
"@ | Out-File -FilePath "$webuiDir\docker-compose.yml" -Encoding ASCII

            Write-Done "Open WebUI configured"

            if (Confirm-Prompt "Start Open WebUI now?" "y") {
                Write-Info "Starting Open WebUI..."
                docker compose -f "$webuiDir\docker-compose.yml" up -d
                Write-Done "Open WebUI started at http://localhost:3000"
            } else {
                Write-Info "To start later:"
                Write-Info "  docker compose -f $webuiDir\docker-compose.yml up -d"
                Write-Info "  Open http://localhost:3000"
            }
        }
    }
}

# ─── Success ─────────────────────────────────────────────────────────
Write-Host @"

╔════════════════════════════════════════════════════╗
║        🎉  Rio Lab Installation Complete!  🎉       ║
╚════════════════════════════════════════════════════╝

"@ -ForegroundColor Green
Write-Host "Your local AI lab is ready!" -ForegroundColor White
Write-Host ""
Write-Info "  🤖  Model:    $($selectedModel.Name)"
Write-Info "  📍  Endpoint: http://127.0.0.1:8080/v1"
Write-Info "  💬  Chat UI:  http://127.0.0.1:8080"
Write-Info "  ⌨️   OpenCode: opencode"
Write-Host ""
Write-Host "Quick start:"
Write-Host "  1. Start the server:  PowerShell $RIOHome\rio-launcher.ps1"
Write-Host "  2. Use OpenCode:      opencode"
Write-Host "  3. Chat UI:           http://127.0.0.1:8080"
Write-Host ""
Write-Host "Enjoy your local AI! 🤖" -ForegroundColor Green
