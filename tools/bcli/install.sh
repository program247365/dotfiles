#!/bin/sh
#
# bcli — Bear Notes CLI (better-bear-cli)
#
# Downloads the latest universal binary from GitHub and installs to ~/.kevin/bin.
# Auth is interactive (bcli auth) — not run here.

set -e

BIN_DIR="$HOME/.kevin/bin"
BCLI="$BIN_DIR/bcli"

mkdir -p "$BIN_DIR"

echo "Installing bcli..."

curl -sL https://github.com/mreider/better-bear-cli/releases/latest/download/bcli-macos-universal.tar.gz \
  -o /tmp/bcli.tar.gz
tar xzf /tmp/bcli.tar.gz -C /tmp
mv /tmp/bcli "$BCLI"
chmod +x "$BCLI"
rm -f /tmp/bcli.tar.gz

# Clean up stale manual install if it exists
if [ -f "$HOME/.local/bin/bcli" ]; then
  rm -f "$HOME/.local/bin/bcli"
  echo "  Removed stale ~/.local/bin/bcli"
fi

echo "Installed bcli to $BCLI"
echo "  Run 'bcli auth' if this is a fresh install"
