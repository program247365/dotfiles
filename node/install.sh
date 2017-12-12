#!/bin/bash
## Common Global Node modules

echo "Installing global node modules..."

declare -a modules=(
    'awesome-lint',
    'create-react-app',
    'ember-cli',
    'emoji-cli',
    'express-generator',
    'fkill-cli',
    'gatsby-cli',
    'generator-awesome-list',
    'graphcool',
    'hexo-cli',
    'how2'
    'hpm-cli',
    'http-console',
    'nativefier',
    'node-inspector',
    'nodemon',
    'now',
    'npm-check',
    'soundscrape',
    'speed-test',
    'tiny-care-terminal',
    'tldr'
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