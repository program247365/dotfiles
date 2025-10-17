#!/usr/bin/env zsh
#
# Setup Claude Code skills by symlinking from dotfiles
# This makes skills discoverable by Claude Code while keeping them in the dotfiles repo

set -e

echo "Setting up Claude Code skills..."

DOTFILES_DIR="${HOME}/.dotfiles"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
DOTFILES_SKILLS_DIR="${DOTFILES_DIR}/.claude/skills"

# Create the .claude/skills directory if it doesn't exist
if [ ! -d "${CLAUDE_SKILLS_DIR}" ]; then
  echo "Creating ${CLAUDE_SKILLS_DIR}..."
  mkdir -p "${CLAUDE_SKILLS_DIR}"
fi

# Symlink each skill from dotfiles to ~/.claude/skills/
for skill_dir in "${DOTFILES_SKILLS_DIR}"/*; do
  if [ -d "${skill_dir}" ]; then
    skill_name=$(basename "${skill_dir}")
    target_link="${CLAUDE_SKILLS_DIR}/${skill_name}"

    # Check if symlink already exists and points to the right place
    if [ -L "${target_link}" ]; then
      current_target=$(readlink "${target_link}")
      if [ "${current_target}" = "${skill_dir}" ]; then
        echo "✓ ${skill_name} already linked correctly"
        continue
      else
        echo "Removing old symlink for ${skill_name}..."
        rm "${target_link}"
      fi
    elif [ -e "${target_link}" ]; then
      echo "⚠️  ${target_link} already exists and is not a symlink. Skipping."
      echo "   Please remove it manually if you want to use the dotfiles version."
      continue
    fi

    # Create the symlink
    echo "Linking ${skill_name}..."
    ln -s "${skill_dir}" "${target_link}"
    echo "✓ ${skill_name} linked successfully"
  fi
done

echo ""
echo "✓ Claude Code skills setup complete!"
echo ""
echo "Available skills:"
ls -1 "${CLAUDE_SKILLS_DIR}" | sed 's/^/  - /'
echo ""
