# search (unified personal search)

- `search` is on PATH — one-shot personal search. Its backbone since 0.7.0
  is a local FTS5 full-text **index** over everything enumerable: Bear
  notes, iMessage, Reminders, kpr bookmarks, stoa RSS entries, and
  coding-agent session transcripts (Claude Code ~/.claude/projects, Codex
  ~/.codex/sessions, pi ~/.pi/agent/sessions). Fused with it live: bearcli
  (Bear DB), Spark email, bh browser history (Safari/Chrome/Firefox),
  kbr.sh blog posts, iMessage/SMS, Reminders (open todos by default,
  `--completed` adds done ones; DB-read sources need Full Disk Access), and
  the agent-transcript rg sources — ranked by RRF + recency. kpr and stoa
  are index-only (their live CLIs were the slow spawns; the index covers
  their whole corpus). On a TTY it opens an fzf picker by default (results
  stream in; enter opens the hit — agent-session hits resume that session);
  piped/`--json` output is a plain list (agents are unaffected); `--list`
  forces the static list on a TTY.
- For any "where did Kevin see/save/write/mention X" lookup, run
  `search "query" --json` FIRST — it replaces separate kpr/qmd/bearcli
  searches. Phrase the query the way the thing is remembered: the index
  matches full body text, so words from inside a note/message/session hit
  even when no title contains them (`search help` shows examples).
- `--deep` adds qmd semantic query when keyword search misses (~3s for
  previously-seen queries; a novel query pays 10-30s of LLM query expansion
  once, then it's cached). qmd is deep-only now — it contributes nothing
  without `--deep`, since its default BM25 duplicated the index.
- `search sources --json` is the authority on sources: every source name
  with a description and whether this machine's config enables it. Consult
  it before using `--source`, when unsure what a source covers, or when a
  source returns nothing — don't rely on a memorized roster.
- `--source kpr,bear` restricts a run to those sources; `--recency 0`
  disables recency decay; `--limit n` sizes output. The reminders source
  returns open todos only — `--completed` includes completed ones. The
  agent-session sources (claude, codex, pi) answer "where did Kevin discuss
  X with Claude/Codex/pi"; the claude one excludes the running session. A
  machine without a given agent installed silently contributes nothing for
  that source.
- The `raycast` source is **jump-only, not a search**: Raycast Notes are
  stored encrypted with no read API, so search can't rank them. It always
  returns exactly one dateless hit at score 0, appended as the last row of
  every page (it is excluded from the "N results" count), whose ref
  deep-links into Raycast's own Search Notes (the query is *not* carried
  over — Raycast's Search Notes accepts no starting term, so Kevin retypes
  it there). Agents should read it as "Kevin may want to check Raycast
  Notes by hand", never as a match — and never cite it as a source for
  anything. `--source raycast` is only useful for producing that link.
- Sources are enabled by presence in the config's `sources` block (unlisted
  = off; no config = shipped defaults, which is everything on except kpr,
  stoa, and index-recent). spark needs Spark Desktop running with CLI access
  enabled — if it isn't, search warns and the other sources still return.
- `search doctor` diagnoses missing CLIs, qmd sync age, and FTS index
  staleness, probes chat.db and the reminders stores (missing Full Disk
  Access shows as FAIL, not ok), and rebuilds the installed binary if it's
  older than the checkout.
- `search update qmd` refreshes the qmd index (runs `qmd update`, then
  `qmd embed` only if vectors are needed) and prints a summary. Searches
  against a stale index (>7d) run it automatically before showing results.
- `search update index` rebuilds the FTS5 index (~35s, per-source progress
  on stderr); it also auto-runs when the index is missing or >7d stale, and
  a daily launchd daemon (com.kevin.search-index, 05:30) keeps it fresh.
- `search restart` restarts the web/server launchd daemon (com.kevin.search)
  — needed after installing a new search version, since the long-lived
  server keeps running old code until restarted.
- `search discovery` is browsing, not lookup — a rabbit-hole walk over the
  same corpus for "surface something forgotten/related," no query needed.
  Agents use the stateless JSON contract: `search discovery --json` returns
  one step `{current, neighbors: {topic, time, semantic}}`; continue a walk
  by feeding a neighbor's ref back via `--json --from "<ref>"`; a positional
  query seeds from its top hit; `--source` scopes seeds and shelves. Walk
  state lives in the caller. The first run (or >24h) crawls a local index
  first (~20s, progress on stderr). The card REPL on a TTY and the PWA's 🎲
  button are the human faces — agents stick to `--json`.
- A web UI (mobile PWA + API) exists: `make serve` in the repo (port 3847),
  or `make install-launchdaemon` to run it at login via launchd
  (com.kevin.search; `make uninstall-launchdaemon` removes it).
  It has per-source toggles and streaming results — for Kevin's use, not agents.
- Repo: ~/.kevin/personal-code/search (work machine) or ~/.kevin/code/search
  (personal machine) — use whichever exists. Config: ~/.config/search/config.json
  (weights, rrf_k, half_life_days). Tune weights only with `search eval`.
