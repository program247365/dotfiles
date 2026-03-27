---
name: workday
description: |
  Daily and weekly planning rituals. Reviews Bear notes, Linear issues, and
  organizes #supernormal/_today. Modes: day-start, day-end, week-start, week-end.
---

# Workday Skill

Manage daily and weekly planning rituals by combining Bear notes (`bcli`) and Linear (MCP).

## Invocation

```
/workday day-start
/workday day-end
/workday week-start
/workday week-end
```

If no argument is given, infer from day-of-week and time:
- Monday before noon → `week-start`
- Friday after 3pm → `week-end`
- Before noon → `day-start`
- After 3pm → `day-end`
- Otherwise → ask the user

## Prerequisites

- `bcli` installed and on PATH (see bear-notes skill; installed via `~/.dotfiles/tools/bcli/install.sh`)
- Linear MCP server connected (for issue queries)

## bcli Auth Recovery

Any `bcli` command can fail with an authentication error (expired token, missing credentials, HTTP 401/403, or "unauthorized"/"not authenticated" in output). When this happens:

1. Tell the user: "bcli authentication has expired. Please run `bcli auth` to re-authenticate."
2. **Stop and wait** for the user to confirm they've completed auth before retrying.
3. Do NOT retry the failed command automatically — the user must complete the interactive `bcli auth` flow first.
4. Once the user confirms, retry the original command and continue the workflow.

## Conventions

- **Tag taxonomy:**
  - `#supernormal/_today` — active/current items (working set)
  - `#supernormal/journal` — archived daily/weekly entries and completed work
  - More specific tags (e.g. `#supernormal/agents-experience`) take priority over `journal` when they exist
- **Note naming:** `YYYYMMDD - <Type>` (e.g. `20260302 - Week Plan`, `20260303 - Day Start`)
- **bcli date filtering:** `bcli ls --all --json` then filter `modificationDate` (unix timestamp float) in Python. bcli does NOT support `@today` or `@last7days`.
- **bcli modificationDate format:** float (unix timestamp in seconds), NOT ISO string. Convert with `datetime.fromtimestamp(value)`.

## Shared Steps

### Gather Bear Notes

```bash
# Save all notes to temp file, then filter in Python
bcli ls --all --json > /tmp/bear_all_notes.json
```

```python
# Filter supernormal notes by date range
import json
from datetime import datetime, timedelta

with open('/tmp/bear_all_notes.json') as f:
    notes = json.load(f)

supernormal = [n for n in notes if any('supernormal' in t.lower() for t in n.get('tags', []))]

# Filter by date range (adjust start/end per mode)
def in_range(n, start, end):
    mod = n.get('modificationDate', 0)
    if not isinstance(mod, (int, float)):
        return False
    dt = datetime.fromtimestamp(mod)
    return start <= dt < end

filtered = [n for n in supernormal if in_range(n, start, end)]
```

### Gather Linear Issues

Use the Linear MCP `list_issues` tool:
- `assignee: "me"` — get all issues assigned to the user
- Parse the JSON result to separate active vs. completed issues
- Active = status not in (Done, Canceled, Duplicate)
- Recently completed = status is Done, updated within the date range

### Read Note Content

```bash
bcli get NOTE_ID --raw
```

Search results only have `id`, `title`, `tags`, `match` — always fetch body separately.

### Retag Notes

To move a note from `_today` to `journal` (or another tag):
1. Read the note body: `bcli get NOTE_ID --raw`
2. Replace `#supernormal/_today` with the target tag in the body text
3. Write back: `printf '%s' "$new_body" | bcli edit NOTE_ID --stdin`

If a note already has a more specific tag (e.g. `#supernormal/agents-experience`), just remove `#supernormal/_today` instead of replacing it with `journal`.

## Mode: `week-start`

**When:** Monday morning (or user invokes manually at start of week)

**Steps:**

1. **Gather last week's data:**
   - Bear notes tagged `#supernormal` modified in the previous Mon-Fri
   - Linear issues assigned to me that were completed last week
   - Linear issues assigned to me that are currently active

2. **Read content** of all last-week notes (use `bcli get ID --raw`, limit to first 40 lines each for context)

3. **Create "Week Review" note** tagged `#supernormal/journal`:
   - Title: `Week Review: <date range>`
   - Sections: Completed (Linear table), Key Work (grouped by theme), Context
   - Be specific about what was shipped, not vague summaries

4. **Create "Week Plan" note** tagged `#supernormal/_today`:
   - Title: `YYYYMMDD - Week Plan`
   - Sections: Active Linear issues (grouped by status/priority), Carryover items, Priorities (numbered)
   - Pull priority context from Slack messages if present in notes

5. **Retag old `_today` notes:**
   - Read all notes currently tagged `#supernormal/_today`
   - For each that looks like last week's work (completed tickets, investigations, explorations):
     - If it has a more specific supernormal subtag → remove `_today`, keep specific tag
     - Otherwise → replace `_today` with `journal`
   - Keep notes that are genuinely ongoing (ideas lists, active conversations, open investigations)
   - When unsure, default to `#supernormal/journal`

6. **Present summary** to user: what was created, what was retagged, what was kept

## Mode: `day-start`

**When:** Morning, any day

**Steps:**

1. **Gather today's context:**
   - Current `#supernormal/_today` notes (the working set)
   - Linear issues assigned to me, active (In Progress, Todo, In Review)
   - Any notes modified yesterday that might need follow-up

2. **Create "Day Start" note** tagged `#supernormal/_today`:
   - Title: `YYYYMMDD - Day Start`
   - Sections: Focus (top 3 priorities for today), Active Issues, Carry Forward
   - Keep it short — this is a checklist, not an essay

3. **Present the plan** to user for confirmation/adjustment

## Mode: `day-end`

**When:** End of day

**Steps:**

1. **Gather today's activity:**
   - Notes modified today tagged `#supernormal`
   - Linear issues completed today (compare against morning state if day-start note exists)
   - Git log for today if in a repo: `git log --oneline --after="YYYY-MM-DDT00:00" --author="kevin"`

2. **Append to or create journal entry** tagged `#supernormal/journal`:
   - Title: `YYYYMMDD - Day End`
   - Sections: Done (what shipped), In Progress (what's mid-flight), Tomorrow (what to pick up)

3. **Retag completed `_today` items** → `journal` (same logic as week-start retagging)

4. **Present summary** to user

## Mode: `week-end`

**When:** Friday afternoon

**Steps:**

1. **Gather the full week:**
   - All `#supernormal/journal` entries from this week
   - Linear issues completed this week
   - PRs authored/reviewed this week (if in a repo with `gh`)

2. **Create "Week Review" note** tagged `#supernormal/journal`:
   - Title: `Week Review: <date range>`
   - Sections: Completed (Linear table), Key Themes, Demo Draft (a paragraph summarizing the week for standup/demo), Brag Items

3. **Retag remaining `_today` notes** that are clearly done → `journal`

4. **Present summary** and ask if user wants to append anything to their Brag Doc

## Output Rules

- Be specific and concrete. "Fixed proxy bug causing silent Claude Code failures" not "worked on bugs."
- Include Linear ticket IDs (e.g. PAIDE-5390) in all references.
- Group work by theme, not by day.
- Keep created notes under 80 lines. These are working documents, not reports.
- When retagging, always tell the user exactly what moved and what stayed.
