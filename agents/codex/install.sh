#!/usr/bin/env bash

set -euo pipefail

echo "Setting up Codex..."

DOTFILES_ROOT="${HOME}/.dotfiles"
DOTFILES_CODEX="${DOTFILES_ROOT}/agents/codex"
DOTFILES_PHILOSOPHY="${DOTFILES_ROOT}/agents/philosophy/SOFTWARE_ENGINEERING.md"
CODEX_DIR="${HOME}/.codex"
CODEX_SKILLS_DIR="${CODEX_DIR}/skills"
DOTFILES_SKILLS_DIR="${DOTFILES_CODEX}/skills"

mkdir -p "${CODEX_DIR}"
mkdir -p "${CODEX_SKILLS_DIR}"

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

link_with_backup "${DOTFILES_CODEX}/home/AGENTS.md" "${CODEX_DIR}/AGENTS.md" "~/.codex/AGENTS.md"
link_with_backup "${DOTFILES_CODEX}/project/AGENTS.md" "${DOTFILES_ROOT}/AGENTS.md" "~/.dotfiles/AGENTS.md"
link_with_backup "${DOTFILES_PHILOSOPHY}" "${CODEX_DIR}/SOFTWARE_ENGINEERING.md" "~/.codex/SOFTWARE_ENGINEERING.md"
link_with_backup "${DOTFILES_PHILOSOPHY}" "${DOTFILES_ROOT}/SOFTWARE_ENGINEERING.md" "~/.dotfiles/SOFTWARE_ENGINEERING.md"

if [ -d "${DOTFILES_SKILLS_DIR}" ]; then
  found_skill=0
  for skill_dir in "${DOTFILES_SKILLS_DIR}"/*; do
    [ -d "${skill_dir}" ] || continue
    found_skill=1
    skill_name="$(basename "${skill_dir}")"
    case "${skill_name}" in
      .*) continue ;;
    esac
    link_with_backup "${skill_dir}" "${CODEX_SKILLS_DIR}/${skill_name}" "~/.codex/skills/${skill_name}"
  done

  if [ "${found_skill}" -eq 0 ]; then
    echo "  No local Codex skills found in ${DOTFILES_SKILLS_DIR}"
  fi
fi

echo "Done setting up Codex"
