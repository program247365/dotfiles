# Brief template

Write the filled brief to `~/.herdr/briefs/<slug>.md` (durable — /tmp does not survive reboots or macOS's periodic cleanup, and the brief must outlive a multi-day campaign). Replace every `{{...}}`; delete sections that genuinely don't apply (don't leave placeholders in). The brief is the agent's ONLY context — every rule you expect it to follow must be in here or in a file it's told to read. Load the repo reference file (`<repo>-repo.md`) for the values marked *(repo)*.

```markdown
# {{Feature|Fix}}: {{one-line problem statement}} ({{TICKET-ID}}) — {{port from <old-branch> | extension of <PR>}}

## Context
- {{Lineage facts (repo): base branch, archived reference branch, the never-merge-across rule, how to reference old code (`git show <old-branch>:<path>`).}} You are in a fresh worktree on branch `{{branch}}` off `origin/{{base}}`; PR back to `{{base}}`.
- Linear ticket **{{TICKET-ID}}** (assigned to Kevin) is the spec. {{One-paragraph restatement of the problem, naming the concrete gap and quoting any code comment that shows the gap is deliberate.}}

## Scope
- Reference implementation: {{exact old-lineage path(s) + what to take from them: UI copy, endpoint, semantics}}.
- {{Port notes: how the old patterns translate to this lineage's architecture (repo) — state layer, API-client boundary, navigation.}}
- {{Decisions the agent must make and document in the PR body, with your guidance on each.}}
- {{Sibling coordination: in-flight PRs touching nearby territory; what to preserve from freshly-merged work.}}
- **Invoke the {{repo state-layer skill (repo)}} before state work**: {{one-line discipline summary}}.

## Allowed outcomes
- {{The success path: ship the PR.}}
- {{The honest exits, when they apply: "does not reproduce (state the evidence, no PR)", "already implemented at HEAD (cite the commit, no PR)", "blocked on X (report, hold)". Naming these tells the agent a null result is a deliverable, not a failure to route around.}}

## Process (standing rules — all mandatory)
- Live checks only under the {{exclusive-resource protocol (repo): lock path, owner name = agent name, ticket id, poll cadence, never kill another owner's processes, the recording/WAV rule if applicable}}. **No audio through the speakers — no `say` runs.**
- Worktree gotchas (repo): {{files to copy from the main checkout, install quirks}}.
- Gates (repo): {{unit tests for the specific behaviors, full test command + known flakiness protocol, typecheck, lint, boundary checks}}.
- Live check: {{exact click-path with expected observable results; the sanctioned target for destructive checks; what NOT to do (e.g. never click an undismissable native dialog — unit-pin both outcomes instead)}}. Screenshots to `~/Desktop/pr-screenshots/{{ticket-dir}}/`. {{If the check creates artifacts on a shared environment: report them for Kevin to delete; do NOT delete them yourself — unless the artifact IS the sanctioned target.}}
- PR: push your branch (pre-authorized), base `{{base}}`, title `{{title including TICKET-ID}}`, Summary + Test plan, no AI mentions, stage files by name, never commit `.claude/settings.local.json`.
- Linear: {{TICKET-ID}} is in your branch/title so it auto-links. Leave the ticket state alone — the orchestrator manages it at every milestone, so touching it yourself creates two writers.
- **You own the PR to merge-ready**: CI + Bugbot; every Bugbot finding fixed AND replied to (assess `@cursor push <hash>` first — if its preview diff is right, post it and `git pull` after; else own fix), reply with SHA + rationale. Report when fully green, mergeable (zero merge conflicts — re-check after any merge into {{base}}), Bugbot-clean — the orchestrator merges.
```

## Filling guidance

- **The recap line in the spawn prompt matters**: the prompt that points the agent at this file should recap the 3–4 rules whose violation is most expensive for THIS task (destructive-check target, audio, sibling coordination), because if the brief read is ever skipped or truncated, the prompt is the fallback. Write the recap in plain words with no backticks, `$`, or quotes — it's interpolated into the orchestrator's shell command (SKILL.md Phase 3), where a backticked `say` runs instead of being quoted.
- **Sanctioned targets**: for any live check with side effects, name one specific target and forbid all others. Prefer targets that double as pending cleanup. This covers *creation* hazards, not just destruction: on a shared environment, typing broadcasts typing indicators, sends land in real rooms, and drafts persist — so a check that only needs to type gets a dedicated test room and an explicit "never press send"-style boundary.
- **Decisions sections earn their space**: naming the judgment calls upfront ("Follow-thread is redundant inside a thread — pick the least surprising behavior and say why") gets you a documented decision in the PR body instead of a silent one in the diff.
