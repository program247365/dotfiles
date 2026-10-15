#!/usr/bin/env bash
set -euo pipefail

REPO="git@github.com:program247365/keeper-cli.git"
DEST="$HOME/.kevin/code/keeper-cli"

# Private repo: cloning needs an SSH key GitHub knows about.
github_ssh_ok() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 \
    | grep -q "successfully authenticated"
}

if [ -d "$DEST/.git" ]; then
  echo "  keeper-cli already cloned"
elif github_ssh_ok; then
  mkdir -p "$(dirname "$DEST")"
  git clone "$REPO" "$DEST"
  echo "  Cloned keeper-cli → $DEST"
else
  echo "  skipped keeper-cli: no SSH access to GitHub yet (add a key, then re-run dot)"
  exit 0
fi

if command -v bun >/dev/null 2>&1; then
  (cd "$DEST" && bun link >/dev/null 2>&1)
  echo "  Linked kpr → ~/.bun/bin/kpr"
else
  echo "  bun not found — skipped kpr link (install bun, then re-run)"
fi
