# Agents

Agent configuration for tools I use from this dotfiles repo.

The goal is the same across agents:

- Keep configuration in version control.
- Install with symlinks instead of copies.
- Make setup idempotent and scriptable.

## Structure

```text
agents/
├── README.md
├── claude/
│   ├── install.sh
│   ├── home/
│   │   └── CLAUDE.md
│   ├── statusline.sh
│   └── project/
│       ├── settings.local.json
│       └── skills/
├── codex/
│   ├── install.sh
│   ├── home/
│   │   └── AGENTS.md
│   ├── project/
│   │   └── AGENTS.md
│   └── skills/
│       └── README.md
└── philosophy/
    ├── install.sh
    └── SOFTWARE_ENGINEERING.md
```

## Quick Start

Run all installers in this repo:

```bash
~/.dotfiles/script/install
```

Or run only agent installers:

```bash
sh ~/.dotfiles/agents/claude/install.sh
sh ~/.dotfiles/agents/codex/install.sh
sh ~/.dotfiles/agents/philosophy/install.sh
```

## Shared Philosophy

Canonical source:

- `agents/philosophy/SOFTWARE_ENGINEERING.md`

`agents/philosophy/install.sh` links this file to:

- `~/.dotfiles/SOFTWARE_ENGINEERING.md`
- `~/.claude/SOFTWARE_ENGINEERING.md`
- `~/.codex/SOFTWARE_ENGINEERING.md`

It also follows a future-friendly convention: any agent folder under `agents/<name>/` that has an `install.sh` gets a linked `~/.<name>/SOFTWARE_ENGINEERING.md`.

## Always-On Global Behavior

These are the global files that should guide every new session:

- Claude: `~/.claude/CLAUDE.md`
- Codex: `~/.codex/AGENTS.md`

Both of those files explicitly reference:

- `~/.claude/SOFTWARE_ENGINEERING.md` (Claude)
- `~/.codex/SOFTWARE_ENGINEERING.md` (Codex)

Both philosophy files are symlinked to:

- `~/.dotfiles/agents/philosophy/SOFTWARE_ENGINEERING.md`

## Claude Setup

`agents/claude/install.sh` manages:

- `~/.claude/CLAUDE.md` -> `~/.dotfiles/agents/claude/home/CLAUDE.md`
- `~/.claude/statusline.sh` -> `~/.dotfiles/agents/claude/statusline.sh`
- `~/.dotfiles/.claude` -> `~/.dotfiles/agents/claude/project`
- `~/.claude/SOFTWARE_ENGINEERING.md` -> `~/.dotfiles/agents/philosophy/SOFTWARE_ENGINEERING.md`
- `~/.dotfiles/SOFTWARE_ENGINEERING.md` -> `~/.dotfiles/agents/philosophy/SOFTWARE_ENGINEERING.md`

This keeps project Claude settings and skills in repo while remaining active in this workspace.

## Codex Setup

`agents/codex/install.sh` manages:

- `~/.codex/AGENTS.md` -> `~/.dotfiles/agents/codex/home/AGENTS.md`
- `~/.dotfiles/AGENTS.md` -> `~/.dotfiles/agents/codex/project/AGENTS.md`
- `~/.codex/SOFTWARE_ENGINEERING.md` -> `~/.dotfiles/agents/philosophy/SOFTWARE_ENGINEERING.md`
- `~/.codex/skills/<skill-name>` -> `~/.dotfiles/agents/codex/skills/<skill-name>` (for each local skill directory)

Installer behavior:

- Creates missing `~/.codex` and `~/.codex/skills` directories.
- Is idempotent (safe to rerun).
- Backs up existing non-symlink files before replacing them (`.bak.<timestamp>`).

## Add a Codex Skill

1. Create a new directory under `agents/codex/skills/`:

```bash
mkdir -p ~/.dotfiles/agents/codex/skills/my-skill
```

2. Add `SKILL.md`:

```bash
cat > ~/.dotfiles/agents/codex/skills/my-skill/SKILL.md <<'EOF'
---
name: my-skill
description: "What this skill does."
---

# My Skill

Instructions go here.
EOF
```

3. Re-run installer:

```bash
sh ~/.dotfiles/agents/codex/install.sh
```

## Verify

```bash
ls -l ~/.dotfiles/.claude
ls -l ~/.claude/CLAUDE.md
ls -l ~/.claude/statusline.sh
ls -l ~/.dotfiles/AGENTS.md
ls -l ~/.codex/AGENTS.md
ls -l ~/.dotfiles/SOFTWARE_ENGINEERING.md
ls -l ~/.claude/SOFTWARE_ENGINEERING.md
ls -l ~/.codex/SOFTWARE_ENGINEERING.md
ls -la ~/.codex/skills
```

You should see symlinks pointing into `~/.dotfiles/agents/...`.

## Keep Philosophy Up To Date

To ensure both agents always use the latest philosophy:

1. Edit only the canonical file:
   - `~/.dotfiles/agents/philosophy/SOFTWARE_ENGINEERING.md`
2. Commit and sync dotfiles as usual.
3. Re-run installers only when links are missing/broken or on new machines:
   - `~/.dotfiles/script/install`
   - or `sh ~/.dotfiles/agents/claude/install.sh && sh ~/.dotfiles/agents/codex/install.sh && sh ~/.dotfiles/agents/philosophy/install.sh`
4. Start a new Claude/Codex session to ensure updated guidance is loaded.

## Troubleshooting

- Broken symlink after moving dotfiles:
  - Re-run relevant installer script.
- Local file was replaced by installer:
  - Restore from generated backup (`*.bak.<timestamp>`).
- Skill not visible in Codex:
  - Confirm the skill folder contains `SKILL.md`.
  - Re-run `agents/codex/install.sh`.
