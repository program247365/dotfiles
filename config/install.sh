#!/bin/sh
#
# Neovim (LazyVim): link ~/.config/nvim to this directory.
# An existing config and its plugin/state/cache dirs are moved to *.bak first,
# so lazy.nvim starts clean against this config.

set -e

target="$HOME/.config/nvim"
source="$HOME/.dotfiles/config"

if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
  echo "  [ok] $target"
  exit 0
fi

for dir in "$target" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
  if [ -e "$dir" ] || [ -L "$dir" ]; then
    mv "$dir" "$dir.bak"
    echo "  moved $dir to $dir.bak"
  fi
done

mkdir -p "$HOME/.config"
ln -s "$source" "$target"
echo "  linked $target -> $source (plugins install on first nvim launch)"
