---
name: srv-ify
description: Prepare an existing application for Kevin's srv home server by adding the standard Docker Compose, startup, health, and persistent-data contract. Use when asked to srv-ify an app or make a repo installable from the home server's repo list.
---

Adapt the existing app; preserve its language, package manager, working development
flow, and deployment files that serve other environments.

## Read the contract first

Locate the srv checkout at `~/.kevin/code/srv` or `~/.kevin/personal-code/srv`.
Read `docs/app-contract.md` and `README.md` there. They are the source of truth
for repo metadata, startup, persistence, and registration. If neither checkout
exists, ask for the srv location or contract before inventing a schema.

Inspect the target's instructions, current Docker/start commands, dependency
lockfile, database initialization, workers, health endpoint, and required secrets.
Determine whether it can run on Linux ARM64. macOS integrations (Bear, Messages,
Reminders, AppleScript, etc.) need the contract's native service/job path; do not
force them into Docker or claim a native app supports the plain Docker repo list.

## Adapt a Docker app

- Add or adapt root `compose.yaml`, `Dockerfile`, `.dockerignore`, executable
  `script/start`, and `srv.yaml` to the contract. Preserve existing Compose services
  and dependencies. Avoid adding a second competing production stack.
- Use a unique host port in `srv.yaml`; inspect the home server manifest and known
  repo descriptors when accessible. Otherwise clearly mark the port as provisional.
  The app listens on 0.0.0.0:8080 inside the container. Host `PORT` interpolation
  and container `PORT=8080` are different values.
- Keep dependencies/builds inside the image. `script/start` initializes only missing
  state, performs safe idempotent migrations, then `exec`s the foreground process.
  Do not overwrite user data to make a startup pass.
- Mount `SRV_DATA_DIR` at `/data` and configure the app's actual database/upload
  paths there. Merely exporting DATA_DIR does not make an app use it. Adapt its
  configuration or code where necessary. Keep secrets outside Git/images.
- Add a meaningful `/health` readiness endpoint and a Compose healthcheck whose
  probe tool exists in the image. Include dependency readiness and worker health.
  Keep cron/workflow observability claims limited to what srv actually reports.
- Describe how existing SQLite/uploads move into the data directory. Test with
  throwaway data; live import, destructive migrations, and deployment require
  the user's authorization. Preparing an app does not authorize adding it to a
  live watched list, since that triggers automatic execution.

## Verify and hand back

Run the app's required checks. Validate `docker compose config` with temporary
PORT/SRV_DATA_DIR values. When Docker is available, use a unique Compose project,
unused local-only host port, and throwaway data directory: build/start with
`--wait`, probe readiness, write representative state, restart/recreate, and confirm
that state persists. Check logs and clean up only resources created for this test.
Never bring down an existing project or remove its volumes. Report unavailable
checks rather than calling them passed.

For native apps, verify install/start scripts and provide an explicit `apps:`
entry instead. Avoid installing a production LaunchAgent during a conversion test.

Document the supported srv startup/data/secret/health interface in the target's
README and AGENTS.md, including remaining one-time setup. Return the exact repo
URL to add under `repos:` (or native manifest entry), host port, data import steps,
and verification results. Commit/push/deploy only within the user's authorization;
adding a URL on this Mac needs no webhook or public ingress once srv-sync is set up.
