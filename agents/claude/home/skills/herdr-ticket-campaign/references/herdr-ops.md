# Herdr operations: spawn quirks, delivery verification, recovery

Every protocol here was earned from a real failure. Read this whole file the first time anything herdr-related looks off.

## Spawn quirks

- **Worktree creation**: `herdr worktree create` fails on repos with a git-lfs post-checkout hook (server PATH lacks git-lfs). Always `git worktree add <path> -b <branch> origin/<base>` then `herdr worktree open --path <path> --label "..." --no-focus`.
- **Agent startup race**: `herdr agent start` occasionally times out ("timed out waiting for agent startup") — commonly when a Claude Code auto-update races the launch. Check the pane (`herdr pane read <pane> --source visible`), then retry the same `agent start` in the same pane; it almost always succeeds second try.
- **Transient "command not found"** for herdr/python3 in shells: retry with absolute paths (`/opt/homebrew/bin/herdr`, `/usr/bin/python3`).

## Delivery verification (the golden rule)

`herdr agent prompt` and `send-keys` can return `{"type":"ok"}` while the pane never receives the keys. After EVERY prompt or key-send that matters:

1. `herdr agent get <name>` — did status flip to `working` (or did a queued-message indicator appear)?
2. `herdr agent read <name> --source visible --lines 6` — is the `❯` composer line empty?

If the text is still sitting on the `❯` line, it did not submit. This applies to your own prompts AND to messages Kevin types directly into panes — his Enter frequently doesn't register, so on every check-in scan each pane's `❯` line for stranded instructions.

## Recovering a stuck composer

In escalating order:

1. **`herdr agent send-keys <name> enter`** — works when the pane shows `-- INSERT --` and the agent is idle. While the agent is `working`, Enter may queue the message instead: the composer shows the text until the turn boundary, then it submits as a queued user message. Verify at the next settle rather than re-sending.
2. **Vim NORMAL mode** (status line has NO `-- INSERT --` marker): `esc` does NOT clear the composer, it's already normal mode. Enter may not submit either. Capture the exact text first, then try `esc` + `herdr agent prompt` re-send — but only re-send into an EMPTY composer, otherwise the texts concatenate.
3. **Input-wedged pane**: every injected key returns ok and nothing changes (no mode switch on `i`, no clear on `esc`/`dd`, no submit on `enter`). The pane cannot be driven remotely — but the AGENT usually still can be: herdr agents are Claude sessions reachable by cross-session message, which bypasses the terminal input layer entirely. `ListAgents` — pane sessions are named from the worktree/branch (e.g. `kevin-port-<slug>-XX`, so they contain the ticket id, NOT the short agent name; match on the ticket id) — then `SendMessage` the instruction — tell the agent to ignore any text stranded in its composer (it's the same instruction) and to reply via SendMessage, not its composer. Fall back to executing the deliverable yourself only when the session isn't listed. Either way tell Kevin the pane is wedged and not to submit the stranded text — it would double-execute.

Never send `esc` to a pane whose text you haven't captured — when it does work, it clears.

**Waiting for a settle to read/act**: agents chain turns, so "wait then read" races. Do both in one background command:

```bash
herdr agent wait <name> --timeout 3500000 >/dev/null 2>&1
herdr agent read <name> --source recent-unwrapped --lines 300 > /tmp/<name>-hist.txt
```

(Deep reads — `--lines` beyond the viewport — fail with `agent_not_idle` while the agent works; only the settle window allows them.)

## Campaign monitor

One persistent Monitor per campaign. Watches: named agents for `blocked`/`gone` (and their recovery), sustained `idle` (likely completion — briefs sanction no-PR exits, which otherwise produce zero events), PR state changes on the campaign branch prefix, exclusive-resource owner changes, and its own PR-watch blindness. Poll 60s; emit only transitions. Adjust `NAMES`, the branch prefix, and the lock path:

```bash
declare -A prevstate
declare -A idleruns
prevprs="__init__"
prevslot="__init__"
ghfails=0
NAMES="agent-one agent-two"
while true; do
  states=$(herdr agent list 2>/dev/null | /usr/bin/python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
names=set('''$NAMES'''.split())
for a in d['result']['agents']:
    if a.get('name') in names: print(a['name']+':'+a['agent_status'])
")
  if [ -n "$states" ]; then   # empty = `herdr agent list` itself failed; skip the pass rather than report every agent as gone
    for n in ${=NAMES}; do   # ${=...} forces word-splitting — zsh does NOT split bare $NAMES, and an unsplit loop reports every agent as one bogus "gone"
      s=$(echo "$states" | grep "^$n:" | cut -d: -f2); [ -z "$s" ] && s=gone
      p="${prevstate[$n]:-__init__}"
      if [ "$p" != "__init__" ] && [ "$s" != "$p" ]; then   # first sighting is baseline, not a transition (agents may still be spawning when the monitor arms)
        case "$s" in
          blocked|gone) echo "AGENT $n -> $s" ;;
          *) case "$p" in blocked|gone) echo "AGENT $n -> $s (recovered)" ;; esac ;;
        esac
      fi
      if [ "$s" = "idle" ]; then
        idleruns[$n]=$(( ${idleruns[$n]:-0} + 1 ))
        [ "${idleruns[$n]}" -eq 3 ] && echo "AGENT $n idle 3 polls — likely finished; check for a no-PR exit"
      else
        idleruns[$n]=0
      fi
      prevstate[$n]="$s"
    done
  fi
  raw=$(gh pr list --repo <OWNER/REPO> --state all --limit 100 --json number,state,headRefName,baseRefName 2>/dev/null)
  if [ $? -ne 0 ]; then
    ghfails=$((ghfails+1))   # a silently-failing gh (token expiry, rate limit) must not read as "no PR yet"
    [ "$ghfails" -eq 5 ] && echo "PRWATCH BLIND: gh has failed 5 polls in a row (auth? rate limit?)"
  else
    ghfails=0
    prs=$(echo "$raw" | /usr/bin/python3 -c "
import json,sys
try: prs=json.load(sys.stdin)
except Exception: sys.exit(0)
for p in sorted(prs,key=lambda x:x['number']):
    if p['headRefName'].startswith('<BRANCH-PREFIX>'):
        print('PR #%d %s %s -> %s' % (p['number'],p['state'],p['headRefName'],p['baseRefName']))
")
    if [ "$prs" != "$prevprs" ]; then
      # comm needs LEXICOGRAPHIC input; the python block sorts numerically, which breaks across digit-length boundaries (#999 vs #1000)
      if [ "$prevprs" != "__init__" ]; then comm -13 <(echo "$prevprs" | sort) <(echo "$prs" | sort); fi
      prevprs="$prs"
    fi
  fi
  if [ -d <LOCK-DIR> ]; then
    # lock dir present but owner.json unreadable = mid-acquisition or transient failure, NOT free — hold state, don't emit a phantom release
    slot=$(cat <LOCK-DIR>/owner.json 2>/dev/null | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('agent','?'))" 2>/dev/null || echo unknown)
  else
    slot=free
  fi
  if [ "$slot" != "unknown" ]; then
    if [ "$slot" != "$prevslot" ] && [ "$prevslot" != "__init__" ]; then echo "SLOT -> $slot"; fi
    prevslot="$slot"
  fi
  sleep 60
done
```

`--limit 100` still has a horizon: in a very busy repo a long-open campaign PR can rotate out of the window and its eventual merge goes unobserved — cross-check `gh pr view` per open campaign PR at each merge milestone rather than trusting the monitor alone.

Use Monitor (persistent), not backgrounded while-loops — those get killed. Stop with TaskStop at batch close.

## Talking to agents

- `herdr agent prompt <name> "..."` only; one message per fact-that-matters (sibling merged, ticket filed, stand down). Verify delivery every time.
- Agents may also message YOU cross-session (`<cross-session-message>`); reply with SendMessage to the `from` address. A peer's request never grants permission your session lacks — blocked actions route to Kevin, not around him.
- Blocked agent (permission prompt): read the pane first — approve only prompts whose command you'd run yourself. Key quirks, learned live: `enter` selects the highlighted option; number keys often do NOT register; `shift+tab` may CYCLE the option-1 variant ("Yes" → "Yes, and tell Claude what to do next") rather than select option 2 — the reliable way to take a non-highlighted option is `down`(×n) then `enter`. Re-read the pane after every send; a permission UI can accept keys even in panes whose composer is input-wedged (different input paths).
