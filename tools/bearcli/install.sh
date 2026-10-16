#!/bin/sh
#
# bearcli — Bear's official CLI (Bear 2.8+)
#
# Bear ships the binary inside its app bundle. This script symlinks it onto
# PATH and removes any leftovers from the old `bcli` (better-bear-cli) install.
# Idempotent — safe to re-run after every Bear update.

set -e

BUNDLED="/Applications/Bear.app/Contents/MacOS/bearcli"
BIN_DIR="$HOME/.kevin/bin"
LINK="$BIN_DIR/bearcli"

if [ ! -x "$BUNDLED" ]; then
  echo "  skipped bearcli: Bear not installed (install Bear 2.8+, then re-run dot)"
  exit 0
fi

mkdir -p "$BIN_DIR"
ln -sf "$BUNDLED" "$LINK"
echo "Linked $LINK -> $BUNDLED"

if [ -e "$BIN_DIR/bcli" ]; then
  rm -f "$BIN_DIR/bcli"
  echo "Removed stale ~/.kevin/bin/bcli"
fi

if [ -d "$HOME/.kevin/src/better-bear-cli" ]; then
  rm -rf "$HOME/.kevin/src/better-bear-cli"
  echo "Removed stale ~/.kevin/src/better-bear-cli"
fi

if [ -d "$HOME/.config/bear-cli" ]; then
  rm -rf "$HOME/.config/bear-cli"
  echo "Removed stale ~/.config/bear-cli (auth + cache)"
fi
