Use the bear-notes skill. Then execute the idempotent Tweet Notes Enrichment Workflow below.

The workflow is fully idempotent — run it any time to catch up on anything that's missing.

---

**Pre-check — Audit all tweet notes and classify what needs work**

This single query covers all three categories:
1. Bare x.com URL notes with no content
2. Notes with `#inbox/saved-tweets` missing an image
3. Notes with `#inbox/saved-tweets` missing structured body OR missing additional tags

```python
import sqlite3, re, json, os

DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
conn = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
conn.row_factory = sqlite3.Row

rows = conn.execute('''
    SELECT Z_PK, ZUNIQUEIDENTIFIER, ZTEXT
    FROM ZSFNOTE
    WHERE ZTRASHED = 0 AND ZTEXT LIKE "%x.com%"
    ORDER BY ZCREATIONDATE DESC
''').fetchall()

todo = []
for row in rows:
    text = (row['ZTEXT'] or '').strip()
    pk, uuid = row['Z_PK'], row['ZUNIQUEIDENTIFIER']

    url_match = re.search(r'https?://(?:www\.)?x\.com/\S+', text)
    if not url_match: continue
    url = re.sub(r'[\)\]>"\s]+$', '', url_match.group(0))

    tags = [r['ZTITLE'] for r in conn.execute('''
        SELECT t.ZTITLE FROM ZSFNOTETAG t
        JOIN Z_5TAGS nt ON t.Z_PK = nt.Z_13TAGS
        WHERE nt.Z_5NOTES = ?
    ''', (pk,)).fetchall()]
    has_inbox_tag = 'inbox/saved-tweets' in tags

    is_bare = re.match(r'^https?://(?:www\.)?x\.com/\S+$', text) is not None
    if not is_bare and not has_inbox_tag:
        continue  # not a tweet note

    has_image = conn.execute(
        'SELECT 1 FROM ZSFNOTEFILE WHERE ZNOTE=? AND ZPERMANENTLYDELETED=0', (pk,)
    ).fetchone() is not None

    # Structured body = has a # heading AND a > blockquote (from enrichment)
    has_body = bool(re.search(r'^#\s+\S', text, re.MULTILINE)) and '> ' in text

    needs = []
    if not has_inbox_tag: needs.append('inbox_tag')
    if not has_image:     needs.append('image')
    if not has_body:      needs.append('body')
    if has_inbox_tag and len(tags) == 1: needs.append('extra_tags')

    if needs:
        todo.append({
            'pk': pk, 'uuid': uuid, 'url': url,
            'has_image': has_image, 'has_body': has_body,
            'has_inbox_tag': has_inbox_tag, 'tags': tags, 'needs': needs
        })

conn.close()
with open('/tmp/tweet_todo.json', 'w') as f: json.dump(todo, f)

from collections import Counter
counts = Counter(need for n in todo for need in n['needs'])
print(f'{len(todo)} notes need work:')
for k, v in sorted(counts.items()): print(f'  {k}: {v}')
print()
for n in todo:
    print(f'  pk={n["pk"]} needs={n["needs"]} {n["url"][:65]}')
```

Review the output before proceeding. Then:

---

**Step A — Playwright pass (image + content extraction)**

For all notes that need `image` OR `body`, run a Playwright batch to screenshot and extract tweet text. Notes that only need `extra_tags` or `inbox_tag` skip this step.

```python
import json
todo = json.load(open('/tmp/tweet_todo.json'))
playwright_batch = [n for n in todo if 'image' in n['needs'] or 'body' in n['needs']]
print(json.dumps([{'pk': n['pk'], 'uuid': n['uuid'], 'url': n['url']} for n in playwright_batch]))
```

Use `browser_run_code` with the batch inlined. Closes Chrome if open first (`osascript -e 'tell application "Google Chrome" to quit'`). Screenshots go to `/tmp/tweet_{uuid}.png`:

```js
async (page) => {
  const notes = /* INLINE JSON HERE */;
  const results = [];
  const dismissBanners = async () => {
    await page.evaluate(() => {
      ['[data-testid="BottomBar"]', '[data-testid="sheetDialog"]', '[data-testid="LoginForm"]'].forEach(sel =>
        document.querySelectorAll(sel).forEach(el => el.remove())
      );
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      let node;
      while ((node = walker.nextNode())) {
        if (node.textContent.includes("Don't miss what's happening")) {
          let el = node.parentElement;
          for (let i = 0; i < 8; i++) {
            if (el && el.offsetWidth > 300 && el.offsetHeight > 40) { el.remove(); break; }
            el = el?.parentElement;
          }
          break;
        }
      }
    });
  };
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
      await dismissBanners();
      // Extract content
      const tweetTextEl = article.locator('[data-testid="tweetText"]').first();
      const tweetText = await tweetTextEl.count() ? await tweetTextEl.innerText().catch(() => '') : '';
      const pageTitle = await page.title();
      const titleMatch = pageTitle.match(/^(.+?) on X:/);
      const author = titleMatch ? titleMatch[1].trim() : '';
      const handleMatch = note.url.match(/x\.com\/([^/?]+)/);
      const handle = handleMatch ? handleMatch[1] : '';
      await article.screenshot({ path: filename, type: 'png' });
      results.push({ uuid: note.uuid, pk: note.pk, status: 'ok', filename,
                     tweetText, author, handle, url: note.url });
    } catch(e) {
      results.push({ uuid: note.uuid, pk: note.pk, status: 'error', error: String(e), url: note.url });
    }
  }
  try {
    const fs = await import('fs');
    fs.writeFileSync('/tmp/tweet_playwright.json', JSON.stringify(results));
  } catch(_) {}
  const ok = results.filter(r => r.status === 'ok').length;
  return JSON.stringify({ ok, failed: results.filter(r => r.status !== 'ok'), results });
}
```

After the run, **close the browser** (`browser_close`).

If `/tmp/tweet_playwright.json` was not written, save the `results` array from the `### Result` JSON manually:
```bash
python3 -c "import json; data=json.loads('''PASTE_JSON_HERE'''); json.dump(data['results'], open('/tmp/tweet_playwright.json', 'w'))"
```

Verify screenshots landed:
```python
import json, os
results = json.load(open('/tmp/tweet_playwright.json'))
ok = sum(1 for r in results if r.get('status') == 'ok' and os.path.exists(f'/tmp/tweet_{r["uuid"]}.png'))
print(f'{ok}/{len(results)} screenshots confirmed on disk')
```

---

**Step B — SQLite update (Quit Bear first)**

```bash
osascript -e 'tell application "Bear" to quit' && sleep 2
```

```python
import sqlite3, os, uuid, shutil, struct, json
from datetime import datetime

DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
NOTE_IMAGES = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note Images')

todo = {n['pk']: n for n in json.load(open('/tmp/tweet_todo.json'))}
playwright = {r['pk']: r for r in json.load(open('/tmp/tweet_playwright.json')) if r.get('status') == 'ok'}

bear_epoch = datetime(2001, 1, 1).timestamp()
bear_time = datetime.now().timestamp() - bear_epoch

conn = sqlite3.connect(DB, timeout=10)
cur = conn.cursor()
new_pk = (cur.execute('SELECT MAX(Z_PK) FROM ZSFNOTEFILE').fetchone()[0] or 0) + 1

for pk, note in todo.items():
    needs = note['needs']
    pr = playwright.get(pk, {})
    tweet_text = pr.get('tweetText', '').strip()
    author = pr.get('author', '').strip()
    handle = pr.get('handle', '').strip()
    url = note['url']

    # --- Insert image if needed ---
    if 'image' in needs:
        screenshot = f'/tmp/tweet_{note["uuid"]}.png'
        if os.path.exists(screenshot):
            with open(screenshot, 'rb') as f:
                f.read(8); f.read(4); f.read(4)
                width  = struct.unpack('>I', f.read(4))[0]
                height = struct.unpack('>I', f.read(4))[0]
            file_size = os.path.getsize(screenshot)
            file_uuid = str(uuid.uuid4()).upper()
            img_folder = os.path.join(NOTE_IMAGES, file_uuid)
            os.makedirs(img_folder, exist_ok=True)
            shutil.copy2(screenshot, os.path.join(img_folder, 'tweet_screenshot.png'))
            cur.execute('''
                INSERT INTO ZSFNOTEFILE
                (Z_PK, Z_ENT, Z_OPT, ZDOWNLOADED, ZFILESIZE, ZINDEX, ZPERMANENTLYDELETED,
                 ZSKIPSYNC, ZUNUSED, ZUPLOADED, ZNOTE, ZANIMATED, ZHEIGHT, ZWIDTH,
                 ZDURATION, ZHEIGHT1, ZWIDTH1, ZCREATIONDATE, ZMODIFICATIONDATE, ZUPLOADEDDATE,
                 ZFILENAME, ZNORMALIZEDFILEEXTENSION, ZSEARCHTEXT, ZLASTEDITINGDEVICE, ZUNIQUEIDENTIFIER)
                VALUES (?,9,1,1,?,0,0,0,0,0,?,0,?,?,NULL,NULL,NULL,?,?,NULL,"tweet_screenshot.png","png",NULL,NULL,?)
            ''', (new_pk, file_size, pk, height, width, bear_time, bear_time, file_uuid))
            new_pk += 1
        else:
            print(f'Screenshot missing for pk={pk}, skipping image insert')

    # --- Build new ZTEXT ---
    if 'image' in needs or 'body' in needs or 'inbox_tag' in needs:
        cur_text = cur.execute('SELECT ZTEXT FROM ZSFNOTE WHERE Z_PK=?', (pk,)).fetchone()
        cur_text = (cur_text[0] or '').rstrip()
        has_img_md = '![tweet_screenshot.png]' in cur_text

        if tweet_text and author and ('body' in needs):
            short = tweet_text[:70] + ('…' if len(tweet_text) > 70 else '')
            # Prefix every line with > to handle multiline tweets properly
            blockquoted = '\n'.join(
                f'> {line}' if line.strip() else '>'
                for line in tweet_text.split('\n')
            )
            new_text = (
                f'# {author}: {short}\n\n'
                f'{blockquoted}\n\n'
                f'**@{handle}** · [View on X]({url})\n\n'
                f'#inbox/saved-tweets\n\n'
                f'![tweet_screenshot.png](tweet_screenshot.png)\n'
            )
        else:
            # Preserve existing text, just add what's missing
            if '#inbox/saved-tweets' not in cur_text:
                cur_text += '\n\n#inbox/saved-tweets'
            if not has_img_md and 'image' in needs:
                cur_text += '\n\n![tweet_screenshot.png](tweet_screenshot.png)'
            new_text = cur_text + '\n'

        cur.execute('UPDATE ZSFNOTE SET ZTEXT=?, ZMODIFICATIONDATE=? WHERE Z_PK=?',
                    (new_text, bear_time, pk))
        if tweet_text and author:
            title = f'{author}: {tweet_text[:70]}{"…" if len(tweet_text) > 70 else ""}'
            cur.execute('UPDATE ZSFNOTE SET ZTITLE=? WHERE Z_PK=?', (title, pk))
        print(f'Updated pk={pk} needs={needs}')

conn.commit()
conn.close()
print('SQLite done')
```

Restart Bear:
```bash
open -a Bear
```

---

**Step C — Auto-tag pass (notes needing `extra_tags`)**

```python
import sqlite3, json, os

DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
conn = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
conn.row_factory = sqlite3.Row

todo = json.load(open('/tmp/tweet_todo.json'))
needs_tags = [n for n in todo if 'extra_tags' in n['needs']]

all_tags = [r['ZTITLE'] for r in conn.execute('SELECT ZTITLE FROM ZSFNOTETAG ORDER BY ZTITLE').fetchall()]
notes_with_text = []
for n in needs_tags:
    row = conn.execute('SELECT ZTEXT FROM ZSFNOTE WHERE Z_PK=?', (n['pk'],)).fetchone()
    notes_with_text.append({**n, 'text': (row['ZTEXT'] or '') if row else ''})
conn.close()

with open('/tmp/tweet_tagging.json', 'w') as f:
    json.dump({'tags': all_tags, 'notes': notes_with_text}, f)

print(f'{len(needs_tags)} notes need extra tags')
print('Existing tags:', json.dumps(all_tags, indent=2))
print()
for n in notes_with_text:
    print(f'pk={n["pk"]} current_tags={n["tags"]}')
    print(f'  {n["text"][:200]}')
    print()
```

Read the note content above. For each note, pick 1–3 tags from the existing tag list. Prefer `#learn/*` tags. Build the assignment dict and apply:

```python
import sqlite3, json
from datetime import datetime

DB = os.path.expanduser('~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')

# Fill this in based on your analysis:
TAG_ASSIGNMENTS = {
    # pk: ['#tag1', '#tag2'],
}

bear_time = datetime.now().timestamp() - datetime(2001, 1, 1).timestamp()
conn = sqlite3.connect(DB, timeout=10)
cur = conn.cursor()

for pk, tags in TAG_ASSIGNMENTS.items():
    row = cur.execute('SELECT ZTEXT FROM ZSFNOTE WHERE Z_PK=?', (pk,)).fetchone()
    if not row or not row[0]: continue
    text = row[0].rstrip()
    for tag in tags:
        if tag not in text:
            text += f'\n{tag}'
    cur.execute('UPDATE ZSFNOTE SET ZTEXT=?, ZMODIFICATIONDATE=? WHERE Z_PK=?',
                (text + '\n', bear_time, pk))
    print(f'Tagged pk={pk}: {tags}')

conn.commit()
conn.close()

# Restart Bear to pick up tag changes
import subprocess
subprocess.run(['osascript', '-e', 'tell application "Bear" to quit'])
import time; time.sleep(2)
subprocess.run(['open', '-a', 'Bear'])
print(f'Done: {len(TAG_ASSIGNMENTS)} notes tagged')
```

---

**Final report**: how many notes updated per category (image, body, inbox_tag, extra_tags), how many `no_article` (deleted/protected tweets), how many failed.
