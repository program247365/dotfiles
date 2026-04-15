# Pi

Pi integration managed from this dotfiles repo.

## What The Installer Manages

- `~/.pi/agent/settings.json` -> symlinked from dotfiles
- `~/.pi/agent/AGENTS.md` -> symlinked from dotfiles
- `~/.pi/agent/models.json` -> copied once from `models.json.default`, then left machine-local
- `~/.kevin/bin/pi` -> symlink to the global `pnpm` install

## Install

Base install:

```bash
sh ~/.dotfiles/agents/pi/install.sh
```

Install Pi plus Ollama, and ensure the Ollama API is running:

```bash
sh ~/.dotfiles/agents/pi/install.sh --install-ollama
```

The installer uses:

```bash
pnpm add -g @mariozechner/pi-coding-agent
```

When `--install-ollama` is passed:

- if `ollama` is missing, the installer runs `brew install ollama`
- it then starts Ollama
- it waits for `http://127.0.0.1:11434/api/tags` to respond before finishing

The automatic Ollama install/start path uses:

```bash
brew install ollama
```

and then either:

```bash
brew services start ollama
```

or, if Homebrew services are unavailable:

```bash
ollama serve
```

## First-Time Setup

Recommended first-time flow:

1. Run the base install or the Ollama-enabled install.
2. Set up hosted provider auth.
3. Run the preflight to see what local models this machine can handle.
4. Optionally bootstrap recommended local models.
5. Start Pi and use `/model` or `Ctrl+L` to confirm the available model IDs Pi sees.

If you want Anthropic via API key instead of subscription billing:

```bash
export ANTHROPIC_API_KEY=...
```

If you want OpenAI or Gemini too:

```bash
export OPENAI_API_KEY=...
export GEMINI_API_KEY=...
```

Or configure credentials locally in:

```bash
~/.pi/agent/auth.json
```

## Local Models

Pi local-model config is intentionally split in two:

- `settings.json` is repo-managed and stable.
- `models.json` starts from a committed default but becomes local to the machine after first install.

That split lets you keep a good default provider catalog in git without overwriting machine-specific ports, temporary experiments, or local-only model tweaks later.

### Preflight

```bash
~/.dotfiles/agents/pi/system-preflight-check.sh
```

This inspects the machine and classifies the curated Ollama models as:

- `recommended`
- `borderline`
- `not recommended`

It also reports:

- whether `pi` is installed
- whether `ollama` is installed
- whether `apfel` is installed
- how much RAM, CPU, and free disk the machine currently has

### Optional Local Model Bootstrap

```bash
~/.dotfiles/agents/pi/install-local-models.sh --recommended
```

This script:

- runs the preflight automatically
- shows memory and CPU guidance for each model
- prints the exact `ollama pull ...` commands it will run
- skips models that are already installed
- can install Ollama for you with `--install-ollama`
- does not overwrite `~/.pi/agent/models.json`

Useful variants:

```bash
~/.dotfiles/agents/pi/install-local-models.sh --dry-run
~/.dotfiles/agents/pi/install-local-models.sh --all-borderline
~/.dotfiles/agents/pi/install-local-models.sh --install-ollama --recommended
~/.dotfiles/agents/pi/install-local-models.sh qwen2.5-coder:14b
```

## Runtime Files

Managed by dotfiles:

- `~/.pi/agent/settings.json`
- `~/.pi/agent/AGENTS.md`

Seeded once, then machine-local:

- `~/.pi/agent/models.json`

Typically local-only:

- `~/.pi/agent/auth.json`

## Custom Models And Providers

Pi uses `~/.pi/agent/models.json` for custom providers like:

- Ollama
- LM Studio
- `apfel`
- other OpenAI-compatible local or remote endpoints

This repo ships a committed `models.json.default` that includes:

- an `ollama` provider on `http://127.0.0.1:11434/v1`
- an `apfel` provider on `http://127.0.0.1:11435/v1`
- a curated starting set of local model IDs

Having those entries in config does not mean the weights are downloaded. That is why the optional bootstrap script exists separately.

## Daily Usage

Useful commands after setup:

```bash
pi
pipreflight
pimodels --recommended
piensure qwen2.5-coder:7b
```

`piensure <model>` checks whether the Ollama model is already installed, offers to run `ollama pull <model>` if it is missing, and then launches `pi`.

Inside Pi:

- `/model` opens model selection
- `Ctrl+L` opens the model picker
- `Ctrl+P` cycles the enabled model shortlist
- `/login` authenticates subscription-based providers
- `/logout` removes a provider login so API-key auth can take over

See [LOCAL_MODELS.md](/Users/kevin/.dotfiles/agents/pi/LOCAL_MODELS.md) for setup details and recommendations.
