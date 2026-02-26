# Codex Skills

Drop local Codex skills in this directory as one folder per skill:

```text
agents/codex/skills/<skill-name>/SKILL.md
```

When `agents/codex/install.sh` runs, each skill directory here is symlinked into:

```text
~/.codex/skills/<skill-name>
```

This keeps skill definitions versioned in dotfiles while remaining available globally to Codex.
