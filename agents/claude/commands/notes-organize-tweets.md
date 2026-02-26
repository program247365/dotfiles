Use the bear-notes skill. Then execute the Batch Add Tweet Screenshots Workflow to find all notes that are just a bare x.com URL (no tags, title = URL) and are missing screenshot images, then enrich them.

The workflow is:

**Step 1 — Find bare x.com URL notes missing images**

Query Bear's SQLite database directly. These notes have no tags — just a raw x.com URL as both title and text, saved from the iOS share sheet. Find all that don't already have an image attached:

```python
import sqlite3, re, json, os
from datetime import datetime, timezone

DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
conn = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
conn.row_factory = sqlite3.Row

rows = conn.execute('''
    SELECT Z_PK, ZUNIQUEIDENTIFIER, ZTEXT
    FROM ZSFNOTE
    WHERE ZTRASHED = 0
      AND ZTEXT LIKE "%x.com%"
    ORDER BY ZCREATIONDATE DESC
''').fetchall()

need_image = []
for row in rows:
    text = (row['ZTEXT'] or '').strip()
    # Must be essentially just a URL — bare tweet note
    if not re.match(r'^https?://(?:www\.)?x\.com/\S+$', text): continue
    if re.search(r'!\[.*?\]\(.*?\.png\)', text): continue  # already has image
    # Check no existing file attachment
    has_file = conn.execute(
        'SELECT 1 FROM ZSFNOTEFILE WHERE ZNOTE=? AND ZPERMANENTLYDELETED=0',
        (row['Z_PK'],)
    ).fetchone()
    if has_file: continue
    need_image.append({'pk': row['Z_PK'], 'uuid': row['ZUNIQUEIDENTIFIER'], 'url': text})

conn.close()
with open('/tmp/need_image_notes.json', 'w') as f: json.dump(need_image, f)
print(f'{len(need_image)} notes need screenshots')
for n in need_image:
    print(f'  pk={n["pk"]} {n["url"][:80]}')
```

**Step 2 — Screenshot each tweet URL via Playwright**

First get the inlined JSON:
```bash
python3 -c "import json; notes=json.load(open('/tmp/need_image_notes.json')); print(json.dumps(notes))"
```

Then use `browser_run_code` with the notes data inlined (no `require()` available). Screenshots are named by UUID and saved to `/tmp/tweet_{uuid}.png`:

```js
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
      // Dismiss the "Don't miss what's happening" signup banner before screenshotting
      await page.evaluate(() => {
        document.querySelectorAll('[data-testid="BottomBar"]').forEach(el => el.remove());
      });
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

After the Playwright run, build the results JSON from the notes file + confirmed screenshots on disk:
```python
import json, os
notes = json.load(open('/tmp/need_image_notes.json'))
results = []
for n in notes:
    img = f'/tmp/tweet_{n["uuid"]}.png'
    results.append({'uuid': n['uuid'], 'pk': n['pk'], 'status': 'ok' if os.path.exists(img) else 'missing', 'filename': img})
with open('/tmp/tweet_screenshots.json', 'w') as f: json.dump(results, f)
```

**Step 3 — Insert images into SQLite and patch ZTEXT, then restart Bear**

Quit Bear first. For each successful screenshot:
1. Copy PNG to `~/Library/Group Containers/.../Local Files/Note Images/{file_uuid}/tweet_screenshot.png`
2. INSERT into `ZSFNOTEFILE` with the correct schema (Z_ENT=9, includes ZHEIGHT/ZWIDTH)
3. UPDATE `ZSFNOTE SET ZTEXT` to append `![tweet_screenshot.png](tweet_screenshot.png)` — do NOT use `bcli edit` (bcli updates CloudKit but NOT ZTEXT, so Bear won't render the image)

```python
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
    screenshot = r['filename']
    if not os.path.exists(screenshot):
        print(f'Missing: {screenshot}')
        continue

    with open(screenshot, 'rb') as f:
        f.read(8); f.read(4); f.read(4)
        width  = struct.unpack('>I', f.read(4))[0]
        height = struct.unpack('>I', f.read(4))[0]
    file_size = os.path.getsize(screenshot)
    filename = 'tweet_screenshot.png'
    file_uuid = str(uuid.uuid4()).upper()

    img_folder = os.path.join(NOTE_IMAGES, file_uuid)
    os.makedirs(img_folder)
    shutil.copy2(screenshot, os.path.join(img_folder, filename))

    cur.execute('''
        INSERT INTO ZSFNOTEFILE
        (Z_PK, Z_ENT, Z_OPT, ZDOWNLOADED, ZFILESIZE, ZINDEX, ZPERMANENTLYDELETED,
         ZSKIPSYNC, ZUNUSED, ZUPLOADED, ZNOTE, ZANIMATED, ZHEIGHT, ZWIDTH,
         ZDURATION, ZHEIGHT1, ZWIDTH1, ZCREATIONDATE, ZMODIFICATIONDATE, ZUPLOADEDDATE,
         ZFILENAME, ZNORMALIZEDFILEEXTENSION, ZSEARCHTEXT, ZLASTEDITINGDEVICE, ZUNIQUEIDENTIFIER)
        VALUES (?,9,1, 1,?,0,0,0,0,0, ?,0,?,?,NULL,NULL,NULL, ?,?,NULL, ?,"png",NULL,NULL,?)
    ''', (new_pk, file_size, r['pk'], height, width, bear_time, bear_time, filename, file_uuid))

    row = cur.execute('SELECT ZTEXT FROM ZSFNOTE WHERE Z_PK=?', (r['pk'],)).fetchone()
    if row and row[0] and '![tweet_screenshot.png]' not in row[0]:
        new_text = row[0].rstrip() + '\n\n![tweet_screenshot.png](tweet_screenshot.png)\n'
        cur.execute('UPDATE ZSFNOTE SET ZTEXT=?, ZMODIFICATIONDATE=? WHERE Z_PK=?',
                    (new_text, bear_time, r['pk']))
    print(f'Done pk={r["pk"]} uuid={r["uuid"][:8]}...')
    new_pk += 1

conn.commit()
conn.close()
print(f'All done: {len(results)} images inserted + ZTEXT patched')
```

Then restart Bear:
```bash
osascript -e 'tell application "Bear" to quit' && sleep 3 && open -a Bear
```

**After completing the batch**, report how many notes were updated, how many had `no_article` (deleted/protected tweets), and how many failed.
