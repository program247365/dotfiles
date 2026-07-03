#!/bin/sh
#
# QMD — local hybrid search engine for notes, docs, and transcripts
#
# Installs upstream @tobilu/qmd from npm (no fork — PR #301 was closed).
# Bear notes are mirrored into ~/.local/share/qmd-bear by bear-sync.ts
# (incremental, via bearcli) and indexed as a plain filesystem collection.
# The collection's update command runs the sync, so `qmd update` always
# pulls fresh notes first.

set -e

UPSTREAM_PKG="@tobilu/qmd"
OLD_FORK_DIR="$HOME/.kevin/tools/qmd"
BIN_DIR="$HOME/.kevin/bin"
MIRROR_DIR="$HOME/.local/share/qmd-bear"
SYNC_SCRIPT="$HOME/.dotfiles/tools/qmd/bear-sync.ts"

echo "Setting up QMD..."

# --- Prerequisites ---

# Node >= 22 (README requirement)
NODE_VERSION=$(node --version 2>/dev/null | sed 's/^v//')
if [ -z "$NODE_VERSION" ]; then
  echo "  Error: node not found. Run: mise install node@22 && mise use node@22"
  exit 1
fi
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "  Error: node v$NODE_VERSION too old. QMD requires >= 22"
  echo "  Run: mise install node@22 && mise use node@22"
  exit 1
fi

# bun runs bear-sync.ts
if ! command -v bun >/dev/null 2>&1; then
  echo "  Error: bun not found. Run: brew install oven-sh/bun/bun"
  exit 1
fi

# bearcli reads Bear notes (ships with Bear 2.8+)
if ! command -v bearcli >/dev/null 2>&1; then
  echo "  Error: bearcli not found. Run: ~/.dotfiles/tools/bearcli/install.sh"
  exit 1
fi

# brew sqlite (needed for FTS5 / sqlite-vec extensions)
if ! brew list sqlite >/dev/null 2>&1; then
  echo "  Installing sqlite via brew..."
  brew install sqlite
fi

# --- Install ---

echo "  Installing from npm ($UPSTREAM_PKG)..."
npm install -g "$UPSTREAM_PKG"

if [ -d "$OLD_FORK_DIR" ]; then
  echo "  Removing old fork clone (replaced by upstream npm package)..."
  rm -rf "$OLD_FORK_DIR"
fi

mkdir -p "$BIN_DIR"
ln -sf "$(npm prefix -g)/bin/qmd" "$BIN_DIR/qmd"
echo "  Linked $BIN_DIR/qmd -> $(npm prefix -g)/bin/qmd"

# --- Bear mirror + collection ---

echo "Syncing Bear notes to $MIRROR_DIR..."
bun "$SYNC_SCRIPT"

# Old fork installs registered a `type: bear` collection with no path;
# stock qmd can't use it. Re-register against the mirror directory.
qmd collection remove bear >/dev/null 2>&1 || true
qmd collection add "$MIRROR_DIR" --name bear --mask '**/*.md'
qmd collection update-cmd bear "bun $SYNC_SCRIPT"

echo "Indexing Bear notes..."
qmd update

echo "Generating embeddings..."
qmd embed

echo "Done setting up QMD"
