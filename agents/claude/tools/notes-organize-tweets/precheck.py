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
for n in _search('twitter.com'):  # legacy-domain saves
    by_id.setdefault(n['id'], n)
for n in _search('@untagged'):  # Bear FTS misses bare-URL notes — pick them up here
    by_id.setdefault(n['id'], n)
notes = list(by_id.values())

today = date.today()
auth_needed_ttl = timedelta(days=7)

# Title-prefix matches both `https://x.com/...` and `[https://x.com/...](...)` shapes.
TWEET_URL_RE = re.compile(r'https?://(?:www\.|mobile\.)?(?:x\.com|twitter\.com)/[^\s\])]+/status(?:es)?/\d+(?:\?[^\s\])]*)?', re.IGNORECASE)
TITLE_TWEET_RE = re.compile(r'^\[?https?://(?:www\.|mobile\.)?(?:x\.com|twitter\.com)/\S+/status(?:es)?/\d+', re.IGNORECASE)

# Share-sheet boilerplate: '4.7K likes and 8 replies', 'Name (@handle) on X',
# 'Name (@handle) 107 likes · 5 replies'. Not user words — never an annotation,
# and a heading made of this doesn't count as user-authored structure.
BOILER_LINE_RE = re.compile(
    r'^\s*(?:[\d.,]+[KMB]?\s+likes(?:\s+(?:and|·)\s+[\d.,]+[KMB]?\s+replies)?'
    r'|.*\\?\(@[A-Za-z0-9_]{1,15}\\?\)(?:\s+on\s+X)?(?:\s+[\d.,]+[KMB]?\s+likes.*)?)\s*$',
    re.IGNORECASE)

def residual_text(text):
    """The note minus everything that IS the link: tweet URLs, markdown link/image
    syntax, HTML comments, inline tags, share-sheet boilerplate. What survives is
    the user's own words — the basis for bare-link recognition and the annotation."""
    t = re.sub(r'<!--.*?-->', ' ', text, flags=re.DOTALL)
    t = re.sub(r'!\[[^\]]*\]\([^)]*\)', ' ', t)        # image embeds
    t = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', t)     # unwrap md links, keep link text
    t = TWEET_URL_RE.sub(' ', t)
    t = re.sub(r'(?<!\S)#[\w][\w/-]*', ' ', t)         # inline tags (not '# ' headings)
    t = re.sub(r'(?m)^#{1,6}\s+', '', t)               # heading markers, keep heading text
    t = re.sub(r'(?m)^\s*[*>-]\s*', '', t)             # bullet/quote markers
    lines = [ln.strip() for ln in t.split('\n')]
    lines = [ln for ln in lines if ln and not BOILER_LINE_RE.match(ln)]
    return '\n'.join(lines).strip()

todo = []
manual_review = []  # untagged notes with a tweet URL that look like real project notes
seen_tweets = {}  # status_id -> [(note_id, has_thread_complete)] for conflict-pair detection
for n in notes:
    text = (n.get('content') or '').strip()
    title = (n.get('title') or '').strip()

    raw_tags = [t.lstrip('#') for t in (n.get('tags') or [])]
    has_inbox_tag = 'inbox/saved-tweets' in raw_tags
    topical_tags = [t for t in raw_tags if not t.startswith('inbox')]

    url_match = TWEET_URL_RE.search(text)
    if not url_match:
        continue
    url = url_match.group(0).rstrip('.,)>]"\'')

    has_image = bool(n.get('attachments'))
    is_tombstone = '_Original tweet was deleted or restricted._' in text
    is_link_only = '_Tweet contains only a link — no text content._' in text
    has_body = (
        bool(re.search(r'^#\s+\S', text, re.MULTILINE))
        and ('> ' in text or is_tombstone or is_link_only)
    )
    # Signal 3: enriched by a pipeline whose inline tag Bear never promoted.
    looks_enriched = (
        bool(re.search(r'\*\*@\w+\*\*\s*·\s*\[View (?:thread )?on X\]', text))
        or '<!-- thread:' in text
        or bool(re.search(r'(?m)^#inbox/saved-tweets\s*$', text))
    )

    # Recognize as tweet-save via signals 1-4 (see prose above).
    title_is_tweet = bool(TITLE_TWEET_RE.match(title))
    resid = residual_text(text)
    if not (title_is_tweet or has_inbox_tag or looks_enriched):
        # Signal 4: bare-link shape — little user text besides the link itself.
        user_headings = [h for h in re.findall(r'(?m)^#{1,6}\s+(.+)$', text)
                         if not BOILER_LINE_RE.match(h.strip())]
        resid_lines = [ln for ln in resid.split('\n') if ln.strip()]
        body_lines = resid_lines[1:] if user_headings else resid_lines
        if len(resid) > 300 or (user_headings and len(body_lines) >= 2):
            # Substantial user content → a project note that references a tweet.
            # Never rewrite these; surface fully-untagged ones for a human decision.
            if not raw_tags:
                manual_review.append({'id': n['id'], 'title': title[:70], 'url': url})
            continue

    # User annotation: for still-unstructured bodies, the residual IS the annotation
    # (annotation-first saves, URL-then-note saves, user-titled saves alike). Rendered
    # into a `**My note**` block by Step B so nothing the user typed is lost.
    annotation = None
    if not has_body and resid:
        annotation = resid[:500]

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

    status_id = re.search(r'/status(?:es)?/(\d+)', url).group(1)
    seen_tweets.setdefault(status_id, []).append((n['id'], thread_complete_count is not None))

    needs = []
    if not has_inbox_tag: needs.append('inbox_tag')
    if not has_body:      needs.append('body')
    # Independent of has_body: a failed Tier 3 screenshot must be retried on a later
    # run even though Step B already wrote the body. Tombstones have nothing to shoot.
    if not has_image and not is_tombstone: needs.append('image')
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

# Duplicate guard: two notes for the same tweet are either an iCloud sync-conflict pair
# (created seconds apart; see bear-notes skill → iCloud Sync Conflicts) or a double-save
# (same tweet saved twice, days apart — check created dates to tell them apart). Either
# way, enriching both entrenches the duplicate, so exclude them from this run and surface
# them for resolution: merge tags into the richer/intact copy, trash the other, and — for
# conflict pairs only — recreate the survivor under a fresh ID if it carries the fork icon.
dup_ids = set()
for tid, entries in seen_tweets.items():
    if len(entries) > 1:
        dup_ids.update(nid for nid, _ in entries)
        detail = ', '.join(f'{nid[:8]}{" (thread:complete)" if c else ""}' for nid, c in entries)
        print(f'DUPLICATE tweet={tid}: {detail}')
if dup_ids:
    todo = [t for t in todo if t['id'] not in dup_ids]
    print(f'Excluded {len(dup_ids)} notes in duplicate pairs from this run — resolve them first, then re-run.\n')

with open('/tmp/tweet_todo.json', 'w') as f: json.dump(todo, f)

from collections import Counter
counts = Counter(need for n in todo for need in n['needs'])
print(f'{len(todo)} notes need work:')
for k, v in sorted(counts.items()): print(f'  {k}: {v}')
print()
for n in todo:
    print(f'  id={n["id"]} needs={n["needs"]} {n["url"][:65]}')

if manual_review:
    print(f'\n{len(manual_review)} untagged notes reference a tweet but look like real project notes')
    print('— left untouched; review by hand (open in Bear, tag or enrich manually):')
    for m in manual_review:
        print(f'  id={m["id"]} "{m["title"]}" {m["url"][:60]}')
