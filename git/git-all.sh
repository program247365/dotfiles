#!/bin/zsh

# git-all — run arbitrary git commands across a configured set of repos
# Config: ~/.config/git-all/config (one repo path per line)

CONFIG="$HOME/.config/git-all/config"

if [[ ! -f "$CONFIG" ]]; then
  echo "\033[31mNo config found at $CONFIG\033[0m"
  echo "Create it with one repo path per line. See:"
  echo "  ~/.dotfiles/git/git-all.config.example"
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "\033[31mUsage:\033[0m git-all <git command>"
  echo "  e.g. git-all status"
  echo "  e.g. git-all pull --rebase"
  exit 1
fi

while IFS= read -r line; do
  # skip comments and blank lines
  [[ -z "$line" || "$line" == \#* ]] && continue

  # expand ~ to $HOME
  dir="${line/#\~/$HOME}"

  if [[ ! -d "$dir/.git" ]]; then
    echo "\033[33m⚠ $(basename "$dir")\033[0m — not found at $dir, skipping"
    continue
  fi

  echo "\033[36m━━━ \033[1;35m$(basename "$dir")\033[0;36m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  git -C "$dir" "$@"
  if [[ $? -ne 0 ]]; then
    echo "\033[31m✗ failed\033[0m"
  fi
  echo
done < "$CONFIG"
