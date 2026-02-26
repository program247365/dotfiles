Use the bear-notes skill. Then execute the Batch Add Tweet Screenshots Workflow from SKILL.md to find all #inbox/saved-tweets notes that are missing screenshot images and enrich them.

The workflow is:

**Step 1 — Find saved-tweets notes missing images**

Query Bear's SQLite database directly to find all notes tagged `inbox/saved-tweets` that don't have an associated image file:

```python
import sqlite3, glob, os, json

db = glob.glob(os.path.expanduser(
  '~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite'))[0]
conn = sqlite3.connect(f'file:{db}?mode=ro', uri=True)

rows = conn.execute("""
    SELECT n.Z_PK, n.ZUNIQUEIDENTIFIER, n.ZTITLE
    FROM ZSFNOTE n
    JOIN ZSFNOTETAG nt ON nt.ZNOTE = n.Z_PK
    JOIN ZSFTAG t ON t.Z_PK = nt.ZTAG
    WHERE t.ZTITLE = 'inbox/saved-tweets'
      AND n.ZTRASHED = 0
      AND n.Z_PK NOT IN (SELECT ZNOTE FROM ZSFNOTEFILE WHERE ZPERMANENTLYDELETED = 0)
""").fetchall()
conn.close()

notes = [{'pk': r[0], 'uuid': r[1], 'title': r[2]} for r in rows]
print(json.dumps(notes))
```

Save result to `/tmp/tweet_notes_missing.json`.

**Step 2 — Screenshot each tweet URL via Playwright**

For each note, the title is typically the tweet URL. Use `browser_run_code` with all note data inlined (no `require()` available). Navigate to each URL, wait for content, take a screenshot saved to `/tmp/tweet_{index}.png`.

Important: Chrome must be fully quit (`Cmd+Q`) before running Playwright MCP browser tools.

```js
async (page) => {
  const notes = /* inline JSON array here */;
  const results = [];
  for (let i = 0; i < notes.length; i++) {
    const note = notes[i];
    const url = note.title;
    if (!url.startsWith('http')) { results.push({...note, status: 'skip_not_url'}); continue; }
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      await page.waitForTimeout(2500);
      const imgPath = `/tmp/tweet_${i}.png`;
      await page.locator('article').first().screenshot({ path: imgPath });
      const title = await page.title();
      results.push({...note, status: 'ok', img: imgPath, pageTitle: title});
    } catch(e) {
      results.push({...note, status: 'error', error: e.message});
    }
  }
  return JSON.stringify(results);
}
```

Save result to `/tmp/tweet_screenshots.json`.

**Step 3 — Insert images into SQLite and patch ZTEXT, then restart Bear**

Quit Bear first. For each successful screenshot:
1. Copy PNG to `~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Note Images/{UUID}/tweet_screenshot.png`
2. INSERT into `ZSFNOTEFILE` (see SKILL.md for schema)
3. UPDATE `ZSFNOTE SET ZTEXT` to append `![tweet_screenshot.png](tweet_screenshot.png)` — do NOT use `bcli edit` for this (bcli updates CloudKit but NOT ZTEXT, so Bear won't render the image)

```python
import sqlite3, glob, os, shutil, uuid, json, datetime

db = glob.glob(os.path.expanduser(
  '~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite'))[0]
note_images = os.path.expanduser(
  '~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Note Images')

bear_epoch = datetime.datetime(2001, 1, 1)
now_bear = (datetime.datetime.utcnow() - bear_epoch).total_seconds()

with open('/tmp/tweet_screenshots.json') as f:
    results = json.load(f)

conn = sqlite3.connect(db)
z_ent = conn.execute('SELECT Z_ENT FROM ZSFNOTEFILE LIMIT 1').fetchone()[0]

for r in results:
    if r.get('status') != 'ok': continue
    img_src = r['img']
    note_pk = r['pk']
    note_uuid = r['uuid']
    fname = 'tweet_screenshot.png'

    dest_dir = os.path.join(note_images, note_uuid)
    os.makedirs(dest_dir, exist_ok=True)
    shutil.copy2(img_src, os.path.join(dest_dir, fname))

    fsize = os.path.getsize(img_src)
    max_pk = conn.execute('SELECT MAX(Z_PK) FROM ZSFNOTEFILE').fetchone()[0]
    file_uuid = str(uuid.uuid4()).upper()

    conn.execute("""
        INSERT INTO ZSFNOTEFILE (
            Z_PK, Z_ENT, Z_OPT, ZDOWNLOADED, ZENCRYPTED, ZFILESIZE, ZINDEX,
            ZPERMANENTLYDELETED, ZSKIPSYNC, ZUNUSED, ZUPLOADED, ZVERSION,
            ZNOTE, ZCREATIONDATE, ZINSERTIONDATE, ZMODIFICATIONDATE,
            ZFILENAME, ZNORMALIZEDFILEEXTENSION, ZUNIQUEIDENTIFIER
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, (max_pk+1, z_ent, 1, 1, 0, fsize, 0, 0, 0, 0, 0, 1,
          note_pk, now_bear, now_bear, now_bear,
          fname, 'png', file_uuid))

    current = conn.execute('SELECT ZTEXT FROM ZSFNOTE WHERE Z_PK=?', (note_pk,)).fetchone()[0] or ''
    new_text = current.rstrip() + f'\n\n![{fname}]({fname})\n'
    conn.execute('UPDATE ZSFNOTE SET ZTEXT=?, ZMODIFICATIONDATE=? WHERE Z_PK=?',
                 (new_text, now_bear, note_pk))
    print(f'Done: {r["title"][:60]}')

conn.commit()
conn.close()
print('All done — restart Bear now')
```

After the script completes, restart Bear:
```bash
osascript -e 'quit app "Bear"'
sleep 2
open -a Bear
```

**After completing the batch**, report how many notes were updated, how many were skipped (not a URL), and how many failed.
