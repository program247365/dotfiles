#!/usr/bin/env bash

set -euo pipefail

echo 'Setting up Claude Code...'

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_CLAUDE="$DOTFILES_ROOT/agents/claude"
DOTFILES_PHILOSOPHY="$DOTFILES_ROOT/agents/philosophy/SOFTWARE_ENGINEERING.md"
CLAUDE_DIR="$HOME/.claude"

link_with_backup() {
  local source="$1"
  local target="$2"
  local label="$3"
  local current_target=""
  local backup=""

  if [ -L "$target" ]; then
    current_target="$(readlink "$target")"
    if [ "$current_target" = "$source" ]; then
      echo "  $label already linked"
      return
    fi
    rm "$target"
  elif [ -e "$target" ]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    echo "  Backed up existing $label to $backup"
  fi

  ln -s "$source" "$target"
  echo "  Linked $label"
}

mkdir -p "$CLAUDE_DIR"

link_with_backup \
  "$DOTFILES_CLAUDE/home/CLAUDE.md" \
  "$CLAUDE_DIR/CLAUDE.md" \
  "~/.claude/CLAUDE.md"

link_with_backup \
  "$DOTFILES_CLAUDE/commands" \
  "$CLAUDE_DIR/commands" \
  "~/.claude/commands"

link_with_backup \
  "$DOTFILES_CLAUDE/statusline.sh" \
  "$CLAUDE_DIR/statusline.sh" \
  "~/.claude/statusline.sh"

link_with_backup \
  "$DOTFILES_CLAUDE/project" \
  "$DOTFILES_ROOT/.claude" \
  "~/.dotfiles/.claude"

link_with_backup \
  "$DOTFILES_PHILOSOPHY" \
  "$CLAUDE_DIR/SOFTWARE_ENGINEERING.md" \
  "~/.claude/SOFTWARE_ENGINEERING.md"

link_with_backup \
  "$DOTFILES_PHILOSOPHY" \
  "$DOTFILES_ROOT/SOFTWARE_ENGINEERING.md" \
  "~/.dotfiles/SOFTWARE_ENGINEERING.md"

link_with_backup \
  "$DOTFILES_CLAUDE/rules" \
  "$CLAUDE_DIR/rules" \
  "~/.claude/rules"

link_with_backup \
  "$DOTFILES_CLAUDE/agents" \
  "$CLAUDE_DIR/agents" \
  "~/.claude/agents"

# Source shell.zsh in ~/.zshrc.local (idempotent)
SHELL_ZSH_SOURCE="source \"$DOTFILES_ROOT/agents/shell.zsh\""
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
