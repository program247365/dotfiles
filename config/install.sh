#!/bin/sh
#
# Neovim (LazyVim): link ~/.config/nvim to this directory. The first time, an
# old config's plugin, state and cache dirs are moved to *.bak, so lazy.nvim
# starts clean against this config.

set -e

. "$HOME/.dotfiles/script/link.sh"

source="$HOME/.dotfiles/config"
target="$HOME/.config/nvim"

if [ "$(readlink "$target")" != "$source" ]; then
  for dir in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    if [ -e "$dir" ]; then
      mv "$dir" "$dir.bak"
      echo "  moved $dir to $dir.bak"
    fi
  done
fi
link "$source" "$target"
