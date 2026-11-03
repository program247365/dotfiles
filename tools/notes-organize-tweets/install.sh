#!/bin/sh
#
# notes-organize-tweets — Claude skill that enriches saved tweet notes in Bear.
# Source: github.com/program247365/notes-organize-tweets (private), cloned to
# ~/.kevin/code/notes-organize-tweets and linked into ~/.claude/skills. Own
# code, so it tracks main with a pull instead of a pin in skills.txt.

set -e

REPO="git@github.com:program247365/notes-organize-tweets.git"
DEST="$HOME/.kevin/code/notes-organize-tweets"

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull -q --ff-only || echo "  [note] notes-organize-tweets: couldn't fast-forward $DEST; pull it by hand"
elif ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  mkdir -p "$(dirname "$DEST")"
  git clone -q "$REPO" "$DEST"
  echo "  Cloned notes-organize-tweets → $DEST"
else
  echo "  skipped notes-organize-tweets: no SSH access to GitHub yet (add a key, then re-run dot)"
  exit 0
fi

# x-thread-fetcher.mjs imports @the-convocation/twitter-scraper from here.
if [ ! -d "$DEST/scripts/node_modules" ]; then
  if command -v npm > /dev/null 2>&1; then
    (cd "$DEST/scripts" && npm install --silent --no-fund --no-audit)
    echo "  Installed Node dependencies in $DEST/scripts"
  else
    echo "  [note] npm not found; thread fetching needs \`npm install\` in $DEST/scripts"
  fi
fi

. "$HOME/.dotfiles/script/link.sh"
link "$DEST" "$HOME/.claude/skills/notes-organize-tweets"
