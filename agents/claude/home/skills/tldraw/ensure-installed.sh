#!/usr/bin/env bash
# Ensure the tldraw offline desktop app is installed, running, and agent-ready.
# Idempotent: safe to run repeatedly. Exit 0 = fully ready.

set -uo pipefail

APP="/Applications/tldraw offline.app"
SERVER_JSON="$HOME/Library/Application Support/tldraw/server.json"
OFFICIAL_SKILL="$HOME/.claude/skills/tldraw-offline/SKILL.md"

# 1. App installed (Homebrew cask 'tldraw' is tldraw offline)
if [ ! -d "$APP" ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "[install] installing tldraw offline via Homebrew..."
    brew install --cask tldraw || { echo "[fail] brew install --cask tldraw failed"; exit 1; }
  else
    echo "[fail] app not installed and Homebrew missing. Download: https://offline.tldraw.com"
    exit 1
  fi
fi
echo "[ok] installed: $APP"

# 2. App running
if ! pgrep -qf "tldraw offline.app/Contents/MacOS"; then
  echo "[launch] starting tldraw offline..."
  open -a "tldraw offline"
fi

# 3. Local server responding (server.json holds per-launch port + token)
ready=""
for _ in $(seq 1 15); do
  if [ -f "$SERVER_JSON" ]; then
    port=$(jq -r .port "$SERVER_JSON" 2>/dev/null)
    if [ -n "$port" ] && curl -sf --max-time 2 "http://localhost:$port/" >/dev/null 2>&1; then
      ready=1
      break
    fi
  fi
  sleep 1
done
if [ -n "$ready" ]; then
  echo "[ok] server responding on port $port"
else
  echo "[warn] server not responding. If server.json exists its port is dead, so the app"
  echo "       quit uncleanly or is still launching (locked session / first-run Gatekeeper"
  echo "       prompt). Unlock the session, approve the launch, then re-run this script."
  exit 2
fi

# 4. Official agent skills installed (app menu: Develop -> Install Agent Skills)
if [ -f "$OFFICIAL_SKILL" ]; then
  echo "[ok] official agent skill present: ~/.claude/skills/tldraw-offline"
else
  echo "[install] triggering Develop -> Install Agent Skills..."
  osascript \
    -e 'tell application "tldraw offline" to activate' \
    -e 'delay 1' \
    -e 'tell application "System Events" to tell process "tldraw offline" to click menu item "Install Agent Skills" of menu "Develop" of menu bar 1' \
    >/dev/null 2>&1
  # the install runs async after the click — give it a moment to land
  for _ in $(seq 1 10); do
    [ -f "$OFFICIAL_SKILL" ] && break
    sleep 1
  done
  if [ -f "$OFFICIAL_SKILL" ]; then
    echo "[ok] official agent skill installed"
  else
    echo "[action] could not automate the menu (needs Accessibility permission)."
    echo "         In the app, choose: Develop -> Install Agent Skills"
    exit 3
  fi
fi

echo "[ready] tldraw offline is agent-ready"
