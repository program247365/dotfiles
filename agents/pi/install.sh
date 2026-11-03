#!/usr/bin/env bash

set -euo pipefail

echo "Setting up Pi..."

DOTFILES_ROOT="${HOME}/.dotfiles"
DOTFILES_PI="${DOTFILES_ROOT}/agents/pi"
PI_DIR="${HOME}/.pi"
PI_AGENT_DIR="${PI_DIR}/agent"
KEVIN_BIN_DIR="${HOME}/.kevin/bin"
SHELL_ZSH_SOURCE="source \"$DOTFILES_ROOT/agents/shell.zsh\""

mkdir -p "${PI_AGENT_DIR}"
mkdir -p "${KEVIN_BIN_DIR}"

. "${DOTFILES_ROOT}/script/link.sh"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "  Error: pnpm not found. Run mise use --global pnpm@latest first." >&2
  exit 1
fi

# pnpm refuses global installs unless its global bin dir is on PATH. The
# zshrc does this for interactive shells; bootstrap is not one. With
# PNPM_HOME set the dir is $PNPM_HOME; unset, pnpm defaults to
# ~/Library/pnpm/bin, so put both on PATH.
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
mkdir -p "$PNPM_HOME/bin"
export PATH="$PNPM_HOME:$PNPM_HOME/bin:$PATH"

echo "  Installing Pi via pnpm..."
if pnpm ls -g --depth 0 2>/dev/null | grep -q "@mariozechner/pi-coding-agent"; then
  echo "  Removing deprecated @mariozechner/pi-coding-agent..."
  pnpm remove -g @mariozechner/pi-coding-agent
fi
pnpm add -g @earendil-works/pi-coding-agent

PNPM_BIN_DIR="$(pnpm bin -g)"
if [ ! -x "${PNPM_BIN_DIR}/pi" ]; then
  echo "  Error: pi binary not found in ${PNPM_BIN_DIR}" >&2
  exit 1
fi

link "${PNPM_BIN_DIR}/pi" "${KEVIN_BIN_DIR}/pi"

link "${DOTFILES_PI}/home/settings.json" "${PI_AGENT_DIR}/settings.json"
# Global instructions come from the shared-rules extension. Older installs
# linked ~/.pi/agent/AGENTS.md to a file that was never committed.
if [ -L "${PI_AGENT_DIR}/AGENTS.md" ] \
  && [ "$(readlink "${PI_AGENT_DIR}/AGENTS.md")" = "${DOTFILES_PI}/home/AGENTS.md" ]; then
  rm "${PI_AGENT_DIR}/AGENTS.md"
  echo "  Removed stale ~/.pi/agent/AGENTS.md link"
fi
link "${DOTFILES_PI}/home/presets.json" "${PI_AGENT_DIR}/presets.json"

if ! grep -qF "${SHELL_ZSH_SOURCE}" "${HOME}/.zshrc.local" 2>/dev/null; then
  echo "${SHELL_ZSH_SOURCE}" >> "${HOME}/.zshrc.local"
  echo "  Added shell.zsh source to ~/.zshrc.local"
else
  echo "  shell.zsh already sourced in ~/.zshrc.local"
fi

echo "Done setting up Pi"
