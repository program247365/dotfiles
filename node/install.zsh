#!/bin/sh

echo "Installing Volta..."

# install Volta
curl https://get.volta.sh | bash

echo "Installing the latest version of Node.js..."

# install Node
volta install node

echo 'Lets Install Yarn...'
volta install yarn@latest

## Common Global Node modules

echo "Installing global node modules..."
declare -a PKGS
PKGS=(
    'clinic' # node trace tool
    'create-next-app'
    'emma-cli'
    'licensed'
    'np'
    'npm-check'
    'vsce'
)
declare -r PKGS

for i in "${modules[@]}"
do
    if test ! "$(command -v "$i")"
    then
        yarn global add "$i"
    else
        echo "$i" "already installed."
        echo "Updating..." "$i"
        yarn global upgrade "$i"
    fi
done

# Note: macOS specific thing...
osascript -e 'display notification "All installed now!" with title ".dotfiles Node Modules"'
