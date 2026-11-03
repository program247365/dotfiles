#!/bin/sh

echo 'Setting up git-all...'

DOTFILES_GIT="$HOME/.dotfiles/git"
CONFIG_DIR="$HOME/.config/git-all"

. "$HOME/.dotfiles/script/link.sh"

# Symlink the local config if it exists
if [ -f "$DOTFILES_GIT/git-all.config.local" ]; then
  link "$DOTFILES_GIT/git-all.config.local" "$CONFIG_DIR/config"
else
  echo "  No git-all.config.local found — copy git-all.config.example to git-all.config.local and edit it"
fi

# The script goes on PATH
link "$DOTFILES_GIT/git-all.sh" "$HOME/.kevin/bin/git-all"

echo 'Done setting up git-all'
