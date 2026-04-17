---
name: git-recon
description: Use when starting work on an unfamiliar codebase, onboarding to a new repo, or returning after extended absence — runs structured git commands to map churn, ownership, bug hotspots, momentum, and culture before reading code.
---

# git-recon

## Overview

Run 10 git commands to extract codebase intelligence before reading a line of code. Synthesize results into a structured TUI report. Optionally generate an HTML dashboard with `--visual`.

**Invoke with:** `/git-recon` or `/git-recon --visual`

**Not useful for:** repos with < 3 months history or < 5 contributors (too little signal to interpret).

## Workflow

### Step 1: Run all commands in parallel

Run all 10 Bash commands at once. Do not run sequentially — they are independent.

**Churn — top 20 most-changed files (1 year):**
```bash
git log --format=format: --name-only --since="1 year ago" \
  | sort | uniq -c | sort -nr | head -20
```

**Contributors — ranked by commit count (all time vs. recent):**
```bash
git shortlog -sn --no-merges
git shortlog -sn --no-merges --since="6 months ago"
```

**Bug hotspots — files tied to bug/fix commits:**
```bash
git log -i -E --grep="fix|bug|broken" --name-only --format='' \
  | sort | uniq -c | sort -nr | head -20
```

**Momentum — commit frequency by month:**
```bash
git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```

**Firefighting — reverts, hotfixes, emergencies:**
```bash
git log --oneline --since="1 year ago" \
  | grep -iE 'revert|hotfix|emergency|rollback'
```

**Entry-point skeleton — first files ever created:**
```bash
git log --reverse --diff-filter=A --name-only --format='' | head -40
```

**Directory heat map — churn grouped by module:**
```bash
git log --format=format: --name-only --since="1 year ago" \
  | grep -v '^$' \
  | awk -F/ '{print NF>1 ? $1"/"$2 : $1}' \
  | sort | uniq -c | sort -rn | head -20
```

**Commit vocabulary — what the team cares about:**
```bash
git log --format='%s' --since="1 year ago" \
  | tr '[:upper:]' '[:lower:]' \
  | grep -oE '\b[a-z]{4,}\b' \
  | sort | uniq -c | sort -rn | head -30
```

**Author-to-file ownership — who to ask about what:**
```bash
git log --since="1 year ago" --format='%an' --name-only \
  | awk 'NF==1 && !/^$/{author=$0} NF>1{print author, $0}' \
  | sort | uniq -c | sort -rn | head -30
```

**Large-change detection — biggest commits by files touched:**
```bash
git log --oneline --since="1 year ago" --shortstat \
  | awk '/^[0-9a-f]/{sha=$0} /files changed/{print $1+$3, sha}' \
  | sort -rn | head -10
```

### Step 2: Synthesize the TUI report

Output a structured report directly in the conversation using this format. Lead with risk signals, not raw data. Interpret — don't just repeat command output.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  git-recon: <repo-name>
  Analyzed: last 12 months  |  <total-commit-count> commits
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CHURN HOTSPOTS (top files by change frequency)
  <count>  <file>   ← [RISK if also appears in bug hotspots]
  ...

BUG HOTSPOTS (files tied to fix/bug commits)
  <count>  <file>   ← [HIGH RISK if overlaps with churn]
  ...

RISK OVERLAP (files on both lists — read these first)
  <file>
  ...

MOMENTUM
  Trend: [Growing / Stable / Declining] — explain in 1 sentence
  Peak: <YYYY-MM> (<count> commits)
  Last 3 months avg: <n> commits/month

FIREFIGHTING SIGNALS
  <count> reverts/hotfixes in the last year
  Examples: [list up to 3 commit summaries]
  Assessment: [Low / Moderate / High] instability

CONTRIBUTORS
  Total active (6mo): <n>
  Bus factor risk: [Low / Moderate / High] — explain who and why
  Top 3: <name> (<n> commits), ...

OWNERSHIP MAP (who to ask about what)
  <name> → <file/dir>, <file/dir>, ...
  ...

ACTIVE MODULES (directory heat map)
  <count>  <dir>
  ...

ARCHITECTURAL SKELETON (founding files)
  First files created suggest: [describe the project's genesis in 1-2 sentences]

CULTURE (commit vocabulary signals)
  Top non-noise words: <word> (<n>), ...
  Interpretation: [e.g. "high 'fix' frequency suggests reactive culture"]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RECOMMENDED READING ORDER
  1. <file> — highest risk overlap
  2. <file> — core churn
  3. <dir>/ — active module, check architecture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Interpretation rules:**
- A file in both churn AND bug hotspots = read it first, treat it as fragile
- Bus factor is HIGH if top contributor holds > 50% of commits in last 6 months
- Firefighting is HIGH if > 10% of commits in last year are reverts/hotfixes
- Momentum is Declining if the last 3 months average less than half the peak month
- Vocabulary heavy on `fix`/`bug`/`patch` vs. `feat`/`add`/`improve` is a culture signal

### Step 3: --visual (optional)

If `--visual` was passed, invoke the `visual-explainer` skill after outputting the TUI report. Pass the collected data as context. The HTML dashboard should include:

- **Bar chart** (Chart.js): top 15 churn files, color-coded red if also a bug hotspot
- **Line chart** (Chart.js): monthly commit momentum over time
- **Table**: ownership map (author → files), sortable
- **Cards**: bus factor risk, firefighting signal, culture summary
- **Section**: architectural skeleton + recommended reading order

Use the visual-explainer skill's full workflow: generate HTML to `/tmp/visual-explainer-git-recon-<repo>.html`, create Bear note, attach HTML, open in browser.

## Interpreting Low-Signal Repos

If the repo has < 3 months of history or < 5 contributors, say so upfront and skip sections that can't produce meaningful signal. Don't fabricate interpretations from sparse data.
