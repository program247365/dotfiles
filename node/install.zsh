#!/bin/sh
# Node.js setup — delegates to mise
# See also: mise/install.zsh for the mise binary itself

echo "Setting global Node.js version via mise..."
mise use --global node@24

echo "Installing global Node.js tools..."
# Claude Code is NOT installed here — it ships a native binary now and is
# installed by agents/claude/install.sh. See migrations/2026-09-04-*.
npm install -g dev-browser
if [ ! -d "$HOME/.dev-browser/node_modules" ]; then
  dev-browser install
fi

echo "Node.js setup complete"
