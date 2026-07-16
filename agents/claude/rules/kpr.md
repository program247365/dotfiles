# kpr (Keeper bookmarks)

- `kpr` is on PATH — CLI for Kevin's bookmarks at kpr.sh (self-hosted Pinboard alternative).
- Use `kpr search "query" --json` to find saved bookmarks (full-text + tags).
- Use `kpr ls --tag a+b --json` to list by tag(s); `--unread` for the read-later queue.
- Use `kpr add <url> --title t --tags "a b"` to save a bookmark. Re-adding an existing URL merges: only passed flags change.
- Use `kpr update <id> ...` to edit; ids are on the `id:` line of listings.
- `kpr tags --json` lists top tags — check it before inventing new tags.
- Do NOT run `kpr rm <id>` without explicit confirmation — deletion is immediate and permanent.
- Full reference: ~/.kevin/code/keeper/cli/README.md. Config: ~/.config/kpr/config.json (never read or print the token).
