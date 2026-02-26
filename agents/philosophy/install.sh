#!/usr/bin/env bash

set -euo pipefail

echo "Setting up shared software engineering philosophy..."

DOTFILES_ROOT="${HOME}/.dotfiles"
PHILOSOPHY_SOURCE="${DOTFILES_ROOT}/agents/philosophy/SOFTWARE_ENGINEERING.md"
PHILOSOPHY_TARGET="${DOTFILES_ROOT}/SOFTWARE_ENGINEERING.md"

link_with_backup() {
  local source="$1"
  local target="$2"
  local label="$3"
  local current_target=""
  local backup=""

  if [ -L "${target}" ]; then
    current_target="$(readlink "${target}")"
    if [ "${current_target}" = "${source}" ]; then
      echo "  ${label} already linked"
      return
    fi
    rm "${target}"
  elif [ -e "${target}" ]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "${target}" "${backup}"
    echo "  Backed up existing ${label} to ${backup}"
  fi

  ln -s "${source}" "${target}"
  echo "  Linked ${label}"
}

if [ ! -f "${PHILOSOPHY_SOURCE}" ]; then
  echo "  Missing source file: ${PHILOSOPHY_SOURCE}"
  exit 1
fi

link_with_backup "${PHILOSOPHY_SOURCE}" "${PHILOSOPHY_TARGET}" "~/.dotfiles/SOFTWARE_ENGINEERING.md"

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
  link_with_backup \
    "${PHILOSOPHY_SOURCE}" \
    "${agent_home}/SOFTWARE_ENGINEERING.md" \
    "${agent_home}/SOFTWARE_ENGINEERING.md"
done

echo "Done setting up shared software engineering philosophy"
