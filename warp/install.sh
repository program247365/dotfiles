#!/usr/bin/env bash

set -euo pipefail

echo 'Setting up Warp...'

DOTFILES_WARP="$HOME/.dotfiles/warp"
WARP_HOME="$HOME/.warp"

# Only user-authored config is linked. ~/.warp/launch_configurations stays
# machine-local (it can name work projects; this repo is public).
mkdir -p "$WARP_HOME"

link() {
  local name="$1"
  local source="$DOTFILES_WARP/$name"
  local target="$WARP_HOME/$name"

  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" = "$source" ]; then
      echo "  [ok] $name"
    else
      echo "  [relink] $name (was -> $(readlink "$target"))"
      ln -sfn "$source" "$target"
    fi
  elif [ -e "$target" ]; then
    if [ ! -e "$source" ]; then
      echo "  [adopt] moving local $name into dotfiles"
      mv "$target" "$source"
    elif diff -rq "$target" "$source" >/dev/null; then
      echo "  [link] $name (local copy matched dotfiles)"
      rm -rf "$target"
    else
      # A fresh Warp writes default settings, and a Settings-panel save may
      # replace the symlink with a plain file. Keep the local copy to diff.
      local backup
      backup="$target.pre-dotfiles.$(date +%Y%m%d%H%M%S)"
      echo "  [backup] local $name differs — saved to $backup, using dotfiles version"
      echo "           review: diff -r $backup $source"
      mv "$target" "$backup"
    fi
    ln -s "$source" "$target"
  else
    echo "  [link] $name"
    ln -s "$source" "$target"
  fi
}

link settings.toml
link themes
link tab_configs

echo 'Done setting up Warp'
