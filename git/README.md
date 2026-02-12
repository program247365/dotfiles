# git-all

Run arbitrary git commands across a set of repos.

I tried several multi-repo tools ([git-workspace](https://github.com/orf/git-workspace), [meta](https://github.com/mateodelnorte/meta), [ghq](https://github.com/x-motemen/ghq)) and none of them did the simple thing I wanted: run path-based git commands across a known set of repos, with no provider integration, no special directory structure, and no dependencies.

`git-all` is a ~40 line zsh script that does exactly that.

## Usage

```
git-all status
git-all pull --rebase
git-all log --oneline -5
git-all stash
```

Any arguments are passed directly to `git`.

## Setup

The config is per-machine and not committed to the dotfiles repo.

1. Copy the example config:
   ```
   cp git-all.config.example git-all.config.local
   ```
2. Edit `git-all.config.local` with your repo paths (one per line).
3. Run `git/install.sh` (or `dot`) to symlink everything:
   - `git-all.config.local` → `~/.config/git-all/config`
   - `git-all.sh` → `~/.kevin/bin/git-all`

On a fresh machine, just create your `git-all.config.local` after cloning dotfiles and run the install.

## Files

| File | Committed | Purpose |
|------|-----------|---------|
| `git-all.sh` | yes | The script |
| `git-all.config.example` | yes | Example config showing the format |
| `git-all.config.local` | no | Your machine's repo list (gitignored) |
