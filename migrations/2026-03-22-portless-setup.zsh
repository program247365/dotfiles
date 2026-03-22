#!/usr/bin/env zsh
#
# Install portless globally - https://port1355.dev/
# Named .localhost URLs for dev servers instead of random port juggling.

set -e

if command -v portless > /dev/null 2>&1; then
  echo "portless: already installed"
  return 0
fi

echo "portless: installing globally..."

if command -v npm > /dev/null 2>&1; then
  npm install -g portless
  echo "portless: installed via npm"
elif command -v pnpm > /dev/null 2>&1; then
  pnpm add -g portless
  echo "portless: installed via pnpm"
else
  echo "portless: [warn] npm/pnpm not found — install manually: npm install -g portless"
fi
