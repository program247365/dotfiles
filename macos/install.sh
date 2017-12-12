# The Brewfile handles Homebrew-based app and library installs, but there may
# still be updates and installables in the Mac App Store. There's a nifty
# command line interface to it that we can use to just install everything, so
# yeah, let's do that.

echo "› sudo softwareupdate -i -a"
sudo softwareupdate -i -a

echo "Installing Apple App Store apps..."

declare -a modules=(
    '1091189122' # Bear Writer
    '878995413'  # OutlineEdit
    '1278508951' # Trello
)

if test $(which mas)
then
    for i in "${modules[@]}"
    do
        mas install $i
    done
else
    echo $i "You need to 'brew install mas' first."
fi

echo "Installing Xcode..."
xcode-select --install

echo "Updating homebrew, and checking it..."
## Update homebrew
brew update && brew update && brew prune && brew doctor