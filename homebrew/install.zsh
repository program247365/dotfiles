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
    # The installer ends with "Next steps" telling you to edit .zprofile by
    # hand; the lines below do that, so drop that block from its output.
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" 2>&1 \
      | sed '/^==> Next steps:/,$d'
  elif test "$(expr substr $(uname -s) 1 5)" = "Linux"
  then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)"
  fi
fi

## Update paths (once per machine)
if ! grep -qs 'brew shellenv' "$HOME/.zprofile"
then
  echo "  adding Homebrew to $HOME/.zprofile"
  echo '# Set PATH, MANPATH, etc., for Homebrew.' >> "$HOME/.zprofile"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SKIP_FILE="${DOTFILES_BREW_SKIP:-$HOME/.config/dotfiles/brew-skip}"

# Choose which entries to install: on the first interactive run on a machine,
# or whenever `dot --select-brews` asks for it.
if [ -t 0 ] && { [ -n "$DOTFILES_SELECT_BREWS" ] || [ ! -e "$SKIP_FILE" ]; }
then
  "$DOTFILES_ROOT/homebrew/select-brews"
fi

echo " Installing brews for you!"
brew update

# Homebrew 6 refuses formulae and casks from third-party taps until they are
# trusted, so trust every tap the Brewfile declares or references.
for tap in $(sed -nE "s/^tap '([^']+)'.*/\1/p; s/^(brew|cask) '([^'\/]+\/[^'\/]+)\/[^']+'.*/\2/p" "$DOTFILES_ROOT/Brewfile" | sort -u)
do
  brew trust --tap "$tap" >/dev/null 2>&1 || echo "  could not trust tap $tap"
done
if [ -s "$SKIP_FILE" ]
then
  echo "  skipping $(wc -l < "$SKIP_FILE" | tr -d ' ') entries listed in $SKIP_FILE"
  grep -v -F -f "$SKIP_FILE" "$DOTFILES_ROOT/Brewfile" | brew bundle --file=-
else
  brew bundle --file="$DOTFILES_ROOT/Brewfile"
fi

exit 0
