#!/usr/bin/env bash
#
# Install portless globally - https://port1355.dev/
# Portless gives every dev server a stable named .localhost URL instead of a random port.
# Run: portless myapp pnpm dev  →  http://myapp.localhost:1355

set -euo pipefail

if command -v portless > /dev/null 2>&1; then
  echo "  [ok] portless already installed ($(portless --version 2>/dev/null || echo 'version unknown'))"
  exit 0
fi

echo "Installing portless..."

if command -v npm > /dev/null 2>&1; then
  npm install -g portless
  echo "  [ok] portless installed via npm"
elif command -v pnpm > /dev/null 2>&1; then
  pnpm add -g portless
  echo "  [ok] portless installed via pnpm"
else
  echo "  [warn] npm/pnpm not found — install portless manually:"
  echo "         npm install -g portless"
  exit 1
fi
