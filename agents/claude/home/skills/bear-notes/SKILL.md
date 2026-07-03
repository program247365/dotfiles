---
name: bear-notes
description: "Search, read, and create notes in Bear. Use when the user asks about their notes, wants to search Bear, save something to Bear, or reference their personal knowledge base."
---

# Bear Notes Assistant

You have full access to the user's Bear notes via `bearcli`, Bear's official CLI (Bear 2.8+). It reads and writes Bear's local SQLite directly through Bear's own frameworks — no auth, no CloudKit roundtrip, no cache, no rate limits, and changes appear immediately in the running app.

## Setup

`bearcli` ships inside the Bear app bundle. The dotfiles install script symlinks it onto PATH:

```bash
~/.dotfiles/tools/bearcli/install.sh
```

Verify: `bearcli list -n 1 --format json` should return a note row.

## Available Commands

All commands accept `--format tsv|csv|json` (default `tsv`). Use `--format json` for parsing. Mutating commands print nothing on success in TSV/CSV; in JSON they emit `{"ok":true}`. Run `bearcli help all` for the full reference.

### Search Notes

```bash
bearcli search "query"                              # default TSV, all matches
bearcli search "query" --format json
bearcli search "query" -n 20 --format json          # cap to 20
bearcli list --tag "tagname" --format json          # tag filter (incl. nested)
bearcli list --location all --format json           # incl. trash/archive
```

`bearcli search` supports Bear's full search syntax inline:

- Text: `keyword`, `"exact phrase"`, `-negation`
- Tags: `#tag`, `!#tag` (exact, no children), `#*/tag` (subtags only)
- Dates (modified): `@today`, `@yesterday`, `@last7days`, `@date(YYYY-MM-DD)`, `@date(>2026-01-01)`
- Created: `@ctoday`, `@created7days`, `@cdate(...)`
- Tasks: `@todo`, `@done`, `@task`
- State: `@pinned`, `@untagged`, `@empty`, `@untitled`, `@locked`
- Content: `@images`, `@files`, `@attachments`, `@code`
- Combine freely: `bearcli search "@today @todo meeting" --format json`

### Read a Note

```bash
bearcli cat NOTE_ID                                  # raw markdown only
bearcli show NOTE_ID --format json --fields all,content   # full metadata + body
bearcli show --title "Mars" --format json --fields all,content   # by title
```

### Create a Note

```bash
bearcli create "Title" --content "Body" --tags "tag1,tag2"
NEW_ID=$(bearcli create "Title" --content "Body" --tags "tag1" --format json --fields id \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
```

If the body has a `# heading` matching the title, Bear strips the duplicate automatically. To avoid an auto-derived title, omit the title positional and put `# Title` in `--content`.

### Edit a Note

```bash
bearcli append NOTE_ID --content "text to append"
bearcli append NOTE_ID --content "text" --position beginning   # prepend (after title/tags)
bearcli edit NOTE_ID --at "old text" --replace "new text"      # surgical, exact match
bearcli edit NOTE_ID --at "## Section" --insert "\nNew line"   # insert after match
bearcli edit NOTE_ID --at "cat" --replace "dog" --all --word   # whole-word, all matches
printf '%s' "replacement body" | bearcli write NOTE_ID         # overwrite entire content
```

`bearcli write` reads from stdin when `--content` is omitted. `bearcli write` accepts `--base <hash>` (from `bearcli show --fields hash`) for optimistic concurrency — pass it when the note may have been edited concurrently.

> **Editor flow:** for an interactive edit, do `bearcli cat ID > /tmp/note.md && $EDITOR /tmp/note.md && bearcli write ID < /tmp/note.md`.

### Tags

```bash
bearcli tags list --format json                     # global tag list
bearcli tags list NOTE_ID --format json             # tags on one note
bearcli tags add NOTE_ID work work/meetings         # adds without touching body text
bearcli tags remove NOTE_ID draft
bearcli tags rename old-name new-name [--force]
bearcli tags delete unused-tag
```

`tags add`/`remove` are the right call for tag mutations — they don't disturb the note body or its modification date. Use `bearcli edit ... --at ... --replace ...` only when you specifically need the inline `#tag` text changed.

### Attachments

```bash
bearcli attachments list NOTE_ID --format json
cat photo.jpg | bearcli attachments add NOTE_ID --filename photo.jpg
bearcli attachments add NOTE_ID --filename photo.jpg < photo.jpg
bearcli attachments delete NOTE_ID --filename photo.jpg
bearcli attachments save NOTE_ID --filename photo.jpg > photo.jpg
```

After adding, reference the attachment in the note body with `![photo.jpg](photo.jpg)` (use `bearcli edit --at "<anchor>" --insert` or `bearcli append`).

### Open / Pin / Lifecycle

```bash
bearcli open NOTE_ID                                # foregrounds Bear with note open
bearcli open NOTE_ID --header "Section" --edit      # scroll + start editing
bearcli pin add NOTE_ID global                      # All Notes pin
bearcli pin add NOTE_ID work projects               # tag-scoped pins
bearcli pin remove NOTE_ID global
bearcli trash NOTE_ID
bearcli archive NOTE_ID
bearcli restore NOTE_ID
```

## QMD Search (Preferred for Discovery)

When the user asks to search or find Bear notes, prefer `qmd` over `bearcli search` — it uses BM25 full-text search, vector similarity, and LLM reranking for much better relevance.

```bash
qmd search "query" -c bear --json                   # fast keyword (BM25)
qmd query  "query" -c bear --json                   # hybrid + reranking
qmd get "#abc123"                                    # full document by docid
qmd get "uuid.md" --full
```

QMD returns docids (`#abc123`), scores, titles, and snippets. The `path` field is the Bear UUID + `.md` — strip `.md` to get the bearcli `NOTE_ID` for write operations.

**Use `bearcli search` directly when:**
- You need Bear's date/state operators (`@today`, `@last7days`, `@todo`, `@untagged`, `@images`)
- You need exact-match tag filtering (`!#tag`, `#*/subtag`)
- The QMD index is stale (tell user to run `qmd update` — it mirrors Bear notes via bear-sync first, then re-indexes)

**Always use bearcli for mutations** (`create`, `edit`, `write`, `append`, `tags`, `attachments`, `trash`, `open`).

## Workflow

**When answering questions:**
1. **Search first** — `qmd query` for relevance ranking, `bearcli search` for date/state filters
2. **Read details** — `bearcli show ID --format json --fields all,content` for full content
3. **Synthesize** — combine across notes
4. **Cite sources** — always mention which note titles you're referencing

**When creating content:**
1. Offer to save important information to Bear
2. Suggest tags from existing taxonomy (run `bearcli tags list --format json` to check)
3. Ask if the user wants `bearcli open ID` to jump into the new note

## Enrich Saved Tweets Workflow

Use this when the user asks to enrich, process, or title their saved tweet notes. The full per-note enrichment lives in the `notes-organize-tweets` slash command — invoke it for the idempotent pipeline. The high-level flow:

1. **Audit** existing tweet notes via `bearcli search "x.com" --format json --fields all,content,attachments,tags`. Classify each note's needs (`image`, `body`, `inbox_tag`, `extra_tags`).
2. **Playwright** fetch tweet content + screenshot for notes needing `image` or `body`.
3. **Mutate** via `bearcli`:
   - Image: `bearcli attachments add ID --filename tweet_screenshot.png < /tmp/tweet_<id>.png`
   - Structured body: `bearcli write ID --content "..."` (Bear derives the title from the first heading)
   - Image markdown line: `bearcli edit ID --at "<anchor>" --insert "\n![tweet_screenshot.png](tweet_screenshot.png)"`
   - Inbox tag: `bearcli tags add ID inbox/saved-tweets`
   - Extra tags: `bearcli tags add ID #learn/something`

No Bear restart, no SQLite, no Core Data dance — `bearcli` writes through Bear's own frameworks.

## Attach a Single Screenshot to a Note

The whole flow is one line:

```bash
bearcli attachments add "$NOTE_ID" --filename screenshot.png < /tmp/screenshot.png
bearcli edit "$NOTE_ID" --at "<anchor line>" --insert "\n![screenshot.png](screenshot.png)"
```

Or, for a fresh note created with the image at the bottom:

```bash
ID=$(bearcli create "Title" --content "# Title\n\n![screenshot.png](screenshot.png)" \
       --format json --fields id | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
bearcli attachments add "$ID" --filename screenshot.png < /tmp/screenshot.png
```

Bear renders the image immediately — no app restart. The attachment is stored in Bear's `Note Images` directory by Bear itself, with the correct Core Data relationships in place.

## Notes

- **bearcli IDs are Bear's `ZUNIQUEIDENTIFIER`** — interchangeable with the Bear URL scheme: `bear://x-callback-url/open-note?id=<bearcli_id>`. Prefer `bearcli open ID` over the URL scheme.
- **No auth, no cache, no sync.** `bearcli` reads/writes Bear's running database in place. Drop any retry-on-rate-limit logic — there are no rate limits.
- **No Bear restart needed for any operation**, including attachments and tag changes. This was the single biggest pain point of the previous `bcli` (CloudKit) workflow.
- **Optimistic concurrency:** for risky writes, capture `hash` from `bearcli show --fields hash` and pass `--base <hash>` to `bearcli write` — the write is rejected if the note changed since the read.
- **Tags can be hierarchical:** `work/projects/2025`. `bearcli tags add ID a b/c` adds both, leaving the body untouched.
- **Wiki links syntax (in note body):** `[[note title]]`, `[[note title|alias]]`. `@wikilinks` / `@backlinks` in search find them.
- **Locked notes** return metadata via `bearcli show` but reject `--fields content`.
- **Always search before claiming a note doesn't exist.** Prefer `qmd` for natural-language searches; fall back to `bearcli search` for date or state operators.
- **MCP server alternative:** `bearcli mcp-server` exposes the same surface over JSON-RPC stdio for MCP-aware clients.
