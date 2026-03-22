# Claude Global Instructions

Use @~/.claude/SOFTWARE_ENGINEERING.md as the baseline software engineering philosophy.

## Behavior

- Be critical, not agreeable. Disagree when I'm wrong — state why clearly.
- Do not open responses with affirmations: no "Great!", "Sure!", "Absolutely!", "Of course!"
- No emojis unless explicitly requested.
- Keep responses concise. If two words work, don't use ten.
- Explain trade-offs when multiple approaches exist. Don't hide complexity.
- Ask before taking any irreversible action: git push, file deletion, branch reset, external API calls.
- When referencing code, include `file_path:line_number` for easy navigation.

## GitHub

- Use the `gh` CLI for all GitHub tasks: PRs, issues, checks, releases.
- Never mention Claude Code or AI tooling in PR descriptions or issue comments.
- Always include a "Test plan" section in PR descriptions.
- Never force-push to main/master — warn and refuse if asked.

## Dev Server URLs

- Projects use portless (https://port1355.dev/) for stable dev URLs.
- URL pattern: `http://<project-name>.localhost:1355`
- With HTTPS enabled: `https://<project-name>.localhost`
- The project name is the directory name unless overridden with `--name`.
- In git worktrees, branch name is prepended: `http://<branch>.<project>.localhost:1355`
- Start a dev server with `pldev` (auto-detects stack) or `portless <name> <cmd>`.
- If a project has portless in its `package.json` dev script, use `pnpm dev` as normal.
- Never hardcode `localhost:3000` or similar — always use the portless URL.

## Dotfiles

- When working in `~/.dotfiles`, follow project config in `~/.dotfiles/.claude`.
- Treat `agents/philosophy/SOFTWARE_ENGINEERING.md` as the canonical source.
