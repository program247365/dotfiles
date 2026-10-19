---
name: make-check-repo
description: Use when Kevin runs /make-check-repo, when a new repo has just been created or scaffolded (git init, create-*-app, cargo new, uv init), or when an existing repo has no single local command that runs everything CI runs (no `make check`), so agents can't verify their own work before calling it done.
---

# make-check-repo — a local CI run behind one command

One strict command, `make check`, that runs every automated quality gate the
repo has: format check, lint, typecheck, tests, build, and whatever else CI
does. Agents run it before declaring work done. The stricter the check, the
better the agent output.

This skill builds that check for an **existing** repo, runs it until green,
and records it in `AGENTS.md`.

## 1. Survey what the repo already automates

Read, don't guess:

- **CI config is the spec:** `.github/workflows/*`, `.gitlab-ci.yml`,
  `.circleci/`, `buildkite`, `Jenkinsfile`. List every step that is a check.
- **Existing entry points:** `Makefile`, `justfile`, `Taskfile.yml`,
  `package.json` scripts, `pyproject.toml` (`[tool.*]`, scripts), `Cargo.toml`,
  `go.mod`, `mise.toml`, `.pre-commit-config.yaml`, `lefthook.yml`, husky.
- **Tool configs present but not wired up:** eslint/biome/oxlint, prettier,
  tsconfig, ruff/mypy/pyright, clippy/rustfmt, golangci-lint, shellcheck,
  cspell, knip, markdownlint, actionlint, hadolint.
- **Lockfile → package manager:** bun.lock, pnpm-lock.yaml, uv.lock, etc.
  Use the one the repo uses.

## 2. Pick the gates

Include every gate CI runs, plus cheap gates whose config already exists in
the repo. Order cheap to expensive:

| Gate | Examples |
|---|---|
| format (check mode, never write) | `prettier --check`, `biome format`, `ruff format --check`, `cargo fmt --check`, `gofmt -l` |
| lint | eslint, biome lint, ruff, clippy `-D warnings`, golangci-lint, shellcheck |
| typecheck | `tsc --noEmit`, mypy/pyright, `cargo check` |
| unused code / deps, spelling | knip, cspell, `cargo machete` |
| unit tests | vitest, pytest, `cargo test`, `go test ./...` |
| build | the production build CI runs |
| e2e / integration | only if runnable locally without secrets |

**Exclude:** deploy, publish, release, anything needing CI secrets or cloud
access. Note each exclusion in the report.

Don't install new tools unless a gate is clearly missing (e.g. a TS repo with
no lint at all) — then propose it and ask before adding the dependency.

## 3. Write the Makefile targets

- No Makefile → create one. Makefile exists → add or fix `check`; leave other
  targets alone. Repo standardized on `just`/`task` → ask first.
- Each gate is its own target, so a failure names itself and `make -j check`
  can parallelize. Delegate to existing package scripts rather than duplicate
  their flags.
- Non-mutating and idempotent: `check` never rewrites files. A `fix` target
  (format + lint --fix) is fine if the tools support it.
- Exit non-zero on any failure. No `|| true`, no `-` prefixes.

```make
.PHONY: check fmt-check lint typecheck test build fix

check: fmt-check lint typecheck test build

fmt-check: ; bun run format:check
lint:      ; bun run lint
typecheck: ; bun run tsc --noEmit
test:      ; bun run test
build:     ; bun run build

fix:
	bun run format
	bun run lint --fix
```

If `check` takes more than ~5 minutes, keep it as the full CI mirror and add
`check-fast` (no build/e2e) for the inner loop. Never shorten `check` itself.

## 4. Run it until green

Run `make check`. For each failure, decide which kind it is:

- **The check is wrong** (wrong command, missing install step, tool not on
  PATH, flags that differ from CI) → fix the Makefile.
- **The repo has real failures** (lint errors, failing tests) → report them.
  Fix only trivial ones (formatting via `make fix`); ask before larger fixes.

Never delete, skip, or loosen a gate to get green. If a gate can't run
locally, leave it out and say why.

## 5. Record it in AGENTS.md

Create `AGENTS.md` if missing. Add or replace one section:

```markdown
## Verification

Run `make check` before calling any task done, and before committing. It
mirrors CI (`<CI file>`): <gates in order>. All gates must pass.

- A gate fails because of your change → fix the code, not the check.
- The check itself is broken or stale (CI gained a step, a tool moved, a
  command is wrong) → fix the Makefile and update this section in the same
  change. Never weaken or remove a gate to get green.
- `make fix` auto-formats and applies lint fixes.
```

Claude Code reads `AGENTS.md` directly, but only when no `CLAUDE.md` exists
in the repo. Don't create a `CLAUDE.md`. If one already exists without
referencing `AGENTS.md`, add an `@AGENTS.md` line to it.

Drop the `make fix` bullet if the repo has no `fix` target. With no hosted CI,
say so: "`make check` is the CI".

## 6. Report

A short table: CI step → make target, what was excluded and why, wall time of
a green `make check`, and any real failures left for Kevin. Don't commit
unless asked.

## Common mistakes

- `check` that formats or fixes files — CI would never do that.
- Inventing gates the repo has no config for, instead of proposing them.
- Calling it done without a green run.
- Drifting from CI: a gate CI runs that `check` skips silently.
