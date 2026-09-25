import json, subprocess

# Assignments come from /tmp/tweet_tag_assignments.json, written by the agent after
# classifying the candidates printed by step_c_collect.py:
#   { "NOTE-UUID": ["learn/foo", "projects/bar"], ... }
TAG_ASSIGNMENTS = json.load(open('/tmp/tweet_tag_assignments.json'))

for note_id, tags in TAG_ASSIGNMENTS.items():
    r = subprocess.run(['bearcli', 'tags', 'add', note_id, *tags],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f'tags FAILED id={note_id}: {r.stderr.strip()}')
    else:
        print(f'tagged id={note_id[:8]}: {tags}')
print(f'Done: {len(TAG_ASSIGNMENTS)} notes tagged')
