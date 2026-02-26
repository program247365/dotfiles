#!/usr/bin/env bash

set -euo pipefail

echo 'Setting up Claude Code...'

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_CLAUDE="$DOTFILES_ROOT/agents/claude"
DOTFILES_PHILOSOPHY="$DOTFILES_ROOT/agents/philosophy/SOFTWARE_ENGINEERING.md"
CLAUDE_DIR="$HOME/.claude"

# adopt_and_link: move existing config into dotfiles, then symlink back.
#
# For files:
#   - target is already the correct symlink → skip
#   - target is a symlink to somewhere else → replace with correct symlink
#   - target is a real file, source doesn't exist → move target to source, symlink
#   - target is a real file, source exists → keep source (dotfiles wins), remove target, symlink
#   - target doesn't exist → just symlink
#
# For directories:
#   - same as above, but merges contents when both exist
#     (files in target that don't exist in source get moved over; conflicts keep dotfiles version)
adopt_and_link() {
  local source="$1"
  local target="$2"
  local label="$3"

  # Already correctly linked — nothing to do
  if [ -L "$target" ]; then
    local current_target
    current_target="$(readlink "$target")"
    if [ "$current_target" = "$source" ]; then
      echo "  [ok] $label"
      return
    fi
    echo "  [relink] $label (was -> $current_target)"
    rm "$target"
    ln -s "$source" "$target"
    return
  fi

  # Target exists as a real file or directory — adopt it
  if [ -e "$target" ]; then
    if [ -d "$target" ] && [ -d "$source" ]; then
      # Both are directories — merge contents (target fills gaps in source)
      local count=0
      while IFS= read -r -d '' file; do
        local rel="${file#"$target"/}"
        if [ ! -e "$source/$rel" ]; then
          mkdir -p "$source/$(dirname "$rel")"
          mv "$file" "$source/$rel"
          count=$((count + 1))
        fi
      done < <(find "$target" -not -type d -print0 2>/dev/null)
      if [ "$count" -gt 0 ]; then
        echo "  [adopt] $label (merged $count file(s) into dotfiles)"
      else
        echo "  [adopt] $label (no new files to merge)"
      fi
      rm -rf "$target"
    elif [ -d "$target" ] && [ ! -e "$source" ]; then
      # Target is a directory, source doesn't exist — move wholesale
      mv "$target" "$source"
      echo "  [adopt] $label (moved to dotfiles)"
    elif [ -f "$target" ] && [ ! -e "$source" ]; then
      # Target is a file, source doesn't exist — move it
      mkdir -p "$(dirname "$source")"
      mv "$target" "$source"
      echo "  [adopt] $label (moved to dotfiles)"
    elif [ -f "$target" ] && [ -e "$source" ]; then
      # Both exist as files — dotfiles wins, discard target
      rm "$target"
      echo "  [adopt] $label (dotfiles version kept)"
    else
      echo "  [skip] $label (unexpected state: target and source both exist but types differ)"
      return
    fi
  fi

  # Ensure parent directory exists
  mkdir -p "$(dirname "$target")"

  # Ensure source exists (create dir for directory links, warn for files)
  if [ ! -e "$source" ]; then
    # Check if this looks like it should be a directory (no extension)
    if [[ "$source" != *.* ]]; then
      mkdir -p "$source"
      echo "  [create] $label (created empty directory in dotfiles)"
    else
      echo "  [skip] $label (source $source does not exist)"
      return
    fi
  fi

  ln -s "$source" "$target"
  echo "  [link] $label"
}

mkdir -p "$CLAUDE_DIR"

adopt_and_link \
  "$DOTFILES_CLAUDE/home/CLAUDE.md" \
  "$CLAUDE_DIR/CLAUDE.md" \
  "~/.claude/CLAUDE.md"

adopt_and_link \
  "$DOTFILES_CLAUDE/commands" \
  "$CLAUDE_DIR/commands" \
  "~/.claude/commands"

adopt_and_link \
  "$DOTFILES_CLAUDE/statusline.sh" \
  "$CLAUDE_DIR/statusline.sh" \
  "~/.claude/statusline.sh"

adopt_and_link \
  "$DOTFILES_CLAUDE/project" \
  "$DOTFILES_ROOT/.claude" \
  "~/.dotfiles/.claude"

adopt_and_link \
  "$DOTFILES_PHILOSOPHY" \
  "$CLAUDE_DIR/SOFTWARE_ENGINEERING.md" \
  "~/.claude/SOFTWARE_ENGINEERING.md"

adopt_and_link \
  "$DOTFILES_PHILOSOPHY" \
  "$DOTFILES_ROOT/SOFTWARE_ENGINEERING.md" \
  "~/.dotfiles/SOFTWARE_ENGINEERING.md"

adopt_and_link \
  "$DOTFILES_CLAUDE/rules" \
  "$CLAUDE_DIR/rules" \
  "~/.claude/rules"

adopt_and_link \
  "$DOTFILES_CLAUDE/agents" \
  "$CLAUDE_DIR/agents" \
  "~/.claude/agents"

# Source shell.zsh in ~/.zshrc.local (idempotent)
SHELL_ZSH_SOURCE="source \"$DOTFILES_ROOT/agents/shell.zsh\""
if ! grep -qF "$SHELL_ZSH_SOURCE" "$HOME/.zshrc.local" 2>/dev/null; then
  echo "$SHELL_ZSH_SOURCE" >> "$HOME/.zshrc.local"
  echo "  Added shell.zsh source to ~/.zshrc.local"
else
  echo "  [ok] shell.zsh sourced in ~/.zshrc.local"
fi

# Merge statusLine config into ~/.claude/settings.json (idempotent)
SETTINGS_JSON="$CLAUDE_DIR/settings.json"
if command -v jq > /dev/null 2>&1; then
  if [ -f "$SETTINGS_JSON" ]; then
    if jq -e '.statusLine' "$SETTINGS_JSON" > /dev/null 2>&1; then
      echo "  [ok] statusLine in ~/.claude/settings.json"
    else
      tmp=$(mktemp)
      jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' "$SETTINGS_JSON" > "$tmp" && mv "$tmp" "$SETTINGS_JSON"
      echo "  [add] statusLine to ~/.claude/settings.json"
    fi
  else
    echo '{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' > "$SETTINGS_JSON"
    echo "  [create] ~/.claude/settings.json with statusLine"
  fi
else
  echo "  [warn] jq not found, skipping statusLine config (install jq and re-run)"
fi

echo 'Done setting up Claude Code'
