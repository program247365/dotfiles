# kit — Design Spec

**Date:** 2026-04-06
**Status:** Approved

## Overview

`kit` ("Kevin's installed tools") is a shell script CLI that lives in `~/.dotfiles/kit/`. It gives fast, name-first recall of everything the dotfiles declare as installed: Homebrew formulae, casks, custom `bin/` scripts, shell aliases, and shell functions. Selecting a tool renders its full `--help` output inline. An index file keeps startup instant.

## Structure & Installation

```
kit/
  kit           # main executable shell script (bash)
  README.md     # documents kit, name origin, all commands
  install.zsh   # sourced by dotfiles bootstrap — symlinks kit into bin/
```

`install.zsh` symlinks `kit/kit` → `~/.dotfiles/bin/kit`, which is already on PATH via dotfiles. Running `dot` (the existing bootstrap) triggers `kit index` after `brew bundle`, so the index is always fresh after a dotfiles sync.

The index lives at `~/.kit/index.json` — machine-local state, not committed to the repo.

## Index Schema

`~/.kit/index.json` is an array of objects:

```json
{
  "name": "bat",
  "type": "brew",
  "description": "A cat clone with syntax highlighting",
  "dotfiles_added": "2024-03-15",
  "installed": true,
  "installed_at": "2024-03-16",
  "help_flag": "--help"
}
```

**Fields:**

| Field | Description |
|---|---|
| `name` | Command name |
| `type` | `brew`, `cask`, `bin`, `alias`, `function` |
| `description` | From Brewfile inline comment, script header comment, or alias comment |
| `dotfiles_added` | Date the entry first appeared in dotfiles (from `git log`) |
| `installed` | Whether the tool is actually present on this machine |
| `installed_at` | Date brew installed it (`brew info --json`); null for bin/alias/function |
| `help_flag` | Defaults to `--help`; can be manually overridden in `index.json` for tools that use `-h` or `help` — `kit index` will not overwrite a manually set value |

## Index Sources

| Source | Extracts |
|---|---|
| `Brewfile` formulae | name, inline comment as description, tap entries |
| `Brewfile` casks | name, inline comment as description |
| `bin/` scripts | filename as name, first `#` comment block as description |
| `zsh/aliases.zsh` + other `*.zsh` alias files | alias name, RHS command, inline comment |
| `functions/functions.zsh` | function name, first comment line as description |
| `brew list --formula` + `brew list --cask` | cross-ref: sets `installed: true/false` |
| `brew info <name> --json` | `installed_at` timestamp |
| `git log --follow Brewfile` | `dotfiles_added` date (first commit adding that line) |

## Commands

```
kit                   # interactive sk picker over all entries
kit <query>           # sk picker pre-filtered to <query>
kit index             # rebuild ~/.kit/index.json from scratch
kit recent [n]        # n most recently added/installed tools (default: 10)
kit missing           # tools declared in dotfiles but not installed on this machine
```

## Interactive Picker UX

1. Load `~/.kit/index.json` (auto-run `kit index` if missing)
2. Format each entry as: `<name>  [<type>]  <description>`
3. Pipe to `sk` for fuzzy selection
4. On selection:
   - If `installed: true` — run `<name> <help_flag>` and render output with `bat`, paged via `less`
   - If `installed: false` — print install command (`brew install <name>`) instead of running `--help`
5. Tools with `installed: false` display a `[not installed]` suffix in the picker

## `kit recent` Output Format

```
bat          brew       added 2024-03-15  installed 2024-03-16
apfel        brew       added 2026-04-06  not yet installed
```

## Stale Index Detection

On each `kit` invocation, compare the mtime of `~/.kit/index.json` against `Brewfile` and all sourced `.zsh` files. If any source is newer than the index, print a non-blocking warning and proceed:

```
⚠ index may be stale (Brewfile changed) — run 'kit index' to refresh
```

`kit index` always rebuilds from scratch — no partial updates.

## What kit Does NOT Do

- Cache `--help` output (deferred as YAGNI — live execution is fast enough)
- Scan all of PATH (only dotfiles-declared sources are authoritative)
- Run `--help` on every tool during index build (too slow; deferred to selection)

## Dependencies

All already present in dotfiles:
- `sk` — fuzzy picker
- `bat` — syntax-highlighted paging of `--help` output
- `jq` — JSON index read/write
- `git` — `dotfiles_added` date extraction
- `brew` — cross-reference and `installed_at` timestamps
