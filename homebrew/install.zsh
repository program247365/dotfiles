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
echo '# Set PATH, MANPATH, etc., for Homebrew.' >> $HOME + "/.profile"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME + "/.zprofile"
eval "$(/opt/homebrew/bin/brew shellenv)"

echo " Installing brews for you!"
brew update
brew bundle

exit 0
