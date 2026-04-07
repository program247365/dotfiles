---
title: "feat: Resolve qmd fork dependency for Bear Notes integration"
type: feat
status: completed
date: 2026-03-25
---

# Resolve qmd Fork Dependency for Bear Notes Integration

## Overview

You maintain a fork of `tobi/qmd` (`program247365/qmd`) with 3 commits that add Bear Notes source plugin support. PR #301 was closed without merge. Upstream has since shipped v2.0.0 and v2.0.1 with a major refactor (CLI/MCP split, store rewrite). Your fork is stuck on v1.1.0 and falling further behind. This plan resolves the fork dependency so you can either rejoin upstream or maintain the fork sustainably.

## Problem Frame

- **qmd works today** — Bear collection indexes 5,634 notes, search and query both function
- **qmd is stale** — v1.1.0 (fork) vs v2.0.1 (upstream), missing ~40 commits of bug fixes, embed improvements, ONNX conversion, and the v2.0 SDK redesign
- **Fork maintenance is unsustainable** — the 3 Bear commits touch `src/qmd.ts`, `src/store.ts`, `src/collections.ts`, and `src/mcp.ts`, which were all significantly refactored in v2.0. A naive rebase won't work.
- **install.sh auto-detects** fork vs upstream by checking if `src/sources/` exists on `tobi/qmd` main — a clever mechanism that will switch to npm install if upstream ever adopts the feature

## Requirements Trace

- R1. Bear Notes must remain searchable via `qmd search` and `qmd query`
- R2. qmd should track upstream releases without manual intervention
- R3. The install script must work for fresh installs and updates
- R4. The dotfiles `agents/claude/rules/qmd.md` and `bear-notes/SKILL.md` must stay accurate

## Scope Boundaries

- Not re-submitting the PR to upstream (that's your call, not automation)
- Not changing the Bear Notes skill or bcli integration
- Not adding new qmd features beyond what's needed for Bear

## Context & Research

### Current Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| Fork clone | `~/.kevin/tools/qmd/` | Built from source, symlinked to `~/.kevin/bin/qmd` |
| Install script | `~/.dotfiles/tools/qmd/install.sh` | Detects fork/upstream, installs, registers Bear, indexes |
| Collection config | `~/.config/qmd/index.yml` | `type: bear` with empty path/pattern |
| Claude rules | `agents/claude/rules/qmd.md` | Search usage instructions |
| Bear skill | `agents/claude/home/skills/bear-notes/SKILL.md` | Integrates qmd with bear-notes skill |
| Alias | `zsh/aliases.zsh` | `alias q='qmd'` |
| Permissions | `agents/claude/project/settings.local.json` | Bash(qmd:*) allowlisted |

### Fork vs Upstream Divergence

**Fork-only commits (3):**
1. `9c7523c` — Bear source plugin architecture (`src/sources/`, `src/bear.ts`)
2. `584be26` — Merge feat/source-plugins
3. `403b5ec` — MCP fix for source-type collections

**Upstream-only changes since fork point (`40610c3`):**
- `v2.0.0` — Major refactor: `src/qmd.ts` split into `src/cli/qmd.ts` + `src/mcp/server.ts`, store rewrite, SDK redesign
- `v2.0.1` — Bug fixes: embed memory, lockfile priority, zod pin, sqlite-vec cleanup
- ~40 commits of fixes, ONNX conversion, skill install, etc.

**Key structural conflicts:**
- `src/qmd.ts` — deleted upstream, replaced by `src/cli/qmd.ts` (3,020 lines removed)
- `src/mcp.ts` — deleted upstream, replaced by `src/mcp/server.ts` (738 lines removed)
- `src/store.ts` — heavily rewritten (+1,207 / -1,307 lines changed)
- `src/collections.ts` — changed upstream (84 lines diff), still has no `type` field

### Upstream `Collection` Interface (v2.0)

```
interface Collection {
  path: string;       // Required — filesystem path
  pattern: string;    // Glob pattern
  ignore?: string[];
  context?: ContextMap;
  update?: string;
  includeByDefault?: boolean;
}
```

No `type` field. No source plugin concept. No Bear awareness.

## Key Technical Decisions

### Decision: Rebase Bear changes onto upstream v2.0

**Rationale:** The fork exists solely for Bear support. Staying on v1.1.0 means missing real bug fixes (embed memory issues, sqlite-vec crashes, etc). The source plugin architecture is clean and well-designed — it just needs to be adapted to v2.0's new file structure.

**Alternative rejected: Maintain v1.1.0 fork indefinitely.** Growing divergence makes this increasingly costly. You'd need to cherry-pick individual upstream fixes, which is worse than a one-time rebase.

**Alternative rejected: Drop Bear from qmd, use bcli only.** qmd's hybrid search (BM25 + vectors + reranking) is materially better than bcli's basic search. The bear-notes skill already prefers qmd for discovery.

### Decision: Keep the fork + install.sh auto-detect pattern

**Rationale:** The install script's `src/sources/` detection is the right abstraction. If Tobi ever adopts source plugins, the script automatically switches to the npm package. No changes needed to the detection mechanism.

### Decision: Pin fork to upstream tags, not HEAD

**Rationale:** Currently the fork tracks `origin/main` which could break at any time. After rebasing, the fork should be based on a specific upstream tag (e.g., `v2.0.1`) so updates are deliberate.

## Open Questions

### Resolved During Planning

- **Q: Does upstream have any Bear/source plugin support?** No. `Collection` requires filesystem `path`. No `type` field. No source registry.
- **Q: Can the fork simply merge upstream?** No. The 3 Bear commits touch files that were deleted or heavily rewritten in v2.0. Manual conflict resolution required.
- **Q: Is the `src/sources/` API detection in install.sh still correct?** Yes. Upstream has no `src/sources/` directory. The check works.
- **Q: Is there a `claude/bear-on-2.0-iTzjd` branch?** Yes, on your fork's remote. It appears to be a prior attempt at porting Bear to v2.0. Should be investigated during implementation.

### Deferred to Implementation

- **Exact conflict resolution** — depends on reading v2.0's `src/cli/qmd.ts` and `src/mcp/server.ts` to understand where the Bear dispatch hooks should go
- **Whether `claude/bear-on-2.0-iTzjd` branch has useful work** — needs code review during implementation
- **Whether `better-sqlite3` dependency is still compatible** — v2.0 may have changed its sqlite strategy

## Implementation Units

- [ ] **Unit 1: Investigate the existing v2.0 rebase branch**

**Goal:** Determine if `claude/bear-on-2.0-iTzjd` already has a working or near-working port of Bear to v2.0.

**Requirements:** R1, R2

**Dependencies:** None

**Files:**
- Inspect: `origin/claude/bear-on-2.0-iTzjd` branch on the fork

**Approach:**
- Check out the branch, review what was done
- Compare its `src/bear.ts`, `src/sources/`, and integration points against upstream v2.0.1
- Determine if it builds, and how close it is to working
- If it's close, use it as the starting point. If not, start fresh from upstream v2.0.1 tag.

**Verification:**
- Clear decision on whether to build from this branch or start fresh

- [ ] **Unit 2: Port Bear source plugin to upstream v2.0.1**

**Goal:** Rebase the 3 Bear commits onto upstream v2.0.1, adapting to the new file structure.

**Requirements:** R1, R2

**Dependencies:** Unit 1

**Files:**
- Create: `src/bear.ts` (Bear SQLite reader — likely unchanged)
- Create: `src/sources/types.ts`, `src/sources/index.ts`, `src/sources/bear.ts` (source plugin registry)
- Create: `src/sources/README.md`
- Modify: `src/collections.ts` (add optional `type` field to `Collection`)
- Modify: `src/store.ts` (make `path`/`pattern` optional for source-type collections, add `indexDocuments()`)
- Modify: `src/cli/qmd.ts` (dispatch `collection add --type` and `update` through source registry)
- Modify: `src/mcp/server.ts` (make StatusResult path/pattern optional)

**Approach:**
- Start from upstream `v2.0.1` tag
- Apply the source plugin architecture adapted to v2.0's file layout
- The core `src/bear.ts` (SQLite reader) should port cleanly — it has no dependencies on qmd internals
- The `src/sources/` directory and registry should port cleanly — it's self-contained
- The integration points (`collections.ts`, `store.ts`, CLI, MCP) need manual adaptation to v2.0's APIs
- The `indexDocuments()` function (generic non-filesystem indexing) moves from the old monolithic `qmd.ts` to wherever v2.0 handles indexing (likely `store.ts`)

**Patterns to follow:**
- Existing `src/bear.ts` from v1.1.0 fork as reference for the SQLite reader
- v2.0's `src/cli/qmd.ts` for CLI dispatch patterns
- v2.0's `src/mcp/server.ts` for MCP handler patterns

**Test scenarios:**
- `qmd collection add --type bear --name bear` succeeds
- `qmd search "test" -c bear` returns results
- `qmd query "test" -c bear` returns results with reranking
- `qmd update` re-indexes bear collection
- `qmd collection list` shows bear with correct count
- `tsc --noEmit` passes
- Existing filesystem collection functionality unaffected

**Verification:**
- All test scenarios pass
- `qmd --version` reports v2.0.1-based version
- Bear collection indexes successfully with >5,000 notes

- [ ] **Unit 3: Update fork remote and install script**

**Goal:** Point the fork's main branch to the rebased v2.0.1 + Bear, and update install.sh for any v2.0 changes.

**Requirements:** R2, R3

**Dependencies:** Unit 2

**Files:**
- Modify: `~/.dotfiles/tools/qmd/install.sh`

**Approach:**
- Force-push rebased main to `program247365/qmd` (after confirming with user)
- Check if v2.0 changed the build process (still `npm run build`? still `dist/qmd.js`?)
- Update install.sh if the build output path or process changed
- Consider adding a version check that warns when fork is behind upstream

**Test scenarios:**
- Fresh install via `install.sh` succeeds
- Update of existing install succeeds
- Bear collection is registered and indexed

**Verification:**
- `qmd --version` shows new version after running install.sh
- `qmd collection list` shows bear collection
- `qmd search "test" -c bear` returns results

- [ ] **Unit 4: Update dotfiles references for v2.0 compatibility**

**Goal:** Ensure all qmd references in dotfiles are accurate for v2.0.

**Requirements:** R4

**Dependencies:** Unit 3

**Files:**
- Review: `agents/claude/rules/qmd.md` (likely unchanged — search/query syntax is stable)
- Review: `agents/claude/home/skills/bear-notes/SKILL.md` (qmd usage section)
- Review: `agents/claude/project/settings.local.json` (permissions)
- Review: `~/.config/qmd/index.yml` (collection config format)

**Approach:**
- Verify each file's qmd references against v2.0's actual CLI interface
- Update any changed command syntax or options
- The `--help` output from earlier confirms search/query syntax is unchanged, so most references should be stable

**Test scenarios:**
- All documented commands in `qmd.md` work as described
- Bear skill's qmd usage works end-to-end

**Verification:**
- Manual walkthrough of each documented command

## System-Wide Impact

- **Bear Notes skill:** Depends on `qmd search -c bear` and `qmd query -c bear` — syntax unchanged, but underlying index format may differ between v1.1.0 and v2.0. Full re-index during install handles this.
- **Embeddings:** v2.0 changed embedding internals (memory fixes, ONNX support). Existing embeddings may need regeneration via `qmd embed -f`.
- **MCP server:** v2.0 moved MCP to `src/mcp/server.ts`. If you use `qmd mcp` directly, the interface should be compatible but worth verifying.
- **Collection config:** `~/.config/qmd/index.yml` format may have changed in v2.0 — the `type: bear` field is fork-only and needs to survive.

## Risks & Dependencies

- **Force-push to fork main:** Required for the rebase. Low risk since you're the only consumer, but should be confirmed before executing.
- **v2.0 build dependencies:** May require different Node version or additional native deps. `npm install` should handle this, but could fail on first attempt.
- **Embedding model compatibility:** v2.0 may use a different embedding model. Full re-embed may be needed, which takes time depending on note count.
- **Upstream moves fast:** Between planning and execution, upstream could ship v2.1. Pin to `v2.0.1` tag to avoid a moving target.

## Sources & References

- PR #301 (closed): https://github.com/tobi/qmd/pull/301
- Fork: https://github.com/program247365/qmd
- Upstream: https://github.com/tobi/qmd
- Install script: `~/.dotfiles/tools/qmd/install.sh`
- Existing rebase branch: `origin/claude/bear-on-2.0-iTzjd`
