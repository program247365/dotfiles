#!/bin/sh

echo 'Setting up Claude Code...'

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_CLAUDE="$DOTFILES_ROOT/agents/claude"
CLAUDE_DIR="$HOME/.claude"

# Create ~/.claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Symlink statusline script to ~/.claude/
ln -sf "$DOTFILES_CLAUDE/statusline.sh" "$CLAUDE_DIR/statusline.sh"
echo "  Linked statusline.sh to ~/.claude/statusline.sh"

# Symlink project-level .claude/ directory in the dotfiles repo
ln -sfn "$DOTFILES_CLAUDE/project" "$DOTFILES_ROOT/.claude"
echo "  Linked project config to .dotfiles/.claude"

# Source shell.zsh in ~/.zshrc.local (idempotent)
SHELL_ZSH_SOURCE="source \"$DOTFILES_CLAUDE/shell.zsh\""
if ! grep -qF "$SHELL_ZSH_SOURCE" "$HOME/.zshrc.local" 2>/dev/null; then
  echo "$SHELL_ZSH_SOURCE" >> "$HOME/.zshrc.local"
  echo "  Added shell.zsh source to ~/.zshrc.local"
else
  echo "  shell.zsh already sourced in ~/.zshrc.local (skipping)"
fi

# Merge statusLine config into ~/.claude/settings.json (idempotent)
SETTINGS_JSON="$CLAUDE_DIR/settings.json"
if command -v jq > /dev/null 2>&1; then
  if [ -f "$SETTINGS_JSON" ]; then
    if jq -e '.statusLine' "$SETTINGS_JSON" > /dev/null 2>&1; then
      echo "  statusLine already set in ~/.claude/settings.json (skipping)"
    else
      tmp=$(mktemp)
      jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' "$SETTINGS_JSON" > "$tmp" && mv "$tmp" "$SETTINGS_JSON"
      echo "  Added statusLine to ~/.claude/settings.json"
    fi
  else
    echo '{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' > "$SETTINGS_JSON"
    echo "  Created ~/.claude/settings.json with statusLine"
  fi
else
  echo "  Warning: jq not found, skipping statusLine config (install jq and re-run)"
fi

echo 'Done setting up Claude Code'
