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

Read commands accept `--format tsv|csv|json` (default `tsv`). Use `--format json` for parsing. Commands that change state or perform an app action print nothing on success and do not accept `--format` — the exit code is the signal (0 success, 1 business error, 64 usage error). Run `bearcli help all` for the full reference.

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
bearcli cat NOTE_ID --format json                    # {"content":...,"hash":...} — hash feeds overwrite --base
bearcli cat NOTE_ID --section "## Tasks"             # just one section (JSON adds the section's hash)
bearcli outline NOTE_ID                              # section addresses + byte ranges
bearcli search-in NOTE_ID --string "TODO"            # exact-match hits with snippets (searches attachment OCR text too)
bearcli show NOTE_ID --format json --fields all,content   # full metadata + body
bearcli show --title "Mars" --format json --fields all,content   # by title
```

**Section addressing:** `--section` (on `cat`, `outline`, `search-in`, `append`, `edit`, `overwrite`) scopes the operation to one section. An address is the heading line as written (`"## Tasks"`); if the heading repeats, prepend ancestor headings and/or append a 1-based index, joined with `\n` (`"# Build\n## Install\n2"`). A trailing `preamble` line addresses a section's lead text above its first subheading. `bearcli outline` prints every section's copy-pasteable address; ambiguous addresses come back with an error suggesting valid ones.

### Create a Note

```bash
bearcli create "Title" --content "Body" --tags "tag1,tag2"
bearcli create "Title" --content "Body" --if-not-exists      # return the existing note if the title exists
NEW_ID=$(bearcli create "Title" --content "Body" --tags "tag1" --format json --fields id \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
```

If the body has a `# heading` matching the title, Bear strips the duplicate automatically. To avoid an auto-derived title, omit the title positional and put `# Title` in `--content`.

### Edit a Note

```bash
bearcli append NOTE_ID --content "text to append"
bearcli append NOTE_ID --content "text" --position beginning   # prepend (after title/tags)
bearcli append NOTE_ID --section "## Tasks" --content "- [ ] New task"  # grow one section
bearcli edit NOTE_ID --find "old text" --replace "new text"          # surgical, exact match
bearcli edit NOTE_ID --find "## Section" --insert-after "\nNew line" # insert after match
bearcli edit NOTE_ID --find "stale paragraph\n" --delete             # delete matched text
bearcli edit NOTE_ID --find "cat" --replace "dog" --all --word       # whole-word, all matches
bearcli edit NOTE_ID --find "a" --replace "A" --find "b" --delete    # batch: atomic multi-edit
bearcli edit NOTE_ID --section "## Tasks" --find "done" --replace "DONE"  # confine find to a section
printf '%s' "replacement body" | bearcli overwrite NOTE_ID           # overwrite entire content
bearcli overwrite NOTE_ID --section "## Tasks" --content "## Tasks\nRewritten"  # replace one section
```

Batched edits pair each `--find` with the action flag that follows it; if any edit fails, none apply. `--ignore-case` and `--no-update-modified` are available.

`bearcli overwrite` reads from stdin when `--content` is omitted (prefer stdin — `--content` interprets `\n`/`\t` escapes). It accepts `--base <hash>` for optimistic concurrency — the hash comes from a prior read (`bearcli cat NOTE_ID --format json`, whole-note or `--section`; reading is the only source) and the write is rejected if the target changed since. Pass it when the note may have been edited concurrently. Section overwrites must start with the section's heading line (address `"## Tasks\npreamble"` to replace only the body); empty content deletes the section. Overwrites that drop an existing attachment reference are rejected unless `--force` is passed.

> **Editor flow:** for an interactive edit, do `bearcli cat ID > /tmp/note.md && $EDITOR /tmp/note.md && bearcli overwrite ID < /tmp/note.md`.

### Tags

```bash
bearcli tags list --format json                     # global tag list
bearcli tags list NOTE_ID --format json             # tags on one note
bearcli tags add NOTE_ID work work/meetings         # adds without touching body text
bearcli tags remove NOTE_ID draft
bearcli tags rename old-name new-name [--force]
bearcli tags delete unused-tag
```

`tags add`/`remove` are the right call for tag mutations — they don't disturb the note body or its modification date. Use `bearcli edit ... --find ... --replace ...` only when you specifically need the inline `#tag` text changed.

### Attachments

```bash
bearcli attachments list NOTE_ID --format json
cat photo.jpg | bearcli attachments add NOTE_ID --filename photo.jpg
bearcli attachments add NOTE_ID --filename photo.jpg < photo.jpg
bearcli attachments add-url NOTE_ID --url https://example.com/photo.jpg   # fetch over HTTPS
bearcli attachments delete NOTE_ID --filename photo.jpg
bearcli attachments save NOTE_ID --filename photo.jpg > photo.jpg
```

`add`/`add-url` append a markdown link to the attachment automatically (on filename collision Bear renames, and the link uses the resolved name — no manual link insertion needed). To position the link elsewhere, move it afterwards with `bearcli edit`. `delete` removes both the bytes and the markdown link.

### Open / Pin / Lifecycle

```bash
bearcli app open NOTE_ID                            # foregrounds Bear with note open
bearcli app open NOTE_ID --header "Section" --edit  # scroll + start editing
bearcli app open NOTE_ID --new-window --float       # separate / always-on-top window
bearcli app open NOTE_ID --selection-text "Phobos"  # open with text selected
bearcli app get-selection --format json             # what's selected in Bear right now
bearcli pin list                                    # every pin context in use
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

**Always use bearcli for mutations** (`create`, `edit`, `overwrite`, `append`, `tags`, `attachments`, `trash`, `app open`).

## Workflow

**When answering questions:**
1. **Search first** — `qmd query` for relevance ranking, `bearcli search` for date/state filters
2. **Read details** — `bearcli show ID --format json --fields all,content` for full content
3. **Synthesize** — combine across notes
4. **Cite sources** — always mention which note titles you're referencing

**When creating content:**
1. Offer to save important information to Bear
2. Suggest tags from existing taxonomy (run `bearcli tags list --format json` to check)
3. Ask if the user wants `bearcli app open ID` to jump into the new note

## Enrich Saved Tweets Workflow

Use this when the user asks to enrich, process, or title their saved tweet notes. The full per-note enrichment lives in the `notes-organize-tweets` slash command — invoke it for the idempotent pipeline. The high-level flow:

1. **Audit** existing tweet notes via `bearcli search "x.com" --format json --fields all,content,attachments,tags`. Classify each note's needs (`image`, `body`, `inbox_tag`, `extra_tags`).
2. **Playwright** fetch tweet content + screenshot for notes needing `image` or `body`.
3. **Mutate** via `bearcli`:
   - Image: `bearcli attachments add ID --filename tweet_screenshot.png < /tmp/tweet_<id>.png` (the markdown link is appended automatically; move it with `bearcli edit` if it belongs elsewhere)
   - Structured body: `printf '%s' "..." | bearcli overwrite ID` (Bear derives the title from the first heading)
   - Inbox tag: `bearcli tags add ID inbox/saved-tweets`
   - Extra tags: `bearcli tags add ID #learn/something`

No Bear restart, no SQLite, no Core Data dance — `bearcli` writes through Bear's own frameworks.

## Attach a Single Screenshot to a Note

The whole flow is one line — the markdown link is appended to the note automatically:

```bash
bearcli attachments add "$NOTE_ID" --filename screenshot.png < /tmp/screenshot.png
```

To place the image somewhere other than the end, move the auto-appended link:

```bash
bearcli edit "$NOTE_ID" --find "\n![screenshot.png](screenshot.png)" --delete \
                        --find "<anchor line>" --insert-after "\n![screenshot.png](screenshot.png)"
```

Bear renders the image immediately — no app restart. The attachment is stored in Bear's `Note Images` directory by Bear itself, with the correct Core Data relationships in place.

## iCloud Sync Conflicts

Bear syncs via CloudKit, and **CloudKit only syncs while the Bear app is running**. `bearcli` writes to the local database regardless — so a write made before a newer remote version has synced down produces a conflict: CloudKit keeps both versions, creating a duplicate note marked with a red fork icon in the note list. (Observed 2026-08-11: notes enriched on one machine, then edited via bearcli on another before sync caught up.)

Mechanics, learned the hard way:

- The fork icon is driven by `ZSFNOTE.ZCONFLICTUNIQUEIDENTIFIER` — a permanent stamp (`<sibling-note-id>/<timestamp>`) on the conflict-created copy. It means "born from a conflict," not "conflict currently unresolved."
- Bear's FAQ ([how-bear-pro-handles-conflicted-notes](https://bear.app/faq/how-bear-pro-handles-conflicted-notes/)) says deleting one version or editing the note resolves the conflict — **but that logic runs in Bear's UI layer only**. `bearcli trash` and `bearcli overwrite` do NOT clear the stamp (verified against the DB). Never write the SQLite column directly.
- Detect flagged notes read-only:
  ```bash
  sqlite3 -readonly ~/Library/Group\ Containers/9K33E3U3T4.net.shinyfrog.bear/Application\ Data/database.sqlite \
    "SELECT ZUNIQUEIDENTIFIER FROM ZSFNOTE WHERE ZCONFLICTUNIQUEIDENTIFIER IS NOT NULL AND ZTRASHED=0"
  ```

**Resolving a conflict pair via bearcli:**

1. Compare the pair (`cat`, `tags list`, `attachments list`); keep the richer version, trash the stale one.
2. If the survivor shows the fork icon, clear it by recreating the note under a fresh ID: `bearcli create` a placeholder → copy each attachment (`attachments save` old → `attachments add` new, binary-safe) → `bearcli overwrite` the new note with the original content (stdin) → re-add any tags missing from the body → verify title/content/tags/attachments match → trash the flagged original. Wiki links survive (they resolve by title); the note's created date resets to today.

Not every duplicate is a sync conflict: two near-identical notes created days apart (no conflict stamp in the DB) are a double-save — the user captured the same thing twice. The stamp query above is the discriminator. Double-saves resolve the same way minus the recreate step: merge tags into the better copy, trash the other.

**Prevention:** before a batch of bearcli writes, make sure Bear is running and give sync a settle window — `open -g -a Bear`, then wait ~60s if it was cold-launched (~15s if already running). A local audit cannot distinguish "never edited" from "edited elsewhere, sync pending."

## Notes

- **bearcli IDs are Bear's `ZUNIQUEIDENTIFIER`** — interchangeable with the Bear URL scheme: `bear://x-callback-url/open-note?id=<bearcli_id>`. Prefer `bearcli app open ID` over the URL scheme.
- **No auth, no cache, no sync roundtrip.** `bearcli` reads/writes Bear's running database in place. Drop any retry-on-rate-limit logic — there are no rate limits. But iCloud sync still runs underneath (see **iCloud Sync Conflicts** above): writing before remote changes have synced down creates conflict duplicates.
- **No Bear restart needed for any operation**, including attachments and tag changes. This was the single biggest pain point of the previous `bcli` (CloudKit) workflow.
- **Optimistic concurrency:** for risky writes, capture `hash` from `bearcli cat ID --format json` (whole note, or `--section` for a section-scoped hash) and pass `--base <hash>` to `bearcli overwrite` — the write is rejected if the target changed since the read. Reading is the only source of a hash.
- **Tags can be hierarchical:** `work/projects/2025`. `bearcli tags add ID a b/c` adds both, leaving the body untouched.
- **Wiki links syntax (in note body):** `[[note title]]`, `[[note title|alias]]`. `@wikilinks` / `@backlinks` in search find them.
- **Locked notes** return metadata via `bearcli show` but reject `--fields content`.
- **Always search before claiming a note doesn't exist.** Prefer `qmd` for natural-language searches; fall back to `bearcli search` for date or state operators.
- **MCP server alternative:** `bearcli mcp-server` exposes the same surface over JSON-RPC stdio for MCP-aware clients. `--only-tags` / `--exclude-tags` restrict the server to a tag-defined scope (out-of-scope notes error; with a single `--only-tags` value, created notes get the scope tag auto-injected).
