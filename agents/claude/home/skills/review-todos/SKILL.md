---
name: review-todos
description: "Triage all open Apple Reminders todos one by one, newest to oldest. D=Do Now (full-screen), C=Complete, X=Delete, S=Skip. All interaction is local — no LLM calls in the loop."
allowed-tools:
  - Bash
---

# Review Todos

Run the triage script and report the summary. Do not call AskUserQuestion or loop
through todos yourself — the script handles all interaction locally.

## Step 1 — Run the script

```bash
python3 ~/.claude/skills/review-todos/triage.py
```

The script takes over the terminal, handles all keypresses, calls remindctl directly,
and exits with a JSON summary on stdout.

## Step 2 — Report the summary

Parse the JSON output and show a clean summary:

```
Review complete.
──────────────────────
Completed : N
Deleted   : N
Do Now    : N
Skipped   : N
```

If `do_now` is non-empty, list those titles — they are the user's current focus.
If `quit_at` is present, note that the user quit early at that position.
If the message field says "No open todos.", just say that and stop.
