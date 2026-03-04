#!/bin/sh
#
# QMD — local hybrid search engine for notes, docs, and transcripts
#
# While PR #301 is pending on tobi/qmd, installs from the fork via
# git clone + npm install (the README's dev install path). Once upstream
# merges, switches to `npm install -g @tobilu/qmd` (prebuilt binaries).

set -e

UPSTREAM_PKG="@tobilu/qmd"
FORK_REPO="https://github.com/program247365/qmd.git"
FORK_DIR="$HOME/.kevin/tools/qmd"
BIN_DIR="$HOME/.kevin/bin"

echo "Setting up QMD..."

# --- Prerequisites ---

# Node >= 22 (README requirement)
NODE_VERSION=$(node --version 2>/dev/null | sed 's/^v//')
if [ -z "$NODE_VERSION" ]; then
  echo "  Error: node not found. Run: fnm install 22 && fnm default 22"
  exit 1
fi
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "  Error: node v$NODE_VERSION too old. QMD requires >= 22"
  echo "  Run: fnm install 22 && fnm default 22"
  exit 1
fi

# brew sqlite (needed for FTS5 / sqlite-vec extensions)
if ! brew list sqlite >/dev/null 2>&1; then
  echo "  Installing sqlite via brew..."
  brew install sqlite
fi

# --- Install ---

mkdir -p "$BIN_DIR"

# Check if upstream PR merged (src/sources/ directory exists on tobi/qmd main)
UPSTREAM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://api.github.com/repos/tobi/qmd/contents/src/sources" 2>/dev/null || echo "000")

if [ "$UPSTREAM_STATUS" = "200" ]; then
  # Upstream merged — use published npm package (has prebuilt binaries)
  echo "  Installing from npm ($UPSTREAM_PKG)..."
  npm install -g "$UPSTREAM_PKG"

  # Clean up fork clone if it exists
  if [ -d "$FORK_DIR" ]; then
    echo "  Removing fork clone (no longer needed)..."
    rm -rf "$FORK_DIR"
  fi

  QMD_EXEC="$(npm prefix -g)/bin/qmd"
else
  # Fork — clone + npm install (README dev install path)
  echo "  PR #301 not yet merged — installing from fork..."

  if [ -d "$FORK_DIR/.git" ]; then
    echo "  Updating existing clone..."
    cd "$FORK_DIR"
    git pull --ff-only
  else
    echo "  Cloning fork..."
    mkdir -p "$(dirname "$FORK_DIR")"
    git clone "$FORK_REPO" "$FORK_DIR"
    cd "$FORK_DIR"
  fi

  npm install

  QMD_EXEC="$FORK_DIR/dist/qmd.js"
  if [ ! -f "$QMD_EXEC" ]; then
    echo "  Building..."
    npm run build
  fi
  chmod +x "$QMD_EXEC"
fi

# Symlink to ~/.kevin/bin
if [ -f "$QMD_EXEC" ]; then
  ln -sf "$QMD_EXEC" "$BIN_DIR/qmd"
  echo "  Linked $BIN_DIR/qmd -> $QMD_EXEC"
else
  echo "  Error: qmd binary not found at $QMD_EXEC"
  exit 1
fi

echo "Done setting up QMD"
