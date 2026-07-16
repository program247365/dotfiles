#!/usr/bin/env bash
set -euo pipefail

REPO="git@github.com:program247365/keeper-cli.git"
DEST="$HOME/.kevin/code/keeper-cli"

if [ ! -d "$DEST/.git" ]; then
  mkdir -p "$(dirname "$DEST")"
  git clone "$REPO" "$DEST"
  echo "  Cloned keeper-cli → $DEST"
else
  echo "  keeper-cli already cloned"
fi

if command -v bun >/dev/null 2>&1; then
  (cd "$DEST" && bun link >/dev/null 2>&1)
  echo "  Linked kpr → ~/.bun/bin/kpr"
else
  echo "  bun not found — skipped kpr link (install bun, then re-run)"
fi
