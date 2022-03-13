#!/bin/sh

echo 'Installing Starship config...'
mkdir -p "$HOME/.config"
repo_location="$HOME/.dotfiles"

starship_toml_repo="$repo_location/starship/config/starship.toml"
starship_toml_app="$HOME/.config/starship.toml"

ln -sf "$starship_toml_repo" "$starship_toml_app"
echo 'Done installing Starship config'