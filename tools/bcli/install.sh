#!/bin/sh
#
# bcli — Bear Notes CLI (better-bear-cli)
#
# Clones/updates upstream repo and builds from the latest tagged release.
# Auth is interactive (bcli auth) — not run here.

set -e

BIN_DIR="$HOME/.kevin/bin"
BCLI="$BIN_DIR/bcli"
SRC_DIR="$HOME/.kevin/src/better-bear-cli"
UPSTREAM_REPO="mreider/better-bear-cli"

mkdir -p "$BIN_DIR"

echo "Installing bcli..."

if [ -d "$SRC_DIR" ]; then
  cd "$SRC_DIR"
  git fetch --tags origin
else
  git clone "https://github.com/$UPSTREAM_REPO.git" "$SRC_DIR"
  cd "$SRC_DIR"
fi

LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)")
echo "  Building $LATEST_TAG..."
git checkout "$LATEST_TAG"

swift build -c release 2>&1 | tail -1
cp .build/release/bcli "$BCLI"
chmod +x "$BCLI"

# Clean up stale manual install if it exists
if [ -f "$HOME/.local/bin/bcli" ]; then
  rm -f "$HOME/.local/bin/bcli"
  echo "  Removed stale ~/.local/bin/bcli"
fi

echo "Installed bcli to $BCLI"
echo "  Run 'bcli auth' if this is a fresh install"
