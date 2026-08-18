---
name: quickmd
description: Use when Kevin says "monitor that markdown file", "watch the markdown file", "let me see it as it's written", or otherwise wants to visually follow a markdown file — especially one an agent is actively writing (WORKLOG, plan, notes, report). Also use to show Kevin any markdown deliverable rendered.
---

# QuickMD — live markdown viewer

QuickMD (`/Applications/QuickMD.app`, Homebrew cask `b451c/quickmd`) renders
markdown and auto-reloads on every save — appends, full rewrites, and atomic
temp-file-and-rename saves all work (verified 2026-08-18).

**"Watch/monitor that markdown file" means: open it in QuickMD so Kevin can
see it render live.** It does NOT mean tail, poll, or log the file yourself.
Kevin wants eyes on the document; you keep doing your work.

## Commands

```bash
open -a QuickMD /absolute/path/to/file.md   # open (file must exist — touch it first if needed)
osascript -e 'quit app "QuickMD"'           # close when Kevin is done
```

If the app is missing:

```bash
brew tap b451c/quickmd && brew install --cask quickmd
# newer Homebrew may first require: brew trust b451c/quickmd
```

## Common mistakes

- Building a `tail -f`/polling watcher when Kevin says "watch" — he wants to
  see the file, not have you observe it.
- Passing a relative path or a not-yet-created file to `open`.
