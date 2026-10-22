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
  # The Brewfile no longer uses start_service: Homebrew 6's bundle marked the
  # whole herdr entry failed when the service start errored. Start it here.
  # `status server` exits 0 even when stopped; only --json says which.
  if herdr status server --json | grep -q '"running":true'; then
    # A server from an older build can't take a reload; restarting it exits
    # every herdr pane, so that stays a manual step outside dot.
    reload_output=$(herdr server reload-config 2>&1) || {
      case "$reload_output" in
        *protocol_mismatch*)
          echo "  [note] herdr server is an older build than the CLI; from a plain shell run \`herdr server stop\`, then \`herdr\` (stopping exits herdr panes)"
          ;;
        *)
          echo "$reload_output"
          exit 1
          ;;
      esac
    }
  else
    # The formula ships no service and herdr has no `server start`; the
    # server comes up the first time `herdr` launches.
    echo "  [note] herdr server not running; it starts the first time you run \`herdr\`"
  fi
else
  echo "  [skip] herdr not installed yet (brew bundle installs it) — re-run for integrations"
fi

echo 'Done setting up Herdr'
