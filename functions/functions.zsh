gch() {
  git branch | sk | xargs git checkout
}

gcode() {
  cd `lsd -ld code/*/*  | awk '{ print $11 }' | sk`
}

mzk () {
  find $HOME/.kevin/listen -type f | sk --height 40% --reverse | tr '\n' '\0' | xargs -0 $HOME/.kevin/bin/looper play --url
}

npmr() {
  npm run | sk | xargs npm run
}
