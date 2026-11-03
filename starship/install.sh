#!/bin/sh

echo 'Installing Starship config...'
. "$HOME/.dotfiles/script/link.sh"
link "$HOME/.dotfiles/starship/config/starship.toml" "$HOME/.config/starship.toml"
echo 'Done installing Starship config'