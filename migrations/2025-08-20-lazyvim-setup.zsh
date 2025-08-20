#!/bin/zsh

# LazyVim Migration Script - 2025-08-20
# This script sets up LazyVim on a new machine and creates symlinks from this dotfiles repo

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

# Clone the LazyVim starter
echo "📥 Cloning LazyVim starter..."
git clone https://github.com/LazyVim/starter ~/.config/nvim

# Remove the .git folder
echo "🗑️  Removing .git folder from starter..."
rm -rf ~/.config/nvim/.git

# Remove the starter directory and create symlink to our dotfiles config
echo "🔗 Setting up symlink to dotfiles nvim config..."
rm -rf ~/.config/nvim
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