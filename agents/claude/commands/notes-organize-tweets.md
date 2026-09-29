Use the bear-notes skill. Then execute the idempotent Tweet Notes Enrichment Workflow below.

The workflow is fully idempotent — run it any time to catch up on anything that's missing. All step scripts live in `~/.dotfiles/agents/claude/tools/notes-organize-tweets/` — **run them from there; never re-type or copy them**. Each script's comments carry the detailed rationale.

> **Three-tier fetching strategy:**
>
> 1. **Tier 1 (always):** `cdn.syndication.twimg.com/tweet-result?id=<id>` — X's own embed API. Returns full JSON for any single tweet (text, author, photos, video, conversation_count). No login, no bot detection. The `token` parameter isn't validated.
> 2. **Tier 2 (thread enrichment, opt-in):** `@the-convocation/twitter-scraper` Node lib calling X's authenticated GraphQL via the user's exported cookies. Used to fetch self-thread continuations when a tweet has `conversation_count > 0`, and for **full text**: Tier 1 truncates long-form "note tweets" to ~280 chars and truncates quoted tweets, so any note tweet or quote tweet is routed here too, replies or not. Every tweet in the chain is re-fetched via `getTweet` (TweetDetail), the only endpoint carrying `note_tweet` text and the quoted tweet. Skipped silently if cookies are missing or stale. A first-pass single body is stamped `thread:unchecked`; a later run re-flags it for Tier 2 and upgrades it to a thread (or settles it at `thread:complete count=1`). Set `FORCE_THREAD_RECHECK=1` to re-open already-settled notes for backfill.
> 3. **Tier 3 (screenshot fallback):** Playwright loads `platform.twitter.com/embed/Tweet.html?id=<id>` and screenshots the rendered tweet card. Runs only when Tier 1 returned no embedded photo, so text-only and link-card tweets still get a visual attachment. No auth required.
>
> Cookies live at `~/.config/notes-organize-tweets/x-cookies.json` (gitignored). Run `~/.dotfiles/agents/claude/tools/refresh-x-cookies.sh` for setup instructions.

**Thread markers** (HTML comments in note bodies — the idempotency anchor):

- `<!-- thread:complete count=N fetched=YYYY-MM-DD -->` — settled: Tier 2 has run, trust it
- `<!-- thread:unchecked fetched=YYYY-MM-DD -->` — provisional: text captured, Tier 2 pending
- `<!-- thread:auth-needed fetched=YYYY-MM-DD -->` — Tier 2 wanted cookies, none available; re-prompted after a 7-day TTL

Before the first step, clear stale state from prior runs:

```bash
rm -f /tmp/tweet_todo.json /tmp/tweet_syndication.json /tmp/tweet_thread_auth_needed.json /tmp/tweet_thread_errors.json /tmp/tweet_tagging.json /tmp/tweet_tag_assignments.json
```

---

**Step 0 — Sync guard (let iCloud settle before auditing)**

The audit reads only this machine's local Bear database. If another machine already enriched a note and that version hasn't synced down yet, this run will re-edit the stale local copy and CloudKit will resolve the collision by duplicating the note (red fork icon in Bear's note list — this happened 2026-08-11). `bearcli` has no sync command and CloudKit only syncs while the Bear app is running, so the guard is: make sure Bear is open, then give sync a settle window before touching anything.

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/step0_sync_guard.py
```

This does not make conflicts impossible (a remote edit can always land mid-run), but it closes the common case: running the workflow right after login/wake, before Bear has caught up with edits made elsewhere.

If duplicates appear anyway, the **bear-notes skill → iCloud Sync Conflicts** section has the full playbook: keep the copy with the `thread:complete` marker, trash the other, and if the survivor still shows the red fork icon (the conflict stamp is UI-cleared only — `bearcli trash`/`overwrite` can't remove it), recreate it under a fresh ID. The pre-check below detects such pairs automatically and excludes them from the run.

---

**Pre-check — Audit all tweet notes and classify what needs work**

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/precheck.py
# FORCE_THREAD_RECHECK=1 python3 ...  to re-open already-settled notes for thread backfill
```

Three `bearcli search` calls cover the audit surface: text searches for `x.com` and `twitter.com` (catch notes with structured bodies and `#inbox/saved-tweets` tags) plus `@untagged` (catches bare-URL notes that Bear's FTS doesn't tokenize reliably). Results are merged by ID.

Tweet-save notes are recognized by any of four signals (verified against the real corpus 2026-08-25 — title-prefix alone missed ~30 untagged notes):

1. **Title prefix** — a title starting with `https://x.com/.../status/...` (or twitter.com). Catches bare URLs and markdown-link-wrapped `[url](url)`.
2. **Existing `#inbox/saved-tweets` tag.**
3. **Enriched-looking body** — the `**@handle** · [View on X]` footer, a `<!-- thread:` marker, or a literal `#inbox/saved-tweets` line. Catches notes written by external pipelines (e.g. iOS Shortcuts) whose inline tag text Bear never promoted to a real tag, leaving them fully untagged.
4. **Bare-link shape** — after stripping tweet URLs, markdown link/image syntax, HTML comments, inline tags, and share-sheet boilerplate (`4.7K likes · 8 replies`, `Name (@handle) on X`), at most ~300 chars of user text remain and the note has no substantial user-authored structure. Catches annotation-first saves (`Make agents.md! https://x.com/…`) and `[Name (@handle) 107 likes](url)` share-sheet saves, whose titles never match signal 1.

Notes containing a tweet URL that fail all four signals but are fully untagged are printed as a **manual-review list** — they look like project notes that merely reference a tweet, and rewriting them would destroy user content. Everything stripped-but-surviving in signal 4 is captured as `annotation` and rendered into a `**My note**` block by Step B, so user words are never lost.

The pre-check also excludes **duplicate pairs** (two notes for the same tweet) from the run and prints them. A pair is either an iCloud sync conflict (one copy created seconds after the other, typically at run time) or a double-save (same tweet saved twice, days apart). Discriminate by created dates — the post-run check below prints them. Either way: merge tags into the richer/intact copy, trash the other, and — for conflict pairs only — recreate the survivor under a fresh ID if it carries the fork icon (see bear-notes skill → iCloud Sync Conflicts).

Review the output before proceeding. Then:

---

**Step A — Syndication API (text + photos via HTTP)**

For all notes that need `image`, `body`, or `thread_check`, hits the syndication API and downloads embedded photos (`?name=large`). Notes that only need `extra_tags` or `inbox_tag` skip this step.

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/step_a_syndication.py
```

**Step A2 — Thread fetch via twitter-scraper (auth required)**

Candidates: notes flagged `thread_check` whose head tweet has `conversation_count > 0`, plus any note getting a body or thread check whose tweet is a long-form note tweet or a quote tweet (Step A records `is_note_tweet` / `quoted_id`). Each chain tweet is re-fetched at full fidelity; a rate limit or failed re-fetch counts as transient, so the note stays unsettled instead of settling on truncated text. Skips cleanly if cookies are missing/stale — affected notes get an `auth-needed` marker via Step B. Transient fetch errors (503s) land in `/tmp/tweet_thread_errors.json` so Step B leaves those notes unsettled for a retry.

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/step_a2_threads.py
```

**Step A3 — Tweet-card screenshot fallback (Playwright)**

For notes that need an image but got no embedded photo from Tier 1, renders X's embed widget and screenshots the tweet card to `/tmp/tweet_<note_id>.png` — the same path Step A would have used, so Step B picks it up transparently. If Chromium isn't cached yet — or the run fails with `Executable doesn't exist` because `uv` pulled a newer Playwright than the cached browser — run: `uv run --with playwright playwright install chromium`.

A3 soft-fails (Step B counts `no_photo_available`). That's safe to leave: the pre-check flags `image` for any non-tombstone note without an attachment, body or not, so the next run retries the screenshot. One consequence: a note whose tweet was deleted after its body was written (syndication `no_article`, but never tombstoned) is re-flagged for `image` every run — expected noise, not a bug.

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/step_a3_screenshots.py
```

**Step B — Apply mutations via bearcli**

Writes bodies (single/thread/tombstone/link-only), inbox tags, attachments, and thread markers. Preserves topical tags across body rewrites, keeps every existing attachment referenced (bearcli's overwrite guard), and dedups Bear's auto-injected image links. Renders quoted tweets as a `**Quoting @handle**` block, expands `t.co` links to their targets (dropping only those pointing at the tweet's own media or its quote), carries an existing `**My note**` block through any rebuild, and skips re-attaching thread photos already on the note. The pre-check keys each note on its `**@handle** · [View on X](…)` footer, since quote and expanded links put other tweets' URLs higher in the body. Body precedence and marker rules are documented in the script's comments.

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/step_b_apply.py
```

---

**Convergence pass**

A first pass over fresh saves builds bodies stamped `thread:unchecked`; those notes now need `thread_check` and `extra_tags`. Instead of leaving that for a future run, re-run the pre-check now and, if it flags work, repeat Steps A → A2 → A3 → B. The second pass settles thread markers (or upgrades bodies to threads) and feeds Step C.

---

**Step C — Auto-tag pass (notes needing `extra_tags`)**

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/step_c_collect.py
```

Prints the tag taxonomy (top 50; full list in `/tmp/tweet_tagging.json`) and each candidate's tweet text. Notes needing only `extra_tags` aren't fetched by Step A, so the collector falls back to reading author + text from the enriched note body — equivalent for classification.

Read the candidates. For each note, pick 1–3 tags from the existing taxonomy. Prefer `learn/*` tags. Skip link-only tweets. If nothing in the taxonomy genuinely fits, tag the note `learn/misc` — the designated catch-all. Any non-inbox tag settles the note durably (the audit's `extra_tags` check only fires when a note has *no* topical tag), so a `learn/misc` note stops resurfacing on every run. Never leave a candidate untagged as a "skip": that decision doesn't persist anywhere the audit can see, and the note will be re-flagged forever.

Write the assignments to `/tmp/tweet_tag_assignments.json` as `{"NOTE-UUID": ["learn/foo", "projects/bar"], ...}`, then apply:

```bash
python3 ~/.dotfiles/agents/claude/tools/notes-organize-tweets/step_c_apply.py
```

---

**Post-run conflict check**

A remote version can sync down mid-run and collide with this run's writes (it happened 2026-08-11: thread bodies enriched on another machine arrived 47s after local writes, duplicating 4 notes). A conflict leaves two live notes for the same tweet, so the check re-runs the pre-check's duplicate detection and prints each pair's created/modified times via `bearcli` (exit 1 when pairs exist). It deliberately avoids the SQLite conflict stamp — `bearcli` doesn't expose it, and reading Bear's DB directly needs Full Disk Access:

```bash
~/.dotfiles/agents/claude/tools/notes-organize-tweets/postrun_conflict_check.sh
```

If pairs come back, report them and resolve per **bear-notes skill → iCloud Sync Conflicts** (keep the richer copy, trash the stale one, recreate the survivor if it carries the fork icon — `bearcli` alone cannot clear the stamp).

---

**Final report**: counts per category — `body`, `body_thread`, `body_thread_enrich`, `body_full_text` (settled single tweet rebuilt from Tier 2's untruncated text/quote), `body_link_only`, `body_tombstone`, `thread_marker_only`, `thread_auth_needed`, `thread_retry_pending` (Tier 2 hit a transient error — left unchecked for a later run), `image` (covers both embedded photos and Tier 3 screenshots — same attachment slot), `thread_image`, `inbox_tag`, `extra_tags`. Plus `no_article`, `no_photo_available`, `skipped_no_data`, `failed`. If `thread_auth_needed > 0`, surface the cookie-refresh hint:

> `~/.dotfiles/agents/claude/tools/refresh-x-cookies.sh`

Re-run the workflow after refreshing cookies to backfill the threads.

If the pre-check excluded conflict pairs or the post-run check found duplicate pairs, list them in the report with the resolution pointer (bear-notes skill → iCloud Sync Conflicts).
