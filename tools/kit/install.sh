#!/bin/sh
#
# kit — fuzzy picker over the tools these dotfiles declare (Brewfile, bin/,
# aliases, functions). Source: github.com/program247365/kit (private), cloned
# to ~/.kevin/code/kit and linked onto PATH. It reads the dotfiles from
# $DOTFILES (default ~/.dotfiles); `dot` rebuilds its index after installing.

set -e

REPO="git@github.com:program247365/kit.git"
DEST="$HOME/.kevin/code/kit"

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull -q --ff-only || echo "  [note] kit: couldn't fast-forward $DEST; pull it by hand"
elif ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  mkdir -p "$(dirname "$DEST")"
  git clone -q "$REPO" "$DEST"
  echo "  Cloned kit → $DEST"
else
  echo "  skipped kit: no SSH access to GitHub yet (add a key, then re-run dot)"
  exit 0
fi

. "$HOME/.dotfiles/script/link.sh"
link "$DEST/kit" "$HOME/.kevin/bin/kit"
