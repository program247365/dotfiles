# One-off machine updates (macOS updates, Xcode command line tools, brew
# upgrade). Not run by dot.

echo "› sudo softwareupdate -i -a"
sudo softwareupdate -i -a

# App Store apps moved to the Brewfile as `mas` lines.

echo "Installing Xcode..."
xcode-select --install

echo "Updating homebrew, and checking it..."

## Update homebrew
brew upgrade && brew doctor
