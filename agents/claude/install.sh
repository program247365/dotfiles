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
      # Both exist as files — prompt user to resolve
      if diff -q "$source" "$target" > /dev/null 2>&1; then
        rm "$target"
        echo "  [adopt] $label (files identical)"
      else
        echo "  [conflict] $label"
        echo "    Local:    $target"
        echo "    Dotfiles: $source"
        diff --color=auto -u "$source" "$target" 2>/dev/null | head -30 || true
        echo ""
        printf "    Keep (d)otfiles, keep (l)ocal, open (m)erge tool, or (s)kip? "
        read -r choice
        case "$choice" in
          d|D)
            rm "$target"
            echo "  [adopt] $label (dotfiles version kept)"
            ;;
          l|L)
            mv "$target" "$source"
            echo "  [adopt] $label (local version adopted into dotfiles)"
            ;;
          m|M)
            # Merge local changes into dotfiles source, then link
            if command -v code > /dev/null 2>&1; then
              code --diff "$source" "$target" --wait
            elif command -v vimdiff > /dev/null 2>&1; then
              vimdiff "$source" "$target"
            else
              echo "    No merge tool found. Manually resolve, then re-run."
              return
            fi
            rm -f "$target"
            echo "  [adopt] $label (merged)"
            ;;
          *)
            echo "  [skip] $label"
            return
            ;;
        esac
      fi
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
  "$DOTFILES_CLAUDE/home/settings.json" \
  "$CLAUDE_DIR/settings.json" \
  "~/.claude/settings.json"

adopt_and_link \
  "$DOTFILES_CLAUDE/commands" \
  "$CLAUDE_DIR/commands" \
  "~/.claude/commands"

adopt_and_link \
  "$DOTFILES_CLAUDE/statusline.sh" \
  "$CLAUDE_DIR/statusline.sh" \
  "~/.claude/statusline.sh"

# Project-scoped: only available in the dotfiles repo
# Add project-only skills to agents/claude/project/skills/
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

# Global skills: available in all projects
# Add global skills to agents/claude/home/skills/
# On a new machine, adopt_and_link merges any locally-installed skills
# (e.g. from ~/.claude/skills/) into dotfiles, then the prompt below
# offers to commit them so they follow you across machines.
adopt_and_link \
  "$DOTFILES_CLAUDE/home/skills" \
  "$CLAUDE_DIR/skills" \
  "~/.claude/skills"

# Check for new skills not yet tracked in git
SKILLS_DIR="$DOTFILES_CLAUDE/home/skills"
NEW_SKILLS=$(git -C "$DOTFILES_ROOT" ls-files --others --exclude-standard "$SKILLS_DIR" 2>/dev/null)
if [ -n "$NEW_SKILLS" ]; then
  echo ""
  echo "  New skills found (not tracked in dotfiles):"
  git -C "$DOTFILES_ROOT" ls-files --others --exclude-standard "$SKILLS_DIR" \
    | sed 's|.*/skills/||' | cut -d/ -f1 | sort -u \
    | while read -r skill; do echo "    - $skill"; done
  printf "  Commit to dotfiles? (y/n) "
  read -r answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    git -C "$DOTFILES_ROOT" add "$SKILLS_DIR"
    git -C "$DOTFILES_ROOT" commit -m "feat(claude): track adopted skills from $(hostname -s)"
    echo "  [commit] new skills tracked"
  else
    echo "  [skip] skills left untracked"
  fi
fi

# Source shell.zsh in ~/.zshrc.local (idempotent)
SHELL_ZSH_SOURCE="source \"$DOTFILES_ROOT/agents/shell.zsh\""
if ! grep -qF "$SHELL_ZSH_SOURCE" "$HOME/.zshrc.local" 2>/dev/null; then
  echo "$SHELL_ZSH_SOURCE" >> "$HOME/.zshrc.local"
  echo "  Added shell.zsh source to ~/.zshrc.local"
else
  echo "  [ok] shell.zsh sourced in ~/.zshrc.local"
fi

echo 'Done setting up Claude Code'
