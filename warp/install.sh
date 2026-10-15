#!/bin/sh

echo 'Installing Warp themes...'
repo_location="$HOME/.dotfiles"
warp_themes_dir="$HOME/.warp/themes"

mkdir -p "$warp_themes_dir"
for theme in "$repo_location"/warp/themes/*.yaml; do
  ln -sf "$theme" "$warp_themes_dir/$(basename "$theme")"
done
echo 'Done installing Warp themes'
