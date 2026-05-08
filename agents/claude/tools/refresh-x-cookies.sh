#!/usr/bin/env bash
# refresh-x-cookies — set up or refresh x-cookies.json for /notes-organize-tweets
#
# Usage:
#   refresh-x-cookies.sh                       Print setup instructions.
#   refresh-x-cookies.sh --convert < cookies.txt
#                                              Convert a Netscape-format cookies.txt
#                                              (e.g. from the "cookies.txt" Firefox extension)
#                                              to the JSON shape this skill expects.

set -euo pipefail

DEST="${HOME}/.config/notes-organize-tweets/x-cookies.json"
mkdir -p "$(dirname "$DEST")"

if [ "${1:-}" != "--convert" ]; then
  cat <<'EOF'
Cookie setup for /notes-organize-tweets thread fetching:

OPTION A — Manual copy (30 seconds):
  1. Open Firefox → x.com (signed in).
  2. F12 → Storage → Cookies → https://x.com.
  3. Copy these three values:
       auth_token   (HttpOnly — visible in DevTools, NOT in document.cookie)
       ct0          (CSRF token)
       twid         (user id, formatted as u%3D<digits>)
  4. Paste into ~/.config/notes-organize-tweets/x-cookies.json:

     [
       { "name": "auth_token", "value": "PASTE_HERE", "domain": ".x.com" },
       { "name": "ct0",        "value": "PASTE_HERE", "domain": ".x.com" },
       { "name": "twid",       "value": "PASTE_HERE", "domain": ".x.com" }
     ]

  5. chmod 600 ~/.config/notes-organize-tweets/x-cookies.json

OPTION B — Pipe a Netscape cookies.txt (from the Firefox "cookies.txt" extension):
  cookies.txt → File → Export current site → save → then:
       refresh-x-cookies.sh --convert < /path/to/cookies.txt

Verify with:
  node ~/.dotfiles/agents/claude/tools/x-thread-fetcher.mjs --probe

Cookies are gitignored. They live only in ~/.config and are never committed.
EOF
  exit 0
fi

# Stdin is piped — convert Netscape cookies.txt to our JSON shape.
# (Heredoc-as-stdin would collide with the piped cookies file, so we write the script
# to a temp file and pipe stdin separately.)
TARGET_NAMES="auth_token ct0 twid"
PARSER="$(mktemp -t refresh-x-cookies-parser.XXXXXX.py)"
trap 'rm -f "$PARSER"' EXIT

cat > "$PARSER" <<'PY'
import json, os, sys

target_names = set(sys.argv[1].split())
dest = sys.argv[2]
out = []
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line.strip():
        continue
    # Some exporters prefix HttpOnly cookies' domain with `#HttpOnly_` — strip that
    # before treating `#` as a comment (which would skip auth_token, the HttpOnly row).
    if line.startswith("#HttpOnly_"):
        line = line[len("#HttpOnly_"):]
    elif line.startswith("#"):
        continue
    parts = line.split("\t")
    if len(parts) < 7:
        continue
    domain, _flag, _path, _secure, _expiry, name, value = parts[:7]
    if name not in target_names:
        continue
    if "x.com" not in domain and "twitter.com" not in domain:
        continue
    out.append({
        "name": name,
        "value": value,
        "domain": domain if domain.startswith(".") else "." + domain.lstrip("."),
    })

found = {c["name"] for c in out}
missing = target_names - found
if missing:
    print(f"WARNING: missing cookies in input: {sorted(missing)}", file=sys.stderr)

with open(dest, "w") as f:
    json.dump(out, f, indent=2)
os.chmod(dest, 0o600)
print(f"wrote {len(out)} cookies to {dest}", file=sys.stderr)
PY

python3 "$PARSER" "$TARGET_NAMES" "$DEST"
