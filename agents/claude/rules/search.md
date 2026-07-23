# search (unified personal search)

- `search` is on PATH — one-shot personal search fusing kpr bookmarks, qmd
  (semantic Bear index), and bearcli (live Bear DB), ranked by RRF + recency.
- For any "where did Kevin see/save/write/mention X" lookup, run
  `search "query" --json` FIRST — it replaces separate kpr/qmd/bearcli searches.
- `--deep` swaps in qmd semantic query (~16s) when keyword search misses.
- `--source kpr,bear` restricts sources; `--recency 0` disables recency decay;
  `--limit n` sizes output.
- `search doctor` diagnoses missing CLIs and index staleness.
- Repo: ~/.kevin/personal-code/search. Config: ~/.config/search/config.json
  (weights, rrf_k, half_life_days). Tune weights only with `search eval`.
