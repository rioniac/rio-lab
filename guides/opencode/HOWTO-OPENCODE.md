# OpenCode — Reference Guide

OpenCode is an open-source AI coding agent that runs in your terminal. It reads files, edits code, runs commands, and works through multi-step problems autonomously.

This guide covers configuration and usage with a local LLM.

## Prerequisites

- llama-server running locally (see your platform's HOWTO guide)
- OpenCode installed

## Configuration

### Environment Variable

Set the `LOCAL_ENDPOINT` environment variable to point at your local llama-server:

```bash
export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"
```

Make it permanent by adding to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
echo 'export LOCAL_ENDPOINT="http://127.0.0.1:8080/v1"' >> ~/.bashrc
```

### Config File

Create `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "providers": {
    "local": {
      "baseURL": "http://127.0.0.1:8080/v1",
      "models": {
        "qwen2.5-coder-7b-instruct-q4_k_m": {
          "tools": true
        }
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
```

Or create a project-specific `opencode.json` in your project root.

### Model Names

Model names use the format: `local.<model-id>` where `<model-id>` matches the GGUF filename (without `.gguf`).

Examples:
- `qwen2.5-coder-7b-instruct-q4_k_m` → `local.qwen2.5-coder-7b-instruct-q4_k_m`
- `deepseek-coder-v2-lite-instruct-q4_k_m` → `local.deepseek-coder-v2-lite-instruct-q4_k_m`
- `codegemma-7b-it-q4_k_m` → `local.codegemma-7b-it-q4_k_m`

## Verifying the Connection

### 1. Check the API endpoint

```bash
curl http://127.0.0.1:8080/v1/models
```

You should see a JSON response listing available models.

### 2. Test a chat completion

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Say hello in 5 words or less"}],
    "max_tokens": 20
  }'
```

### 3. Test OpenCode

```bash
opencode run "What model are you running?"
```

## Performance Tuning

### Context Window

Local models often have shorter context windows. If you see errors about context length:

1. Increase `--ctx-size` when starting llama-server (e.g., `--ctx-size 16384`)
2. Reduce `maxTokens` in the OpenCode config
3. Note: larger context uses more VRAM/RAM

### Temperature

- **0.2-0.4**: More deterministic, better for code generation
- **0.6-0.8**: More creative, better for brainstorming
- **0.8-1.0**: Very creative, may produce less coherent code

### Thread Count

Set `--threads` to match your CPU core count for optimal prompt processing:
```bash
--threads $(nproc)  # Linux
```

## OpenCode Commands

| Command | Description |
|---|---|
| `opencode` | Open the TUI (terminal UI) |
| `opencode run "prompt"` | Run a single task and exit |
| `opencode run -f prompt.txt` | Run from a file |
| `opencode session` | Continue last session |
| `opencode doctor` | Check configuration |
| `opencode --version` | Show version |

### Inside the TUI

| Key | Action |
|---|---|
| `Ctrl+C` | Cancel current operation |
| `Ctrl+D` | Exit |
| `/help` | Show help |
| `/model` | Show current model |
| `/cost` | Show token usage |
| `Up/Down` | Scroll through history |

## Multiple Models

You can configure different models for different agents:

```json
{
  "agents": {
    "coder": {
      "model": "local.qwen2.5-coder-14b-instruct-q4_k_m",
      "maxTokens": 8192
    },
    "task": {
      "model": "local.qwen2.5-coder-7b-instruct-q4_k_m",
      "maxTokens": 4096
    },
    "title": {
      "model": "local.qwen2.5-coder-3b-instruct-q4_k_m",
      "maxTokens": 80
    }
  }
}
```

Use a fast, small model for simple tasks (title generation) and a larger model for complex coding tasks.

## Switching Models

To switch between models (e.g., Qwen2.5 vs DeepSeek):

1. Stop llama-server (`Ctrl+C`)
2. Restart with the new model:
   ```bash
   llama-server --model ~/rio-lab/models/deepseek-coder-v2-lite-instruct-q4_k_m.gguf --host 127.0.0.1 --port 8080
   ```
3. Update `model` in `opencode.json` to match the new model ID
4. OpenCode will automatically use the new model

## Troubleshooting

### "No provider configured"
Set `LOCAL_ENDPOINT` environment variable or configure a provider in `opencode.json`.

### "Model not found"
The model name in `opencode.json` must match exactly what llama-server reports at `/v1/models`. Check with:
```bash
curl http://127.0.0.1:8080/v1/models
```

### "Context length exceeded"
Increase `--ctx-size` on the server or reduce `maxTokens` in the config.

### OpenCode is slow
Local models are slower than cloud APIs. Expect 5-20 tokens/second depending on your hardware. This is normal.

### "Connection refused"
Make sure llama-server is running. Check with:
```bash
curl http://127.0.0.1:8080/v1/models
```

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [OpenCode GitHub](https://github.com/anomalyco/opencode)
- [llama.cpp Documentation](https://github.com/ggml-org/llama.cpp)
