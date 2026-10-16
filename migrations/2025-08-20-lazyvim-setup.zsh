#!/bin/zsh

# LazyVim Migration Script - 2025-08-20
# This script sets up LazyVim on a new machine and creates symlinks from this dotfiles repo

# Already linked: nothing to do. Without this, `[ -d ~/.config/nvim ]` is true
# for the symlink itself and every dot run would move config and plugins aside.
if [ -L ~/.config/nvim ] && [ "$(readlink ~/.config/nvim)" = "$HOME/.dotfiles/config" ]; then
    echo "✓ ~/.config/nvim already linked to ~/.dotfiles/config"
    exit 0
fi

echo "🚀 Starting LazyVim migration setup..."

# Make a backup of current Neovim files
echo "📦 Backing up existing Neovim configuration..."

# Required backup
if [ -d ~/.config/nvim ]; then
    echo "  Moving ~/.config/nvim to ~/.config/nvim.bak"
    mv ~/.config/nvim ~/.config/nvim.bak
else
    echo "  No existing ~/.config/nvim found"
fi

# Optional but recommended backups
if [ -d ~/.local/share/nvim ]; then
    echo "  Moving ~/.local/share/nvim to ~/.local/share/nvim.bak"
    mv ~/.local/share/nvim ~/.local/share/nvim.bak
fi

if [ -d ~/.local/state/nvim ]; then
    echo "  Moving ~/.local/state/nvim to ~/.local/state/nvim.bak"
    mv ~/.local/state/nvim ~/.local/state/nvim.bak
fi

if [ -d ~/.cache/nvim ]; then
    echo "  Moving ~/.cache/nvim to ~/.cache/nvim.bak"
    mv ~/.cache/nvim ~/.cache/nvim.bak
fi

# ~/.dotfiles/config is already a LazyVim config (from the starter), so link it
echo "🔗 Setting up symlink to dotfiles nvim config..."
mkdir -p ~/.config
ln -s ~/.dotfiles/config ~/.config/nvim

# Verify the symlink
echo "✅ Verifying symlink..."
if [ -L ~/.config/nvim ]; then
    echo "  Symlink created successfully:"
    ls -la ~/.config/nvim
    echo "  Target: $(readlink ~/.config/nvim)"
else
    echo "❌ Error: Symlink was not created properly"
    exit 1
fi

echo ""
echo "🎉 LazyVim setup complete!"
echo "📁 Your nvim config is now linked to: ~/.dotfiles/config"
echo "🚀 You can now run 'nvim' to start LazyVim"
echo ""
echo "Note: LazyVim will automatically install plugins on first launch."