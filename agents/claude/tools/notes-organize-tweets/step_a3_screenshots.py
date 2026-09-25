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
    # System python3 has no playwright module — uv supplies it per-run. If Chromium isn't
    # cached yet (~/Library/Caches/ms-playwright), first run:
    #   uv run --with playwright playwright install chromium
    cp = subprocess.run(
        ['uv', 'run', '--with', 'playwright', 'python3', fetcher],
        input=json.dumps(shot_candidates),
        capture_output=True, text=True,
    )
    print(cp.stdout)
    if cp.returncode != 0:
        print('STDERR:', cp.stderr, file=sys.stderr)
        # Soft-fail: Step B will hit `no_photo_available` for whichever shots didn't land.
