#!/usr/bin/env zsh
#
# Switch the dotfiles repo's project instructions to a committed AGENTS.md.
#
# Why: Claude Code 2.1.277+ reads AGENTS.md natively when a repo has no
# CLAUDE.md, so one file now serves Claude, Codex and pi. Before this,
# ~/.dotfiles/AGENTS.md was a gitignored symlink that agents/codex/install.sh
# pointed at agents/codex/project/AGENTS.md, a file that was never committed.
#
# End state: ~/.dotfiles/AGENTS.md is the tracked file, no root CLAUDE.md
# shadows it, claude is new enough to read it, and ~/.codex/AGENTS.md is
# generated (it was a dangling symlink too).
# Idempotent: safe to re-run.

set -e

DOTFILES_ROOT="$HOME/.dotfiles"
AGENTS_MD="$DOTFILES_ROOT/AGENTS.md"
MIN_CLAUDE_VERSION=2.1.277

# 1. Replace the old codex project symlink with the tracked file
if [[ -L "$AGENTS_MD" ]]; then
  echo "Removing old AGENTS.md symlink (-> $(readlink "$AGENTS_MD"))..."
  rm "$AGENTS_MD"
fi
if [[ ! -f "$AGENTS_MD" ]]; then
  git -C "$DOTFILES_ROOT" checkout -- AGENTS.md
  echo "Restored AGENTS.md from git"
fi
echo "✓ AGENTS.md is the tracked file"

# 2. Any of these makes Claude Code read them instead of AGENTS.md. They may
#    hold local notes, so warn rather than delete.
for shadow in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md; do
  if [[ -e "$DOTFILES_ROOT/$shadow" ]]; then
    echo "⚠ ~/.dotfiles/$shadow exists, so Claude Code skips AGENTS.md here."
    echo "  Move its contents into AGENTS.md and delete it."
  fi
done

# 3. Codex: ~/.codex/AGENTS.md was a symlink to a file that was never
#    committed. Replace it with the generated global instructions.
if [[ -d "$HOME/.codex" ]] || command -v codex >/dev/null 2>&1; then
  bash "$DOTFILES_ROOT/agents/codex/generate-agents-md.sh"
  echo "✓ ~/.codex/AGENTS.md generated"
else
  echo "⊘ Codex not installed; agents/codex/install.sh generates ~/.codex/AGENTS.md"
fi

# 4. Claude Code must be new enough to read AGENTS.md directly
if ! command -v claude >/dev/null 2>&1; then
  echo "⊘ claude not installed; agents/claude/install.sh installs the current version"
  exit 0
fi

autoload -Uz is-at-least
current=$(claude --version 2>/dev/null | awk '{print $1}')
if is-at-least "$MIN_CLAUDE_VERSION" "$current"; then
  echo "✓ Claude Code $current reads AGENTS.md"
else
  echo "Claude Code $current predates AGENTS.md support ($MIN_CLAUDE_VERSION); updating..."
  claude update || echo "⚠ claude update failed; run it by hand"
fi
