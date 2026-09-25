export EDITOR='nvim'

# Add dotfiles bin/ to PATH for scripts like fresh
export PATH="$ZSH/bin:$PATH"

# Add ~/.local/bin to PATH — home of native single-binary installers
# (Claude Code, uv, herdr, cursor-agent). Loaded after mise/path.zsh so these
# win over anything mise puts on PATH.
export PATH="$HOME/.local/bin:$PATH"
