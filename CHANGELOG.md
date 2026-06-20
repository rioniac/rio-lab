# Changelog

## 2026-06-19 — Uncommitted Changes

### Bug Fixes

| File | Fix |
|------|-----|
| `install.sh` | Removed `local` keyword used outside functions (lines 125, 228) |
| `install.sh` | Guarded server verification to skip gracefully when `--no-model` is used |
| `install.ps1` | Fixed broken string interpolation: `[math]::Round(...)` → `$([math]::Round(...))` |
| `install.ps1` | Replaced deprecated `Get-WmiObject` with `Get-CimInstance` (PowerShell 7+ compat) |
| `detect-gpu.sh` | Fixed operator precedence bug in integrated GPU detection (`||` vs `&&` binding) |
| `suggest-model.sh` | Changed `IFS` delimiter from `:` to `\|` to prevent silent truncation of names |
| `configure.sh` | Consolidated duplicate `local` declarations into a single assignment |
| `install-llamacpp.sh` | Used `find` to locate binaries in tarball instead of assuming root-level layout |
| `download-model.sh` | Removed redundant identical branches in download conditional |
| `uninstall.sh` | Moved `RIO_HOME` assignment before its first use |

### Improvements

| File | Change |
|------|--------|
| `install.sh` | `clear` now only runs when stdout is a TTY (`[[ -t 1 ]]`) |
| `install.ps1` | Added 4 missing models (Qwen 14B/32B, DeepSeek-Coder-V2-Lite, CodeGemma-7B) for parity with bash |
| `install.ps1` | Updated `.PARAMETER Method` help text to reflect actual supported values |
| `suggest-model.sh` | Added comment explaining "last (largest) fitting model wins" iteration logic |
| `create-steam-launcher.sh` | Replaced `sed -i` with `render_template` for consistency with `configure.sh` |
| `fix-after-update.sh` | Wrapped `cd` + `cmake` in a subshell to prevent working directory leak |
| `common.sh` | Replaced `eval` with `printf -v` in `prompt_value` for safer variable assignment |
| `setup-webui.sh` | Added security note documenting curl-pipe-sh trust assumption |
| `install-opencode.sh` | Added security note documenting curl-pipe-bash trust assumption |

### New Files

| File | Purpose |
|------|---------|
| `.shellcheckrc` | ShellCheck linting configuration (disables SC1091 for sourced files) |
| `lint.sh` | Convenience script to run ShellCheck on all project scripts |

---

## 2026-06-18 — Commits

### `0ae5b8e` — Initial commit
> Initial repository creation with project scaffolding.

### `42dc923` — initial commit
> Core installer and script infrastructure:
> - `install.sh` / `install.ps1` — Unified installers for Linux/macOS and Windows
> - `scripts/` — Modular bash scripts for platform detection, GPU detection, model recommendation, llama.cpp/OpenCode install, model download, configuration, systemd services, Steam launcher, and verification
> - `configs/` — Template files for OpenCode, systemd, and environment variables
> - `guides/` — Platform-specific how-to documentation (Arch, Debian, Fedora, Steam Deck, Windows)
> - `uninstall.sh` — Clean removal script
> - `README.md`, `CONTRIBUTING.md`, `DISCLAIMER.md`, `LICENSE` (MIT)

### `62096d2` — Implement Open WebUI with full lifecycle management
> Added Docker-based Open WebUI chat interface:
> - `scripts/setup-webui.sh` — Full lifecycle management (setup, start, stop, restart, status, logs)
> - Docker Compose config with health checks, GPU passthrough comments, and `host.docker.internal` networking
> - `.env` generation with secret key, telemetry opt-out, and safe mode
> - Interactive and CLI-driven modes (`--start`, `--stop`, `--restart`, `--status`, `--logs`)
