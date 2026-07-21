Use the bear-notes skill. Then execute the idempotent Tweet Notes Enrichment Workflow below.

The workflow is fully idempotent — run it any time to catch up on anything that's missing.

> **Three-tier fetching strategy:**
>
> 1. **Tier 1 (always):** `cdn.syndication.twimg.com/tweet-result?id=<id>` — X's own embed API. Returns full JSON for any single tweet (text, author, photos, video, conversation_count). No login, no bot detection. The `token` parameter isn't validated.
> 2. **Tier 2 (thread enrichment, opt-in):** `@the-convocation/twitter-scraper` Node lib calling X's authenticated GraphQL via the user's exported cookies. Used only to fetch self-thread continuations when a tweet has `conversation_count > 0`. Skipped silently if cookies are missing or stale. A first-pass single body is stamped `thread:unchecked`; a later run re-flags it for Tier 2 and upgrades it to a thread (or settles it at `thread:complete count=1`). Set `FORCE_THREAD_RECHECK=1` to re-open already-settled notes for backfill.
> 3. **Tier 3 (screenshot fallback):** Playwright loads `platform.twitter.com/embed/Tweet.html?id=<id>` and screenshots the rendered tweet card. Runs only when Tier 1 returned no embedded photo, so text-only and link-card tweets still get a visual attachment. No auth required.
>
> Cookies live at `~/.config/notes-organize-tweets/x-cookies.json` (gitignored). Run `~/.dotfiles/agents/claude/tools/refresh-x-cookies.sh` for setup instructions.

---

**Pre-check — Audit all tweet notes and classify what needs work**

Two `bearcli search` calls cover the audit surface: a text search for `x.com` (catches notes with structured bodies and `#inbox/saved-tweets` tags) plus `@untagged` (catches bare-URL notes that Bear's FTS doesn't tokenize reliably). Results are merged by ID.

Tweet-save notes are recognized by **title prefix** — Bear auto-derives the title from the first content line, so a title starting with `https://x.com/.../status/...` is a high-confidence signal regardless of body shape. This catches: bare URLs, URL + user annotation (`* note: …`), markdown-link-wrapped `[url](url)`, and notes where the user typed `#inbox/saved-tweets` inline but Bear failed to promote it to a structured tag. Any text following the URL is captured as `annotation` and rendered into a `**My note**` block by Step B.

```python
import json, os, re, subprocess
from datetime import date, timedelta

# Set FORCE_THREAD_RECHECK=1 to re-flag already-settled (thread:complete) notes so a re-run
# re-fetches them via Tier 2. Use to backfill threads saved before thread:unchecked tracking
# existed, or to pick up self-replies added since a note was last enriched.
FORCE_THREAD_RECHECK = os.environ.get('FORCE_THREAD_RECHECK') == '1'

def _search(query):
    raw = subprocess.check_output([
        'bearcli', 'search', query,
        '--format', 'json',
        '--fields', 'id,title,tags,attachments,content',
        '--location', 'notes',
    ])
    return json.loads(raw)

by_id = {}
for n in _search('x.com'):
    by_id[n['id']] = n
for n in _search('@untagged'):  # Bear FTS misses bare-URL notes — pick them up here
    by_id.setdefault(n['id'], n)
notes = list(by_id.values())

today = date.today()
auth_needed_ttl = timedelta(days=7)

# Title-prefix matches both `https://x.com/...` and `[https://x.com/...](...)` shapes.
TWEET_URL_RE = re.compile(r'https?://(?:www\.)?x\.com/[^\s\])]+/status/\d+(?:\?\S*)?', re.IGNORECASE)
TITLE_TWEET_RE = re.compile(r'^\[?https?://(?:www\.)?x\.com/\S+/status/\d+', re.IGNORECASE)

todo = []
for n in notes:
    text = (n.get('content') or '').strip()
    title = (n.get('title') or '').strip()

    raw_tags = [t.lstrip('#') for t in (n.get('tags') or [])]
    has_inbox_tag = 'inbox/saved-tweets' in raw_tags
    topical_tags = [t for t in raw_tags if not t.startswith('inbox')]

    # Recognize as tweet-save via title prefix OR existing inbox tag.
    title_is_tweet = bool(TITLE_TWEET_RE.match(title))
    if not title_is_tweet and not has_inbox_tag:
        continue  # not a tweet note (e.g. project note that mentions a tweet)

    url_match = TWEET_URL_RE.search(text)
    if not url_match:
        continue
    url = url_match.group(0).rstrip('.,)>]"\'')

    # Capture any user annotation after the URL (excluding inline #inbox/saved-tweets
    # text and markdown link closers). Only meaningful when the body is still unstructured.
    annotation = None
    after_url = text[url_match.end():].strip()
    after_url = re.sub(r'^\]\([^)]*\)\s*', '', after_url)  # strip markdown link closer
    after_url = after_url.strip()
    if after_url and not after_url.startswith('#') and not after_url.startswith('<!--'):
        annotation = after_url[:500]

    has_image = bool(n.get('attachments'))
    is_tombstone = '_Original tweet was deleted or restricted._' in text
    is_link_only = '_Tweet contains only a link — no text content._' in text
    has_body = (
        bool(re.search(r'^#\s+\S', text, re.MULTILINE))
        and ('> ' in text or is_tombstone or is_link_only)
    )

    # Parse thread markers — they're the idempotency anchor.
    #   <!-- thread:complete count=N fetched=YYYY-MM-DD -->   settled: Tier 2 has run, trust it
    #   <!-- thread:unchecked fetched=YYYY-MM-DD -->          provisional: text captured, Tier 2 pending
    #   <!-- thread:auth-needed fetched=YYYY-MM-DD -->        Tier 2 wanted cookies, none available
    thread_complete_count = None
    thread_auth_needed_date = None
    thread_unchecked = False
    m = re.search(r'<!--\s*thread:complete\s+count=(\d+)\s+fetched=(\d{4}-\d{2}-\d{2})', text)
    if m:
        thread_complete_count = int(m.group(1))
    elif re.search(r'<!--\s*thread:unchecked\b', text):
        # First-pass single body: text is captured, but Tier 2 hasn't looked for a
        # self-thread continuation yet. Treated as "still needs a thread check" below.
        thread_unchecked = True
    else:
        m2 = re.search(r'<!--\s*thread:auth-needed\s+fetched=(\d{4}-\d{2}-\d{2})', text)
        if m2:
            try:
                thread_auth_needed_date = date.fromisoformat(m2.group(1))
            except ValueError:
                thread_auth_needed_date = None

    # Stale auth-needed markers (>7d) are quietly cleared by retreating to "no marker"
    # so the user gets re-prompted. We treat them as "no marker" for flagging purposes.
    if thread_auth_needed_date and (today - thread_auth_needed_date) > auth_needed_ttl:
        thread_auth_needed_date = None
        # Body still has the marker; Step A2 will overwrite it.

    needs = []
    if not has_inbox_tag: needs.append('inbox_tag')
    if not has_body:      needs.append('body')
    if not has_image and not has_body: needs.append('image')
    if has_inbox_tag and not topical_tags and not is_tombstone and not is_link_only:
        needs.append('extra_tags')

    # Thread states — only when the body is structured. Tombstones and link-only never thread-check.
    if has_body and not is_tombstone and not is_link_only and thread_auth_needed_date is None:
        # thread_complete_count is None for both freshly-built bodies marked thread:unchecked
        # and legacy bodies with no marker — in either case Tier 2 hasn't run, so check.
        # FORCE_THREAD_RECHECK re-opens already-settled (count=N) notes for backfill.
        if thread_complete_count is None or FORCE_THREAD_RECHECK:
            needs.append('thread_check')

    if needs:
        todo.append({
            'id': n['id'], 'url': url,
            'has_image': has_image, 'has_body': has_body,
            'has_inbox_tag': has_inbox_tag, 'tags': raw_tags, 'needs': needs,
            'thread_complete_count': thread_complete_count,
            'annotation': annotation,  # carried into Step B's body builders
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

**Step A — Syndication API (text + photos via HTTP)**

For all notes that need `image`, `body`, or `thread_check`, hit `cdn.syndication.twimg.com/tweet-result?id=<status_id>&token=4&lang=en` and download embedded photos. Notes that only need `extra_tags` or `inbox_tag` skip this step.

```python
import json, os, re, subprocess
from collections import Counter

todo = json.load(open('/tmp/tweet_todo.json'))
batch = [n for n in todo if {'image','body','thread_check'} & set(n['needs'])]

results = []
for n in batch:
    m = re.search(r'/status/(\d+)', n['url'])
    if not m:
        results.append({'id': n['id'], 'status': 'no_id', 'url': n['url']})
        continue
    tid = m.group(1)
    out_json = f'/tmp/syndication_{n["id"]}.json'
    cp = subprocess.run([
        'curl', '-sS', '--max-time', '15',
        '-H', 'User-Agent: Mozilla/5.0',
        '-w', '%{http_code}',
        '-o', out_json,
        f'https://cdn.syndication.twimg.com/tweet-result?id={tid}&token=4&lang=en',
    ], capture_output=True, text=True)
    if cp.stdout.strip() != '200':
        results.append({'id': n['id'], 'status': 'http_error', 'http': cp.stdout.strip(), 'url': n['url']})
        continue
    try:
        data = json.load(open(out_json))
    except Exception as e:
        results.append({'id': n['id'], 'status': 'parse_error', 'err': str(e), 'url': n['url']})
        continue
    if data.get('__typename') == 'TweetTombstone' or 'tombstone' in data:
        results.append({'id': n['id'], 'status': 'no_article', 'url': n['url']})
        continue
    user = data.get('user') or {}
    photos = [p.get('url') for p in (data.get('photos') or []) if p.get('url')]
    results.append({
        'id': n['id'], 'status': 'ok',
        'tweet_id': tid,
        'tweetText': data.get('text') or '',
        'author': user.get('name') or '',
        'handle': user.get('screen_name') or '',
        'photo_urls': photos,
        'url': n['url'],
        'conversation_count': data.get('conversation_count') or 0,
    })

# Download first photo per tweet (?name=large for higher-res)
for r in results:
    if r['status'] != 'ok' or not r.get('photo_urls'):
        continue
    url = r['photo_urls'][0]
    if '?' not in url:
        url = url + '?name=large'
    out = f'/tmp/tweet_{r["id"]}.png'
    subprocess.run(['curl', '-sS', '-L', '--max-time', '20', '-o', out, url], capture_output=True)

with open('/tmp/tweet_syndication.json', 'w') as f:
    json.dump(results, f, indent=2)

print(Counter(r['status'] for r in results))
for r in results:
    if r['status'] == 'ok':
        photos = len(r.get('photo_urls') or [])
        cc = r.get('conversation_count', 0)
        print(f'  ok    {r["id"][:8]} @{r["handle"]:20s} photos={photos} conv_count={cc}')
    else:
        print(f'  {r["status"]:11s} {r["id"][:8]} {r["url"][:60]}')
```

---

**Step A2 — Thread fetch via twitter-scraper (auth required)**

Notes flagged `thread_check` whose head tweet has `conversation_count > 0` are candidates for thread enrichment. Skip cleanly if cookies are missing — affected notes get an `auth-needed` marker.

```python
import json, os, subprocess
from datetime import date

todo = {n['id']: n for n in json.load(open('/tmp/tweet_todo.json'))}
syn = {r['id']: r for r in json.load(open('/tmp/tweet_syndication.json'))}

# Clear any stale thread-error manifest from a prior run. The fetcher rewrites it when it runs;
# clearing here guarantees a no-candidate run doesn't leave last run's errors for Step B to read.
try:
    os.remove('/tmp/tweet_thread_errors.json')
except FileNotFoundError:
    pass

candidates = []
for note_id, n in todo.items():
    if 'thread_check' not in n['needs']:
        continue
    pr = syn.get(note_id) or {}
    if pr.get('status') != 'ok':
        continue
    if (pr.get('conversation_count') or 0) == 0:
        # No replies at all → definitely single tweet. Skip Tier 2 entirely; Step B will write count=1.
        continue
    candidates.append({
        'note_id': note_id,
        'head_id': pr.get('tweet_id'),
        'author': pr.get('handle'),
    })

print(f'{len(candidates)} thread candidates (conversation_count > 0)')

if not candidates:
    print('no thread candidates — skipping Step A2')
else:
    fetcher = os.path.expanduser('~/.dotfiles/agents/claude/tools/x-thread-fetcher.mjs')
    cp = subprocess.run(
        ['node', fetcher],
        input=json.dumps(candidates),
        capture_output=True, text=True,
    )
    print(cp.stdout)
    if cp.returncode != 0:
        print('STDERR:', cp.stderr, file=__import__('sys').stderr)
        if cp.returncode in (2, 3):
            # No cookies / stale cookies — mark every candidate so audit doesn't keep flagging.
            today_iso = date.today().isoformat()
            with open('/tmp/tweet_thread_auth_needed.json', 'w') as f:
                json.dump({'note_ids': [c['note_id'] for c in candidates], 'date': today_iso}, f)
            print(f'Marked {len(candidates)} notes thread:auth-needed for {today_iso}')
        else:
            raise SystemExit(f'x-thread-fetcher.mjs failed with exit {cp.returncode}')

# Per-candidate: load the thread JSON if present, download each tweet's first photo.
for c in candidates:
    p = f'/tmp/syndication_thread_{c["note_id"]}.json'
    if not os.path.exists(p):
        continue
    thread = json.load(open(p))
    for seq, t in enumerate(thread.get('tweets') or [], start=1):
        photos = t.get('photos') or []
        if not photos:
            continue
        url = photos[0].get('url')
        if not url:
            continue
        if '?' not in url:
            url = url + '?name=large'
        out = f'/tmp/tweet_{c["note_id"]}_{seq}.png'
        subprocess.run(['curl', '-sS', '-L', '--max-time', '20', '-o', out, url], capture_output=True)
```

---

**Step A3 — Tweet-card screenshot fallback (Playwright)**

For notes that need an image but the syndication API returned no embedded photo, render the tweet via X's embed widget (`platform.twitter.com/embed/Tweet.html`) and screenshot the article element. The screenshot lands at `/tmp/tweet_<note_id>.png` — the same path Step A would have used for an embedded photo — so Step B picks it up transparently without any further branching.

The embed widget is the same one third-party sites use to render tweets. No auth required, stable interface. Single Chromium process serves the whole batch.

```python
import json, os, subprocess, sys

todo = {n['id']: n for n in json.load(open('/tmp/tweet_todo.json'))}
syn = {r['id']: r for r in json.load(open('/tmp/tweet_syndication.json'))}

shot_candidates = []
for note_id, n in todo.items():
    if 'image' not in n['needs']:
        continue
    # If Step A already downloaded an embedded photo, /tmp/tweet_<id>.png exists.
    if os.path.exists(f'/tmp/tweet_{note_id}.png'):
        continue
    pr = syn.get(note_id) or {}
    if pr.get('status') != 'ok':
        continue
    shot_candidates.append({'note_id': note_id, 'tweet_id': pr['tweet_id']})

print(f'{len(shot_candidates)} notes need a tweet-card screenshot')

if shot_candidates:
    fetcher = os.path.expanduser('~/.dotfiles/agents/claude/tools/x-screenshot-fetcher.py')
    cp = subprocess.run(
        ['python3', fetcher],
        input=json.dumps(shot_candidates),
        capture_output=True, text=True,
    )
    print(cp.stdout)
    if cp.returncode != 0:
        print('STDERR:', cp.stderr, file=sys.stderr)
        # Soft-fail: Step B will hit `no_photo_available` for whichever shots didn't land.
```

---

**Step B — Apply mutations via bearcli**

```python
import json, os, re, subprocess, sys
from collections import Counter
from datetime import date

todo = {n['id']: n for n in json.load(open('/tmp/tweet_todo.json'))}
syn = {r['id']: r for r in json.load(open('/tmp/tweet_syndication.json'))}

# Auth-needed list from Step A2 (may not exist if Tier 2 ran successfully or had nothing to do)
auth_needed = set()
auth_needed_date = date.today().isoformat()
try:
    j = json.load(open('/tmp/tweet_thread_auth_needed.json'))
    auth_needed = set(j['note_ids'])
    auth_needed_date = j['date']
except FileNotFoundError:
    pass

# Notes whose Tier 2 fetch hit a transient error (e.g. 503). These must NOT be settled to
# count=1 — a transient failure is not evidence the tweet has no self-thread.
thread_errors = set()
try:
    thread_errors = set(json.load(open('/tmp/tweet_thread_errors.json'))['note_ids'])
except FileNotFoundError:
    pass

def run(*args, **kwargs):
    if isinstance(kwargs.get('input'), (bytes, bytearray)):
        return subprocess.run(args, check=False, capture_output=True, **kwargs)
    return subprocess.run(args, check=False, capture_output=True, text=True, **kwargs)

def overwrite(note_id, body):
    # stdin path — `--content` interprets \n/\t escapes and would mangle tweet text
    return subprocess.run(['bearcli', 'overwrite', note_id],
                          input=body, check=False, capture_output=True, text=True)

def get_content(note_id):
    return run('bearcli', 'cat', note_id).stdout

def get_topical_tags(note_id):
    """Tags currently on the note that aren't part of the inbox/* hierarchy.
    Captured before any body-rewrite so we can re-add them after `bearcli overwrite`
    (which sets tags from the body markdown alone, dropping anything not present)."""
    r = run('bearcli', 'tags', 'list', note_id, '--format', 'json')
    if r.returncode != 0: return []
    try: tags = [t.lstrip('#') for t in [e.get('tag','') for e in json.loads(r.stdout)] if t]
    except Exception: return []
    return [t for t in tags if not t.startswith('inbox')]

def reference_existing_attachments(note_id, body):
    """bearcli overwrite rejects any write that drops the last reference to an existing
    attachment. Rebuilt bodies — especially thread upgrades over a note that already has
    tweet_screenshot.png — must therefore keep every attached file referenced. The
    head-tweet screenshot lands at the end of the Tweet 1 section; anything else goes
    above the @handle footer (or above the trailing marker as a last resort)."""
    r = run('bearcli', 'attachments', 'list', note_id, '--format', 'json')
    if r.returncode != 0:
        return body
    try:
        attached = [e.get('filename') or e.get('name') or '' for e in json.loads(r.stdout)]
    except Exception:
        return body
    for fname in [f for f in attached if f]:
        if f']({fname})' in body:
            continue
        ref = f'![{fname}]({fname})\n\n'
        m = re.search(r'^## Tweet 2 of \d+$', body, re.MULTILINE)
        if fname == ATTACH_NAME and m:
            body = body[:m.start()] + ref + body[m.start():]
        elif '**@' in body:
            body = body.replace('**@', ref + '**@', 1)
        elif '<!--' in body:
            body = body.replace('<!--', ref + '<!--', 1)
        else:
            body = body.rstrip('\n') + '\n\n' + ref
    return body

def clean_text(t):
    return re.sub(r'\s*https://t\.co/\S+\s*$', '', t).strip()

def blockquote(text):
    return '\n'.join((f'> {line}' if line.strip() else '>') for line in text.split('\n'))

def heading_short(author, text):
    single_line = re.sub(r'\s+', ' ', text).strip()
    short = single_line[:70] + ('…' if len(single_line) > 70 else '')
    return f'# {author}: {short}'

today_iso = date.today().isoformat()
ATTACH_NAME = 'tweet_screenshot.png'
counts = Counter()

def thread_marker(count):
    return f'<!-- thread:complete count={count} fetched={today_iso} -->'

def auth_needed_marker(date_iso):
    return f'<!-- thread:auth-needed fetched={date_iso} -->'

def unchecked_marker():
    # Provisional marker for a first-pass single-tweet body: text is captured, but Tier 2
    # has not yet checked for a self-thread. A later run re-flags this note thread_check.
    return f'<!-- thread:unchecked fetched={today_iso} -->'

def build_single_body(syn_entry, url, count_marker=None, annotation=None):
    # count_marker is the trailing marker for a real-text single tweet. First-pass callers
    # pass unchecked_marker() so a later run will thread-check it. Link-only bodies ignore it
    # and stamp count=1, since a link card never has a self-thread to fetch.
    if count_marker is None:
        count_marker = unchecked_marker()
    tweet_text = clean_text(syn_entry.get('tweetText') or '')
    author = (syn_entry.get('author') or '').strip()
    handle = (syn_entry.get('handle') or '').strip()
    expanded_url = ''
    try:
        full = json.load(open(f'/tmp/syndication_{syn_entry["id"]}.json'))
        for u in (full.get('entities') or {}).get('urls') or []:
            if u.get('expanded_url'):
                expanded_url = u['expanded_url']; break
    except Exception:
        pass

    if not tweet_text:
        target = expanded_url[:60] if expanded_url else 'external resource'
        lines = [
            f'# {author}: link to {target}',
            '',
            '> _Tweet contains only a link — no text content._',
            '',
        ]
        if expanded_url:
            lines += [f'**Linked URL**: <{expanded_url}>', '']
        kind = 'body_link_only'
    else:
        lines = [
            heading_short(author, tweet_text),
            '',
            blockquote(tweet_text),
            '',
        ]
        kind = 'body'

    if annotation:
        lines += ['**My note**:', '', blockquote(annotation), '']

    # Link-only bodies have no thread to fetch → settle them immediately at count=1.
    trailing_marker = thread_marker(1) if kind == 'body_link_only' else count_marker
    lines += [
        f'**@{handle}** · [View on X]({url})',
        '',
        '#inbox/saved-tweets',
        '',
        trailing_marker,
    ]
    return '\n'.join(lines) + '\n', kind

def build_thread_body(syn_entry, url, thread, annotation=None):
    """Multi-tweet thread body. `thread['tweets']` is the chronological self-reply list."""
    tweets = thread['tweets']
    n = len(tweets)
    head = tweets[0]
    author = (syn_entry.get('author') or head.get('name') or '').strip()
    handle = (syn_entry.get('handle') or head.get('username') or '').strip()
    head_text = clean_text(head.get('text') or '')
    single_line = re.sub(r'\s+', ' ', head_text).strip()
    short = single_line[:60] + ('…' if len(single_line) > 60 else '')
    lines = [f'# {author}: {short} (thread: {n} tweets)', '']
    for seq, t in enumerate(tweets, start=1):
        body = clean_text(t.get('text') or '')
        lines.append(f'## Tweet {seq} of {n}')
        lines.append('')
        lines.append(blockquote(body) if body else '> _(no text)_')
        lines.append('')
        if t.get('photos'):
            lines.append(f'![tweet_{seq}.png](tweet_{seq}.png)')
            lines.append('')
    if annotation:
        lines += ['**My note**:', '', blockquote(annotation), '']
    lines += [
        f'**@{handle}** · [View thread on X]({url})',
        '',
        '#inbox/saved-tweets',
        '',
        thread_marker(n),
    ]
    return '\n'.join(lines) + '\n'

def build_tombstone_body(url):
    return (
        '# Tweet unavailable\n\n'
        '_Original tweet was deleted or restricted._\n\n'
        f'[Original URL]({url})\n\n'
        '#inbox/saved-tweets\n\n'
        + thread_marker(1) + '\n'
    )

for note_id, note in todo.items():
    needs = note['needs']
    pr = syn.get(note_id, {})
    status = pr.get('status', 'missing')
    url = note['url']
    annotation = note.get('annotation')

    # Capture topical tags BEFORE any body rewrite so we can re-add them after.
    # bearcli overwrite reads tags from the body markdown, so non-inbox tags would be lost.
    preserved_topical = get_topical_tags(note_id)

    # 1. Inbox tag
    if 'inbox_tag' in needs:
        r = run('bearcli', 'tags', 'add', note_id, 'inbox/saved-tweets')
        if r.returncode == 0: counts['inbox_tag'] += 1
        else:
            print(f'inbox_tag FAILED id={note_id}: {r.stderr.strip()}', file=sys.stderr)
            counts['failed'] += 1

    # Decide which body to write. Order of precedence:
    #   - thread_check + we have a thread fetch with N>1 → thread body
    #   - thread_check + auth needed → leave body but stamp auth-needed marker
    #   - body in needs + status ok → single body stamped thread:unchecked (real text)
    #                                   or count=1 (link-only); a later run thread-checks it
    #   - body in needs + status no_article → tombstone body
    #   - thread_check only (no body needs) → just stamp count marker

    thread_path = f'/tmp/syndication_thread_{note_id}.json'
    have_thread = os.path.exists(thread_path)
    thread_data = None
    thread_size = 1
    if have_thread:
        thread_data = json.load(open(thread_path))
        thread_size = len(thread_data.get('tweets') or [])

    write_body = None
    write_kind = None

    if 'body' in needs:
        if status == 'ok':
            if have_thread and thread_size > 1:
                write_body = build_thread_body(pr, url, thread_data, annotation=annotation)
                write_kind = 'body_thread'
            else:
                # First-pass single body: stamp thread:unchecked so a re-run thread-checks it
                # (build_single_body downgrades link-only bodies to count=1 internally).
                write_body, write_kind = build_single_body(pr, url, unchecked_marker(), annotation=annotation)
        elif status == 'no_article':
            write_body = build_tombstone_body(url)
            write_kind = 'body_tombstone'
        else:
            counts['skipped_no_data'] += 1
    elif 'thread_check' in needs:
        if note_id in thread_errors:
            # Tier 2 hit a transient error (503/network). Leave the existing marker untouched —
            # thread:unchecked for a first-pass body, or a prior count=N under FORCE — so a later
            # run retries. Crucially, do NOT fall through to the count=1 settle below.
            counts['thread_retry_pending'] += 1
        elif note_id in auth_needed:
            # Stamp auth-needed marker without rewriting the body.
            cur = get_content(note_id)
            stamp = auth_needed_marker(auth_needed_date)
            # Remove any existing thread:* marker first, then append
            cleaned = re.sub(r'\n*<!--\s*thread:[^>]+-->\s*\n*$', '\n', cur)
            new_body = cleaned.rstrip('\n') + '\n\n' + stamp + '\n'
            r = overwrite(note_id, new_body)
            if r.returncode == 0:
                counts['thread_auth_needed'] += 1
            else:
                print(f'auth-needed marker write FAILED id={note_id}: {r.stderr.strip()}', file=sys.stderr)
                counts['failed'] += 1
        elif have_thread and thread_size > 1 and status == 'ok':
            # Body already exists — Tier 2 found a thread. Rebuild as thread.
            write_body = build_thread_body(pr, url, thread_data, annotation=annotation)
            write_kind = 'body_thread_enrich'
        elif status == 'ok':
            # Single tweet OR thread fetch returned 1 tweet. Stamp count=1 on existing body.
            cur = get_content(note_id)
            cleaned = re.sub(r'\n*<!--\s*thread:[^>]+-->\s*\n*$', '\n', cur)
            new_body = cleaned.rstrip('\n') + '\n\n' + thread_marker(1) + '\n'
            r = overwrite(note_id, new_body)
            if r.returncode == 0:
                counts['thread_marker_only'] += 1
            else:
                print(f'thread marker write FAILED id={note_id}: {r.stderr.strip()}', file=sys.stderr)
                counts['failed'] += 1

    if write_body is not None:
        # Keep every existing attachment referenced so bearcli's overwrite guard passes.
        write_body = reference_existing_attachments(note_id, write_body)
        r = overwrite(note_id, write_body)
        if r.returncode == 0:
            counts[write_kind] += 1
            # Re-add any topical tags Bear stripped during the rewrite.
            if preserved_topical:
                rt = run('bearcli', 'tags', 'add', note_id, *preserved_topical)
                if rt.returncode == 0:
                    counts['tags_preserved'] += 1
                else:
                    print(f'tag preserve FAILED id={note_id}: {rt.stderr.strip()}', file=sys.stderr)
        else:
            print(f'body write FAILED id={note_id}: {r.stderr.strip()}', file=sys.stderr)
            counts['failed'] += 1

    # 3. Image attachment (single-tweet head photo) — same as before, only when unstructured.
    if 'image' in needs:
        screenshot = f'/tmp/tweet_{note_id}.png'
        if os.path.exists(screenshot) and os.path.getsize(screenshot) > 1000:
            with open(screenshot, 'rb') as f:
                r = run('bearcli', 'attachments', 'add', note_id,
                        '--filename', ATTACH_NAME, input=f.read())
            if r.returncode != 0:
                err = r.stderr.decode() if isinstance(r.stderr, bytes) else r.stderr
                print(f'attach FAILED id={note_id}: {err.strip()}', file=sys.stderr)
                counts['failed'] += 1
                continue
            counts['image'] += 1
            if not ('body' in needs and status == 'ok'):
                cur = get_content(note_id)
                if f'![{ATTACH_NAME}]' not in cur and f'![]({ATTACH_NAME})' not in cur:
                    run('bearcli', 'append', note_id,
                        '--content', f'\n\n![{ATTACH_NAME}]({ATTACH_NAME})\n')
        else:
            counts['no_photo_available'] += 1

    # 3b. Thread photos — for thread-enriched notes, attach each tweet_<seq>.png.
    if write_kind in ('body_thread', 'body_thread_enrich') and thread_data:
        for seq, t in enumerate(thread_data['tweets'], start=1):
            shot = f'/tmp/tweet_{note_id}_{seq}.png'
            if not (os.path.exists(shot) and os.path.getsize(shot) > 1000):
                continue
            fname = f'tweet_{seq}.png'
            with open(shot, 'rb') as f:
                r = run('bearcli', 'attachments', 'add', note_id,
                        '--filename', fname, input=f.read())
            if r.returncode != 0:
                err = r.stderr.decode() if isinstance(r.stderr, bytes) else r.stderr
                print(f'thread attach FAILED id={note_id} seq={seq}: {err.strip()}', file=sys.stderr)
                counts['failed'] += 1
                continue
            counts['thread_image'] += 1
        # Bear auto-injects ![](filename) lines after each attachments add. The body
        # already has explicit `![tweet_N.png](tweet_N.png)` references, so dedup
        # the bare `![](tweet_N.png)` lines that Bear appended.
        cur = get_content(note_id)
        deduped = re.sub(r'\n!\[\]\(tweet_\d+\.png\)\s*\n', '\n', cur)
        if deduped != cur:
            overwrite(note_id, deduped)

    print(f'  applied id={note_id} needs={needs} status={status} thread_size={thread_size}')

print('\nSummary:', json.dumps(dict(counts), indent=2))
```

---

**Step C — Auto-tag pass (notes needing `extra_tags`)**

Pull the existing tag taxonomy and the live tags for each candidate, classify, then apply with `bearcli tags add` — body untouched, modification date untouched.

```python
import json, re, subprocess

todo = json.load(open('/tmp/tweet_todo.json'))
syn = {r['id']: r for r in json.load(open('/tmp/tweet_syndication.json'))}

candidates = []
for n in todo:
    pr = syn.get(n['id'], {})
    if pr.get('status') != 'ok':
        continue
    tags_raw = subprocess.check_output(['bearcli', 'tags', 'list', n['id'], '--format', 'json'])
    tags = [t.lstrip('#') for t in [e.get('tag', '') for e in json.loads(tags_raw)] if t]
    if any(not t.startswith('inbox') for t in tags):
        continue
    candidates.append({
        'id': n['id'], 'tags': tags,
        'author': pr.get('author'), 'handle': pr.get('handle'),
        'text': pr.get('tweetText') or '',
    })

tags_raw = subprocess.check_output(['bearcli', 'tags', 'list', '--format', 'json'])
all_tags = sorted({(e.get('tag') or '').lstrip('#')
                   for e in json.loads(tags_raw) if e.get('tag')})

with open('/tmp/tweet_tagging.json', 'w') as f:
    json.dump({'tags': all_tags, 'candidates': candidates}, f)

print(f'{len(candidates)} notes need topical tags\n')
print('Existing taxonomy (top of list):')
for t in all_tags[:50]: print(f'  {t}')
print('...')
for c in candidates:
    one_line = re.sub(r'\s+', ' ', c['text']).strip()
    print(f"\nid={c['id'][:8]} @{c['handle']}")
    print(f"  text: {one_line[:240]}")
```

Read the candidate content above. For each note, pick 1–3 tags from the existing taxonomy. Prefer `learn/*` tags. Skip link-only tweets. Then apply:

```python
import subprocess

TAG_ASSIGNMENTS = {
    # 'NOTE-UUID': ['learn/foo', 'projects/bar'],
}

for note_id, tags in TAG_ASSIGNMENTS.items():
    r = subprocess.run(['bearcli', 'tags', 'add', note_id, *tags],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f'tags FAILED id={note_id}: {r.stderr.strip()}')
    else:
        print(f'tagged id={note_id[:8]}: {tags}')
print(f'Done: {len(TAG_ASSIGNMENTS)} notes tagged')
```

---

**Final report**: counts per category — `body`, `body_thread`, `body_thread_enrich`, `body_link_only`, `body_tombstone`, `thread_marker_only`, `thread_auth_needed`, `thread_retry_pending` (Tier 2 hit a transient error — left unchecked for a later run), `image` (covers both embedded photos and Tier 3 screenshots — same attachment slot), `thread_image`, `inbox_tag`, `extra_tags`. Plus `no_article`, `no_photo_available`, `skipped_no_data`, `failed`. If `thread_auth_needed > 0`, surface the cookie-refresh hint:

> `~/.dotfiles/agents/claude/tools/refresh-x-cookies.sh`

Re-run the workflow after refreshing cookies to backfill the threads.
