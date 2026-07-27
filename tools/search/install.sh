#!/bin/sh
#
# search — unified personal search across kpr bookmarks, Bear notes, Spark
# email, and browser history.
#
# Fuses kpr (bookmarks), qmd (semantic Bear index), bearcli (live Bear DB),
# spark (email keyword search), and bh (Safari/Chrome/Firefox history) into
# one RRF-ranked list. Source (github.com/program247365/search) lives at
# ~/.kevin/personal-code/search on the work machine and
# ~/.kevin/code/search on the personal machine — whichever exists is used;
# fresh machines clone to ~/.kevin/code/search. Compiled with bun into
# ~/.kevin/bin, which is on PATH. Rebuilds from the local checkout on every
# `dot` run so the binary tracks local main.
#
# Also clones/builds bh (github.com/program247365/bh, Rust) so the
# browser-history source works out of the box; skipped with a note when
# cargo is missing. spark is installed by Spark Desktop.app itself.

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

# bh — the browser-history source, same two-location repo convention.
BH_DIR=""
for dir in "$HOME/.kevin/personal-code/bh" "$HOME/.kevin/code/bh"; do
  if [ -d "$dir" ]; then
    BH_DIR="$dir"
    break
  fi
done
[ -n "$BH_DIR" ] || BH_DIR="$HOME/.kevin/code/bh"

if command -v cargo >/dev/null 2>&1; then
  if [ ! -d "$BH_DIR" ]; then
    git clone https://github.com/program247365/bh.git "$BH_DIR"
  fi
  (cd "$BH_DIR" && cargo build --release --quiet && cp target/release/bh "$BIN_DIR/bh")
  echo "  bh $("$BIN_DIR/bh" --version | cut -d' ' -f2) (browser-history source)"
else
  echo "  Note: cargo not found — skipping bh, the browser-history source. Run: brew install rust"
fi

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
