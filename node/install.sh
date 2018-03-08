#!/bin/bash

echo "Installing NVM..."

curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.7/install.sh | bash

echo "Installing the latest version of Node.js..."

nvm install node

source ~/.bashrc

## Common Global Node modules

echo "Installing global node modules..."

declare -a modules=(
    '@alexlafroscia/tldr-alfred-workflow'
    'alfred-messages'
    'alfred-npms'
    'alfred-updater'
    'awesome-lint'
    'create-react-app'
    'ember-cli'
    'emoji-cli'
    'express-generator'
    'fkill-cli'
    'gatsby-cli'
    'generator-awesome-list'
    'generator-alfred'
    'generator-code'
    'git-standup' #required by tiny-care-terminal
    'graphcool'
    'hexo-cli'
    'how2'
    'hpm-cli'
    'http-console'
    'nativefier'
    'nodemon'
    'now'
    'npm-check'
    'polymer-cli'
    'soundscrape'
    'speed-test'
    'tiny-care-terminal'
    'tldr'
    'vsce'
    'vtop'
    'yo'
)

## now loop through the above array
for i in "${modules[@]}"
do
    if test ! $(which $i)
    then
        npm i -g $i
    else
        echo $i "already installed."
    fi
done