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
    '1176895641' # Spark Email Client
    '1351639930' # Gifski
    '955297617'  # Coderunner 3
    '1423210932' # Flow - Focus and Break timer
    '1510445899' # Meeter
    '1502839586' # Handmirror
)

# 1510445899  Meeter       (1.9.6)
# 497799835   Xcode        (13.2.1)
# 1496833156  Playgrounds  (4.0)
# 409183694   Keynote      (11.2)
# 408981434   iMovie       (10.3.1)
# 1502839586  Hand Mirror  (1.5)
# 1319884285  Black Out    (2.0.4)
# 1604176982  One Thing    (1.6.0)
# 1091189122  Bear         (1.9.6)
# 409201541   Pages        (11.2)
# 1415311616  Countdowns   (2.2.1)
# 682658836   GarageBand   (10.4.5)
# 443439127   Focusbar     (1.3)
# 1176895641  Spark        (2.11.13)
# 937984704   Amphetamine  (5.2.2)
# 409203825   Numbers      (11.2)
# 1551460285  jandi        (1.9)

if test $(command -v mas)
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
brew update && brew prune && brew doctor
