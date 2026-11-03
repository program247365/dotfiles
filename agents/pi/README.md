# Pi

Pi integration managed from this dotfiles repo.

## What The Installer Manages

- `~/.pi/agent/settings.json` -> symlinked from dotfiles
- `~/.pi/agent/presets.json` -> symlinked from dotfiles
- Global instructions: injected by the `shared-rules` extension from the Claude CLAUDE.md, philosophy and rules (no `~/.pi/agent/AGENTS.md`)
- Skills: the `claude-skills` extension shares `~/.claude/skills` with pi
- `~/.kevin/bin/pi` -> symlink to the global `pnpm` install

## Install

```bash
sh ~/.dotfiles/agents/pi/install.sh
```

The installer uses:

```bash
pnpm add -g @earendil-works/pi-coding-agent
```

## First-Time Setup

1. Run the install.
2. Set up hosted provider auth (`/login` inside Pi, or the API keys below).
3. Start Pi and use `/model` or `Ctrl+L` to confirm the model IDs Pi sees.

If you want Anthropic via API key instead of subscription billing:

```bash
export ANTHROPIC_API_KEY=...
```

If you want OpenAI or Gemini too:

```bash
export OPENAI_API_KEY=...
export GEMINI_API_KEY=...
```

Or configure credentials locally in `~/.pi/agent/auth.json` (see
`home/auth.json.example`).

## Runtime Files

Managed by dotfiles:

- `~/.pi/agent/settings.json`
- `~/.pi/agent/presets.json`

Local-only:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/models.json`: custom providers (Ollama, LM Studio, other
  OpenAI-compatible endpoints), if you add any

## Daily Usage

Inside Pi:

- `/model` opens model selection
- `Ctrl+L` opens the model picker
- `Ctrl+P` cycles the enabled model shortlist
- `/login` authenticates subscription-based providers
- `/logout` removes a provider login so API-key auth can take over
