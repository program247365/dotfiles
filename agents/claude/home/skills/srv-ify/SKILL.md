---
name: srv-ify
description: Prepare an existing application for Kevin's srv home server by adding the standard Docker Compose, startup, health, and persistent-data contract. Use when asked to srv-ify an app for the home server, including preparing a Docker repo or registering a local macOS service/job.
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
Determine whether it can run on Linux ARM64. macOS integrations (EventKit,
Reminders, AppleScript, protected local databases, etc.) can be tracked as native
LaunchAgent services/jobs. Do not assume Docker or Apple's Linux container runtime
can access macOS frameworks. Do not force these apps into containers.

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

## Native macOS services

Use the user's existing checkout via `path` in an explicit `apps:` entry; native
services do not belong in the Docker-only `repos:` list. Set `kind: service` or
`kind: job`, make `install` noninteractive/idempotent, keep `run` in the foreground,
and add an HTTP readiness route where applicable. srv supplies `PORT`,
`SRV_DATA_DIR`, `SRV_HOME`, `SRV_MANIFEST`, and `PATH` to LaunchAgents.

Read the actual data path and TCC boundaries. Move durable SQLite/files under
`SRV_DATA_DIR` with a consistent, integrity-checked backup before changing the
path; retain the source copy until the managed app is verified. A LaunchAgent does
not inherit Terminal's Full Disk Access or Reminders grant. Identify the executable
that performs each protected read (the server and a helper can be different
binaries), verify that operation directly, and report the precise System Settings
grant still needed. `/api/health` only proves the HTTP server is live. Never reset
TCC or bypass consent. Keep every service bound to loopback (Docker apps via
`SRV_BIND_IP: 127.0.0.1` in `srv.yaml`). Tailnet reachability is defined only by
srv's `script/tailscale-serve` allowlist: to expose an app, add its port there and
to that file's table, set `url: https://{host}:<port>`, and run `make
tailscale-serve` in the srv repo. Only do so if the app's Host and CSRF
protections support the proxy; an app not listed there stays Mac-local.

LaunchAgents get srv's fixed PATH (mise shims first, then `~/.kevin/bin`,
Homebrew, system), not the installing shell's. Build native modules under the
mise-pinned runtime so a `brew upgrade` of an incidental Homebrew runtime can't
break them.

srv names each job's executable for System Settings > Login Items: it writes `run`
into `~/server/bin/srv-<name>` and the plist launches that, so the app shows as
`srv-<name>` instead of "zsh". Pick an app `name` that reads well there, and never
hand-write a `com.srv.*` plist or point one at `/bin/zsh -c`; register through
`apps.yaml` and `srv sync`.

Do not install a production LaunchAgent during a conversion test. For an
end-to-end `srv sync` test, set a scratch `SRV_HOME`, `SRV_MANIFEST`, and
`SRV_LAUNCH_AGENTS=$SRV_HOME/LaunchAgents`. Without the last one, test plists land
in the real `~/Library/LaunchAgents`, reload at every login, and show up in Login
Items. The jobs still load into the live launchd session, so boot out every test
label you created (`launchctl bootout gui/$(id -u)/com.srv.<test>`) and confirm
`launchctl list | grep com.srv.` shows only real apps before handing back. After the app is
ready, provide the exact `apps:` entry, required one-time TCC grants, local URL,
data migration result, and live deployment status.

Document the supported srv startup/data/secret/health interface in the target's
README and AGENTS.md, including remaining one-time setup. Return the exact repo
URL to add under `repos:` (or native manifest entry), host port, data import steps,
and verification results. Commit/push/deploy only within the user's authorization;
adding a URL on this Mac needs no webhook or public ingress once srv-sync is set up.
