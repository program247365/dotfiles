#!/usr/bin/env zsh
#
# Migrate Claude Code from the Homebrew cask to the npm package,
# managed by mise's npm backend so it survives per-project node switches.
# Idempotent: safe to re-run.

set -e

echo "Migrating Claude Code: brew cask -> mise npm backend..."

# 1. Remove the Homebrew cask if present
if brew list --cask claude-code &>/dev/null; then
  echo "Uninstalling brew cask claude-code..."
  brew uninstall --cask claude-code
else
  echo "✓ brew cask claude-code not installed"
fi

# 2. Remove per-node-version npm copies (they shadow the mise tool on PATH)
for node_bin in "$HOME"/.local/share/mise/installs/node/*/bin/claude(N); do
  node_dir="${node_bin:h:h}"
  echo "Removing per-node copy in ${node_dir:t}..."
  npm uninstall -g --prefix "$node_dir" @anthropic-ai/claude-code
done

# 3. Install via mise's npm backend if missing
if ! mise where 'npm:@anthropic-ai/claude-code' &>/dev/null; then
  echo "Installing npm:@anthropic-ai/claude-code via mise..."
  mise use --global 'npm:@anthropic-ai/claude-code'
else
  echo "✓ npm:@anthropic-ai/claude-code already installed via mise"
fi

# 4. Verify end state
echo ""
echo "Verifying..."

if brew list --cask claude-code &>/dev/null; then
  echo "✗ brew cask claude-code is still installed" >&2
  exit 1
fi
echo "✓ Homebrew version is uninstalled"

for leftover in /opt/homebrew/bin/claude /usr/local/bin/claude; do
  if [ -e "$leftover" ]; then
    echo "✗ Leftover binary at $leftover — remove it so mise's copy wins on PATH" >&2
    exit 1
  fi
done
echo "✓ No leftover brew binaries on PATH"

# Resolve through an interactive shell so mise activation is in effect
resolved=$(zsh -ic 'whence -p claude' 2>/dev/null | tail -1)
case "$resolved" in
  "$HOME"/.local/share/mise/installs/npm-anthropic-ai-claude-code/*)
    echo "✓ claude resolves to mise npm tool: $resolved" ;;
  *)
    echo "✗ claude resolves to unexpected location: ${resolved:-not found}" >&2
    exit 1 ;;
esac

echo "✓ $("$resolved" --version | head -1)"
echo ""
echo "Migration complete"
