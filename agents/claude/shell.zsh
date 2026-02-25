# Claude Code shell aliases and functions
# Auto-sourced via $ZSH/*/*.zsh glob in zshrc.symlink

alias c="claude"

# Claude Code Upgrade - upgrades claude-code via brew and shows version
# Usage: ccu [-n|--notes] to open release notes after upgrade
ccu() {
  local show_notes=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--notes)
        show_notes=true
        shift
        ;;
      -h|--help)
        echo "Usage: ccu [-n|--notes] [-h|--help]"
        echo ""
        echo "Upgrade Claude Code via Homebrew"
        echo ""
        echo "Options:"
        echo "  -n, --notes  Open release notes in browser after upgrade"
        echo "  -h, --help   Show this help message"
        return 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use 'ccu --help' for usage"
        return 1
        ;;
    esac
  done

  echo "Upgrading Claude Code..."
  echo ""

  brew upgrade claude-code

  echo ""
  local version=$(brew info claude-code --json=v2 2>/dev/null | grep -o '"installed": "[^"]*"' | head -1 | cut -d'"' -f4)
  echo "Installed version: $version"

  if $show_notes; then
    echo ""
    echo "Opening release notes..."
    open "https://github.com/anthropics/claude-code/releases"
  else
    echo ""
    echo "Tip: Run 'ccu -n' to open release notes in browser"
  fi
}

# Claude with zero context: no MCPs, no skills/hooks, optional system prompt
# Usage: c0 [system prompt...]
# Example: c0 you are a bash expert
c0() {
  local base_cmd=(claude --strict-mcp-config --disable-slash-commands --setting-sources "")
  if [[ $# -gt 0 ]]; then
    "${base_cmd[@]}" --system-prompt "$*"
  else
    "${base_cmd[@]}"
  fi
}
