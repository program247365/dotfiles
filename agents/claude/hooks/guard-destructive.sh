#!/usr/bin/env bash
# PreToolUse hook: blocks high-risk Bash commands before execution.
# Reads JSON from stdin: {"tool_name": "Bash", "tool_input": {"command": "..."}}
# Exit 2 = block with message. Exit 0 = allow (always fail open on errors).
#
# Requires: jq (installed via Homebrew)

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Read stdin; bail out (allow) if we can't read or parse it
input="$(cat 2>/dev/null)" || exit 0
[ -n "$input" ] || exit 0

# Only intercept Bash tool calls
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
[ "$tool_name" = "Bash" ] || exit 0

# Extract the command; allow if empty or unparseable
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[ -n "$command" ] || exit 0

# Fixed-string match against high-risk patterns (grep handles multiline commands)
blocked=""
for pattern in "rm -rf" "git push --force" "git push -f " "git reset --hard" \
               "git clean -f" "git branch -D" "chmod -R 777" "DROP TABLE" "DROP DATABASE"; do
  if printf '%s' "$command" | grep -qF -- "$pattern"; then
    blocked="$pattern"
    break
  fi
done

if [ -n "$blocked" ]; then
  echo "BLOCKED: Destructive pattern '$blocked' detected."
  echo "Ask the user for explicit confirmation before running this command."
  exit 2
fi

exit 0
