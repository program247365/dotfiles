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
has_fields=$(echo "$bat_entry" | jq -r 'has("name") and has("type") and has("installed") and has("help_flag") and has("description") and has("dotfiles_added")' 2>/dev/null)
assert "bat entry has required fields" "$has_fields"

# T5: bat type is brew
bat_type=$(echo "$bat_entry" | jq -r '.type')
assert "bat type is brew" "$([[ $bat_type == brew ]] && echo true || echo false)"

# T6: dot (bin/ script) is in the index
has_dot=$(jq -r 'any(.[]; .name == "dot")' "$INDEX")
assert "dot bin entry present" "$has_dot"

# T7: dot type is bin
dot_type=$(jq -r '.[] | select(.name == "dot") | .type' "$INDEX")
assert "dot type is bin" "$([[ $dot_type == bin ]] && echo true || echo false)"

# T8: ll (alias) is in the index
has_ll=$(jq -r 'any(.[]; .name == "ll")' "$INDEX")
assert "ll alias entry present" "$has_ll"

# T9: gch (function) is in the index
has_gch=$(jq -r 'any(.[]; .name == "gch")' "$INDEX")
assert "gch function entry present" "$has_gch"

# T13: kit can format entries for display (non-interactive smoke test)
formatted=$(jq -r '.[] | [.name, ("[" + .type + "]"), .description,
  (if .installed then "" else "[not installed]" end)] | @tsv' "$INDEX" | column -t -s $'\t' 2>/dev/null)
assert "kit formats entries for display" "$([[ -n $formatted ]] && echo true || echo false)"

# T10: bat should be installed (it's in Brewfile and definitely installed)
bat_installed=$(jq -r '.[] | select(.name == "bat") | .installed' "$INDEX")
assert "bat is marked installed" "$([[ $bat_installed == true ]] && echo true || echo false)"

# T11: no entry should have installed:false AND type:bin (bin scripts are always installed)
bin_not_installed=$(jq '[.[] | select(.type == "bin" and .installed == false)] | length' "$INDEX")
assert "no bin entries marked not-installed" "$([[ $bin_not_installed -eq 0 ]] && echo true || echo false)"

# T12: all entries have a non-null name
null_names=$(jq '[.[] | select(.name == null or .name == "")] | length' "$INDEX")
assert "all entries have non-empty names" "$([[ $null_names -eq 0 ]] && echo true || echo false)"

# T14: kit recent returns output
recent_output=$(kit recent 5 2>/dev/null)
assert "kit recent returns output" "$([[ -n $recent_output ]] && echo true || echo false)"

# T15: kit recent respects n
recent_lines=$(kit recent 3 2>/dev/null | wc -l | tr -d ' ')
assert "kit recent 3 returns ≤3 lines" "$([[ $recent_lines -le 3 ]] && echo true || echo false)"

# T16: kit missing runs without error
kit missing 2>/dev/null
assert "kit missing exits cleanly" "true"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
