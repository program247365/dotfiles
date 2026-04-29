---
name: workday
description: |
  Daily and weekly planning rituals. Reviews Bear notes, Linear issues, and
  organizes #supernormal/_today. Modes: day-start, day-end, week-start, week-end.
---

# Workday Skill

Manage daily and weekly planning rituals by combining Bear notes (`bearcli`) and Linear (MCP).

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

- `bearcli` installed and on PATH (see bear-notes skill; installed via `~/.dotfiles/tools/bearcli/install.sh`)
- Linear MCP server connected (for issue queries)

## Conventions

- **Tag taxonomy:**
  - `#supernormal/_today` — active/current items (working set)
  - `#supernormal/journal` — archived daily/weekly entries and completed work
  - More specific tags (e.g. `#supernormal/agents-experience`) take priority over `journal` when they exist
- **Note naming:** `YYYYMMDD - <Type>` (e.g. `20260302 - Week Plan`, `20260303 - Day Start`)
- **Date filtering:** prefer Bear's inline operators — `@today`, `@yesterday`, `@last7days`, `@date(>YYYY-MM-DD)`. Combine with tags: `bearcli search "#supernormal @last7days" --format json`. No more post-processing in Python for date windows.

## Shared Steps

### Gather Bear Notes

For most modes, a single `bearcli search` query returns the right window directly:

```bash
# Last week's supernormal notes
bearcli search "#supernormal @last7days" --format json --fields id,title,tags,modified \
  > /tmp/bear_last_week.json

# Today's working set
bearcli search "#supernormal/_today" --format json --fields id,title,tags > /tmp/bear_today.json

# Notes modified in a specific window
bearcli search "#supernormal @date(>2026-04-21) @date(<2026-04-29)" --format json
```

For modes that need exact start/end boundaries, fall back to date-clamped searches like `@date(>YYYY-MM-DD) @date(<YYYY-MM-DD)`.

### Gather Linear Issues

Use the Linear MCP `list_issues` tool:
- `assignee: "me"` — get all issues assigned to the user
- Parse the JSON result to separate active vs. completed issues
- Active = status not in (Done, Canceled, Duplicate)
- Recently completed = status is Done, updated within the date range

### Read Note Content

```bash
bearcli cat NOTE_ID                                      # raw markdown
bearcli show NOTE_ID --format json --fields all,content  # everything
```

Search/list results carry only `id`, `title`, `tags`, `matches` by default. Add `--fields all,content` (and pass via `--format json`) when you need the body in the same call.

### Retag Notes

To move a note from `_today` to `journal` (or another tag), use the dedicated tag commands — they don't disturb the body or modification date:

```bash
bearcli tags remove NOTE_ID supernormal/_today
bearcli tags add    NOTE_ID supernormal/journal
```

If a note already has a more specific subtag (e.g. `supernormal/agents-experience`), just remove `_today` and skip the `journal` add.

## Mode: `week-start`

**When:** Monday morning (or user invokes manually at start of week)

**Steps:**

1. **Gather last week's data:**
   - Bear notes tagged `#supernormal` modified in the previous Mon-Fri
   - Linear issues assigned to me that were completed last week
   - Linear issues assigned to me that are currently active

2. **Read content** of all last-week notes (use `bearcli cat ID`, limit to first 40 lines each for context)

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
