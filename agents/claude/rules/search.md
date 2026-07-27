# search (unified personal search)

- `search` is on PATH — one-shot personal search fusing kpr bookmarks, qmd
  (semantic Bear index), bearcli (live Bear DB), and Spark email (keyword
  search via spark CLI), ranked by RRF + recency.
- For any "where did Kevin see/save/write/mention X" lookup, run
  `search "query" --json` FIRST — it replaces separate kpr/qmd/bearcli searches.
- `--deep` swaps in qmd semantic query (~16s) when keyword search misses.
- `--source kpr,bear` restricts sources (kpr,qmd,bear,spark); `--recency 0`
  disables recency decay; `--limit n` sizes output.
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
