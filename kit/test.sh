#!/usr/bin/env bash
# kit smoke tests
set -euo pipefail

PASS=0; FAIL=0

assert() {
  local desc="$1" result="$2"
  if [[ "$result" == "true" ]]; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# Rebuild index fresh
kit index 2>/dev/null

INDEX="$HOME/.kit/index.json"

# T1: index file exists
assert "index file created" "$([[ -f $INDEX ]] && echo true || echo false)"

# T2: index is non-empty valid JSON array
count=$(jq 'length' "$INDEX" 2>/dev/null || echo 0)
assert "index has entries" "$([[ $count -gt 0 ]] && echo true || echo false)"

# T3: bat is in the index (it's in Brewfile)
has_bat=$(jq -r 'any(.[]; .name == "bat")' "$INDEX")
assert "bat entry present" "$has_bat"

# T4: bat entry has required fields
bat_entry=$(jq -r '.[] | select(.name == "bat")' "$INDEX")
has_fields=$(echo "$bat_entry" | jq -r 'has("name") and has("type") and has("installed") and has("help_flag")' 2>/dev/null)
assert "bat entry has required fields" "$has_fields"

# T5: bat type is brew
bat_type=$(echo "$bat_entry" | jq -r '.type')
assert "bat type is brew" "$([[ $bat_type == brew ]] && echo true || echo false)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
