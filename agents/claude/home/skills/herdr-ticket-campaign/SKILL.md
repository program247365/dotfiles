---
name: herdr-ticket-campaign
description: Orchestrate a Linear-ticket → herdr Claude-agent → merged-PR workflow, one agent per ticket in its own worktree/workspace. Use whenever Kevin asks to file a ticket AND start an agent on it, port a feature "using a new herdr pane with a claude agent", spin up a workspace for a ticket, run things "same as before" in a port/feature campaign, check in on port agents, merge an agent's PR, or close out a batch (verify + cleanup). Also use for a bare "create a ticket for X and start working on it" when herdr is available — delegation to a herdr agent IS the standing process, even if Kevin doesn't name herdr.
---

# Herdr ticket campaign

Run tickets end-to-end by delegating each to a dedicated Claude agent in a herdr pane, while you stay the orchestrator: you write the ticket and brief, spawn and monitor the agent, audit and merge its PR, sync trackers, and clean up. One agent = one ticket = one worktree = one PR.

**Invoke the `herdr` skill before any herdr command** (it requires `HERDR_ENV=1`; if the check fails you are not in a herdr session — stop and tell Kevin rather than falling back to doing the work inline, since delegation is the point). Check `references/` for a repo-specific file matching the current repo (named `<repo>-repo.md`; these are machine-local and gitignored — company-internal conventions stay out of the public dotfiles) and load it — it holds the conventions the generic process below parameterizes, including the GitHub repo slug and branch-prefix list every later phase needs.

## Why this shape

Agents run without your conversation context, so the brief is their entire world — anything not in it does not exist for them. You keep the merge decision because agents optimize for "my PR is green" while you see cross-agent hazards (sibling conflicts, shared-machine resources, user-stated rules). Events (Monitor) beat polling because agent turns take tens of minutes.

## Phase 1 — Ticket

**Search Linear before filing — the ticket may already exist.** Query the team's issues for the symptom's distinctive words (feature name, error text, UI surface — try 2–3 phrasings, since the existing ticket was worded by someone else), including closed/done ones. Then say explicitly in your report which case you're in:
- **Open ticket exists** → don't file a duplicate. Use it: add the new evidence (user report, screenshot context) as a comment, and run the campaign against its id.
- **Done/closed ticket covers it** → the report may be a regression or a stale build; say so, link the old ticket in the new one if you do file.
- **Related-but-different ticket** → file yours and cross-link both ways.
- **Nothing found** → file fresh, and note in your report that you searched.

**Also search open PRs** — a ticket may not exist but the work might: `gh pr list --repo <slug> --state open --json number,title,headRefName,author`, scanning titles/branches for the feature's words (and a quick `--state all` pass for a recently-merged fix). Someone else's open PR on the same surface means coordinate or stand down, not file-and-spawn; report what you found either way.

Recon before filing so the ticket is a real spec, not a wish:
- Find the reference implementation (for ports: `git show <old-branch>:<path>`; never merge/rebase/cherry-pick across unrelated lineages — reference only).
- Check what exists on the current lineage (the gap is often deliberate — quote the code comment that says so).
- Name concrete files, endpoints, and store methods in the ticket.

**Recon can contradict the premise — honor that.** If the feature already exists at HEAD, or the "bug" looks like a stale build, don't file the ticket Kevin described: tell Kevin the finding first, and if a ticket still makes sense, reframe it (repro-first bug with "does not reproduce" as an allowed outcome; or a smaller gap than assumed). An agent-day spent porting something already ported is the expensive failure this paragraph prevents.

File with the repo's Linear conventions (team/project from the repo reference file). **Assign the ticket to the human running the herdr campaign** — the repo reference file names the operator; if it doesn't and you can't tell who is operating, ask before filing rather than guessing or leaving it unassigned. This applies to adopted tickets too: when the campaign picks up an existing unassigned ticket, assign it to the operator at the same moment you move it In Progress. Cross-link related tickets and PRs. Finish this phase before starting the next two: the ticket id is embedded in the branch name, brief filename, brief body, and PR title, so there is no useful parallelism — drafting a brief before the id exists just produces placeholders.

**Naming, fixed here for every later phase:** `<slug>` is `<ticket-id>-<feature>` in lowercase kebab (e.g. `abc-1234-dark-mode`) — it names the brief file, worktree dir, and branch suffix, which is how the ticket id lands in all of them. The agent `<name>` is different and shorter: just the feature part (`dark-mode`). Don't improvise a third scheme mid-campaign; the wedged-pane recovery in herdr-ops.md finds sessions by the ticket id in the worktree-derived session name.

## Phase 2 — Brief

Write the brief to `~/.herdr/briefs/<slug>.md` from `references/brief-template.md` (`mkdir -p ~/.herdr/briefs` first — NOT /tmp, which macOS purges on reboot and cleans after ~3 days; a multi-day campaign's agent re-reading a deleted brief improvises with zero context). The template encodes every standing rule (lineage rules, exclusive-resource protocol, gates, PR bar, Bugbot ownership) — fill its placeholders rather than writing from scratch, and keep "the orchestrator merges" unless Kevin says otherwise. Give the agent a sanctioned live-check target when the check has side effects (ideally one that doubles as pending cleanup — e.g. deleting a leftover test room verifies a delete feature AND clears a manual item).

## Phase 3 — Spawn

```bash
git fetch origin <base> &&
git worktree add ~/.herdr/worktrees/<repo>/<slug> -b <branch> origin/<base> &&   # NOT herdr worktree create — see herdr-ops.md
herdr worktree open --path ~/.herdr/worktrees/<repo>/<slug> --label "<TICKET> <slug>" --no-focus
# root pane id = .result.root_pane.pane_id in the JSON this prints (e.g. "wV:p1") — parse it, don't guess
herdr agent start <name> --kind claude --pane <root-pane-id>                  # retry once on startup timeout
herdr agent prompt <name> 'Read ~/.herdr/briefs/<slug>.md — it is your complete task brief. Execute it end to end (<one-line recap of the critical rules>).'
```

The `&&` chaining is load-bearing: a failed `git worktree add` ("branch already exists", left over from an aborted attempt) followed blindly by `worktree open` + `agent start` puts a working agent on the previous attempt's stale branch — delivery verification passes and the mistake surfaces only as a PR from the wrong head. Stop on any failure, fix the cause (delete the stale branch or pick a new slug), and restart the block. Single-quote the prompt and keep the recap free of backticks, `$`, and quotes — it's interpolated into your own shell, and a recap written in the docs' backticked style (`` `pnpm test` ``, `` `say` ``) would execute those commands on your machine instead of quoting them.

Branch name uses a prefix from the repo reference file's blessed list — the campaign monitor matches on prefix, so an off-list branch silently falls out of PR monitoring. Agent `<name>`: a short kebab slug of the feature (`dark-mode`, `csv-export`), not the ticket id; must be unique among live agents (`herdr agent list` first — names from prior campaigns can linger until their panes close).

Once delivery is verified (below), move the Linear ticket to **In Progress** — the ticket's state should track reality, and reality is that an agent is now working it. You own ticket state throughout the campaign; agents are briefed to leave it alone so there is exactly one writer.

**Verify delivery — never trust the prompt result.** `agent prompt`/`send-keys` can return ok while the pane never receives the keys. Confirm the agent flips to `working` AND re-read the pane to see the composer emptied. Recovery protocols for every observed failure mode (unsubmitted composer text, vim NORMAL mode, input-wedged panes, startup races) are in `references/herdr-ops.md` — read it the first time anything looks off.

## Phase 4 — Monitor

Arm one watcher per campaign by passing the script in `references/herdr-ops.md` as the `command` of the **Monitor tool** with `persistent: true` — the script's `while true` shape is correct *inside* Monitor and forbidden as a plain backgrounded Bash loop (those get killed and you lose the campaign's eyes without noticing). It watches agent `blocked`/`gone` transitions, PR state changes for the campaign's branch prefixes, and exclusive-resource owner changes. Then act only on events; stop it with TaskStop at batch close.

On every check-in, read each pane's `❯` input line: Kevin's typed messages often sit unsubmitted (his Enter doesn't register). A stuck instruction is work Kevin believes is happening — recover it (herdr-ops.md), or execute it yourself if relaying is blocked, and tell Kevin which you did.

Relay cross-agent facts the moment they matter: a sibling merge that forces a rebase-check, a discovered dormant feature, a resource collision. Agents can't see each other's work; you can.

Keep the Linear ticket current as milestones land: when the PR opens, check whether the repo's GitHub↔Linear integration moved the state (it links PRs by the ticket id in the branch) and set **In Review** yourself if it didn't, and run the repo reference file's own on-PR-open obligations (tracker rows and the like — re-read its Tracker section at this milestone rather than from memory); if the agent hits an allowed-outcome exit (does not reproduce, already implemented, blocked), post the verdict as a ticket comment and move the state to match (back to Backlog/Todo, or ask Kevin about canceling). A stakeholder reading the ticket should never be behind what you already know.

## Phase 5 — Audit and merge

The agent reports merge-ready; you verify independently — its claims are usually right, but the audit is what makes "green" mean something:

1. `gh pr view <n> --json mergeable,mergeStateStatus` → MERGEABLE / CLEAN.
2. `gh pr checks <n>` → all pass on the **latest** head.
3. Bugbot: every top-level `cursor[bot]` review comment has a non-cursor reply (`gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate`). Zero comments also passes.

Merge only under explicit or standing authorization (standing = Kevin granted it this campaign, or the campaign memory file records it). Absent that, "spin up an agent, same as before" authorizes the workflow, not the merge — report merge-ready and ask. Repo uses merge commits; never `--delete-branch` (branches may be checked out in worktrees). If `gh pr merge` is permission-blocked, `gh api repos/<owner>/<repo>/pulls/<n>/merge -X PUT -f merge_method=merge` is the same action — use it only when the merge itself is authorized, and say so.

If Kevin merges a PR himself (it happens), run the same audit post-hoc and report any gap.

## Phase 6 — Sync and close

After each merge: confirm the Linear ticket reached **Done** (the GitHub integration usually moves it on merge — correct it yourself if not), update the tracker row (repo reference file says where), execute any other post-merge standing orders the repo reference file records (e.g. closing a superseded reference-lineage PR with a note + link — left open, it becomes a false "someone else is working this" hit for the next ticket's Phase 1 PR search), notify the agent to stand down (verify delivery), and expect sibling PRs to need mergeability re-checks. Surface every leftover the agent reported for Kevin: test artifacts on shared environments (agents create, Kevin deletes), screenshots pending drag into PR bodies.

At batch close: verify the merged features together on the base branch (pull, drive each feature live), then ask Kevin before removing workspaces/worktrees — removal is destructive and outside standing authorization. On approval, teardown in this order: (1) message each agent to stand down and disarm its own watchers; (2) stop YOUR campaign monitors; (3) `herdr worktree remove --workspace <id> --force` per workspace + `git worktree prune`; (4) sweep for orphans — an agent with an armed watcher can re-acquire the exclusive-resource lock seconds before its workspace closes, leaving a dead-owner lock (verify the lock owner is alive before trusting it; clear it if not). Update the campaign memory file last. Agents may have created worktrees in OTHER repos (cross-repo tickets) — find and remove those too, after verifying their branches are pushed.

## Cross-cutting rules

- Exclusive resources (one app instance, one test device) go through the repo's lock protocol; never kill another owner's processes. A production copy of the app running from /Applications blocks every agent machine-wide — that's a Kevin decision, surface it (push notification if he's away) rather than waiting silently.
- Report faithfully: agents' findings (dormant features, pre-existing failures) go to Kevin verbatim-in-substance, and failures are stated as failures.
- Anything you were told mid-campaign that outlives this session (standing orders, new leftovers) goes into the campaign memory file immediately.
