# portless helper functions - https://port1355.dev/
#
# pldev - smart portless wrapper that auto-detects project type.
#
# Usage:
#   pldev               # infers name from dirname, detects stack
#   pldev myapp         # custom name, detects stack
#   pldev myapp pnpm dev  # custom name + explicit command
#
# Project type detection order:
#   Django  → manage.py present
#   pnpm    → pnpm-lock.yaml present
#   Yarn    → yarn.lock present
#   npm     → package.json present (fallback)
#
# Django note: portless sets $PORT before launch. Django's runserver
# doesn't read $PORT from env, so we wrap it in `sh -c '...$PORT'`
# to expand it at runtime.
#
# Turbo monorepos: run pldev from each workspace package directory,
# or use plturbo from the repo root to run all workspaces at once.
pldev() {
  local name="${1:-$(basename "$PWD")}"

  # If additional args supplied, use them as the command directly
  if [[ $# -gt 1 ]]; then
    shift
    portless "$name" "$@"
    return
  fi

  # Django
  if [[ -f "manage.py" ]]; then
    echo "portless: detected Django → http://$name.localhost:1355"
    portless "$name" sh -c 'python manage.py runserver 0.0.0.0:$PORT'
    return
  fi

  # pnpm
  if [[ -f "pnpm-lock.yaml" ]]; then
    echo "portless: detected pnpm → http://$name.localhost:1355"
    portless "$name" pnpm dev
    return
  fi

  # Yarn
  if [[ -f "yarn.lock" ]]; then
    echo "portless: detected yarn → http://$name.localhost:1355"
    portless "$name" yarn dev
    return
  fi

  # npm fallback
  if [[ -f "package.json" ]]; then
    echo "portless: detected npm → http://$name.localhost:1355"
    portless "$name" npm run dev
    return
  fi

  echo "portless: no recognized project in $PWD"
  echo "Usage: pldev [name] [command...]"
  return 1
}

# plturbo - run a Turborepo dev pipeline with portless-aware workspace URLs.
#
# Usage:
#   plturbo                  # runs `pnpm turbo run dev` (Turbo handles port assignment)
#   plturbo web              # starts only the 'web' workspace: http://web.localhost:1355
#   plturbo api              # starts only the 'api' workspace: http://api.localhost:1355
#
# For multiple workspaces simultaneously, run in separate terminals:
#   plturbo web &
#   plturbo api &
#
# Or put portless directly in each package's package.json dev script:
#   "dev": "portless web next dev"
plturbo() {
  if [[ ! -f "turbo.json" ]]; then
    echo "plturbo: no turbo.json found in $PWD"
    return 1
  fi

  local filter="${1:-}"

  if [[ -n "$filter" ]]; then
    echo "portless: turbo workspace '$filter' → http://$filter.localhost:1355"
    portless "$filter" pnpm turbo run dev --filter="$filter"
  else
    # No filter: run full turbo pipeline (each package handles its own portless)
    echo "portless: running full turbo dev pipeline"
    pnpm turbo run dev
  fi
}
