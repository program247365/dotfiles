---
name: bear-notes
description: "Search, read, and create notes in Bear. Use when the user asks about their notes, wants to search Bear, save something to Bear, or reference their personal knowledge base."
---

# Bear Notes Assistant

You have full access to the user's Bear notes via `bcli` (better-bear-cli), which reads and writes through Bear's CloudKit API. Use the Bash tool to run commands. `bear.py` is still available at `~/.dotfiles/.claude/skills/bear-notes/bear.py` but is only needed for the screenshot attachment workflow (SQLite direct access).

## Setup

Install bcli (one-time):
```bash
curl -L https://github.com/mreider/better-bear-cli/releases/latest/download/bcli-macos-universal.tar.gz \
  -o /tmp/bcli.tar.gz && tar xzf /tmp/bcli.tar.gz -C /tmp && mv /tmp/bcli ~/.local/bin/bcli
```

Authenticate (opens browser for Apple Sign-In):
```bash
bcli auth
```

Token stored at `~/.config/bear-cli/auth.json`. Cache at `~/.config/bear-cli/cache.json` (5-min staleness threshold). Run `bcli sync` to force refresh.

## Available Commands

### Search Notes
```bash
bcli search "query" --json
bcli search "query" --limit 20 --json
bcli ls --tag "tagname" --json
bcli ls --all --json
```

> **Note:** bcli does NOT support Bear's `@today`, `@last7days`, `@date(>...)` operators. For date filtering, use `bcli ls --all --json` and post-process the `modificationDate` ISO8601 field in Python. Search results contain only `id`, `title`, `tags`, `match` — no body. Use `bcli get NOTE_ID --json` to fetch body (`text` field).

### Read a Note
```bash
bcli get NOTE_ID --json    # full metadata + body
bcli get NOTE_ID --raw     # markdown body only
```

### Create a Note
```bash
bcli create "Title" --body "Content" --tags "tag1,tag2"
NEW_ID=$(bcli create "Title" --body "Content" --tags "tag1" --quiet)  # capture ID
```

### Add to a Note
```bash
bcli edit NOTE_ID --append "text to append"
printf '%s' "replacement body" | bcli edit NOTE_ID --stdin   # replace mode
bcli edit NOTE_ID --editor                                    # open in $EDITOR
```

> **Note:** bcli has no `--prepend`. To prepend: read with `bcli get NOTE_ID --raw`, construct new body, pipe back with `--stdin`.

### List All Tags
```bash
bcli tags --flat --json
```

### Open a Note in Bear
bcli has no `open` command. bcli IDs are Bear's `ZUNIQUEIDENTIFIER` — use them directly in the URL scheme:
```bash
open "bear://x-callback-url/open-note?id=NOTE_ID"
# Or by title:
TITLE=$(bcli get NOTE_ID --json | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])")
open "bear://x-callback-url/open-note?title=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TITLE")"
```

### Trash / Sync
```bash
bcli trash NOTE_ID --force
bcli sync --full -v
```

## Workflow

**When answering questions:**
1. **Search first** — use `search` to find relevant notes
2. **Read details** — use `read NOTE_ID` for full content of relevant notes
3. **Synthesize** — combine info from multiple notes
4. **Cite sources** — always mention which note titles you're referencing

**When creating content:**
1. Offer to save important information to Bear
2. Suggest tags based on existing tags (run `tags` to check)
3. Ask if user wants to open the note after creation

## Enrich Saved Tweets Workflow

Use this when the user asks to enrich, process, or title their saved tweet notes.

**Step 1 — Find bare tweet URL notes:**
```bash
# bcli search returns title/tags/id only (no body). Must fetch each note individually.
bcli ls --all --json | python3 -c "
import json, sys, subprocess, re
notes = json.load(sys.stdin)
results = []
for note in notes:
    title = note.get('title', '')
    if not title.startswith('https://x.com/'): continue
    detail = json.loads(subprocess.check_output(['bcli', 'get', note['id'], '--json']))
    body = detail.get('text', '')
    links = re.findall(r'https?://(?:www\.)?x\.com/\S+', body)
    if len(links) == 1:
        url = re.sub(r'[\)\]>]+$', '', links[0])
        results.append({'id': note['id'], 'url': url})
print(json.dumps(results))
" > /tmp/tweet_notes.json
```

**Step 2 — Fetch tweet content via Playwright (MCP browser tool):**
Use `browser_run_code` with a loop over all URLs to extract tweet text from page titles:
```js
async (page) => {
  const fs = require('fs');
  const notes = JSON.parse(fs.readFileSync('/tmp/tweet_notes.json', 'utf8'));
  const results = [];
  for (const {url} of notes) {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
    await page.waitForTimeout(2500);
    const title = await page.title();
    const match = title.match(/^(.+?) on X: "(.+?)"(?:\s*\/\s*X)?$/s);
    if (match) results.push({ url, author: match[1], tweet: match[2].trim() });
    else results.push({ url, author: null, tweet: title });
  }
  return JSON.stringify(results);
}
```
Save results to `/tmp/tweet_data.json`.

**Step 3 — Update notes via bcli:**
```python
python3 -c "
import json, subprocess, re

with open('/tmp/tweet_data.json') as f: tweets = json.load(f)
with open('/tmp/tweet_notes.json') as f: notes = json.load(f)

url_to_id = {n['url']: n['id'] for n in notes}

for t in tweets:
    url = t['url']
    tweet_text = t.get('tweet', '').strip()
    author = t.get('author', '')
    note_id = url_to_id.get(url)
    if not note_id or not tweet_text: continue

    m = re.match(r'https?://(?:www\.)?x\.com/([^/]+)/status/', url)
    handle = f'@{m.group(1)}' if m else ''
    short = tweet_text[:60] + ('…' if len(tweet_text) > 60 else '')
    title = f'{author}: {short}' if author else short

    new_body = f'# {title}\n\n> {tweet_text}\n\n**{handle}** · [View on X]({url})\n\n#inbox/saved-tweets'

    result = subprocess.run(
        ['bcli', 'edit', note_id, '--stdin'],
        input=new_body, text=True, capture_output=True
    )
    if result.returncode != 0:
        print(f'Error {note_id}: {result.stderr.strip()}')
    else:
        print(f'Updated: {title[:50]}')
print('Done')
"
```
No `time.sleep()` required (CloudKit API, not URL scheme fire-and-forget). No `urllib.parse.quote()` needed.

## Batch Add Tweet Screenshots Workflow

Use this when the user asks to add screenshots/images to their saved tweet notes. This embeds the actual tweet screenshot into each note.

**Prerequisites:** bcli auth done. Playwright MCP browser available. **Chrome must be fully quit** (`Cmd+Q`) before running Playwright — the MCP uses Chrome's persistent context which conflicts with a running Chrome instance.

**Step 1 — Find notes needing screenshots (via SQLite, not bcli):**
> bcli tag search has a result limit. Use SQLite directly to get all notes in the tag.
```python
python3 -c "
import sqlite3, re, json, os
DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
conn = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
conn.row_factory = sqlite3.Row
rows = conn.execute('''
    SELECT n.Z_PK, n.ZUNIQUEIDENTIFIER, n.ZTEXT
    FROM ZSFNOTE n
    JOIN Z_5TAGS nt ON n.Z_PK = nt.Z_5NOTES
    JOIN ZSFNOTETAG t ON nt.Z_13TAGS = t.Z_PK
    WHERE t.ZTITLE = \"inbox/saved-tweets\" AND n.ZTRASHED = 0
    ORDER BY n.ZMODIFICATIONDATE DESC
''').fetchall()
need_image = []
for row in rows:
    text = row['ZTEXT'] or ''
    if re.search(r'!\[.*?\]\(.*?\.png\)', text): continue  # already has image
    url_match = re.search(r'https?://(?:www\.)?x\.com/([^\s\)\"]+)', text)
    url = 'https://x.com/' + url_match.group(1) if url_match else None
    if not url: continue
    need_image.append({'pk': row['Z_PK'], 'uuid': row['ZUNIQUEIDENTIFIER'], 'url': url})
with open('/tmp/need_image_notes.json', 'w') as f: json.dump(need_image, f)
print(f'{len(need_image)} notes need screenshots')
"
```

**Step 2 — Screenshot tweets via Playwright (`browser_run_code`):**
> `require()` is not available in `browser_run_code` — inline the notes data directly. `locator.screenshot({path})` writes to disk natively. After screenshotting, load notes JSON into the code inline (generate it from Python first, then paste into the tool call).
```js
// Generate the inlined notes array first:
// python3 -c "import json; notes=json.load(open('/tmp/need_image_notes.json')); print(json.dumps(notes))"
// Then inline it as: const notes = [...paste here...];

async (page) => {
  const notes = /* INLINE JSON HERE */;
  const results = [];
  for (const note of notes) {
    const filename = '/tmp/tweet_' + note.uuid + '.png';
    try {
      await page.goto(note.url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      const article = page.locator('article[data-testid="tweet"]').first();
      try { await article.waitFor({ timeout: 6000 }); } catch(_) {}
      if (!await article.count()) {
        results.push({ uuid: note.uuid, pk: note.pk, status: 'no_article', url: note.url });
        continue;
      }
      await article.screenshot({ path: filename, type: 'png' });
      results.push({ uuid: note.uuid, pk: note.pk, status: 'ok', filename });
    } catch(e) {
      results.push({ uuid: note.uuid, pk: note.pk, status: 'error', error: String(e), url: note.url });
    }
  }
  const ok = results.filter(r => r.status === 'ok').length;
  return JSON.stringify({ ok, failed: results.filter(r => r.status !== 'ok'), results });
}
```
Parse results: `python3 -c "import json,re; raw=open('TOOL_RESULT_FILE').read(); ..."` — extract the JSON from the `### Result` wrapper and save to `/tmp/tweet_screenshots.json`.

**Step 3 — Quit Bear, bulk insert image records into SQLite, patch ZTEXT, restart:**
> Do NOT use `bcli edit` to add the image markdown — bcli updates CloudKit but Bear renders from its local `ZTEXT` column. Write `ZTEXT` directly.
```python
python3 << 'EOF'
import sqlite3, os, uuid, shutil, struct, json
from datetime import datetime

DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
NOTE_IMAGES = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note Images')

with open('/tmp/tweet_screenshots.json') as f:
    results = [r for r in json.load(f) if r['status'] == 'ok']

bear_epoch = datetime(2001, 1, 1).timestamp()
bear_time = datetime.now().timestamp() - bear_epoch

conn = sqlite3.connect(DB, timeout=10)
cur = conn.cursor()
new_pk = (cur.execute('SELECT MAX(Z_PK) FROM ZSFNOTEFILE').fetchone()[0] or 0) + 1

for r in results:
    screenshot = f"/tmp/tweet_{r['uuid']}.png"
    if not os.path.exists(screenshot): continue

    with open(screenshot, 'rb') as f:
        f.read(8); f.read(4); f.read(4)
        width  = struct.unpack('>I', f.read(4))[0]
        height = struct.unpack('>I', f.read(4))[0]
    file_size = os.path.getsize(screenshot)
    filename = 'tweet_screenshot.png'
    file_uuid = str(uuid.uuid4()).upper()
    os.makedirs(os.path.join(NOTE_IMAGES, file_uuid))
    shutil.copy2(screenshot, os.path.join(NOTE_IMAGES, file_uuid, filename))

    cur.execute('''
        INSERT INTO ZSFNOTEFILE
        (Z_PK, Z_ENT, Z_OPT, ZDOWNLOADED, ZFILESIZE, ZINDEX, ZPERMANENTLYDELETED,
         ZSKIPSYNC, ZUNUSED, ZUPLOADED, ZNOTE, ZANIMATED, ZHEIGHT, ZWIDTH,
         ZDURATION, ZHEIGHT1, ZWIDTH1, ZCREATIONDATE, ZMODIFICATIONDATE, ZUPLOADEDDATE,
         ZFILENAME, ZNORMALIZEDFILEEXTENSION, ZSEARCHTEXT, ZLASTEDITINGDEVICE, ZUNIQUEIDENTIFIER)
        VALUES (?,9,1, 1,?,0,0,0,0,0, ?,0,?,?,NULL,NULL,NULL, ?,?,NULL, ?,"png",NULL,NULL,?)
    ''', (new_pk, file_size, r['pk'], height, width, bear_time, bear_time, filename, file_uuid))

    # Patch ZTEXT directly — do NOT use bcli edit (CloudKit sync won't update ZTEXT before restart)
    row = cur.execute('SELECT ZTEXT FROM ZSFNOTE WHERE Z_PK=?', (r['pk'],)).fetchone()
    if row and row[0] and '![tweet_screenshot.png]' not in row[0]:
        new_text = row[0].rstrip() + '\n\n![tweet_screenshot.png](tweet_screenshot.png)\n'
        cur.execute('UPDATE ZSFNOTE SET ZTEXT=?, ZMODIFICATIONDATE=? WHERE Z_PK=?',
                    (new_text, bear_time, r['pk']))
    new_pk += 1

conn.commit()
conn.close()
print(f'Done: {len(results)} images inserted + ZTEXT patched')
EOF
```

Then restart Bear:
```bash
osascript -e 'tell application "Bear" to quit' && sleep 3 && open -a Bear
```

**Notes on this workflow:**
- `bcli --tag` returns 0 results; use `bcli search "tagname"` or SQLite directly
- CloudKit 409 `TRY_AGAIN_LATER` on bcli edits = rate limit; retry with `time.sleep(2)` between calls
- 2 tweet URLs that return `no_article` = deleted/protected accounts; skip them
- bcli IDs = Bear's `ZUNIQUEIDENTIFIER` — you can pass them to `?id=` in URL scheme calls

## Attach Screenshot to Bear Note Workflow

Use this to embed an actual image (e.g. a tweet screenshot) into a Bear note. Bear's URL scheme doesn't accept image uploads directly, so we insert into Bear's SQLite database and then restart Bear.

**Why a restart is required:** Bear uses Apple's Core Data framework — an in-memory object graph loaded from SQLite at startup. When you `INSERT` directly into the SQLite file, Bear's running process doesn't see it (Core Data has its own in-memory state). A restart forces Bear to reload from disk, at which point the image record and the markdown reference both appear correctly.

**Step 1 — Take screenshot via Playwright MCP:**
```js
// browser_take_screenshot with element targeting for a clean crop
// Save to e.g. /tmp/tweet_{handle}.png
```

**Step 2 — Insert image record and append markdown (Python):**
```python
python3 -c "
import sqlite3, os, uuid, shutil, subprocess, urllib.parse, struct, time, json
from datetime import datetime


# NOTE_UUID = the bcli note ID (bcli IDs ARE Bear's ZUNIQUEIDENTIFIER — they're the same)
# NOTE_PK must be looked up from SQLite (bcli has no Z_PK):
# python3 -c "
# import sqlite3, glob, os
# db = glob.glob(os.path.expanduser(
#   '~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite'))[0]
# conn = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
# rows = conn.execute('SELECT Z_PK, ZUNIQUEIDENTIFIER FROM ZSFNOTE WHERE ZUNIQUEIDENTIFIER=\"YOUR-BCLI-ID\"').fetchall()
# print(rows)
# "
NOTE_PK   = 1234
NOTE_UUID = 'YOUR-BCLI-NOTE-ID'
SCREENSHOT = '/tmp/tweet_screenshot.png'
FILENAME   = 'tweet_screenshot.png'

DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
NOTE_IMAGES = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note Images')

# Read PNG dimensions from header
with open(SCREENSHOT, 'rb') as f:
    f.read(8); f.read(4); f.read(4)
    width  = struct.unpack('>I', f.read(4))[0]
    height = struct.unpack('>I', f.read(4))[0]
file_size = os.path.getsize(SCREENSHOT)

# Copy image to Bear's Note Images folder (folder name = file UUID)
file_uuid = str(uuid.uuid4()).upper()
img_folder = os.path.join(NOTE_IMAGES, file_uuid)
os.makedirs(img_folder)
shutil.copy2(SCREENSHOT, os.path.join(img_folder, FILENAME))

# Bear's Core Data epoch starts 2001-01-01
bear_time = datetime.now().timestamp() - datetime(2001, 1, 1).timestamp()

# Insert ZSFNOTEFILE record (Z_ENT=9, Z_OPT=1 for Bear v1)
conn = sqlite3.connect(DB, timeout=10)
cur = conn.cursor()
new_pk = (cur.execute('SELECT MAX(Z_PK) FROM ZSFNOTEFILE').fetchone()[0] or 0) + 1
cur.execute('''
    INSERT INTO ZSFNOTEFILE
    (Z_PK, Z_ENT, Z_OPT, ZDOWNLOADED, ZFILESIZE, ZINDEX, ZPERMANENTLYDELETED,
     ZSKIPSYNC, ZUNUSED, ZUPLOADED, ZNOTE, ZANIMATED, ZHEIGHT, ZWIDTH,
     ZDURATION, ZHEIGHT1, ZWIDTH1, ZCREATIONDATE, ZMODIFICATIONDATE, ZUPLOADEDDATE,
     ZFILENAME, ZNORMALIZEDFILEEXTENSION, ZSEARCHTEXT, ZLASTEDITINGDEVICE, ZUNIQUEIDENTIFIER)
    VALUES (?,9,1, 1,?,0,0,0,0,0, ?,0,?,?,NULL,NULL,NULL, ?,?,NULL, ?,\"png\",NULL,NULL,?)
''', (new_pk, file_size, NOTE_PK, height, width, bear_time, bear_time, FILENAME, file_uuid))
conn.commit()
conn.close()

# Append image markdown via Bear URL scheme
time.sleep(0.5)
img_md = f'\n![{FILENAME}]({FILENAME})'
bear_url = ('bear://x-callback-url/add-text'
    f'?id={urllib.parse.quote(NOTE_UUID)}'
    f'&text={urllib.parse.quote(img_md)}'
    '&mode=append&show_window=yes&open_note=yes')
subprocess.run(['open', bear_url])
print('Done — restart Bear to see image render')
"
```

**Step 3 — Restart Bear:**
```bash
osascript -e 'tell application "Bear" to quit'
sleep 2
open -a Bear
```
After restart, the `![filename](filename)` markdown renders as an inline image.

**Smoother alternative (no restart needed):** Grant your terminal **Accessibility permission** in System Settings → Privacy & Security → Accessibility. Then use AppleScript to paste the image from clipboard — Bear handles the attachment internally through its normal UI path, so Core Data is updated immediately:
```applescript
-- Set clipboard to PNG data, then paste into Bear edit mode
set the clipboard to (read (POSIX file "/tmp/tweet_screenshot.png") as «class PNGf»)
open location "bear://x-callback-url/open-note?id=NOTE_UUID&edit=yes&show_window=yes"
delay 1.5
tell application "System Events"
    tell process "Bear"
        key code 125 using {command down}  -- Cmd+Down → jump to end of note
        keystroke return                    -- new line
        keystroke "v" using {command down} -- Cmd+V → paste image
    end tell
end tell
```
This bypasses the Core Data issue entirely because Bear processes the paste event itself.

## Notes

- **bcli IDs are Bear's `ZUNIQUEIDENTIFIER`** — they are the same value and can be used interchangeably in URL scheme calls (`bear://x-callback-url/...?id=BCLI_ID`).
- The only value bcli cannot give you is `Z_PK` (the integer Core Data primary key needed for `ZSFNOTEFILE.ZNOTE`). Look that up from SQLite by `ZUNIQUEIDENTIFIER`.
- bcli maintains a local cache at `~/.config/bear-cli/cache.json`. Run `bcli sync` if results seem stale.
- bcli does not support Bear's date query operators (`@today`, `@last7days`, etc.). Filter by `modificationDate` ISO8601 field in Python post-processing (field name from `bcli get --json`).
- bcli has no image/attachment support. The screenshot workflow still uses direct SQLite insertion (Bear restart required).
- **`bcli edit` updates CloudKit but does NOT update Bear's local `ZTEXT` column directly.** Bear renders from `ZTEXT`. To add content that must render immediately after restart (e.g. image markdown), write to `ZTEXT` directly in SQLite — do not rely on CloudKit sync timing.
- `#tag` syntax in note body via `bcli edit` should sync to Bear's tag index via CloudKit. Alternatively, set tags explicitly: `bcli create ... --tags 'inbox/saved-tweets'`.
- Tags can be hierarchical: `work/projects/2025`
- URL scheme text must use `urllib.parse.quote()` (percent-encoding) — applies in the screenshot attachment workflow.
- Always search before claiming a note doesn't exist
- Wiki links syntax: `[[note title]]`, `[[note title|alias]]`
- Bear uses Core Data (in-memory object graph over SQLite); direct SQLite INSERTs require a Bear restart to take effect — applies to the screenshot workflow only.
