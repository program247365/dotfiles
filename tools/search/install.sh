#!/bin/sh
#
# search — unified personal search across kpr bookmarks and Bear notes.
#
# Fuses kpr (bookmarks), qmd (semantic Bear index), and bearcli (live Bear
# DB) into one RRF-ranked list. Source lives at ~/.kevin/personal-code/search
# (github.com/program247365/search); compiled with bun into ~/.kevin/bin,
# which is on PATH. Rebuilds from the local checkout on every `dot` run so
# the binary tracks local main.

set -e

REPO_DIR="$HOME/.kevin/personal-code/search"
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

echo "Done setting up search ($("$BIN_DIR/search" --version))"
