#!/usr/bin/env bash

set -euo pipefail

echo 'Setting up Claude Code...'

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_CLAUDE="$DOTFILES_ROOT/agents/claude"
DOTFILES_PHILOSOPHY="$DOTFILES_ROOT/agents/philosophy/SOFTWARE_ENGINEERING.md"
CLAUDE_DIR="$HOME/.claude"

# Claude Code CLI — native installer. Self-updating after this, so only install
# when it's missing. ~/.local/bin is put on PATH by system/env.zsh.
if [ -x "$HOME/.local/bin/claude" ]; then
  echo "  [ok] Claude Code CLI ($("$HOME/.local/bin/claude" --version 2>/dev/null | head -1))"
else
  echo "  [install] Claude Code CLI (native installer)"
  curl -fsSL https://claude.ai/install.sh | bash
fi

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
      # A file that exists in both and differs is kept as <name>.local next
      # to the dotfiles copy (e.g. the tldraw installer replaces ~/.claude/agents
      # with a real dir holding a newer agent file), never silently dropped.
      local count=0
      local conflicts=0
      while IFS= read -r -d '' file; do
        local rel="${file#"$target"/}"
        if [ ! -e "$source/$rel" ]; then
          mkdir -p "$source/$(dirname "$rel")"
          mv "$file" "$source/$rel"
          count=$((count + 1))
        elif ! diff -q "$source/$rel" "$file" > /dev/null 2>&1; then
          mv "$file" "$source/$rel.local"
          echo "  [conflict] $label/$rel differs from dotfiles; local copy saved as $source/$rel.local"
          conflicts=$((conflicts + 1))
        fi
      done < <(find "$target" -not -type d -print0 2>/dev/null)
      if [ "$count" -gt 0 ]; then
        echo "  [adopt] $label (merged $count file(s) into dotfiles)"
      else
        echo "  [adopt] $label (no new files to merge)"
      fi
      if [ "$conflicts" -gt 0 ]; then
        echo "  [warn] $label was a real directory with $conflicts conflicting file(s); diff each *.local, then delete it"
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

# Project-scoped config: settings.local.json, hooks, etc. (only active in dotfiles repo)
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

# link_each: make dst_dir a real directory holding one symlink per entry of
# src_dir. Other installers (npx skills, tldraw, Spark, claude.ai sync) add
# their own entries to dst_dir, so they never write into this repo.
link_each() {
  local src_dir="$1" dst_dir="$2" label="$3" entry name
  if [ -L "$dst_dir" ]; then
    # Old layout: dst_dir was one link to src_dir. Entries git doesn't track
    # came from other installers; move them out so they survive the switch.
    rm "$dst_dir"
    mkdir -p "$dst_dir"
    for entry in "$src_dir"/*; do
      [ -e "$entry" ] || continue
      name="$(basename "$entry")"
      if [ -z "$(git -C "$DOTFILES_ROOT" ls-files -- "$entry")" ]; then
        mv "$entry" "$dst_dir/$name"
        echo "  [move] $label/$name is not tracked; kept in $dst_dir"
      fi
    done
  fi
  mkdir -p "$dst_dir"
  for entry in "$src_dir"/*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    adopt_and_link "$entry" "$dst_dir/$name" "$label/$name"
  done
}

link_each "$DOTFILES_CLAUDE/agents" "$CLAUDE_DIR/agents" "~/.claude/agents"

# Own skills: one link per directory in home/skills.
link_each "$DOTFILES_CLAUDE/home/skills" "$CLAUDE_DIR/skills" "~/.claude/skills"

# Third-party skills: skills.txt lists them. A skill installed for several
# agents lives in ~/.agents/skills and only needs a link; anything else missing
# is installed for Claude, which copies it into ~/.claude/skills.
# -e is false for a broken link, so a broken one gets repaired too.
SKILLS_MANIFEST="$DOTFILES_CLAUDE/skills.txt"
skills_failed=()
while read -r skill_source skill_name; do
  case "$skill_source" in ''|'#'*) continue ;; esac
  [ -e "$CLAUDE_DIR/skills/$skill_name" ] && continue
  if [ -d "$HOME/.agents/skills/$skill_name" ]; then
    ln -sfn "$HOME/.agents/skills/$skill_name" "$CLAUDE_DIR/skills/$skill_name"
    echo "  [link] ~/.claude/skills/$skill_name"
    continue
  fi
  if ! command -v npx > /dev/null 2>&1; then
    echo "  [skip] $skill_name (npx not found; re-run dot once node is installed)"
    continue
  fi
  echo "  [install] $skill_name from $skill_source"
  npx -y skills@1.7.6 add "$skill_source" -g -s "$skill_name" -a claude-code -y < /dev/null > /dev/null 2>&1 || true
  [ -e "$CLAUDE_DIR/skills/$skill_name" ] || skills_failed+=("$skill_name")
done < "$SKILLS_MANIFEST"

# Skills CLI installs that skills.txt doesn't list exist only on this machine.
SKILLS_LOCK="$HOME/.agents/.skill-lock.json"
if [ -f "$SKILLS_LOCK" ] && command -v python3 > /dev/null 2>&1; then
  python3 -c 'import json, sys; print("\n".join(json.load(open(sys.argv[1]))["skills"]))' "$SKILLS_LOCK" |
    while read -r name; do
      [ -e "$CLAUDE_DIR/skills/$name" ] || continue
      if ! awk -v n="$name" '$1 !~ /^#/ && $2 == n { found = 1 } END { exit !found }' "$SKILLS_MANIFEST"; then
        echo "  [note] $name is installed but not in agents/claude/skills.txt, so other machines won't get it"
      fi
    done
fi

# Source shell.zsh in ~/.zshrc.local (idempotent)
SHELL_ZSH_SOURCE="source \"$DOTFILES_ROOT/agents/shell.zsh\""
if ! grep -qF "$SHELL_ZSH_SOURCE" "$HOME/.zshrc.local" 2>/dev/null; then
  echo "$SHELL_ZSH_SOURCE" >> "$HOME/.zshrc.local"
  echo "  Added shell.zsh source to ~/.zshrc.local"
else
  echo "  [ok] shell.zsh sourced in ~/.zshrc.local"
fi

if [ ${#skills_failed[@]} -gt 0 ]; then
  echo "  [fail] could not install: ${skills_failed[*]} (network? re-run dot)"
  exit 1
fi

echo 'Done setting up Claude Code'
