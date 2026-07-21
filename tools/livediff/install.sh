#!/bin/sh
#
# Livediff — real-time diff TUI (github.com/SoCkEt7/Livediff)
#
# Watches files and renders their diffs live as they change — a running
# companion to `git diff` while agents, formatters, or migrations rewrite
# code. No Homebrew formula exists (upstream issue #5 tracks packaging),
# so it installs from crates.io into ~/.cargo/bin, which is on PATH via
# ~/.zshenv sourcing ~/.cargo/env.
#
# `cargo install` is the updater too: it no-ops when the installed
# version matches the latest release and rebuilds when a newer one is
# published, so every `dot` run keeps it current.

set -e

echo "Setting up Livediff..."

if ! command -v cargo >/dev/null 2>&1; then
  echo "  Error: cargo not found. Run: brew install rustup && rustup-init"
  exit 1
fi

cargo install livediff

echo "Done setting up Livediff ($(livediff --version))"
