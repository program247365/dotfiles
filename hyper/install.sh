## Installing My Hyper things... http://hyper.is/

# TODO: The config file is a bit heavy-handed, should probably
# awk the parts of the config file after it's installed that I
# want changed.

echo "Installing Hyper Terminal..."

brew cask install hyper
npm install -g hpm-cli

hpm i hyper-quit
hpm i hyper-tab-icons-plus
hpm i hyperterm-clicky
hpm i hyperterm-copy
hpm i hyperborder
hpm i hypercwd
hpm i hyperlinks
hpm i hyperpanic
hpm i hyperterm-tab-icons
hpm i hyperterm-tabs
hpm i hypercwd
hpm i hyper-statusline

cp hyper.js ~/.hyper.js