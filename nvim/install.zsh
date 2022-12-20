#!/bin/sh

echo 'Installing NeoVim...';
brew install neovim

echo 'Installing VimPlug...';
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'


echo 'Making folders may need...';
mkdir -p $HOME/.config;

echo 'Symlinking Config File from .dotfiles to root...'
ln -s $HOME/.dotfiles/nvim/coc-settings.json $HOME/.config/nvim/coc-settings.json
ln -s $HOME/.dotfiles/nvim/init.vim $HOME/.config/nvim/init.vim
ln -s $HOME/.dotfiles/nvim/lua/ $HOME/.config/nvim/lua
