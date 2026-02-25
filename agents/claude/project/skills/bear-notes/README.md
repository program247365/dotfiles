# Bear Notes Skill

> A Claude Code skill that gives Claude full access to your [Bear](https://bear.app) notes — search, read, create, and update notes directly from your AI coding assistant.

---

## How It Works

This skill uses two complementary methods to interact with Bear:

1. **SQLite Database** (read-only) — Direct access to Bear's local database for fast searching. No network calls, completely private.
2. **x-callback-url API** (write operations) — Creates and modifies notes via Bear's official URL scheme (`bear://x-callback-url/create`, `add-text`, etc.)

---

## Installation

### Option A: Via Dotfiles (this repo)

The skill lives at `.claude/skills/bear-notes/` in this dotfiles repo. Claude Code looks for skills in `~/.claude/skills/`, so symlink it:

```bash
ln -sf ~/.dotfiles/.claude/skills ~/.claude/skills
```

If `~/.claude/skills` already exists as a directory, you can symlink just this skill:

```bash
ln -sf ~/.dotfiles/.claude/skills/bear-notes ~/.claude/skills/bear-notes
```

### Option B: Manual Install

Copy the skill directory to where Claude Code looks for skills:

```bash
cp -r bear-notes ~/.claude/skills/
```

### Verify Installation

Claude Code loads skills from `~/.claude/skills/`. Check that it's accessible:

```bash
ls ~/.claude/skills/bear-notes/SKILL.md   # should exist
```

---

## Usage

### In Claude Code

Once installed, the skill is automatically available. Invoke it by asking Claude about your notes:

> "What notes do I have about Python?"
> "Show me my work notes from the last 7 days"
> "Save this to Bear with tags programming and python"

Or invoke it explicitly via the Skill tool (in Claude Code sessions):

```
/bear-notes
```

### CLI Tool

The skill includes a standalone Python CLI at `bear.py` that works independently:

```bash
# Search notes
python3 ~/.claude/skills/bear-notes/bear.py search "query" --format json
python3 ~/.claude/skills/bear-notes/bear.py search "query" --tag "work"

# Date filtering (Bear operators)
python3 ~/.claude/skills/bear-notes/bear.py search "@last7days"
python3 ~/.claude/skills/bear-notes/bear.py search "@today meetings"
python3 ~/.claude/skills/bear-notes/bear.py search "@date(>2024-01-01) docker"

# Read a specific note
python3 ~/.claude/skills/bear-notes/bear.py read NOTE_ID --format text

# Create a note
python3 ~/.claude/skills/bear-notes/bear.py create --title "Title" --text "Content" --tags "tag1,tag2"

# Add text to an existing note
python3 ~/.claude/skills/bear-notes/bear.py add --id NOTE_ID "text to append" --mode append

# List all tags
python3 ~/.claude/skills/bear-notes/bear.py tags

# Open a note in Bear
python3 ~/.claude/skills/bear-notes/bear.py open --id NOTE_ID --edit
```

#### Date Operators

Use Bear's native date operators directly in the query string:

| Operator | Meaning |
|---|---|
| `@today`, `@yesterday` | Modified today/yesterday |
| `@last7days` | Modified in last N days (any number) |
| `@created7days` | Created in last N days |
| `@date(>2024-01-01)` | Modified after date |
| `@date(<2024-01-01)` | Modified before date |
| `@cdate(>2024-01-01)` | Created after date |

Or use explicit flags: `--modified-after`, `--modified-before`, `--created-after`, `--created-before` (format: `YYYY-MM-DD`)

---

## File Structure

```
bear-notes/
├── SKILL.md             # Claude Code skill definition (what Claude reads)
├── bear.py              # Python CLI tool — core Bear integration
├── claudeskill.yaml     # Legacy skill format (not used by Claude Code)
├── README.md            # This file
└── .gitignore           # Excludes .venv, __pycache__, etc.
```

**Key file:** `SKILL.md` is what Claude Code actually loads. It contains the frontmatter metadata and instructions that tell Claude how to use `bear.py`.

---

## Requirements

- [Bear app](https://bear.app) installed on macOS (free or Pro)
- Python 3.6+ (standard library only — no pip dependencies needed)
- Bear must have been opened at least once (to create its database)
- macOS only (Bear is macOS/iOS exclusive)

---

## Privacy & Security

- All operations are **100% local** — no external API calls
- Direct database access is **read-only**
- Write operations use Bear's **official URL scheme**
- No API keys or tokens required
- Works completely offline

---

## Troubleshooting

**"Bear database not found"**
- Open Bear at least once to initialize its database
- Database path: `~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/`

**Search returns no results**
- Verify notes aren't archived or trashed in Bear
- Run `python3 bear.py tags` to confirm tag names

**Create note fails**
- Ensure Bear is installed and running
- Verify URL scheme handlers are enabled in macOS System Settings

**Permission errors**
- Grant Terminal (or your IDE) Full Disk Access in System Settings → Privacy & Security

---

## Credits

Based on the [Raycast Bear Extension](https://github.com/raycast/extensions/tree/main/extensions/bear) by [@hmarr](https://github.com/hmarr).
Adapted for Claude Code by [@program247365](https://github.com/program247365).
