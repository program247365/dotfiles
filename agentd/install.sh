#!/usr/bin/env bash
#
# agentd (github.com/program247365/agentd, from the Brewfile): archives every
# Claude Code / Codex / pi session and the agents' memory, redacts secrets,
# serves a local browser on 127.0.0.1:3850. `service install` (re)writes its
# two LaunchAgents with the stable /opt/homebrew/bin path, so re-running it
# on every `dot` is safe and also picks up a brew upgrade.
#
# Syncing between Macs is per-machine state, not dotfiles: run
# `agentd sync add <remote>` once on each Mac (see agentd's README).

set -euo pipefail

echo 'Setting up agentd...'

if ! command -v agentd >/dev/null 2>&1; then
  echo '  agentd not installed (brew bundle installs it); skipping'
  exit 0
fi

agentd service install
