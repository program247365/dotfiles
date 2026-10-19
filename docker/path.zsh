# OrbStack ships docker, docker-compose, docker-buildx, and kubectl inside the app.
if [[ -d /Applications/OrbStack.app/Contents/MacOS/xbin ]]; then
  export PATH="$PATH:/Applications/OrbStack.app/Contents/MacOS/xbin"
fi
