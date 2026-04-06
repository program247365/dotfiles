#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$DOTFILES_ROOT/bin"
KIT_SCRIPT="$DOTFILES_ROOT/kit/kit"

chmod +x "$KIT_SCRIPT"

if [ ! -L "$BIN_DIR/kit" ]; then
  # Use relative path so the symlink works on any machine regardless of clone location
  ln -s "../kit/kit" "$BIN_DIR/kit"
  echo "  Linked kit → bin/kit"
else
  echo "  kit already linked"
fi
