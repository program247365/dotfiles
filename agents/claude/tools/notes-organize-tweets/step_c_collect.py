import json, re, subprocess

todo = json.load(open('/tmp/tweet_todo.json'))
syn = {r['id']: r for r in json.load(open('/tmp/tweet_syndication.json'))}

def text_from_note(note_id):
    """Fallback when Step A didn't fetch this note this run: pull author + tweet text
    from the enriched body (`# Author: …` heading, `> ` blockquote, `**@handle**` footer)."""
    body = subprocess.run(['bearcli', 'cat', note_id], capture_output=True, text=True).stdout
    author = ''
    m = re.search(r'(?m)^#\s+([^:\n]+):', body)
    if m: author = m.group(1).strip()
    handle = ''
    m = re.search(r'\*\*@(\w+)\*\*', body)
    if m: handle = m.group(1)
    quote = '\n'.join(ln[2:] for ln in body.split('\n') if ln.startswith('> '))
    return author, handle, quote.strip()

candidates = []
for n in todo:
    if 'extra_tags' not in n['needs']:
        continue
    tags_raw = subprocess.check_output(['bearcli', 'tags', 'list', n['id'], '--format', 'json'])
    tags = [t.lstrip('#') for t in [e.get('tag', '') for e in json.loads(tags_raw)] if t]
    if any(not t.startswith('inbox') for t in tags):
        continue
    pr = syn.get(n['id'], {})
    if pr.get('status') == 'ok':
        author, handle, text = pr.get('author'), pr.get('handle'), pr.get('tweetText') or ''
    else:
        author, handle, text = text_from_note(n['id'])
    if not text:
        continue  # tombstone/link-only — nothing to classify
    candidates.append({'id': n['id'], 'tags': tags, 'author': author, 'handle': handle, 'text': text})

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
