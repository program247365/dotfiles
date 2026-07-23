#!/bin/sh
#
# search — unified personal search across kpr bookmarks and Bear notes.
#
# Fuses kpr (bookmarks), qmd (semantic Bear index), and bearcli (live Bear
# DB) into one RRF-ranked list. Source (github.com/program247365/search)
# lives at ~/.kevin/personal-code/search on the work machine and
# ~/.kevin/code/search on the personal machine — whichever exists is used;
# fresh machines clone to ~/.kevin/code/search. Compiled with bun into
# ~/.kevin/bin, which is on PATH. Rebuilds from the local checkout on every
# `dot` run so the binary tracks local main.

set -e

REPO_DIR=""
for dir in "$HOME/.kevin/personal-code/search" "$HOME/.kevin/code/search"; do
  if [ -d "$dir" ]; then
    REPO_DIR="$dir"
    break
  fi
done
[ -n "$REPO_DIR" ] || REPO_DIR="$HOME/.kevin/code/search"
BIN_DIR="$HOME/.kevin/bin"

echo "Setting up search..."

if ! command -v bun >/dev/null 2>&1; then
  echo "  Error: bun not found. Run: brew install oven-sh/bun/bun"
  exit 1
fi

if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/program247365/search.git "$REPO_DIR"
fi

mkdir -p "$BIN_DIR"
(cd "$REPO_DIR" && bun build --compile search.ts --outfile "$BIN_DIR/search" >/dev/null)

# Config is committed in the search repo and shared across machines via
# symlink. A pre-existing regular file (local divergence) is left alone.
CONFIG_DIR="$HOME/.config/search"
mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_DIR/config.json" ] && [ ! -L "$CONFIG_DIR/config.json" ]; then
  echo "  Note: $CONFIG_DIR/config.json is a local file, not linking (repo copy: $REPO_DIR/config.json)"
else
  ln -sf "$REPO_DIR/config.json" "$CONFIG_DIR/config.json"
fi

echo "Done setting up search ($("$BIN_DIR/search" --version))"
