#!/bin/sh

echo 'Setting up git-all...'

DOTFILES_GIT="$HOME/.dotfiles/git"
CONFIG_DIR="$HOME/.config/git-all"

# Create config directory
mkdir -p "$CONFIG_DIR"

# Symlink the local config if it exists
if [ -f "$DOTFILES_GIT/git-all.config.local" ]; then
  ln -sf "$DOTFILES_GIT/git-all.config.local" "$CONFIG_DIR/config"
  echo "  Linked git-all config"
else
  echo "  No git-all.config.local found — copy git-all.config.example to git-all.config.local and edit it"
fi

# Symlink the script onto PATH
mkdir -p "$HOME/.kevin/bin"
ln -sf "$DOTFILES_GIT/git-all.sh" "$HOME/.kevin/bin/git-all"
echo "  Linked git-all to ~/.kevin/bin/git-all"

echo 'Done setting up git-all'
