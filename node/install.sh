#!/bin/sh

echo "Installing Volta..."

# install Volta
curl https://get.volta.sh | bash

echo "Installing the latest version of Node.js..."

# install Node
volta install node

echo 'Lets Install Yarn...'
volta install yarn@latest

source ~/.zshrc

## Common Global Node modules

echo "Installing global node modules..."

declare -a modules=(
    'awesome-lint'
    'clinic' # node trace tool
    'create-react-app',
    'create-next-app',
    'emoji-cli'
    'gatsby-cli'
    'generator-awesome-list'
    'licensed'
    'multi-git'
    'node-notifier-cli'
    'np'
    'npm-check'
    'speed-test'
    'terser'
    'tldr'
    'vsce'
    'yarn'
)

## now loop through the above array
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
