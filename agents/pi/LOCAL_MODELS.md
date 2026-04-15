# Pi Local Models

This setup treats Ollama as the default local serving layer for Pi.

Why Ollama:

- It is the most common local runtime in current coding-agent workflows.
- Pi can talk to it through the local OpenAI-compatible API described in `~/.pi/agent/models.json`.
- Pulling and removing models is simple and explicit.

`apfel` is also supported as a first-class local option, but it is a different tool:

- `apfel` uses Apple's built-in on-device Foundation Model.
- It needs no model downloads.
- Its context window is only 4,096 tokens, so it is convenient for quick local prompts but much weaker than Ollama-backed models for agentic coding.

## Config Split

- `~/.pi/agent/settings.json`
  Managed by dotfiles. This sets the stable Pi defaults and enabled model shortlist.
- `~/.pi/agent/models.json`
  Seeded from dotfiles once, then kept local on the machine.

That means you can keep a committed provider catalog while still editing ports, model entries, or temporary local experiments without fighting the installer.

## Preflight

Run:

```bash
~/.dotfiles/agents/pi/system-preflight-check.sh
```

The preflight checks:

- Apple Silicon vs non-Apple-Silicon
- RAM
- CPU core count
- free disk
- whether `pi`, `ollama`, and `apfel` are installed

It then classifies the curated models as `recommended`, `borderline`, or `not recommended`.

The thresholds are intentionally conservative. The goal is to avoid a bootstrap script that pulls workstation-class models onto a constrained laptop.

## Optional Bootstrap Script

Run:

```bash
~/.dotfiles/agents/pi/install-local-models.sh --recommended
```

Useful variants:

```bash
~/.dotfiles/agents/pi/install-local-models.sh --dry-run
~/.dotfiles/agents/pi/install-local-models.sh --all-borderline
~/.dotfiles/agents/pi/install-local-models.sh qwen2.5-coder:14b
```

What it does:

- runs the preflight first
- shows the exact `ollama pull ...` commands
- shows approximate memory and CPU guidance
- asks for confirmation before it downloads anything
- skips models that are already installed
- can install Ollama first with `--install-ollama`

If you want the script to handle Ollama installation too:

```bash
~/.dotfiles/agents/pi/install-local-models.sh --install-ollama --recommended
```

## On-Demand Model Install Helper

If Pi is configured to use an Ollama model that is not installed yet, use:

```bash
piensure qwen2.5-coder:7b
```

This helper:

- verifies that `pi` and `ollama` are installed
- verifies that the Ollama API is responding
- checks whether the target model is already present in `ollama list`
- offers to run `ollama pull <model>` if it is missing
- launches `pi` after the model is available

You can also pass Pi args through after `--`:

```bash
piensure qwen2.5-coder:7b -- --model qwen2.5-coder:7b
```

## Recommended Ollama Models

These are the defaults this repo is prepared for:

### `qwen2.5-coder:7b`

- Download size: 4.7 GB
- Context: 32K
- Minimum target: 8 GB RAM / 4+ CPU cores
- Better target: 16 GB RAM / 8+ CPU cores
- Role: best everyday local coding default

Pull:

```bash
ollama pull qwen2.5-coder:7b
```

### `qwen2.5-coder:14b`

- Download size: 9.0 GB
- Context: 32K
- Minimum target: 16 GB RAM / 6+ CPU cores
- Better target: 24 GB RAM / 8+ CPU cores
- Role: stronger coding model when the machine has more headroom

Pull:

```bash
ollama pull qwen2.5-coder:14b
```

### `gemma4:e2b`

- Download size: 7.2 GB
- Context: 128K
- Minimum target: 8 GB RAM / 4+ CPU cores
- Better target: 12 GB RAM / 8+ CPU cores
- Role: fastest useful local fallback

Pull:

```bash
ollama pull gemma4:e2b
```

### `gemma4:e4b`

- Download size: 9.6 GB
- Context: 128K
- Minimum target: 12 GB RAM / 6+ CPU cores
- Better target: 18 GB RAM / 8+ CPU cores
- Role: balanced local reasoning and coding model

Pull:

```bash
ollama pull gemma4:e4b
```

### `gpt-oss:20b`

- Download size: 14 GB
- Context: 128K
- Minimum target: 16 GB RAM / 8+ CPU cores
- Better target: 24 GB RAM / 12+ CPU cores
- Role: strong local agentic model, but heavy on 16 GB systems

Pull:

```bash
ollama pull gpt-oss:20b
```

### `qwen3-coder:30b`

- Download size: 19 GB
- Context: 256K
- Minimum target: 24 GB RAM / 10+ CPU cores
- Better target: 32 GB RAM / 12+ CPU cores
- Role: workstation-class coding model, not a 16 GB laptop default

Pull:

```bash
ollama pull qwen3-coder:30b
```

## Ollama Setup

If Ollama is not installed:

```bash
brew install ollama
```

Start it:

```bash
ollama serve
```

The bootstrap script can also install Ollama for you:

```bash
~/.dotfiles/agents/pi/install-local-models.sh --install-ollama --recommended
```

If you use the Pi installer instead, it can also install and start Ollama:

```bash
sh ~/.dotfiles/agents/pi/install.sh --install-ollama
```

## apfel Setup

`apfel` gives Pi access to Apple's built-in local model through an OpenAI-compatible server.

Install it:

```bash
brew install Arthur-Ficial/tap/apfel
```

Run the server:

```bash
apfel --serve
```

The committed `models.json.default` includes an `apfel` provider entry pointing at `http://127.0.0.1:11435/v1`.

If your local `apfel` server uses a different port, edit `~/.pi/agent/models.json`.

No Pi plugin is required. Pi can talk to `apfel` as a normal custom OpenAI-compatible provider.

## Notes

- Having a model in `models.json` does not mean its weights are already downloaded.
- Ollama model downloads and Pi provider config are separate concerns by design.
- On Apple Silicon, RAM is usually the real limit. CPU matters more for responsiveness than for raw fit.
- The committed defaults are intentionally conservative for laptops. If you move to a higher-memory machine, rerun the preflight and expand the local shortlist there.
