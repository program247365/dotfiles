#!/usr/bin/env bash

set -euo pipefail

echo 'Setting up Claude Code...'

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_CLAUDE="$DOTFILES_ROOT/agents/claude"
CLAUDE_DIR="$HOME/.claude"

# Claude Code CLI — native installer. Self-updating after this, so only install
# when it's missing. ~/.local/bin is put on PATH by system/env.zsh.
if [ -x "$HOME/.local/bin/claude" ]; then
  echo "  [ok] Claude Code CLI ($("$HOME/.local/bin/claude" --version 2>/dev/null | head -1))"
else
  echo "  [install] Claude Code CLI (native installer)"
  curl -fsSL https://claude.ai/install.sh | bash
fi

. "$DOTFILES_ROOT/script/link.sh"

# SOFTWARE_ENGINEERING.md is linked by agents/philosophy/install.sh.
link "$DOTFILES_CLAUDE/home/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
link "$DOTFILES_CLAUDE/home/settings.json" "$CLAUDE_DIR/settings.json"
link "$DOTFILES_CLAUDE/statusline.sh" "$CLAUDE_DIR/statusline.sh"
link "$DOTFILES_CLAUDE/rules" "$CLAUDE_DIR/rules"
# Project-scoped config (settings.local.json, hooks), active only in this repo.
link "$DOTFILES_CLAUDE/project" "$DOTFILES_ROOT/.claude"

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
    link "$entry" "$dst_dir/$name"
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
    link "$HOME/.agents/skills/$skill_name" "$CLAUDE_DIR/skills/$skill_name"
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

# Compare what's installed (the skills CLI's lock) with skills.txt: a skill
# missing from the list exists only on this machine, and one installed at a
# different commit than its pin needs a reinstall. Older installs recorded no
# commit, so they can't be checked.
SKILLS_LOCK="$HOME/.agents/.skill-lock.json"
if [ -f "$SKILLS_LOCK" ] && command -v python3 > /dev/null 2>&1; then
  python3 -c '
import json, sys
for name, entry in json.load(open(sys.argv[1]))["skills"].items():
    print(name, entry.get("ref") or "-")
' "$SKILLS_LOCK" |
    while read -r name installed_ref; do
      [ -e "$CLAUDE_DIR/skills/$name" ] || continue
      pinned_source="$(awk -v n="$name" '$1 !~ /^#/ && $2 == n { print $1 }' "$SKILLS_MANIFEST")"
      if [ -z "$pinned_source" ]; then
        echo "  [note] $name is installed but not in agents/claude/skills.txt, so other machines won't get it"
      elif [ "$installed_ref" != "-" ] && [ "$installed_ref" != "${pinned_source#*#}" ]; then
        echo "  [note] $name is installed at ${installed_ref:0:7}, pinned at $(echo "${pinned_source#*#}" | cut -c1-7); delete ~/.claude/skills/$name, then run dot"
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
