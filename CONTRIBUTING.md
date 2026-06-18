# Contributing to Rio Lab

First off, thanks for your interest! This project thrives on community contributions.

## How to Contribute

### Reporting Issues

- Check existing issues first to avoid duplicates
- Include your platform (OS, distro, GPU, VRAM)
- Include the full output of any failing commands
- Include the installer log if available

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the problem you're solving, not just the feature
- If you've got a working prototype, even better — link to a branch

### Pull Requests

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Test on your platform
5. Submit a PR with a clear description

## Coding Standards

### Shell Scripts

- **Shell**: Bash (with `/usr/bin/env bash` shebang)
- **Style**: Follow existing patterns in `scripts/`
- **Error handling**: Use the helpers from `common.sh`:
  - `log_info`, `log_success`, `log_warning`, `log_error`
  - `check_command` for dependency checks
  - `check_previous` after critical operations
  - `confirm` for user prompts
- **Portability**: Support bash 4.0+ (what ships on macOS and Linux)

### PowerShell (Windows)

- **Style**: Follow existing patterns in `install.ps1`
- **Error handling**: Use `try/catch` and `-ErrorAction Stop`
- **Portability**: Support PowerShell 5.1+ (what ships on Windows)

### Markdown (Guides)

- Write for a non-technical audience
- Use numbered steps
- Include code blocks with language tags
- Include screenshots where helpful
- Test each step before submitting

## Testing

Before submitting your PR, please:

1. Run `shellcheck scripts/*.sh` on any modified shell scripts
2. If adding a new feature, include a test or verification step
3. Update any relevant HOWTO guides

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
