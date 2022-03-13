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
    'create-react-app'
    'create-next-app'
    'emma-cli'
    'licensed'
    'node-notifier-cli'
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
notify -t '.dotfiles Node Modules' -m 'All installed now!'
