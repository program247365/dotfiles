# Tool Use Rules

- Prefer dedicated tools over Bash for file operations:
  - Read files: use Read, not cat/head/tail
  - Search files: use Glob, not find/ls
  - Search content: use Grep tool (backed by ripgrep) for standard searches
  - Edit files: use Edit, not sed/awk
  - Write files: use Write, not echo/heredoc
- `rg` (ripgrep, https://github.com/BurntSushi/ripgrep) is installed on this machine.
  Use it via Bash for searches that need rg-specific features:
  - `--type ts` / `--type py` — filter by file type
  - `--multiline` — match patterns across line boundaries
  - `--json` — structured output for piping
  - `-l` — list matching files only
  - `-c` — count matches per file
  - `-A`/`-B`/`-C N` — context lines around matches
  - `--glob "*.test.ts"` — fine-grained file filtering
  The Grep tool covers most standard searches. Reach for `rg` via Bash when you need
  type filtering, multiline matching, or complex pipelines.
- Use Bash only for system commands that require shell execution.
- Run independent tool calls in parallel when there are no dependencies.
- Use subagents (Task tool) for broad codebase exploration, not repeated Grep loops.
- Stop and ask when blocked — don't retry the same failing approach.
