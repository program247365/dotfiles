#!/usr/bin/env bash

set -euo pipefail

echo "Setting up shared software engineering philosophy..."

DOTFILES_ROOT="${HOME}/.dotfiles"
PHILOSOPHY_SOURCE="${DOTFILES_ROOT}/agents/philosophy/SOFTWARE_ENGINEERING.md"
PHILOSOPHY_TARGET="${DOTFILES_ROOT}/SOFTWARE_ENGINEERING.md"

. "${DOTFILES_ROOT}/script/link.sh"

if [ ! -f "${PHILOSOPHY_SOURCE}" ]; then
  echo "  Missing source file: ${PHILOSOPHY_SOURCE}"
  exit 1
fi

link "${PHILOSOPHY_SOURCE}" "${PHILOSOPHY_TARGET}"

# Link into agent home directories based on agents that have installers.
for agent_dir in "${DOTFILES_ROOT}/agents"/*; do
  [ -d "${agent_dir}" ] || continue
  [ -f "${agent_dir}/install.sh" ] || continue
  agent_name="$(basename "${agent_dir}")"
  case "${agent_name}" in
    philosophy) continue ;;
  esac

  agent_home="${HOME}/.${agent_name}"
  mkdir -p "${agent_home}"
  link "${PHILOSOPHY_SOURCE}" "${agent_home}/SOFTWARE_ENGINEERING.md"
done

echo "Done setting up shared software engineering philosophy"
