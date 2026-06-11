#!/usr/bin/env python3
"""
Interactive triage for Apple Reminders. No LLM calls in the loop.
Keys: d=do now (focus mode), c=complete, x=delete, s=skip, q=quit
Outputs a JSON summary to stdout when done.
"""
import json
import os
import re
import subprocess
import sys
import tty
import termios
import textwrap
from datetime import datetime, timezone

URL_RE = re.compile(r'https?://\S+')


def clear():
    sys.stdout.write('\033[2J\033[H')
    sys.stdout.flush()


def get_key():
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        return sys.stdin.read(1).lower()
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def show_focus(title, cols, rows):
    inner = min(cols - 8, 72)
    h, v, tl, tr, bl, br = '═', '║', '╔', '╗', '╚', '╝'

    def row(content=''):
        return v + ' ' + content.center(inner) + ' ' + v

    lines = [tl + h * (inner + 2) + tr, row(), row()]
    for chunk in textwrap.wrap(title.upper(), inner):
        lines.append(row(chunk))
    lines += [row(), row(), bl + h * (inner + 2) + br, '',
              'Press any key to continue'.center(inner + 4)]

    clear()
    pad = ' ' * max(0, (cols - inner - 4) // 2)
    print('\n' * max(0, (rows - len(lines)) // 2), end='')
    for line in lines:
        print(pad + line)

    get_key()
    clear()


def extract_urls(text):
    return URL_RE.findall(text)


def strip_urls(text):
    return URL_RE.sub('', text).strip(' -–—')


def osc8_link(url):
    """Render a clickable hyperlink using OSC 8 (supported by iTerm2, kitty, etc.)."""
    return f'\033]8;;{url}\033\\{url}\033]8;;\033\\'


def open_urls(urls):
    for url in urls:
        subprocess.run(['open', url], capture_output=True)


def fmt_date(iso):
    if not iso:
        return '—'
    try:
        dt = datetime.fromisoformat(iso.replace('Z', '+00:00'))
        return dt.strftime('%b %-d, %Y')
    except Exception:
        return iso[:10]


def fetch_rich_urls():
    """Query Reminders SQLite databases for rich-link URLs (not in remindctl JSON)."""
    import glob, sqlite3 as _sqlite3
    pattern = os.path.expanduser(
        '~/Library/Group Containers/group.com.apple.reminders'
        '/Container_v1/Stores/Data-*.sqlite'
    )
    url_map = {}  # uuid -> [url, ...]
    for db_path in glob.glob(pattern):
        try:
            con = _sqlite3.connect(f'file:{db_path}?mode=ro', uri=True, timeout=2)
            cur = con.cursor()
            cur.execute("""
                SELECT r.ZCKIDENTIFIER, o.ZURL
                FROM ZREMCDREMINDER r
                JOIN ZREMCDOBJECT o ON (
                    o.ZREMINDER = r.Z_PK OR o.ZREMINDER1 = r.Z_PK
                    OR o.ZREMINDER2 = r.Z_PK OR o.ZREMINDER3 = r.Z_PK
                )
                WHERE o.ZURL IS NOT NULL AND o.ZURL != ''
            """)
            for uuid, url in cur.fetchall():
                url_map.setdefault(uuid, [])
                if url not in url_map[uuid]:
                    url_map[uuid].append(url)
            con.close()
        except Exception:
            pass
    return url_map


def fetch_todos():
    r = subprocess.run(['remindctl', 'show', 'open', '--json'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f'remindctl error: {r.stderr}', file=sys.stderr)
        sys.exit(1)
    todos = json.loads(r.stdout)
    todos.sort(key=lambda t: t.get('creationDate', ''), reverse=True)
    return todos


def main():
    todos = fetch_todos()
    rich_urls = fetch_rich_urls()

    if not todos:
        print(json.dumps({'message': 'No open todos.', 'completed': [],
                          'deleted': [], 'do_now': [], 'skipped': []}))
        return

    try:
        cols = os.get_terminal_size().columns
        rows = os.get_terminal_size().lines
    except OSError:
        cols, rows = 80, 24

    completed, deleted, do_now, skipped = [], [], [], []
    n = len(todos)

    for i, todo in enumerate(todos, 1):
        raw_title = todo.get('title', '(no title)')
        todo_id   = todo.get('id', '')
        list_name = todo.get('listName', '')
        created   = fmt_date(todo.get('creationDate'))
        due       = fmt_date(todo.get('dueDate'))
        title_urls = extract_urls(raw_title)
        db_urls    = rich_urls.get(todo_id, [])
        # notes field may contain a plain domain or full URL
        notes_text = todo.get('notes', '') or ''
        notes_urls = extract_urls(notes_text)
        # merge, dedup, keeping title URLs first
        seen = set()
        urls = []
        for u in title_urls + notes_urls + db_urls:
            if u not in seen:
                seen.add(u)
                urls.append(u)
        title = strip_urls(raw_title) if title_urls else raw_title

        # notes text without any embedded URLs
        notes_body = URL_RE.sub('', notes_text).strip()

        clear()
        bar = '─' * min(cols - 4, 60)
        print(f'\n  [{i}/{n}]  {list_name}')
        print(f'  {bar}')
        for line in textwrap.wrap(title, cols - 4):
            print(f'  {line}')
        if notes_body:
            print(f'  {bar}')
            for line in textwrap.wrap(notes_body, cols - 4):
                print(f'  {line}')
        if urls:
            print(f'  {bar}')
            for url in urls:
                print(f'  {osc8_link(url)}')
        print(f'  {bar}')
        print(f'  Created: {created}  ·  Due: {due}')
        print()
        print('  [D] Do Now    [C] Complete    [X] Delete    [S] Skip    [Q] Quit')
        print()

        while True:
            key = get_key()
            if key == 'd':
                do_now.append(raw_title)
                if urls:
                    open_urls(urls)
                show_focus(title, cols, rows)
                break
            elif key == 'c':
                subprocess.run(['remindctl', 'complete', todo_id],
                               capture_output=True)
                completed.append(title)
                break
            elif key == 'x':
                subprocess.run(['remindctl', 'delete', '--force', todo_id],
                               capture_output=True)
                deleted.append(title)
                break
            elif key == 's':
                skipped.append(title)
                break
            elif key in ('q', '\x03', '\x1b'):
                clear()
                results = {'quit_at': i, 'completed': completed,
                           'deleted': deleted, 'do_now': do_now,
                           'skipped': skipped}
                print(json.dumps(results))
                return

    clear()
    print(json.dumps({'completed': completed, 'deleted': deleted,
                      'do_now': do_now, 'skipped': skipped}))


if __name__ == '__main__':
    main()
