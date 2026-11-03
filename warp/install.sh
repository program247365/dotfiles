#!/usr/bin/env bash

set -euo pipefail

echo 'Setting up Warp...'

DOTFILES_WARP="$HOME/.dotfiles/warp"
WARP_HOME="$HOME/.warp"

# Only user-authored config is linked. ~/.warp/launch_configurations stays
# machine-local (it can name work projects; this repo is public).
. "$HOME/.dotfiles/script/link.sh"

# A fresh Warp writes default settings, and a Settings-panel save can replace a
# link with a plain file; link backs either up as *.pre-dotfiles.<time>.
for name in settings.toml themes tab_configs; do
  link "$DOTFILES_WARP/$name" "$WARP_HOME/$name"
done

echo 'Done setting up Warp'
