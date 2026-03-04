# QMD

- `qmd` is on PATH — a local hybrid search engine for notes, docs, and transcripts.
- Use `qmd search "query" -c bear` for fast keyword search of Bear notes.
- Use `qmd query "query" -c bear` for best-quality hybrid search (BM25 + vectors + reranking).
- Use `qmd search "query"` (no -c) to search across all indexed collections.
- Do not run `qmd collection add`, `qmd embed`, or `qmd update` automatically — write out commands for the user to run.
