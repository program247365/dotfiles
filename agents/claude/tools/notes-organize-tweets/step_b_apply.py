import json, os, re, subprocess, sys, urllib.parse
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
    tags = [t for t in tags if not t.startswith('inbox')]
    # Bear lists implied parents (`learn`, `learn/ai`) alongside `learn/ai/llm`; re-adding
    # them would write redundant parent tags into the body. Keep only the leaves.
    return [t for t in tags if not any(o.startswith(t + '/') for o in tags)]

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
        # Bear writes attachment link targets percent-encoded (`image%202.png`) —
        # a raw space in the target breaks markdown parsing and bearcli's
        # attachment-reference guard rejects the write (hit 2026-08-25).
        quoted = urllib.parse.quote(fname)
        if f']({fname})' in body or f']({quoted})' in body:
            continue
        ref = f'![{fname}]({quoted})\n\n'
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

_tco_cache = {}

def resolve_tco(short):
    if short not in _tco_cache:
        r = run('curl', '-sS', '-o', '/dev/null', '--max-time', '10', '-w', '%{redirect_url}', short)
        _tco_cache[short] = r.stdout.strip() if r.returncode == 0 else ''
    return _tco_cache[short]

def clean_text(t, quoted_id=None):
    """Expand t.co links to their real targets. Links that only point back at the tweet's
    own media or its quoted tweet are dropped — the attachment / quote block covers them.
    An unresolvable link stays as t.co: a working redirect beats silently losing it."""
    def expand(m):
        target = resolve_tco(m.group(0))
        if not target:
            return m.group(0)
        if re.search(r'(?:x|twitter)\.com/\w+/status/\d+/(?:photo|video)/', target):
            return ''
        if quoted_id and re.search(rf'/status/{quoted_id}\b', target):
            return ''
        return target
    return re.sub(r'https://t\.co/\w+', expand, t).strip()

def is_link_only(text):
    return not re.sub(r'https?://\S+', '', text).strip()

def quote_block(q):
    """Render a quoted tweet under the quoting tweet's text."""
    if not q:
        return []
    text = clean_text(q.get('text') or '')
    link = q.get('permanentUrl') or ''
    return [f'**Quoting @{q.get("username", "")}** · [View on X]({link})', '', blockquote(text), '']

def existing_annotation(note_id):
    """The pre-check only extracts annotations from unstructured notes. Rebuilding an
    already-enriched body must carry its `**My note**` block forward or the user's words
    are lost."""
    m = re.search(r'^\*\*My note\*\*:\n\n((?:>.*\n?)+)', get_content(note_id), re.MULTILINE)
    if not m:
        return None
    return '\n'.join(ln[2:] if ln.startswith('> ') else '' for ln in m.group(1).rstrip('\n').split('\n'))

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

def build_single_body(syn_entry, url, count_marker=None, annotation=None, full=None):
    # count_marker is the trailing marker for a real-text single tweet. First-pass callers
    # pass unchecked_marker() so a later run will thread-check it. Link-only bodies ignore it
    # and stamp count=1, since a link card never has a self-thread to fetch.
    # `full` is Tier 2's hydrated record for this tweet, when A2 ran — it carries the
    # untruncated long-form text and the quoted tweet, which syndication lacks.
    if count_marker is None:
        count_marker = unchecked_marker()
    quoted = (full or {}).get('quoted')
    raw_text = (full or {}).get('text') or syn_entry.get('tweetText') or ''
    tweet_text = clean_text(raw_text, (quoted or {}).get('id') or syn_entry.get('quoted_id'))
    author = (syn_entry.get('author') or '').strip()
    handle = (syn_entry.get('handle') or '').strip()
    expanded_url = ''
    try:
        syn_json = json.load(open(f'/tmp/syndication_{syn_entry["id"]}.json'))
        for u in (syn_json.get('entities') or {}).get('urls') or []:
            if u.get('expanded_url'):
                expanded_url = u['expanded_url']; break
    except Exception:
        pass

    if not quoted and is_link_only(tweet_text):
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
        heading_text = tweet_text or f'quoting @{quoted.get("username", "")}'
        lines = [heading_short(author, heading_text), '']
        if tweet_text:
            lines += [blockquote(tweet_text), '']
        lines += quote_block(quoted)
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
    head_text = clean_text(head.get('text') or '', (head.get('quoted') or {}).get('id'))
    single_line = re.sub(r'\s+', ' ', head_text).strip()
    short = single_line[:60] + ('…' if len(single_line) > 60 else '')
    lines = [f'# {author}: {short} (thread: {n} tweets)', '']
    for seq, t in enumerate(tweets, start=1):
        body = clean_text(t.get('text') or '', (t.get('quoted') or {}).get('id'))
        lines.append(f'## Tweet {seq} of {n}')
        lines.append('')
        lines.append(blockquote(body) if body else '> _(no text)_')
        lines.append('')
        lines += quote_block(t.get('quoted'))
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
    # Tier 2's full record of the head tweet, when A2 fetched it (single-tweet case).
    hydrated_head = thread_data['tweets'][0] if thread_data and thread_size == 1 else None
    # Syndication truncated this tweet's text or dropped its quote — an existing body built
    # from it is lossy and worth rebuilding once Tier 2 has the full text.
    lossy_syndication = bool(pr.get('is_note_tweet') or pr.get('quoted_id'))
    if annotation is None and 'body' not in needs:
        annotation = existing_annotation(note_id)

    if 'body' in needs:
        if status == 'ok':
            if have_thread and thread_size > 1:
                write_body = build_thread_body(pr, url, thread_data, annotation=annotation)
                write_kind = 'body_thread'
            else:
                # First-pass single body: stamp thread:unchecked so a re-run thread-checks it
                # (build_single_body downgrades link-only bodies to count=1 internally).
                write_body, write_kind = build_single_body(pr, url, unchecked_marker(), annotation=annotation,
                                                           full=hydrated_head)
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
            # Remove any existing thread:* markers first (not just trailing — an image
            # attached after the marker pushes it mid-body), then append
            cleaned = re.sub(r'\n*<!--\s*thread:[^>]+-->\s*\n*', '\n', cur)
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
        elif hydrated_head and lossy_syndication and status == 'ok':
            # Settled single tweet whose body came from truncated syndication text (long-form
            # note tweet, or a quote tweet with the quote missing). Rebuild at full fidelity.
            write_body, _ = build_single_body(pr, url, thread_marker(1), annotation=annotation,
                                              full=hydrated_head)
            write_kind = 'body_full_text'
        elif status == 'ok':
            # Single tweet OR thread fetch returned 1 tweet. Stamp count=1 on existing body.
            # Strip ALL prior thread markers — a stale mid-body `thread:unchecked` survives
            # a trailing-only regex when an attachment ref was appended after it.
            cur = get_content(note_id)
            cleaned = re.sub(r'\n*<!--\s*thread:[^>]+-->\s*\n*', '\n', cur)
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
        # A re-enrich (FORCE, or a thread that grew) finds earlier photos already attached;
        # re-adding would make Bear store a renamed copy (`tweet_3 2.png`).
        la = run('bearcli', 'attachments', 'list', note_id, '--format', 'json')
        already = {e.get('filename') for e in json.loads(la.stdout)} if la.returncode == 0 else set()
        for seq, t in enumerate(thread_data['tweets'], start=1):
            shot = f'/tmp/tweet_{note_id}_{seq}.png'
            if not (os.path.exists(shot) and os.path.getsize(shot) > 1000):
                continue
            fname = f'tweet_{seq}.png'
            if fname in already:
                continue
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
