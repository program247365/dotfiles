# WORKLOG

## 2026-07-29: qmd/search review — fixed staleness + recency, added daily sync, 10x'd --deep
- What changed
  - search repo: stale-index auto-update now stats the bear-sync manifest
    (the old index-sqlite mtime signal could never fire); doctor 1.50s → 0.03s.
  - bear-sync stamps mirror file mtimes with note modified times; parseQmd
    stats them, so qmd hits finally participate in recency decay. Backfilled
    with one full resync (6,279 notes).
  - tools/qmd/install.sh installs com.kevin.qmd-sync: launchd daily 5:00 AM
    `search update qmd` (runs on wake if asleep), log ~/Library/Logs/qmd-sync.log.
  - qmd context summary attached to the bear collection (and in installer).
  - --deep: forced QMD_LLAMA_GPU=metal (auto-detect falls back to CPU on
    Apple Silicon, 2.5-4x slower) + --no-rerank (fuse() re-ranks across
    sources anyway; only 5/20 hits differed). 27-58s → ~2-4s cached,
    5-30s once per novel query (expansion, cached forever).
  - Metal forced in three contexts: search adapter env, launchd plist,
    zsh/config.zsh export. Full system documented in
    ~/.kevin/code/search/docs/architecture.md.
- What we decided and why
  - Rejected a vsearch middle tier (8.3s vs 11s full query — model load
    dominates, not worth a third mode) and the qmd MCP daemon (CLI never
    routes through it; it only serves MCP clients).
  - Kept the >7d search-time auto-update gate as backstop behind the
    launchd agent; doctor reports true sync age. Three freshness layers.
- What to revisit next time
  - Headless 5 AM run de-risked: kickstarted the agent with Bear quit —
    bearcli read the DB fine, embed ran, exit 0. Log worth one glance after
    the first real unattended run anyway.
  - Consider filing the Apple Silicon GPU auto-detect fallback upstream
    (tobi/qmd) — QMD_LLAMA_GPU=metal shouldn't be necessary.
  - Plan checklist lives in Bear: "QMD for Bear Notes" note (all items done).

## 2026-07-29: search install.sh stoa failure — bun compile naming bug
- What changed
  - stoa-mono 932ba9f: build.ts used `compile: true, naming: "stoa"`, but
    Bun.build ignores `naming` for compiled executables (bun 1.3.x names
    them after the entrypoint → dist/src). Fixed with
    `compile: { outfile: "stoa" }`. Pushed.
  - Fast-forwarded this machine's search checkout
    (~/.kevin/personal-code/search) to 4d90f57; installer now builds
    search 0.3.0 with all nine sources ok per `search doctor`.
- What we decided and why
  - Root cause was in stoa-mono, not install.sh — the installer's
    `cp dist/stoa` was correct; fixing the copy path would have papered
    over the misnamed binary. build.ts also hardcodes its
    "Built dist/stoa" log line, which is why the build "succeeded".
- What to revisit next time
  - `search doctor` here flags bear sync never ran — run
    `search update qmd` once on this machine.
  - Work machine still needs a dot run to pick up both fixes; verify
    `search doctor` there (first real test of parsePi).

## 2026-08-02: Email triage via spark CLI — inbox/trash analysis and deletion report
- Dumped unified inbox (4,175) and recent trash (1,000) with `spark emails`; aggregated senders in scratchpad
- Found k@kbr.sh mirrors kridgway@gmail.com — 3,477 of 4,175 inbox msgs are the mirror backlog; 1,800 msgs are from 197 senders Kevin already routinely deletes
- Wrote triage report (scratchpad/email-triage-report.md) with Spark search strings per delete bucket; all accounts read-only so no actions taken
- Revisit: grant Spark triage access for agent-driven cleanup; fix kridgway→k@kbr.sh duplication at the source

## 2026-08-04: search rule updated for reminders source, doctor upgrades, web UI
- What changed
  - agents/claude/rules/search.md now covers: reminders source (open todos
    only, `--completed` opts in; same Full Disk Access grant as imessage),
    `reminders` in the `--source` list, `--list`, streaming picker with
    session-resume on enter, doctor's FDA probes + stale-binary rebuild,
    and a one-liner on the web PWA (`make serve`, port 3847;
    `make install-launchdaemon` for the login server — renamed mid-session
    from install-agent).
  - Verified every claim against search 0.5.0 (`--source imessage,reminders`
    works despite the help text) and GREEN-tested with a fresh-agent
    retrieval quiz on the updated file.
  - Fixed the upstream stale help too: cli.ts USAGE `--source` list now
    derives from DEFAULT_CONFIG.sources (search repo 4f9feea, not pushed).
  - After Kevin added `search sources`, the rule delegates the source
    roster to `search sources --json` instead of hardcoding 11 names —
    same single-source-of-truth fix as cli.ts.
- What we decided and why
  - Kept the web UI to one line marked "for Kevin's use, not agents" —
    the rule loads into every session, so lines cost permanent context.
  - Rule keeps source *concepts* in prose (quirks like `--completed`,
    session-source semantics) but not the name list, which changes with
    every new source and goes stale.
- What to revisit next time
  - Push search repo 4f9feea (and Kevin's sources/Makefile work) when ready.
## 2026-08-10: OOO meeting catch-up — Supernormal summaries into a Bear note
- Confirmed OOO window Jul 30–Aug 9 (last recording + last commit Jul 29; back Aug 10).
- Found NO Supernormal recordings exist for that window (own capture off, no teammate
  captures visible; Supernormal's own Aug 6 brief confirms the transcription gap).
- Reconstructed gists from daily personal brief emails (Spark IDs 5122–5192) and
  calendar recaps; wrote Bear note 71297200-58CD-4D11-ACEC-A51758B5A596
  ("OOO Catch-up: Jul 30 – Aug 9, 2026", #supernormal/_today).
- Learned: Supernormal MCP `list meetings` only returns own captures; meeting URLs are
  app.supernormal.com/meetings/<id>; brief emails wrap all links in SendGrid trackers
  (underlying URLs unrecoverable without following redirects).
