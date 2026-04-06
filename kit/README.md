# kit — Kevin's installed tools

`kit` is a shell CLI that indexes everything declared in your dotfiles and gives you instant fuzzy recall with full `--help` output.

The name stands for **K**evin's **I**nstalled **T**ools.

## Usage

```sh
kit              # open interactive fuzzy picker
kit <query>      # open picker pre-filtered to <query>
kit index        # rebuild the index (~/.kit/index.json)
kit recent [n]   # show n most recently added tools (default: 10)
kit missing      # show tools declared in dotfiles but not yet installed
```

## How it works

`kit index` reads your dotfiles and builds `~/.kit/index.json`:

| Source | Entry type |
|---|---|
| `Brewfile` formulae | `brew` |
| `Brewfile` casks | `cask` |
| `bin/` scripts | `bin` |
| `zsh/aliases.zsh` (and others) | `alias` |
| `functions/functions.zsh` | `function` |

Entries are cross-referenced against `brew list` to track what's actually installed. `dotfiles_added` is extracted from git log. `installed_at` comes from `brew info`.

## Stale index

If a source file (Brewfile, aliases, etc.) is newer than the index, `kit` prints a warning. Run `kit index` to refresh.

The index is rebuilt automatically when you run `dot`.

## Index location

`~/.kit/index.json` — machine-local, not committed to the repo.

## Dependencies

All already in your Brewfile: `sk`, `bat`, `jq`, `git`, `brew`.
