---
name: spark-inbox-triage
description: Use when triaging a Spark Mail inbox — finding the biggest email senders to hit inbox zero, ranking senders by volume, or turning spark/search CLI data into copy-ready Spark search strings or an interactive HTML sender report.
---

# Spark Inbox Triage

Rank a Spark Mail inbox by sender volume and produce copy-ready `from:` search
strings so the user can clear high-volume senders in batches. Built from a
real run against a 1,701-message unified inbox — see
`~/.kevin/code/inbox-triage/` for the reference report, its README recipe,
and the archived HTML.

## Core rule: one bulk export, not one query per sender

Querying `spark emails Inbox --filter 'from:X'` once per candidate sender
(~40 calls) visibly degrades Spark Desktop — IPC round-trip latency crept
from ~2s to ~18s per call over one session. Instead:

1. `spark folders` — get the real total from the `Inbox` row under `Unified`.
2. Bulk-export with `spark emails Inbox --page-size 500 --page N > pN.txt`,
   paging until "Page N of N" — this is the whole inbox as fixed-width text.
3. Parse sender names **locally**, no more live queries needed for ranking:
   data rows match `^\s+\d+\s`; the `From` column is fixed-width, starting
   at character 34 (~32 chars, truncated with `…`). Strip the
   `"Name" <email>` wrapper with `^"?([^"<]+?)"?\s*<` and `Counter()` the
   results.

## Gotchas that cost time

| Symptom | Cause | Fix |
|---|---|---|
| `from:"Orchard Park High School"` and bare `from:Orchard` return the same (inflated) count | Multi-word `from:` filter without quotes silently degrades to a broad word match, not a phrase match | Always quote multi-word sender names: `--filter 'from:"Full Name"'` |
| A company's real volume is much higher than its display-name count | Platforms like Replit/Substack/LinkedIn send from many different individual addresses (`Matt Palmer <matt@mail.replit.com>`), so grouping by exact display name undercounts | Confirm with a single unquoted word (`from:Replit`) — no quoting ambiguity, matches domain-wide. Only worth doing for 4-5 suspected fan-out senders, not all of them |
| Repeated CLI calls make Spark Desktop sluggish for the rest of the session | Each `spark` invocation is a live IPC round-trip to the running app; many in a row compounds | Bulk-export once (see above); if it does degrade, it recovers on its own or a Spark Desktop restart fixes it |
| A published HTML report renders completely blank — chart empty, stats show `—`, no console-visible error | `const top = 14` (or `name`, `self`, `location`, `parent`, `frames`, `history`, `status`, `event`, `origin`, `length`) collides with a **non-configurable** `window` global — declaring it with `let`/`const` at script scope throws a parse-time `SyntaxError` that silently kills the entire `<script>` block | Never name a top-level `let`/`const` after a `window` global. Prefix instead (`chartTop`, `pageTop`) |

## Categorize, don't just rank

Raw volume mixes real "offenders" (marketing/SaaS, safe to search-and-archive)
with high-volume noise for that framing — a spouse, a school, a kid's sports
team. Before presenting a ranked list, split into:

- **Bulk & marketing** — safe to search-and-archive in one pass
- **Institutional** (school / youth sports / family orgs) — real, worth a
  batch pass, not a delete
- **Personal humans** — call out separately, exclude from "offenders" even
  if they top the raw count (a spouse emailing 42 times beats every company
  in the inbox — that's not spam)

## Deliverable: Spark search strings, not just a table

Spark Desktop's search bar and the `spark` CLI's `--filter` use the same
Gmail-style operators, so the actionable output is literally
`in:inbox from:"Sender Name"` strings the user pastes into Spark — that's
the bridge from CLI analysis back to the GUI they actually triage in.

**Spark deep links are unverified for search.** `readdle-spark://`,
`readdlespark://`, and `spark-mail-url://` are registered URL schemes
(check via `PlistBuddy -c "Print :CFBundleURLTypes" "/Applications/Spark
Desktop.app/Contents/Info.plist"`), confirmed to open a *specific message or
draft* (`readdle-spark://bl=<token>`, from `spark email`/`spark draft`
output) — there's no documented deep link for pre-filling a *search query*.
`open "readdle-spark://search?query=..."` exits 0 but that only proves macOS
found a handler, not that Spark ran the search. Never claim it works without
visually confirming (needs screen/computer-use access). Ship it as a labeled
best-effort fallback; copy-to-clipboard is the reliable path.

## If building an interactive report

Use the `artifact-design` and `dataviz` skills for the HTML/chart itself.
Reuse the palette/typography choices and the SVG bar-chart approach from
`~/.kevin/code/inbox-triage/inbox-triage.html` — no charting library needed
for a ranked sender list (~30 bars, hand-rolled inline SVG is plenty, with
click-to-scroll linking each bar to its search-string card below).
