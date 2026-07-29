# search (unified personal search)

- `search` is on PATH — one-shot personal search fusing kpr bookmarks, qmd
  (semantic Bear index), bearcli (live Bear DB), Spark email (keyword search
  via spark CLI), local browser history (bh: Safari/Chrome/Firefox), stoa
  RSS entries, iMessage/SMS (imsg; needs Full Disk Access for the terminal),
  and coding-agent session transcripts (Claude Code
  ~/.claude/projects, Codex ~/.codex/sessions, pi ~/.pi/agent/sessions),
  ranked by RRF + recency. On a TTY it opens an fzf picker by default;
  piped/`--json` output is a plain list (agents are unaffected).
- For any "where did Kevin see/save/write/mention X" lookup, run
  `search "query" --json` FIRST — it replaces separate kpr/qmd/bearcli searches.
- `--deep` swaps in qmd semantic query when keyword search misses (~3s for
  previously-seen queries; a novel query pays 10-30s of LLM query expansion
  once, then it's cached).
- `--source kpr,bear` restricts sources
  (kpr,qmd,bear,spark,browser-history,stoa,imessage,claude,codex,pi); `--recency 0`
  disables recency decay; `--limit n` sizes output. The agent-session
  sources answer "where did Kevin discuss X with Claude/Codex/pi"; the
  claude one excludes the running session. A machine without a given agent
  installed silently contributes nothing for that source.
- Sources are enabled by presence in the config's `sources` block (unlisted =
  off; no config = all on). spark needs Spark Desktop running with CLI access
  enabled — if it isn't, search warns and the other sources still return.
- `search doctor` diagnoses missing CLIs and index staleness.
- `search update qmd` refreshes the qmd index (runs `qmd update`, then
  `qmd embed` only if vectors are needed) and prints a summary. Searches
  against a stale index (>7d) run it automatically before showing results.
- Repo: ~/.kevin/personal-code/search (work machine) or ~/.kevin/code/search
  (personal machine) — use whichever exists. Config: ~/.config/search/config.json
  (weights, rrf_k, half_life_days). Tune weights only with `search eval`.
