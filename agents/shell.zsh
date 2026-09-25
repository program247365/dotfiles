# Claude Code shell aliases and functions
# Auto-sourced via $ZSH/*/*.zsh glob in zshrc.symlink

alias c="claude"

# Force an immediate update. Claude Code self-updates in the background anyway;
# see what changed with /release-notes inside a session.
alias ccu="claude update"

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

pipreflight() {
  bash "$HOME/.dotfiles/agents/pi/system-preflight-check.sh" "$@"
}

pimodels() {
  bash "$HOME/.dotfiles/agents/pi/install-local-models.sh" "$@"
}

piensure() {
  bash "$HOME/.dotfiles/agents/pi/pi-local-ensure.sh" "$@"
}
