---
name: bear-notes
description: "Search, read, and create notes in Bear. Use when the user asks about their notes, wants to search Bear, save something to Bear, or reference their personal knowledge base."
---

# Bear Notes Assistant

You have full access to the user's Bear notes via a Python CLI at `~/.dotfiles/.claude/skills/bear-notes/bear.py`. Use the Bash tool to run commands.

## Available Commands

### Search Notes
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "query" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "query" --tag "tagname" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "@last7days" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "@today meetings" --format json
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "query" --modified-after 2024-01-01 --format json
```

Bear date operators (use in query string):
- `@today`, `@yesterday` — relative dates
- `@last7days` — modified in last N days (any number)
- `@created7days` — created in last N days
- `@date(>2024-01-01)` — modified after date
- `@date(<2024-01-01)` — modified before date
- `@cdate(>2024-01-01)` — created after date

### Read a Note
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py read NOTE_ID --format text
```

### Create a Note
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py create --title "Title" --text "Content" --tags "tag1,tag2"
```

### Add to a Note
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py add --id NOTE_ID "text to append" --mode append
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py add --title "Note Title" "text" --mode prepend
```

### List All Tags
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py tags
```

### Open a Note in Bear
```bash
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py open --id NOTE_ID
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py open --title "Note Title" --edit
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
```python
# Run inline to get note IDs and URLs
python3 ~/.dotfiles/.claude/skills/bear-notes/bear.py search "x.com" --format json | python3 -c "
import json, sys, re
data = json.load(sys.stdin)
results = []
for note in data:
    text = note.get('text', '')
    title = note.get('title', '')
    links = re.findall(r'https?://(?:www\.)?x\.com/\S+', text)
    if len(links) == 1 and title.startswith('https://x.com/'):
        url = re.sub(r'[\)\]>]+$', '', links[0])
        results.append({'id': note['id'], 'url': url})
import json; print(json.dumps(results))
" > /tmp/tweet_notes.json
```

**Step 2 — Get note UUIDs from Bear's SQLite:**
```python
python3 -c "
import sqlite3, os, glob, json
with open('/tmp/tweet_notes.json') as f: notes = json.load(f)
all_pks = [n['id'] for n in notes]
db_path = glob.glob(os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite'))[0]
conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
conn.row_factory = sqlite3.Row
cur = conn.cursor()
placeholders = ','.join('?' * len(all_pks))
cur.execute(f'SELECT Z_PK, ZUNIQUEIDENTIFIER FROM ZSFNOTE WHERE Z_PK IN ({placeholders})', all_pks)
pk_to_uuid = {row['Z_PK']: row['ZUNIQUEIDENTIFIER'] for row in cur.fetchall()}
with open('/tmp/tweet_uuids.json', 'w') as f: json.dump(pk_to_uuid, f)
print(f'Got {len(pk_to_uuid)} UUIDs')
"
```

**Step 3 — Fetch tweet content via Playwright (MCP browser tool):**
Use `browser_run_code` with a loop over all URLs to extract tweet text from page titles:
```js
async (page) => {
  const urls = [...]; // from /tmp/tweet_notes.json
  const results = [];
  for (const url of urls) {
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

**Step 4 — Update Bear notes with rich formatting:**
```python
python3 -c "
import json, subprocess, time, urllib.parse, re

with open('/tmp/tweet_data.json') as f: tweets = json.load(f)
with open('/tmp/tweet_notes.json') as f: notes = json.load(f)
with open('/tmp/tweet_uuids.json') as f: raw = json.load(f)
pk_to_uuid = {int(k): v for k, v in raw.items()}

url_to_pk = {n['url']: n['id'] for n in notes}

for t in tweets:
    url = t['url']
    tweet_text = t.get('tweet', '').strip()
    author = t.get('author', '')
    pk = url_to_pk.get(url)
    uuid = pk_to_uuid.get(pk)
    if not uuid or not tweet_text: continue

    m = re.match(r'https?://(?:www\.)?x\.com/([^/]+)/status/', url)
    handle = f'@{m.group(1)}' if m else ''
    short = tweet_text[:60] + ('…' if len(tweet_text) > 60 else '')
    title = f'{author}: {short}' if author else short

    new_text = f'# {title}\n\n> {tweet_text}\n\n**{handle}** · [View on X]({url})\n\n#inbox/saved-tweets'
    bear_url = ('bear://x-callback-url/add-text'
        f'?id={urllib.parse.quote(uuid)}'
        f'&text={urllib.parse.quote(new_text)}'
        '&mode=replace&show_window=no&open_note=no')
    subprocess.run(['open', bear_url], capture_output=True)
    time.sleep(0.15)
print('Done')
"
```

**Note on screenshots:** Bear's URL scheme doesn't support image attachments. To embed tweet screenshots, you'd need AppleScript to attach image files, or use Bear's drag-and-drop manually. The blockquote format above is the best automated alternative.

## Notes

- Bear uses a reference date of 2001-01-01 for timestamps (handled by bear.py)
- Tags can be hierarchical: `work/projects/2025`
- Direct database access is read-only; create/modify uses Bear's URL scheme
- Bear note UUIDs (ZUNIQUEIDENTIFIER) are required for URL scheme calls — NOT the integer Z_PK
- URL scheme text must use `urllib.parse.quote()` (percent-encoding), NOT `urlencode()` (plus-encoding)
- Always search before claiming a note doesn't exist
- Wiki links syntax: `[[note title]]`, `[[note title|alias]]`
