#!/usr/bin/env zsh
#
# Migrate Claude Code from the mise npm backend to the native installer.
#
# Why: as of 2.1.x the npm package ships the same native binary as the
# standalone installer and no longer runs on Node, so the mise npm backend
# (added 2026-06-10 to survive per-project node switches) buys nothing. Worse,
# Claude Code's own background auto-updater does `npm i -g` into whatever
# `npm config get prefix` points at — mise's *node* install — so mise and
# Claude were updating two different copies and the one that won PATH was not
# the one mise managed.
#
# End state: a single self-updating install at ~/.local/bin/claude.
# Idempotent: safe to re-run.

set -e

# Skip rather than fail: `dot` runs migrations under `set -e`, so exiting
# non-zero here would abort the whole run.
if [[ -n "$CLAUDECODE" ]]; then
  echo "⊘ Skipped — run this from a plain shell, not inside a Claude Code session."
  echo "  The installer rewrites ~/.claude.json, which a live session also writes."
  exit 0
fi

# Already migrated — nothing to do.
if [[ "$(whence -p claude 2>/dev/null)" == "$HOME/.local/bin/claude" ]] \
  && [[ ! -e /opt/homebrew/bin/claude ]]; then
  echo "✓ Claude Code already on the native install"
  exit 0
fi

echo "Migrating Claude Code: mise npm backend -> native installer..."

# 1. Drop the mise tool entry (also prunes the installed version)
if mise ls --json 2>/dev/null | grep -q 'npm:@anthropic-ai/claude-code'; then
  echo "Removing mise tool npm:@anthropic-ai/claude-code..."
  mise unuse --global 'npm:@anthropic-ai/claude-code' || true
else
  echo "✓ mise tool npm:@anthropic-ai/claude-code not present"
fi

# 2. Remove npm global copies. Claude's auto-updater installs into the active
#    npm prefix, so every node install mise has ever activated may hold one.
for node_bin in "$HOME"/.local/share/mise/installs/node/*/bin/claude(N); do
  node_dir="${node_bin:h:h}"
  echo "Removing npm global copy in node/${node_dir:t}..."
  npm uninstall -g --prefix "$node_dir" @anthropic-ai/claude-code || true
done

if [[ -e /opt/homebrew/bin/claude ]]; then
  echo "Removing npm global copy in /opt/homebrew..."
  npm uninstall -g --prefix /opt/homebrew @anthropic-ai/claude-code || true
fi

# 3. Remove the Homebrew cask if it ever came back
for cask in claude-code@latest claude-code; do
  if brew list --cask "$cask" &>/dev/null; then
    echo "Uninstalling brew cask ${cask}..."
    brew uninstall --cask "$cask"
  fi
done

# 4. Install natively (self-updating, ~/.local/bin/claude -> ~/.local/share/claude/versions/)
echo "Installing Claude Code via the native installer..."
curl -fsSL https://claude.ai/install.sh | bash

# 5. Drop the throttle cache left behind by the old shell-function updater
[[ -f "$HOME/.claude/.update_check" ]] && rm -f "$HOME/.claude/.update_check"

# 6. Verify end state
echo ""
echo "Verifying..."

for leftover in /opt/homebrew/bin/claude /usr/local/bin/claude; do
  if [[ -e "$leftover" ]]; then
    echo "✗ Leftover binary at $leftover — remove it so the native install wins on PATH" >&2
    exit 1
  fi
done
echo "✓ No leftover brew binaries on PATH"

for leftover in "$HOME"/.local/share/mise/installs/node/*/bin/claude(N) \
                "$HOME"/.local/share/mise/installs/npm-anthropic-ai-claude-code(N); do
  echo "✗ Leftover mise-managed copy at $leftover" >&2
  exit 1
done
echo "✓ No leftover mise-managed copies"

# Resolve through an interactive shell so the full PATH is in effect
resolved=$(zsh -ic 'whence -p claude' 2>/dev/null | tail -1)
if [[ "$resolved" != "$HOME/.local/bin/claude" ]]; then
  echo "✗ claude resolves to unexpected location: ${resolved:-not found}" >&2
  echo "  Expected $HOME/.local/bin/claude — is ~/.local/bin on PATH? (system/env.zsh)" >&2
  exit 1
fi
echo "✓ claude resolves to the native install: $resolved"

install_method=$(python3 -c "import json;print(json.load(open('$HOME/.claude.json')).get('installMethod'))" 2>/dev/null)
if [[ "$install_method" != "native" ]]; then
  echo "✗ ~/.claude.json installMethod is '${install_method}', expected 'native'" >&2
  exit 1
fi
echo "✓ installMethod is native (background auto-update enabled)"

echo "✓ $("$resolved" --version | head -1)"
echo ""
echo "Migration complete — Claude Code now updates itself. Run 'claude update' to force one."
echo ""
echo "⚠ Already-open shells still hold the OLD claude() function and a PATH without"
echo "  ~/.local/bin. Since this migration just deleted the binaries that function"
echo "  looked for, it will fail there until you reload. In every open shell run:"
echo ""
echo "      reload!"
echo ""
echo "  (or just open a new tab). Do NOT re-run the installer — 'claude doctor' from"
echo "  a fresh shell is the honest check."
