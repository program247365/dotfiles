#!/usr/bin/env bash

set -euo pipefail

echo 'Setting up Herdr...'

DOTFILES_HERDR="$HOME/.dotfiles/herdr"
SOURCE="$DOTFILES_HERDR/config.toml"
TARGET="$HOME/.config/herdr/config.toml"

# Only config.toml is symlinked — ~/.config/herdr also holds runtime state
# (sockets, logs, session.json) that must stay machine-local.
mkdir -p "$HOME/.config/herdr"

if [ -L "$TARGET" ]; then
  if [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
    echo "  [ok] config.toml"
  else
    echo "  [relink] config.toml (was -> $(readlink "$TARGET"))"
    ln -sf "$SOURCE" "$TARGET"
  fi
elif [ -f "$TARGET" ]; then
  if [ -f "$SOURCE" ]; then
    echo "  [adopt] config.toml exists locally and in dotfiles — keeping dotfiles version"
    mv "$TARGET" "$TARGET.pre-dotfiles"
  else
    echo "  [adopt] moving local config.toml into dotfiles"
    mv "$TARGET" "$SOURCE"
  fi
  ln -s "$SOURCE" "$TARGET"
else
  echo "  [link] config.toml"
  ln -s "$SOURCE" "$TARGET"
fi

# Agent integrations add native session restore; installs are idempotent.
# The claude SessionStart hook in agents/claude/home/settings.json expects
# ~/.claude/hooks/herdr-agent-state.sh, which this creates.
if command -v herdr >/dev/null 2>&1; then
  for agent in claude codex pi; do
    herdr integration install "$agent"
  done
  if herdr status server >/dev/null 2>&1; then
    herdr server reload-config
  fi
else
  echo "  [skip] herdr not installed yet (brew bundle installs it) — re-run for integrations"
fi

echo 'Done setting up Herdr'
