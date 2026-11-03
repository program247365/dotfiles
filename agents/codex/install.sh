#!/usr/bin/env bash

set -euo pipefail

echo "Setting up Codex..."

DOTFILES_ROOT="${HOME}/.dotfiles"
DOTFILES_CODEX="${DOTFILES_ROOT}/agents/codex"
CODEX_DIR="${HOME}/.codex"
CODEX_SKILLS_DIR="${CODEX_DIR}/skills"
DOTFILES_SKILLS_DIR="${DOTFILES_CODEX}/skills"

mkdir -p "${CODEX_DIR}"
mkdir -p "${CODEX_SKILLS_DIR}"

. "${DOTFILES_ROOT}/script/link.sh"

bash "${DOTFILES_CODEX}/generate-agents-md.sh"

if [ -d "${DOTFILES_SKILLS_DIR}" ]; then
  found_skill=0
  for skill_dir in "${DOTFILES_SKILLS_DIR}"/*; do
    [ -d "${skill_dir}" ] || continue
    found_skill=1
    skill_name="$(basename "${skill_dir}")"
    case "${skill_name}" in
      .*) continue ;;
    esac
    link "${skill_dir}" "${CODEX_SKILLS_DIR}/${skill_name}"
  done

  if [ "${found_skill}" -eq 0 ]; then
    echo "  No local Codex skills found in ${DOTFILES_SKILLS_DIR}"
  fi
fi

echo "Done setting up Codex"
