#!/bin/sh
#
# bcli — Bear Notes CLI (better-bear-cli)
#
# Checks if upstream PRs with critical fixes are merged. If so, installs
# the upstream release binary. Otherwise, clones the fork and builds from
# source to get the fixes (vector clock preservation, CloudKit error
# parsing, deleted record decoding).
#
# Auth is interactive (bcli auth) — not run here.

set -e

BIN_DIR="$HOME/.kevin/bin"
BCLI="$BIN_DIR/bcli"
FORK_DIR="$HOME/.kevin/personal-code/better-bear-cli"
UPSTREAM_REPO="mreider/better-bear-cli"
FORK_REPO="program247365/better-bear-cli"

# PRs that must be merged upstream before we can use the release binary
REQUIRED_PRS="6 7 8"

mkdir -p "$BIN_DIR"

echo "Installing bcli..."

# Check if all required PRs are merged upstream
all_merged=true
for pr in $REQUIRED_PRS; do
  state=$(gh pr view "$pr" --repo "$UPSTREAM_REPO" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
  if [ "$state" != "MERGED" ]; then
    all_merged=false
    echo "  PR #$pr not yet merged upstream (state: $state)"
  fi
done

if [ "$all_merged" = true ]; then
  echo "  All fixes merged upstream — installing release binary"
  curl -sL "https://github.com/$UPSTREAM_REPO/releases/latest/download/bcli-macos-universal.tar.gz" \
    -o /tmp/bcli.tar.gz
  tar xzf /tmp/bcli.tar.gz -C /tmp
  mv /tmp/bcli "$BCLI"
  chmod +x "$BCLI"
  rm -f /tmp/bcli.tar.gz
else
  echo "  Fixes not yet upstream — building from fork"
  if [ -d "$FORK_DIR" ]; then
    cd "$FORK_DIR"
    git fetch origin
    git checkout main
    git pull origin main
  else
    git clone "git@github.com:$FORK_REPO.git" "$FORK_DIR"
    cd "$FORK_DIR"
  fi
  swift build -c release 2>&1 | tail -1
  cp .build/release/bcli "$BCLI"
  chmod +x "$BCLI"
  echo "  Built from fork at $FORK_DIR"
fi

# Clean up stale manual install if it exists
if [ -f "$HOME/.local/bin/bcli" ]; then
  rm -f "$HOME/.local/bin/bcli"
  echo "  Removed stale ~/.local/bin/bcli"
fi

echo "Installed bcli to $BCLI"
echo "  Run 'bcli auth' if this is a fresh install"
