# Claude Global Instructions

Use @~/.claude/SOFTWARE_ENGINEERING.md as the baseline software engineering philosophy.

## Behavior

- Ask before taking any irreversible action: git push, file deletion, branch reset, external API calls.

## Dotfiles

- When working in `~/.dotfiles`, follow project config in `~/.dotfiles/.claude`.
- Treat `agents/philosophy/SOFTWARE_ENGINEERING.md` as the canonical source.

## WORKLOG.md

If a `WORKLOG.md` exists in the current project root, read it at session start to
pick up context from prior sessions. At the end of each session, append a dated
entry in this format:

```
## YYYY-MM-DD: <one-line summary of what we worked on>
- What changed
- What we decided and why
- What to revisit next time
```

Do not rewrite prior entries. Append only.
