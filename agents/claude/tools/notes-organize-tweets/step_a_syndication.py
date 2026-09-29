import json, os, re, subprocess
from collections import Counter

todo = json.load(open('/tmp/tweet_todo.json'))
batch = [n for n in todo if {'image','body','thread_check'} & set(n['needs'])]

results = []
for n in batch:
    m = re.search(r'/status(?:es)?/(\d+)', n['url'])
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
        # Long-form "note tweets" arrive truncated to ~280 chars here (only a note_tweet id,
        # no text), and quoted tweets likewise. Step A2 routes both through Tier 2's
        # TweetDetail fetch, which carries the full text.
        'is_note_tweet': 'note_tweet' in data,
        'quoted_id': (data.get('quoted_tweet') or {}).get('id_str'),
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
