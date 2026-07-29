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
