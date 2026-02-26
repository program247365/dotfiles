# Git Workflow Rules

- Use `gh` CLI for all GitHub tasks (PRs, issues, checks, releases).
- Never mention Claude Code or AI in PR descriptions or issue comments.
- Always include a "Test plan" section in PR descriptions.
- Prefer creating new commits over amending; never amend published commits.
- Never skip hooks (`--no-verify`) unless explicitly asked.
- Never force-push to main/master; warn and refuse if asked.
- Confirm before any destructive git operation (reset --hard, branch -D, etc).
- Stage specific files by name rather than `git add -A` or `git add .`.
