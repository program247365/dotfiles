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
    pr = syn.get(note_id) or {}
    if pr.get('status') != 'ok':
        continue
    # Syndication truncates long-form note tweets and quoted tweets — only Tier 2 has the
    # full text, so fetch those whenever a body is being (re)built, replies or not.
    needs_full_text = pr.get('is_note_tweet') or pr.get('quoted_id')
    wants_thread = 'thread_check' in n['needs'] and (pr.get('conversation_count') or 0) > 0
    # No replies at all → definitely single tweet; Step B will write count=1.
    if not (wants_thread or (needs_full_text and {'body', 'thread_check'} & set(n['needs']))):
        continue
    candidates.append({
        'note_id': note_id,
        'head_id': pr.get('tweet_id'),
        'author': pr.get('handle'),
    })

print(f'{len(candidates)} Tier 2 candidates (replies, long-form, or quote tweets)')

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
