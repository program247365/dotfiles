#!/bin/sh

source ~/.zshrc

## Common Global Golang packages

echo "Installing golang packages..."

declare -a packages=(
    'github.com/ericchiang/pup' #https://github.com/EricChiang/pup
)

## now loop through the above array
for i in "${packages[@]}"
do
    go get $i
done