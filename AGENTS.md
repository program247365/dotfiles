# Dotfiles

Kevin's macOS dotfiles. Shared instructions for every coding agent (Claude
Code, Codex, pi) working in this repo. Claude Code reads this file directly;
don't add a `CLAUDE.md` at the root, or Claude stops reading this one.

## Layout

- Topic directories (`zsh/`, `git/`, `docker/`, `mise/`, ...). The zshrc
  sources every `*/*.zsh`: `path.zsh` first, `completion.zsh` last, and
  `install.zsh`/`set-defaults.zsh` never.
- `*/install.sh`: run by `script/install` (sorted, failures collected).
  `mise/` and `node/` run first.
- `*.symlink` files are linked into `$HOME` by `script/bootstrap`.
- `migrations/YYYY-MM-DD-*.zsh`: run on every `dot`. There is no "already
  ran" record, so each one must guard itself.
- `Brewfile`: everything Homebrew, cask and `mas` installs.
- `agents/`: agent config, installed by symlink. See `agents/README.md`.
  - `agents/philosophy/SOFTWARE_ENGINEERING.md` is the canonical philosophy.
  - `agents/claude/home/` is `~/.claude/` (CLAUDE.md, settings.json, skills).
  - `agents/claude/rules/` is `~/.claude/rules/`; pi loads it too.
  - `agents/claude/project/` is this repo's `.claude/` (settings.local.json).

## Conventions

- Installers and migrations must be idempotent and safe on a fresh machine.
  A missing prerequisite should skip with a note, not fail.
- Edit files in the repo, never through the symlinks in `$HOME`.
- Machine-local state stays out of git (`*.local*`, tokens, `auth.json`).

## Verify

No `make check` yet. Before calling a change done:

- `bash -n` / `zsh -n` every shell file you touched.
- Re-run the installer you touched and confirm its links resolve
  (`ls -l` the targets; no dangling symlinks).
- `kit/test.sh` if you touched `kit/`.

## WORKLOG.md

Read `WORKLOG.md` at session start. At the end, append a dated entry
(`## YYYY-MM-DD: summary`, then what changed, what was decided and why,
what to revisit). Never rewrite earlier entries.
