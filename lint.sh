#!/usr/bin/env bash
# Rio Lab — lint.sh
# Runs shellcheck on all project scripts
# Usage: bash lint.sh

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Error: This script requires bash. Run with: bash $0" >&2
  exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v shellcheck &>/dev/null; then
  echo "shellcheck not found. Install it:"
  echo "  sudo apt install shellcheck        # Debian/Ubuntu"
  echo "  sudo pacman -S shellcheck           # Arch"
  echo "  brew install shellcheck             # macOS"
  exit 1
fi

echo "Running shellcheck on all scripts..."
echo ""

# Lint all .sh files
find "$SCRIPT_DIR" -name '*.sh' -type f | sort | while read -r file; do
  rel="${file#"$SCRIPT_DIR/"}"
  if shellcheck -x "$file" 2>/dev/null; then
    echo "  ✔ $rel"
  else
    echo "  ✘ $rel"
  fi
done

echo ""
echo "Done. Fix any warnings above before committing."
