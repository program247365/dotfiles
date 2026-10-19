---
name: local-ci
description: Use when Kevin runs /local-ci, when a repo's GitHub Actions should run on this machine instead of (or before) GitHub, when agents keep pushing just to see whether CI passes, or when a repo mentions agent-ci / Local CI (`run-local-ci`, `@redwoodjs/agent-ci`, `.env.local-ci`).
---

# local-ci — run a repo's GitHub Actions locally

[Local CI](https://github.com/redwoodjs/local-ci) (formerly Agent CI,
agent-ci.dev) runs the official GitHub Actions runner against a local emulation
of GitHub's API, in Docker, against the **working tree**. On failure it pauses
the container so you can fix and retry only the failed step. Remote CI stays the
gatekeeper; nobody pushes just to find out whether it's green.

This skill wires it into an **existing** repo, runs it until green, and records
it in `AGENTS.md`. The package is `run-local-ci` (binary `local-ci`).
`@redwoodjs/agent-ci` is a compatibility shim; don't install it, and don't
install the upstream `npx skills add` skill either, because this one replaces it.

## 1. Preconditions

- **Docker running:** Kevin uses OrbStack (Brewfile `cask 'orbstack'`), not
  Docker Desktop. Run `docker info`. If it fails, run `orb start` and poll
  `docker info` until it reports `OperatingSystem: OrbStack`.
- **Socket:** OrbStack serves Docker at `~/.orbstack/run/docker.sock`, and
  `/var/run/docker.sock` doesn't exist without OrbStack's admin mode. Local CI
  ignores docker contexts, so without this it fails with "couldn't use a Docker
  socket at /var/run/docker.sock". The dotfiles (`docker/env.zsh`) export
  `LOCAL_CI_DOCKER_HOST=unix://$HOME/.orbstack/run/docker.sock`. If that variable
  is empty in your shell, set it inline. Never write it into a repo's
  `.env.local-ci`, because the path is machine-specific.
- **Workflows exist:** `.github/workflows/*.yml`. If there are none, Local CI has
  nothing to run. Offer to add a minimal `ci.yml` whose one job runs
  `make check` (run the make-check-repo skill first if there's no `make check`),
  and ask before creating it.
- **Version:** `npm view run-local-ci version`. Pin that exact version
  everywhere below. Never use `@latest` or a bare `npx run-local-ci`.

## 2. Classify every workflow

Read each workflow's `on:` triggers and jobs. Sort them into:

| Kind | Examples | Local CI |
|---|---|---|
| check | lint, test, build, typecheck, e2e | **run** |
| side-effecting | deploy, release, publish, docker push, comment/label bots, `pages` | **never run** |
| unsupported | `runs-on: windows-*`, macOS jobs without tart, jobs that need cloud secrets | skip, note why |

`--all` runs every workflow that matches the current branch's push event, so it
picks up deploy workflows too. Secrets fall back to **shell env vars of the same
name**, which means a `VERCEL_TOKEN` already in Kevin's shell would let a deploy
job actually deploy. Name the check workflows explicitly with `--workflow`. Use
`--all` only when every workflow it would select is a check.

## 3. Wire it in

**Command.** One run per check workflow, in this form:

```bash
local-ci run --quiet --pause-on-failure --workflow .github/workflows/ci.yml
```

- **Node repo** (`package.json`): add `run-local-ci` as an exact-pinned
  devDependency using the repo's package manager, plus a script
  `"ci:local": "local-ci run --quiet --pause-on-failure --workflow …"`.
- **Any other repo:** call `npx -y run-local-ci@<version> run …` directly.

**Makefile.** Add a `ci-local` target next to `check`, delegating to the package
script if there is one. Leave `check` alone: `check` is the fast native inner
loop, and `ci-local` is the full-fidelity pre-push run.

```make
.PHONY: ci-local
ci-local: ; bun run ci:local
```

**Ignore.** Add `.env.local-ci` to `.gitignore` before anything writes to it.
It holds secrets and machine-local `LOCAL_CI_*` overrides.

**Prewarm (optional).** If several first-wave jobs install from the same
lockfile, give the install step a stable `id:` and set
`LOCAL_CI_PREWARM_THROUGH=<workflow>:<job>:<step-id>` in `.env.local-ci`.

## 4. Run it until green

Run `make ci-local`. When stdout isn't a TTY, a paused step makes the foreground
process exit **77** while the container stays alive. `--json` gives NDJSON with
`run.paused` events, which carry `runner` and `retry_cmd`.

For each failure, decide which kind it is:

- **Missing tool in the runner image** (`python3: not found`, no `xz`, no
  compiler). The default image is the slim self-hosted runner, not
  `ubuntu-latest`. Add `.github/local-ci.Dockerfile`
  (`FROM ghcr.io/actions/actions-runner:latest` plus `apt-get install`). Picked up
  automatically.
- **Missing secret or var.** A check job that needs a secret: ask Kevin to put
  it in `.env.local-ci`, and never write a real secret value yourself. Missing
  `${{ vars.X }}`: use `--var X=…`, or
  `gh variable list --json name,value | local-ci run … --var-file -`.
- **Remote reusable workflow** (`uses: org/repo/.github/workflows/…`): add
  `--github-token`, which resolves through `gh auth token`.
- **Real failure in the repo:** fix it, then
  `local-ci retry --name <runner>` (`--from-step N` / `--from-start` if an
  earlier step needs rerunning). Ask before large fixes.

When you're done, `local-ci abort --name <runner>` any runner that's still
paused, so containers don't pile up. Never comment out a step or loosen a
workflow to get a green local run. If a job can't run locally, leave it to
remote CI and say why.

## 5. Record it in AGENTS.md

Add or replace one section. Create `AGENTS.md` if missing, and add `@AGENTS.md`
to `CLAUDE.md` if it doesn't already reference it. Write `npx local-ci` in Node
repos and `npx -y run-local-ci@<version>` everywhere else.

```markdown
## Local CI

Before pushing, run `make ci-local`. It runs <workflows> through Local CI
(the real GitHub Actions runner in Docker, against the working tree). Don't
push to find out whether CI passes.

- A step fails → it pauses (exit 77 when piped). Fix the code, then
  `npx local-ci retry --name <runner>`. Abort leftover runners with
  `npx local-ci abort --name <runner>`.
- Never run deploy/release workflows locally: <list>.
- Secrets go in `.env.local-ci` (gitignored). Missing runner tools go in
  `.github/local-ci.Dockerfile`.
- `make check` is the fast inner loop; `make ci-local` is the pre-push gate.
```

## 6. Report

A short table: workflow → run / skipped (and why). Also give the pinned version,
the wall time of the cold and warm green runs, any image or secret additions,
and any real failures left for Kevin. Don't commit unless asked.

## Common mistakes

- `--all` in a repo that has deploy workflows.
- An unpinned `npx run-local-ci`, or installing the `@redwoodjs/agent-ci` shim.
- Setting `DOCKER_HOST`: Local CI refuses it. Use `LOCAL_CI_DOCKER_HOST`.
- Starting Docker Desktop, or creating `/var/run/docker.sock` with sudo, instead
  of using OrbStack's socket through `LOCAL_CI_DOCKER_HOST`.
- Mistaking the first run's ~400 MB runner-image pull for a hang. Later runs use
  the cached image.
- Treating an exit 77 as a crash. It means paused: fix, then retry.
- Leaving paused runner containers behind.
- Calling it done without one green run.
