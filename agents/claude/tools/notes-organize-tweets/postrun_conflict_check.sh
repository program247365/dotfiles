#!/bin/bash
# Post-run conflict check, bearcli-only. Bear's conflict stamp
# (ZSFNOTE.ZCONFLICTUNIQUEIDENTIFIER) isn't exposed by bearcli, and reading the
# SQLite file directly needs Full Disk Access (macOS TCC denies it otherwise).
# So detect what a sync conflict leaves behind instead: two live notes for the
# same tweet. precheck.py already finds those pairs; this prints each pair's
# created/modified times so a conflict (created seconds apart, one at run time)
# can be told apart from a double-save (created days apart).
# Exit 0 = no duplicates, 1 = duplicates listed.
set -euo pipefail
cd "$(dirname "$0")"

dups=$(python3 precheck.py | grep '^DUPLICATE' || true)
if [ -z "$dups" ]; then
  echo "No duplicate tweet notes."
  exit 0
fi

while read -r line; do
  echo "$line"
  tweet_id=$(sed -E 's/^DUPLICATE tweet=([0-9]+):.*/\1/' <<<"$line")
  bearcli search "$tweet_id" --fields id,created,modified,title
  echo
done <<<"$dups"
exit 1
