---
name: code-spelunking
description: "Use when exploring an unfamiliar codebase, onboarding to a new repo, or wanting a quick health assessment of a project's git history before reading code. Triggers on 'spelunk', 'explore this repo', 'codebase overview', 'what's the state of this project', 'who works on this', 'where are the bugs'."
---

# Code Spelunking

Run a battery of git archaeology commands against the current repo and produce a structured report revealing project health, risk areas, team dynamics, and development patterns — all before reading a single line of code.

Based on: https://piechowski.io/post/git-commands-before-reading-code/

## When to Use

- First time looking at a codebase
- Onboarding to a new project or team
- Evaluating a repo before contributing
- Quick health check on a project you haven't touched in a while

## Execution

Run ALL of the following commands via Bash, capture their output, then synthesize into the report format below. Run independent commands in parallel where possible.

### 1. High-Churn Files (most-modified in past year)

```bash
git log --format=format: --name-only --since="1 year ago" | sort | uniq -c | sort -nr | head -20
```

Files that change constantly are often the riskiest — every change is a patch on a patch. Research (Microsoft, 2005) found churn predicts defects better than complexity metrics.

### 2. Contributor Breakdown & Bus Factor

```bash
git shortlog -sn --no-merges
```

```bash
git shortlog -sn --no-merges --since="6 months ago"
```

Compare all-time vs recent. If one person has 60%+ of commits, that's a bus factor problem. If top all-time contributors vanish from the recent window, knowledge may have left. Note: squash-merge workflows compress authorship.

### 3. Bug Hotspots

```bash
git log -i -E --grep="fix|bug|broken" --name-only --format='' | sort | uniq -c | sort -nr | head -20
```

Cross-reference with churn data. Files appearing in BOTH lists are highest-risk: they keep breaking and keep getting patched but never get properly fixed.

### 4. Commit Velocity Over Time

```bash
git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```

Steady rhythm = healthy. Sharp drops = people left. Declining curve = losing momentum. Periodic spikes = batch releases instead of continuous shipping.

### 5. Firefighting Signals

```bash
git log --oneline --since="1 year ago" | grep -iE 'revert|hotfix|emergency|rollback'
```

Frequent reverts mean the team doesn't trust its deploy process — unreliable tests, missing staging, or a broken pipeline.

### 6. Repo Basics (additional context)

```bash
git log --oneline | wc -l
```

```bash
git log --format='%ai' --reverse | head -1
```

```bash
git log -1 --format='%ai'
```

Total commits, first commit date, last commit date — frames everything else.

## Report Format

After collecting all data, output a report with this structure:

```
# Code Spelunking Report: <repo-name>

## Overview
- **Total commits:** N
- **Active since:** YYYY-MM-DD
- **Last commit:** YYYY-MM-DD
- **Contributors (all time):** N
- **Contributors (last 6 months):** N

## Bus Factor
Who owns this codebase? Is knowledge concentrated or distributed?
[Analysis of contributor data, flag if top contributor has >60% of commits,
note any all-time top contributors missing from recent window]

## High-Churn Files (Top 20)
[Table: rank, count, file path]
[Narrative: what these files suggest about where complexity lives]

## Bug Hotspots (Top 20)
[Table: rank, count, file path]
[Cross-reference with churn — call out files appearing in BOTH lists as highest-risk]

## Development Velocity
[Monthly commit counts, presented as a compact table or trend summary]
[Flag any sharp drops, spikes, or declining trends]

## Firefighting
[List of revert/hotfix/emergency/rollback commits, if any]
[Assessment: is this a team that ships confidently or one that patches reactively?]

## Key Takeaways
1. [Most important finding]
2. [Second most important]
3. [Third most important]

## Where to Start Reading
Based on the data above, suggest which files/areas to read first and why.
```

## Notes

- All commands assume you're in a git repo. Check with `git rev-parse --is-inside-work-tree` first.
- Shallow clones (`--depth`) will produce incomplete results. Warn if `git rev-parse --is-shallow-repository` returns true.
- Small repos (< 100 commits) may not have enough history for meaningful patterns. Adjust interpretation accordingly.
- The `--since="1 year ago"` window can be adjusted for older or younger repos.
