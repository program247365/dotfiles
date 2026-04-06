#!/usr/bin/env bash
set -e

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$DOTFILES_ROOT/bin"
KIT_SCRIPT="$DOTFILES_ROOT/kit/kit"

chmod +x "$KIT_SCRIPT"

if [ ! -L "$BIN_DIR/kit" ]; then
  ln -s "$KIT_SCRIPT" "$BIN_DIR/kit"
  echo "  Linked kit → bin/kit"
else
  echo "  kit already linked"
fi
