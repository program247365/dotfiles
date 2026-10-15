#!/bin/sh
# Install mise via Homebrew
if ! command -v mise &>/dev/null; then
  echo "Installing mise..."
  brew install mise
fi

# Set global defaults
echo "Setting up mise globals..."
mise use --global node@24
mise use --global pnpm@latest
mise use --global python@3
