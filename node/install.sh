#!/bin/sh

echo "Installing NVM..."

curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.7/install.sh | bash

echo "Installing the latest version of Node.js..."

nvm install node

echo 'Lets Update Yarn...'
brew upgrade yarn

source ~/.zshrc

## Common Global Node modules

echo "Installing global node modules..."

declare -a modules=(
    '@alexlafroscia/tldr-alfred-workflow'
    'alfred-messages'
    'alfred-npms'
    'alfred-updater'
    'awesome-lint'
    'clinic' # node trace tool
    'create-react-app',
    'create-next-app',
    'ember-cli'
    'emoji-cli'
    'express-generator'
    'fkill-cli'
    'gatsby-cli'
    'generator-alfred'
    'generator-awesome-list'
    'generator-code'
    'git-standup' #required by tiny-care-terminal
    'graphcool'
    'hexo-cli'
    'how2'
    'hpm-cli'
    'http-console'
    'hyper-search'
    'licensed'
    'multi-git'
    'nativefier'
    'node-notifier-cli'
    'nodemon'
    'now'
    'np'
    'npm-check'
    'polymer-cli'
    'soundscrape'
    'speed-test'
    'terser'
    'tiny-care-terminal'
    'tldr'
    'vsce'
    'vtop'
    'yarn'
    'yo'
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
