---
name: tldraw
description: Use when a task involves the tldraw offline desktop whiteboard (offline.tldraw.com, .tldraw or .tldr files, "tldraw desktop", drawing/diagramming on the user's canvas) — especially before canvas work, when the app may not be installed, running, or agent-connected. Do NOT script it via AppleScript/UI automation; it has a local HTTP API.
---

# tldraw offline bootstrap

tldraw offline is a local desktop whiteboard (Homebrew cask `tldraw`). The running
app exposes a local HTTP server agents use to inspect and edit live canvases —
never drive it with AppleScript keystrokes or by editing `.tldraw` archives while
they're open.

## Bootstrap (always run first)

```bash
sh ~/.claude/skills/tldraw/ensure-installed.sh
```

Idempotent. Installs the app via Homebrew if missing, launches it, waits for the
local server, and installs the app's official agent skills if absent. Exit 0 =
ready. On exit 2 or 3, report the printed instructions to the user and stop —
they need to unlock the session or approve a dialog.

## Canvas work

Once bootstrapped, the official `tldraw-offline` skill (installed by the app into
`~/.claude/skills/tldraw-offline/`) is the authority for canvas operations — read
it and follow it. Essentials, in case it is momentarily unavailable:

- Server: `http://localhost:<port>`; port and bearer token live in
  `~/Library/Application Support/tldraw/server.json` (default port 7236).
- Helper: `sh ~/skills/tldraw-offline/tq <METHOD> <path> [body]` reads
  port + token itself. Example:
  `sh ~/skills/tldraw-offline/tq POST /api/search '{"code":"return await api.getDocs()"}'`
- `POST /api/search` runs JS with an `api` object (list docs, read shapes,
  screenshots). `POST /api/doc/:id/exec` runs JS with a live `editor` for one
  document. `GET /readme` documents everything (no auth needed).

## Common mistakes

- Env vars don't persist between Bash tool calls — re-read port/token from
  `server.json` in every call, or use `tq`.
- `server.json` present but port dead = app quit uncleanly; treat as not running.
- Agent edits are unsaved working-copy changes. Tell the user to review and
  File → Save; don't claim work is persisted.
