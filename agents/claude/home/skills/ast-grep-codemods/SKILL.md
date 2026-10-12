---
name: ast-grep-codemods
description: Use when a change or check must be applied to the same code shape across many files (roughly 20+ call sites or a whole src/ tree), such as a mechanical migration, rename, API swap, or a repo-wide structural rule to enforce in CI, and especially when regex looks unsafe because of multi-line calls, nested arguments, same-named methods on other objects, or decoys in comments and strings. Also use when tempted to hand-roll a tokenizer, parser walker, or install acorn/babel/jscodeshift to do a rewrite or lint.
---

# ast-grep codemods

## Overview

ast-grep is a structural search, rewrite, and lint tool. A pattern is just code with
`$VARS` in it; it matches AST nodes, so comments, strings, and `other.sameName()` are
excluded by construction. A rewrite is a YAML rule you can read, dry-run, re-run, and
commit. **Get it installed and write a rule instead of writing a parser.**

## When to use

- A mechanical rewrite across many files (migration, rename, signature change).
- A repo-wide structural rule for CI with no ESLint rule for it.
- Any time you catch yourself about to write a tokenizer, walk an acorn/babel AST, or
  chain `sed`/`perl` around multi-line calls.

**Not for:** a handful of sites (just edit them), non-code text, or rewrites that need
type information. Plain `rg` is still right for *finding* things.

## Install (global only; ask first)

Check with `command -v ast-grep`. If it is missing, **ask before installing** and name the exact
command. Do not hand-roll a tokenizer or parser walker while waiting for the answer; the install
is the task's blocker, and a yes is one line.

```bash
brew install ast-grep            # macOS
# elsewhere: cargo install ast-grep  |  pip install ast-grep-cli  |  npm i -g @ast-grep/cli
```

**Never add ast-grep to a repo's package.json, lockfile, or other dependency manifest.**
It is a developer tool, like ripgrep. Rule files may live in the repo; the binary does not.
The binary is `ast-grep`. `sg` is a deprecated alias; do not use it.

## Workflow

1. **Count before touching.** `ast-grep run -p 'legacyLog($$$ARGS)' -l js src --json=compact`
   piped to a length count. Compare against a plain `rg` count; the gap is your decoys.
2. **Survey the shapes** before writing rules: `rg -I 'legacyLog\(' | sort | uniq -c | sort -rn` for calls,
   `rg -I '^import.*legacyLog' | sort | uniq -c` for imports. One rule document per shape you actually saw.
3. **Dry run:** `ast-grep scan -r codemods/x.yml src` prints the diff without writing.
4. **Apply:** add `--update-all`.
5. **Verify:** re-count (expect 0 remaining of the shape, decoys unchanged), run the
   language's syntax check on every changed file, read the diff.

## Verified example: migration

```yaml
# codemods/legacy-log.yml   (applied with: ast-grep scan -r codemods/legacy-log.yml --update-all src)
id: legacy-log-two-arg
language: javascript
rule:
  pattern: legacyLog($MSG, $LEVEL)
constraints:
  LEVEL:
    kind: string          # variable levels are skipped; see "Shapes you cannot rewrite faithfully"
transform:
  LVL:
    substring: { source: $LEVEL, startChar: 1, endChar: -1 }   # strip quotes
fix: log.$LVL($MSG)
---
id: legacy-log-one-arg
language: javascript
rule:
  pattern: legacyLog($MSG)
fix: log.info($MSG)
---
id: legacy-log-import
language: javascript
rule:
  pattern: import { legacyLog } from '$SRC'
fix: import { log } from '$SRC';
```

Multi-line calls, nested commas, escaped quotes, block comments, template strings, and
`audit.legacyLog(...)` were all handled by this file with no special cases.

**Shapes you cannot rewrite faithfully** (here, `legacyLog(msg, level)` with a variable level):
either leave them untouched with their old import intact, or rewrite them with a companion rule
(`constraints: LEVEL: {kind: identifier}`, `fix: log[$LEVEL]($MSG)`) and say what changed
semantically. Either way, list every site in the report. Never let the re-count silently stay
nonzero.

## Verified example: CI rule

```yaml
# sgconfig.yml
ruleDirs:
  - rules
```

```yaml
# rules/no-template-sql.yml
id: no-template-sql
language: javascript
severity: error
message: db.query must take a plain string plus params
rule:
  any:
    - pattern: db.query($SQL)
    - pattern: db.query($SQL, $$$REST)
constraints:
  SQL:
    kind: template_string
```

`ast-grep scan src` exits 1 on any error-severity match and reads `sgconfig.yml` from the
working directory, so run it from the repo root. Wire it as `"lint": "ast-grep scan src"` and
chain it into `test` if the lead wants `npm test` to fail. The CI job installs the binary in its
own setup step, pinned to the local version (`npm i -g @ast-grep/cli@0.50.0`), never via package.json.
The rule catches `db\n  .query(...)` and `db.query(/* c */ \`...\`)` and ignores mentions in
comments and strings.

File:line inventory (`range.start.line` is zero-based; a multi-line match reports its first line):

```bash
ast-grep scan src --json=compact 2>/dev/null | python3 -c "import json,sys
for m in json.load(sys.stdin): print(f\"{m['file']}:{m['range']['start']['line']+1}\")"
```

## Gotchas (all verified on 0.50)

| Gotcha | Fix |
|---|---|
| `f($A, $$$REST)` does **not** match `f(x)`; a trailing `$$$` after a comma needs at least the comma | Use `any:` with one pattern per arity |
| `$A` matches one node; `$$$A` matches zero or more | Use `$$$` only where arity varies |
| Node kind names are tree-sitter's (`template_string`, `string`, `member_expression`) | `--debug-query=ast` prints a pattern's kinds |
| `kind: string` does not match a template literal, so `f(x, \`error\`)` is skipped silently | Constrain with `any: [{kind: string}, {kind: template_string}]` when both occur |
| A pattern must parse as valid code on its own | Wrap fragments, or use `kind:` + `has:` rules |
| Counting needs `--json=compact`; plain output is for humans | Pipe to a JSON length |

## Rationalizations seen in testing

| Excuse | Reality |
|---|---|
| "No AST tool is installed, so I'll hand-roll a tokenizer" | Installing takes one command. A 150-line tokenizer took 4 minutes and still changed semantics. |
| "Installing needs network, so I'll avoid it" | Ask for the one-command global install. A parser written while waiting is the expensive path. |
| "acorn is one dep, the walker is only 60 lines" | The ast-grep rule is 10 lines of YAML, declarative, and reusable for the next rule. |
| "AST rewrites reformat files and bloat the diff" | True of jscodeshift. ast-grep patches only the matched text. |
| "The shapes are regular enough for regex" | Check the trigger list in the description. One multi-line call or decoy breaks it. |
