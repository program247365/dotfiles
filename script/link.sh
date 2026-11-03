# link SOURCE TARGET: make TARGET a symlink to SOURCE. This is the only way
# dotfiles installers create links; source this file, then call it.
#
#   TARGET already links to SOURCE   -> nothing to do
#   TARGET links elsewhere, or broken -> replaced
#   TARGET is a copy of SOURCE        -> replaced
#   TARGET is different content       -> moved to TARGET.pre-dotfiles.<time>
#
# It never prompts and never deletes anything that isn't already in dotfiles.
link() {
  local source="$1" target="$2" label backup
  label="$(echo "$target" | sed "s|^$HOME|~|")"

  if [ ! -e "$source" ]; then
    echo "  [skip] $label (missing source $source)"
    return 0
  fi
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "  [ok] $label"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  # A target reached through a linked parent directory can be the source
  # itself; replacing it would delete the source.
  if [ ! -L "$target" ] && [ -e "$target" ] &&
     [ "$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")" = \
       "$(cd "$(dirname "$source")" && pwd -P)/$(basename "$source")" ]; then
    echo "  [skip] $label (is the source itself, via a linked directory)"
    return 0
  fi

  if [ -L "$target" ]; then
    echo "  [relink] $label (was -> $(readlink "$target"))"
    rm "$target"
  elif [ -e "$target" ]; then
    if diff -rq "$source" "$target" > /dev/null 2>&1; then
      echo "  [link] $label (replaced an identical copy)"
      rm -rf "$target"
    else
      backup="$target.pre-dotfiles.$(date +%Y%m%d%H%M%S)"
      mv "$target" "$backup"
      echo "  [backup] $label differed from dotfiles; saved as $backup"
    fi
  else
    echo "  [link] $label"
  fi
  ln -s "$source" "$target"
}
