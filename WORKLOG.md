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

## 2026-08-11: Tweet notes enrichment run (/notes-organize-tweets)
- Enriched 22 Bear tweet notes: 18 fresh saves got structured bodies (12 tweet-text,
  6 link-only), 18 images (7 embedded photos + 11 Playwright tweet-card screenshots),
  18 inbox tags; 12 notes got topical tags from the existing taxonomy.
- 4 thread-check notes (shadcn, lucasmeijer, jamonholmgren, kappaemme1926) stamped
  thread:auth-needed — no X cookies at ~/.config/notes-organize-tweets/x-cookies.json.
  Run refresh-x-cookies.sh then re-run the workflow to backfill threads.
- System Python lacks playwright; ran x-screenshot-fetcher.py via
  `uv run --with playwright` and installed the Chromium headless shell
  (~/Library/Caches/ms-playwright). Consider baking uv invocation into the workflow.

## 2026-08-11: iCloud conflict cleanup + sync guard for /notes-organize-tweets
- Today's run collided with iCloud sync: the 4 thread-check notes had already been
  thread-enriched on the other machine, but that version hadn't synced down. Local
  auth-needed stamps + late-arriving cloud versions made CloudKit duplicate all 4
  (red fork icon in Bear). Kept the enriched "(thread: N tweets)" copies, trashed
  the 4 stale originals (tags/attachments were identical across each pair).
- bearcli has no sync command (verified: app subgroup is only open/get-selection),
  so added Step 0 to commands/notes-organize-tweets.md: ensure Bear is running
  (open -g -a Bear) and wait 60s cold / 15s warm before the audit.
- Uncommitted: notes-organize-tweets.md edit + earlier WORKLOG entries.

## 2026-08-11: Cleared persistent Bear conflict icons by recreating notes
- Bear's fork icon is driven by ZSFNOTE.ZCONFLICTUNIQUEIDENTIFIER, stamped on the
  conflict-created copy; bearcli trash/overwrite never clears it (verified in DB).
  Bear's FAQ says deleting one version or editing the note resolves it — that logic
  evidently lives in Bear's UI layer, and CLI writes bypass it.
- Fix: recreated all 6 flagged notes (4 tweet threads + Learn Voice + Learn Piano)
  under fresh IDs via bearcli (content + attachments + tags verified identical),
  trashed the flagged originals. DB now has zero conflict stamps.
- Caveat: recreated notes have new IDs and today's created date; wiki links are
  title-based so they survive.

## 2026-08-11: Baked sync/conflict knowledge into bear-notes skill + tweet workflow
- bear-notes SKILL.md: new "iCloud Sync Conflicts" section — conflict-stamp mechanics
  (ZCONFLICTUNIQUEIDENTIFIER), why bearcli can't clear it, read-only detection query,
  recreate-under-fresh-ID recipe, double-save vs conflict discriminator, prevention.
  Softened the "no sync" bullet that implied sync couldn't bite.
- notes-organize-tweets.md: Step 0 now points at the skill section; pre-check gained a
  duplicate guard (groups notes by tweet status id, excludes pairs from the run); Step A3
  now invokes the screenshot fetcher via `uv run --with playwright`; added a post-run
  read-only conflict check before the final report.
- Validation run of the new pre-check surfaced 6 pre-existing DUPLICATE pairs (12 notes)
  — double-saves (created days apart, no conflict stamps), not sync conflicts: shadcn,
  Dan Koe, Machina, Dwarkesh, Thariq, Jerry Liu. Two copies (Thariq 045E9892, Jerry Liu
  3D4D3DD9) have a leading-blank-line bug → empty Bear titles. Pending user decision on
  dedupe.

## 2026-08-11: Deduped 6 double-save tweet note pairs
- Kept the richer/intact copy per pair (shadcn 48187426, Dan Koe 1950EEB2, Machina
  13FF51C0, Dwarkesh DB48F2F2, Thariq 9B937759, Jerry Liu 76CB9816), merged missing
  topical tags into keepers, trashed the 6 others. Guarded against losing My-note
  blocks; only diff found was a redundant parent-tag line (Dwarkesh).
- Post-dedupe audit: zero duplicate pairs. 4 brand-new saves (businessbarista,
  unslothai, shannholmberg, aakashgupta) + 12 thread_checks await the next
  /notes-organize-tweets run (thread backfill still blocked on X cookies).

## 2026-08-18: Herdr setup — integrations, skill, and dotfiles adoption
- Read https://herdr.dev/agent-guide.md; Herdr 0.8.0 was already installed (Homebrew, Brewfile) and this session runs inside a Herdr pane (HERDR_ENV=1), so setup was verification + gap-filling.
- Installed integrations for claude/codex/pi (`herdr integration install <agent>`) — adds native session restore; state detection stays screen-based. The claude installer wrote a SessionStart hook through the settings.json symlink, so agents/claude/home/settings.json is modified in the repo.
- Installed the herdr skill via `npx skills add herdrdev/herdr --skill herdr -g`. The CLI's relative symlink broke through the ~/.claude/skills dotfiles symlink; repointed it absolute to ~/.agents/skills/herdr. Saved as a memory (skills-cli-relative-symlink).
- Added herdr/ (config.toml + install.sh): symlinks only config.toml into ~/.config/herdr (runtime state stays machine-local), then runs the integration installs idempotently and reloads the server config. Uses install.sh so script/install auto-discovers it; the install.zsh files (starship, mise, warp) are the older manually-run generation. Needed because the committed SessionStart hook references ~/.claude/hooks/herdr-agent-state.sh, which only the integration install creates on a fresh machine.
- The adopt step caught live-config drift (agent_panel_sort = "spaces" appeared after the initial copy) — reconciled. ~/.config/herdr/config.toml.pre-dotfiles is a redundant backup, safe to delete.
- Revisit: commit Brewfile, settings.json, skills/herdr symlink, and herdr/ together; decide whether other machines want the same integrations.

## 2026-08-18: Adopted QuickMD as the live markdown viewer for agent-written files
- Added `b451c/quickmd` tap + cask to Brewfile, installed it (needed new `brew trust`), and verified live reload against appends, wipes, and atomic temp-file renames.
- Wrote `agents/claude/home/skills/quickmd/SKILL.md` via the writing-skills TDD loop: baseline agent misread "watch the markdown file" as a polling watcher; with the skill it opens QuickMD instead. Committed as 221c6eb.
- Revisit: brew flagged 10 pre-existing untrusted taps (heroku, stripe, anthropics/tap, illegalstudio, noahgorstein…) it now ignores — trust the ones in use or `brew bundle` will skip them.

## 2026-08-19: pi moved to @earendil-works scope; enabledModels provider ids corrected
- npm deprecated `@mariozechner/pi-coding-agent` in favor of `@earendil-works/pi-coding-agent`.
  A scope rename is a *new* package to pnpm, so `pnpm add -g` the new one would have left both
  installed, each declaring a `pi` bin and racing for the same symlink. agents/pi/install.sh now
  removes the deprecated package first, guarded by a `pnpm ls -g` grep so a fresh machine doesn't
  trip `pnpm remove -g` under `set -euo pipefail`. Verified: 0.73.1 → 0.84.2, deprecation warning
  gone, ~/.kevin/bin/pi relinked, second install.sh run is a no-op. Commit 45adafe.
- enabledModels in agents/pi/home/settings.json had three dead entries, and they were dead for
  two different reasons — worth separating because the symptom is identical:
  - `anthropic/claude-sonnet-4-5` → stale id, replaced with `anthropic/claude-opus-5` (correct
    Opus 5 id; takes no date suffix).
  - `openai/gpt-5.4` → **wrong provider name**. pi's provider is `openai-codex`, not `openai`;
    `pi auth check --provider openai-codex` was `ready` the whole time while the entry warned on
    every startup. Now `openai-codex/gpt-5.5`.
  - `google/gemini-2.5-pro` → removed. Provider id `google` is real (it's in the package), but
    Google has no credentials here and pi's model catalog is auth-filtered, so the entry could
    only ever warn. Commit 753be88; both pushed.
- pi's model catalog is auth-filtered: before credentials, `pi --list-models anthropic` returned
  nothing, so an unauthenticated provider is indistinguishable from a nonexistent one. Also
  `pi auth check` returns `not_ready` for *any* string including nonsense, so it can't confirm a
  provider name — grep the installed package under `$(pnpm root -g)` for provider ids instead.
- Ollama pull failed 4× with an opaque `Error: EOF`. Not network, not the server: attempt 1
  stalled mid-transfer and left 2 of 16 per-chunk resume journals
  (`blobs/sha256-<layer>-partial-0` and `-partial-4`) truncated to 0 bytes. Every retry then read
  a journal claiming a byte range was complete when it wasn't and died instantly at manifest.
  Deleting the 17 `*-partial*` files fixed it first try. A 46MB probe model pulling fine while the
  4.7GB one failed is what isolated it to the cached blobs.
- Gotcha for scripting pi: it reads stdin when stdin isn't a TTY, so from a non-interactive shell
  it blocks waiting for EOF — pass `< /dev/null`. Warnings go to stderr, the answer to stdout, so
  `pi -p ... 2>/dev/null` stays parseable.
- Revisit: no Google credentials on this machine — if Gemini is ever set up, re-add a *verified*
  id rather than the old 2.5-pro string. `pnpm approve-builds -g` is still pending for
  @google/genai and protobufjs.

## 2026-08-24: Researched + verified codebase-memory-mcp (DeusData); Bear note written
- Cloned, built from source, and tested the C-based code-graph MCP server: 15 tools / 158 grammars / 43 client surfaces all check out; indexed ~/.dotfiles (2,730 nodes) correctly; MCP calls 13–47ms warm; zero network sockets at runtime.
- Full security sweep (subagent): clean — no telemetry, download code compiled out of release builds, credential-path indexing denylist, fail-open hooks, reversible config writes. Nits: install appends PATH to shell rc without uninstall cleanup; curl|bash configures all detected agents unless --skip-config.
- Marketing vs paper gap: README says 120x fewer tokens/ms indexing; their own arXiv (2603.27277) says 10x tokens with 83% vs 92% answer quality vs plain file exploration. Dejan's "Claude ignores MCP tools" claim: Claude half supported (repo issue #69, shipped Grep/Glob hooks), ChatGPT half unverified.
- Bear note "codebase-memory-mcp — verified research note" (29DDF584); test artifacts in /tmp/codebase-memory-mcp + /tmp/cbm-test-cache (disposable).
- Revisit: if adopting, install with --skip-config and hand-add only the Claude Code entry; watch issue #1654 (large-repo OOM) before pointing it at supermono.

## 2026-08-25: Tweet-enrichment skill — closed the untagged bare-link hole, enriched 94 notes
- Verified the reported hole: 47 untagged notes held tweet URLs invisible to the classifier, which only recognized title-starts-with-URL or existing inbox tag. Four miss shapes: annotation-first saves ("Make agents.md! <url>"), share-sheet markdown-link saves ("[Name (@handle) 107 likes](url)"), enriched bodies whose literal #inbox/saved-tweets line Bear never promoted to a real tag (external-pipeline writes), and twitter.com-domain URLs.
- Rewrote the pre-check recognition in agents/claude/commands/notes-organize-tweets.md as four signals (title prefix, inbox tag, enriched-body footprint, bare-link residual ≤300 chars); genuine project notes that merely reference a tweet go to a printed manual-review list instead of being rewritten. Residual text becomes the **My note** annotation so user words survive body rewrites.
- Also fixed: URL regex swallowing `)` and `<!--` after query strings; /statuses/ legacy paths; reference_existing_attachments now percent-encodes filenames (Bear rejects writes whose attachment refs contain raw spaces — 7 notes failed on `Screenshot ... PM.png` before the fix); Step C now falls back to reading tweet text from the enriched body, since extra_tags-only notes are never in the current run's syndication batch.
- Ran the full pipeline: 46 bodies built (39 single + 4 tombstone + 3 link-only), 37 thread upgrades via Tier 2 cookies, 35 head images + 22 Playwright card screenshots + 19 thread photos, 73 inbox tags, 37 topical tags. Zero iCloud conflicts.
- Left for Kevin: 2 manual-review notes ("Agents in Stoa" 7DB6A7F7, Dwarkesh podcast note C3C6928A) and 6 tweets skipped in tagging for lack of a taxonomy fit (tferriss patience letter, Dostoevsky letter, Logitech alternative, SahilBloom video, thekitze paperclip, maxedapps thanks).
- Skill edits are uncommitted in ~/.dotfiles (agents/claude/commands/notes-organize-tweets.md).

## 2026-08-26: Tweet-enrichment re-run — idempotence confirmed, stale-marker cleanup
- Re-ran the full workflow: zero new enrichment work needed — yesterday's pass fully converged (no new tweet saves, no iCloud conflicts).
- Found and fixed a marker-hygiene bug: Step B's settle path stripped only *trailing* thread markers, but an attachment ref appended after `<!-- thread:unchecked -->` pushes it mid-body, where it survived. 63 notes carried a stale unchecked marker alongside their settled one — all cleaned; both settle regexes in the skill now strip markers anywhere in the body.
- Settled 3 of the 6 tag-skipped notes: tferriss/Coach Sommer + Dostoevsky letters → writing/quips; maxedapps (links dmmulroy/anti-slop) → learn/ai.
- Permanently skipped (no taxonomy fit, will keep listing under extra_tags): sahilbloom motivational video EA4A9989, almonk openlogi.org rec 4FFE26C4, thekitze paperclip 134E3490. Tag manually or add a taxonomy branch if they grate.
- Manual-review pair unchanged: "Agents in Stoa" 7DB6A7F7, Dwarkesh podcast note C3C6928A.
- Skill edits still uncommitted in ~/.dotfiles.

## 2026-08-26: Tweet notes enrichment run — clean corpus, settled the 3 tag-skipped notes
- Ran /notes-organize-tweets. Audit found zero notes needing body/image/thread work — Steps A/A2/A3/B all no-ops. No duplicate pairs, post-run conflict query clean.
- Tagged the 3 notes the 2026-08-25 session had left as "no taxonomy fit": sahilbloom EA4A9989 → personal/motivational; almonk 4FFE26C4 → personal/technology; thekitze 134E3490 → projects/developer-productivity. Judged these existing tags close enough — remove/retag if they grate. They no longer surface under extra_tags.
- Manual-review pair unchanged: "Agents in Stoa" 7DB6A7F7, Dwarkesh podcast note C3C6928A.

## 2026-08-26: Updated impeccable skill v3.5.0 → v4.1.2
- Ran `npx impeccable update --yes --no-hooks`; it writes through the ~/.claude/skills symlink straight into the vendored copy at agents/claude/home/skills/impeccable. First pass landed 4.1.1 because impeccable.style's bundle lagged the skill-v4.1.2 GitHub release (tagged this morning); re-ran with IMPECCABLE_BUNDLE_PATH pointed at the release's universal.zip to get 4.1.2 exactly.
- The v3.6.0 npm CLI's update path silently skipped installing the four shipped subagents (asset-producer, documenter, finish-reviewer, manual-edit-applier) into ~/.claude/agents — a bug the v4.1.2 notes confirm ("Claude subagents install correctly again"). Copied them from the release bundle by hand; they now live in agents/claude/agents/.
- Deliberately skipped the design hook install (--no-hooks) — the skill works without it; revisit if post-edit detector reminders sound useful (`/impeccable hooks on`).
- Push required a rebase over 4 remote commits (pi scope rename etc.); autostash conflicted in WORKLOG.md, resolved by keeping both sides chronologically. Commit 4a68c68, pushed.
- Added durable-skip convention to the Step C tagging pass in notes-organize-tweets.md: when no taxonomy tag fits, apply catch-all `learn/misc` instead of leaving the note untagged — any topical tag settles it so it stops resurfacing under extra_tags every run. Uncommitted alongside the existing skill edits.
