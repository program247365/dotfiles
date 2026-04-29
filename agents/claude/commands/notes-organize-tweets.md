Use the bear-notes skill. Then execute the idempotent Tweet Notes Enrichment Workflow below.

The workflow is fully idempotent — run it any time to catch up on anything that's missing.

---

**Pre-check — Audit all tweet notes and classify what needs work**

One `bearcli search` call returns everything the classifier needs (tags, attachments, full body) for every note that mentions an x.com URL.

```python
import json, re, subprocess

raw = subprocess.check_output([
    'bearcli', 'search', 'x.com',
    '--format', 'json',
    '--fields', 'id,title,tags,attachments,content',
    '--location', 'notes',
])
notes = json.loads(raw)

todo = []
for n in notes:
    text = (n.get('content') or '').strip()
    url_match = re.search(r'https?://(?:www\.)?x\.com/\S+', text)
    if not url_match:
        continue
    url = re.sub(r'[\)\]>"\s]+$', '', url_match.group(0))

    tags = [t.lstrip('#') for t in (n.get('tags') or [])]
    has_inbox_tag = 'inbox/saved-tweets' in tags

    is_bare = re.match(r'^https?://(?:www\.)?x\.com/\S+$', text) is not None
    if not is_bare and not has_inbox_tag:
        continue  # not a tweet note

    has_image = bool(n.get('attachments'))
    has_body  = bool(re.search(r'^#\s+\S', text, re.MULTILINE)) and '> ' in text

    needs = []
    if not has_inbox_tag: needs.append('inbox_tag')
    if not has_image:     needs.append('image')
    if not has_body:      needs.append('body')
    if has_inbox_tag and len(tags) == 1: needs.append('extra_tags')

    if needs:
        todo.append({
            'id': n['id'], 'url': url,
            'has_image': has_image, 'has_body': has_body,
            'has_inbox_tag': has_inbox_tag, 'tags': tags, 'needs': needs,
        })

with open('/tmp/tweet_todo.json', 'w') as f: json.dump(todo, f)

from collections import Counter
counts = Counter(need for n in todo for need in n['needs'])
print(f'{len(todo)} notes need work:')
for k, v in sorted(counts.items()): print(f'  {k}: {v}')
print()
for n in todo:
    print(f'  id={n["id"]} needs={n["needs"]} {n["url"][:65]}')
```

Review the output before proceeding. Then:

---

**Step A — Playwright pass (image + content extraction)**

For all notes that need `image` OR `body`, run a Playwright batch to screenshot and extract tweet text. Notes that only need `extra_tags` or `inbox_tag` skip this step.

```python
import json
todo = json.load(open('/tmp/tweet_todo.json'))
playwright_batch = [n for n in todo if 'image' in n['needs'] or 'body' in n['needs']]
print(json.dumps([{'id': n['id'], 'url': n['url']} for n in playwright_batch]))
```

Use `browser_run_code` with the batch inlined. Closes Chrome if open first (`osascript -e 'tell application "Google Chrome" to quit'`). Screenshots go to `/tmp/tweet_{id}.png`:

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
    const filename = '/tmp/tweet_' + note.id + '.png';
    try {
      await page.goto(note.url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      const article = page.locator('article[data-testid="tweet"]').first();
      try { await article.waitFor({ timeout: 6000 }); } catch(_) {}
      if (!await article.count()) {
        results.push({ id: note.id, status: 'no_article', url: note.url });
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
      results.push({ id: note.id, status: 'ok', filename,
                     tweetText, author, handle, url: note.url });
    } catch(e) {
      results.push({ id: note.id, status: 'error', error: String(e), url: note.url });
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
ok = sum(1 for r in results if r.get('status') == 'ok' and os.path.exists(f'/tmp/tweet_{r["id"]}.png'))
print(f'{ok}/{len(results)} screenshots confirmed on disk')
```

---

**Step B — Apply mutations via bearcli**

No SQLite. No Bear restart. `bearcli` writes through Bear's own frameworks, so changes appear immediately in the running app.

```python
import json, os, subprocess

todo = {n['id']: n for n in json.load(open('/tmp/tweet_todo.json'))}
playwright = {r['id']: r for r in json.load(open('/tmp/tweet_playwright.json')) if r.get('status') == 'ok'}

def run(*args, **kwargs):
    return subprocess.run(args, check=False, capture_output=True, text=True, **kwargs)

def get_content(note_id):
    r = run('bearcli', 'cat', note_id)
    return r.stdout

ATTACH_NAME = 'tweet_screenshot.png'

for note_id, note in todo.items():
    needs = note['needs']
    pr = playwright.get(note_id, {})
    tweet_text = pr.get('tweetText', '').strip()
    author     = pr.get('author', '').strip()
    handle     = pr.get('handle', '').strip()
    url        = note['url']

    # 1. Inbox tag — dedicated tag command, no body edit
    if 'inbox_tag' in needs:
        run('bearcli', 'tags', 'add', note_id, 'inbox/saved-tweets')

    # 2. Body rewrite — when we have full tweet content, write the structured note
    if 'body' in needs and tweet_text and author:
        short = tweet_text[:70] + ('…' if len(tweet_text) > 70 else '')
        blockquoted = '\n'.join(
            f'> {line}' if line.strip() else '>'
            for line in tweet_text.split('\n')
        )
        body_lines = [
            f'# {author}: {short}',
            '',
            blockquoted,
            '',
            f'**@{handle}** · [View on X]({url})',
            '',
            '#inbox/saved-tweets',
        ]
        # If we're also adding an image this run, include the markdown line too
        if 'image' in needs:
            body_lines += ['', f'![{ATTACH_NAME}]({ATTACH_NAME})']
        new_body = '\n'.join(body_lines) + '\n'
        r = run('bearcli', 'write', note_id, '--content', new_body)
        if r.returncode != 0:
            print(f'write failed id={note_id}: {r.stderr.strip()}')

    # 3. Image — add the binary first, then ensure the markdown reference exists
    if 'image' in needs:
        screenshot = f'/tmp/tweet_{note_id}.png'
        if os.path.exists(screenshot):
            with open(screenshot, 'rb') as f:
                r = run('bearcli', 'attachments', 'add', note_id,
                        '--filename', ATTACH_NAME, input=f.read())
            if r.returncode != 0:
                print(f'attachments add failed id={note_id}: {r.stderr.strip()}')
                continue
            # If we did NOT just rewrite the body, append the markdown reference
            if not ('body' in needs and tweet_text and author):
                cur = get_content(note_id)
                if f'![{ATTACH_NAME}]' not in cur:
                    run('bearcli', 'append', note_id,
                        '--content', f'\n\n![{ATTACH_NAME}]({ATTACH_NAME})\n')
        else:
            print(f'screenshot missing for id={note_id}, skipping image')

    print(f'updated id={note_id} needs={needs}')

print('Done')
```

---

**Step C — Auto-tag pass (notes needing `extra_tags`)**

Pull the existing tag taxonomy and current note bodies, classify, then apply with `bearcli tags add` — body untouched, modification date untouched.

```python
import json, subprocess

tags_raw = subprocess.check_output(['bearcli', 'tags', 'list', '--format', 'json'])
all_tags = sorted({t.lstrip('#') for entry in json.loads(tags_raw) for t in [entry.get('tag', '')] if t})

todo = json.load(open('/tmp/tweet_todo.json'))
needs_tags = [n for n in todo if 'extra_tags' in n['needs']]

notes_with_text = []
for n in needs_tags:
    text = subprocess.check_output(['bearcli', 'cat', n['id']], text=True)
    notes_with_text.append({**n, 'text': text})

with open('/tmp/tweet_tagging.json', 'w') as f:
    json.dump({'tags': all_tags, 'notes': notes_with_text}, f)

print(f'{len(needs_tags)} notes need extra tags')
print('Existing tags:', json.dumps(all_tags, indent=2))
print()
for n in notes_with_text:
    print(f'id={n["id"]} current_tags={n["tags"]}')
    print(f'  {n["text"][:200]}')
    print()
```

Read the note content above. For each note, pick 1–3 tags from the existing tag list. Prefer `learn/*` tags. Build the assignment dict and apply:

```python
import subprocess

# Fill this in based on your analysis (no leading # — bearcli strips them anyway):
TAG_ASSIGNMENTS = {
    # 'NOTE-UUID': ['tag1', 'tag2'],
}

for note_id, tags in TAG_ASSIGNMENTS.items():
    r = subprocess.run(['bearcli', 'tags', 'add', note_id, *tags],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f'tags add failed id={note_id}: {r.stderr.strip()}')
    else:
        print(f'tagged id={note_id}: {tags}')

print(f'Done: {len(TAG_ASSIGNMENTS)} notes tagged')
```

No Bear quit/restart. `bearcli tags add` updates the live database through Bear's own frameworks; changes are visible in the running app immediately.

---

**Final report**: how many notes updated per category (image, body, inbox_tag, extra_tags), how many `no_article` (deleted/protected tweets), how many failed.
