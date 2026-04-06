# kit — Kevin's installed tools

`kit` is a shell CLI that indexes everything declared in your dotfiles and gives you instant fuzzy recall of every tool on your machine.

The name stands for **K**evin's **I**nstalled **T**ools.

## Usage

```sh
kit              # open interactive fuzzy picker
kit <query>      # open picker pre-filtered to <query>
kit index        # rebuild the index (~/.kit/index.json)
kit recent [n]   # show n most recently added tools (default: 10)
kit missing      # show tools declared in dotfiles but not yet installed
kit add <name>   # add a formula to Brewfile, install it, and reindex
```

## Picker keys

| Key | Action |
|---|---|
| `Enter` | Run the selected tool (prompts for optional args) |
| `ctrl-h` | Show full `--help` for the selected tool |
| `Esc` / `ctrl-c` | Exit |

The right-hand preview pane shows the first 50 lines of `--help` as you browse.

## How it works

`kit index` reads your dotfiles and builds `~/.kit/index.json`:

| Source | Entry type | Description source |
|---|---|---|
| `Brewfile` formulae | `brew` | Inline comment → brew formula `desc` fallback |
| `Brewfile` casks | `cask` | Inline comment |
| `bin/` scripts | `bin` | First comment line |
| `zsh/aliases.zsh` (and others) | `alias` | Inline comment or alias expansion |
| `functions/functions.zsh` | `function` | Preceding comment line |

Entries are cross-referenced against `brew list` to track what's installed. `dotfiles_added` comes from git log. `installed_at` comes from `brew info`.

## Stale index

If a source file (Brewfile, aliases, etc.) is newer than the index, `kit` prints a one-line warning. Run `kit index` to refresh.

The index is rebuilt automatically when you run `dot`.

## Index location

`~/.kit/index.json` — machine-local, not committed to the repo.

## Dependencies

All already in your Brewfile: `sk`, `bat`, `jq`, `git`, `brew`.
