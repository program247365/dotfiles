---
name: bear-notes
description: "Search, read, and create notes in Bear. Use when the user asks about their notes, wants to search Bear, save something to Bear, or reference their personal knowledge base."
---

# Bear Notes Assistant

You have full access to the user's Bear notes via a Python CLI at `~/.dotfiles/.claude/skills/bear-notes/bear.py`. Use the Bash tool to run commands.

## Available Commands

### Search Notes
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "query" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "query" --tag "tagname" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "@last7days" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "@today meetings" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "query" --modified-after 2024-01-01 --format json
```

Bear date operators (use in query string):
- `@today`, `@yesterday` — relative dates
- `@last7days` — modified in last N days (any number)
- `@created7days` — created in last N days
- `@date(>2024-01-01)` — modified after date
- `@date(<2024-01-01)` — modified before date
- `@cdate(>2024-01-01)` — created after date

### Read a Note
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py read NOTE_ID --format text
```

### Create a Note
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py create --title "Title" --text "Content" --tags "tag1,tag2"
```

### Add to a Note
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py add --id NOTE_ID "text to append" --mode append
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py add --title "Note Title" "text" --mode prepend
```

### List All Tags
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py tags
```

### Open a Note in Bear
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py open --id NOTE_ID
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py open --title "Note Title" --edit
```

## Workflow

**When answering questions:**
1. **Search first** — use `search` to find relevant notes
2. **Read details** — use `read NOTE_ID` for full content of relevant notes
3. **Synthesize** — combine info from multiple notes
4. **Cite sources** — always mention which note titles you're referencing

**When creating content:**
1. Offer to save important information to Bear
2. Suggest tags based on existing tags (run `tags` to check)
3. Ask if user wants to open the note after creation

## Notes

- Bear uses a reference date of 2001-01-01 for timestamps (handled by bear.py)
- Tags can be hierarchical: `work/projects/2025`
- Direct database access is read-only; create/modify uses Bear's URL scheme
- Always search before claiming a note doesn't exist
- Wiki links syntax: `[[note title]]`, `[[note title|alias]]`
