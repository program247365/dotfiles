#!/bin/sh
#
# Homebrew
#
# This installs some of the common dependencies needed (or at least desired)
# using Homebrew.

# Check for Homebrew
if test ! $(which brew)
then
  echo "  Installing Homebrew for you."

  # Install the correct homebrew for each OS type
  if test "$(uname)" = "Darwin"
  then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  elif test "$(expr substr $(uname -s) 1 5)" = "Linux"
  then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)"
  fi
fi

## Update paths
echo '# Set PATH, MANPATH, etc., for Homebrew.' >> "$HOME/.profile"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
eval "$(/opt/homebrew/bin/brew shellenv)"

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SKIP_FILE="${DOTFILES_BREW_SKIP:-$HOME/.config/dotfiles/brew-skip}"

# First interactive run on a machine: choose which entries to install.
if [ ! -e "$SKIP_FILE" ] && [ -t 0 ]
then
  "$DOTFILES_ROOT/homebrew/select-brews"
fi

echo " Installing brews for you!"
brew update
if [ -s "$SKIP_FILE" ]
then
  echo "  skipping $(wc -l < "$SKIP_FILE" | tr -d ' ') entries listed in $SKIP_FILE"
  grep -v -F -f "$SKIP_FILE" "$DOTFILES_ROOT/Brewfile" | brew bundle --file=-
else
  brew bundle --file="$DOTFILES_ROOT/Brewfile"
fi

exit 0
