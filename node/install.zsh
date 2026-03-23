#!/bin/sh
# Node.js setup — delegates to mise
# See also: mise/install.zsh for the mise binary itself

echo "Setting global Node.js version via mise..."
mise use --global node@24
echo "Node.js setup complete"
