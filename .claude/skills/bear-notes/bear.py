#!/usr/bin/env python3
"""
Bear Notes CLI tool for Claude Code
Provides search, read, and create functionality for Bear notes
Based on the Bear x-callback-url API
"""

import argparse
import json
import os
import sqlite3
import subprocess
import sys
import urllib.parse
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional


class BearDB:
    """Interface to Bear's SQLite database for reading notes"""

    # Bear uses a reference date of 2001-01-01
    BEAR_EPOCH = datetime(2001, 1, 1).timestamp()

    def __init__(self):
        self.db_path = self._find_bear_db()
        self.conn = None
        self.version = None

    def _find_bear_db(self) -> Path:
        """Locate Bear's database file"""
        possible_paths = [
            Path.home() / "Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite",
            Path.home() / "Library/Containers/net.shinyfrog.bear/Data/Library/Application Support/net.shinyfrog.bear/database.sqlite",
        ]

        for path in possible_paths:
            if path.exists():
                return path

        raise FileNotFoundError("Bear database not found. Is Bear installed?")

    def connect(self):
        """Connect to the Bear database"""
        if self.conn is None:
            self.conn = sqlite3.connect(str(self.db_path))
            self.conn.row_factory = sqlite3.Row
            self._detect_version()

    def _detect_version(self):
        """Detect Bear version based on table structure"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='Z_5TAGS'")
        self.version = 2 if cursor.fetchone() else 1

    def _bear_timestamp_to_datetime(self, timestamp: float) -> datetime:
        """Convert Bear's timestamp (seconds since 2001-01-01) to datetime"""
        return datetime.fromtimestamp(self.BEAR_EPOCH + timestamp)

    def _format_tags(self, tags: List[str]) -> str:
        """Format tags in Bear's hashtag format"""
        if not tags:
            return ""
        formatted = []
        for tag in tags:
            # Multi-word tags use double hashtags
            if ' ' in tag or '/' in tag:
                formatted.append(f"#{tag.replace(' ', '/')}#")
            else:
                formatted.append(f"#{tag}")
        return " ".join(formatted)

    def search_notes(self, query: str = "", tag: Optional[str] = None, limit: int = 20) -> List[Dict]:
        """Search notes by text and/or tag"""
        self.connect()

        if self.version == 2:
            sql = """
                SELECT DISTINCT
                    n.Z_PK as id,
                    n.ZTITLE as title,
                    n.ZTEXT as text,
                    n.ZCREATIONDATE as created,
                    n.ZMODIFICATIONDATE as modified,
                    n.ZPINNED as pinned,
                    n.ZARCHIVED as archived,
                    n.ZTRASHED as trashed
                FROM ZSFNOTE n
                LEFT JOIN Z_5TAGS nt ON n.Z_PK = nt.Z_5NOTES
                LEFT JOIN ZSFNOTETAG t ON nt.Z_13TAGS = t.Z_PK
                WHERE (n.ZTRASHED = 0 OR n.ZTRASHED IS NULL)
                    AND (n.ZARCHIVED = 0 OR n.ZARCHIVED IS NULL)
            """
        else:
            sql = """
                SELECT DISTINCT
                    n.Z_PK as id,
                    n.ZTITLE as title,
                    n.ZTEXT as text,
                    n.ZCREATIONDATE as created,
                    n.ZMODIFICATIONDATE as modified,
                    n.ZARCHIVED as archived,
                    n.ZTRASHED as trashed
                FROM ZSFNOTE n
                LEFT JOIN Z_7TAGS nt ON n.Z_PK = nt.Z_7NOTES
                LEFT JOIN ZSFNOTETAG t ON nt.Z_14TAGS = t.Z_PK
                WHERE (n.ZTRASHED = 0 OR n.ZTRASHED IS NULL)
                    AND (n.ZARCHIVED = 0 OR n.ZARCHIVED IS NULL)
            """

        params = []
        if query:
            sql += " AND (n.ZTITLE LIKE ? OR n.ZTEXT LIKE ? OR n.Z_PK = ?)"
            params.extend([f"%{query}%", f"%{query}%", query])

        if tag:
            sql += " AND t.ZTITLE = ?"
            params.append(tag)

        sql += " ORDER BY n.ZPINNED DESC, n.ZMODIFICATIONDATE DESC LIMIT ?"
        params.append(limit)

        cursor = self.conn.cursor()
        cursor.execute(sql, params)

        notes = []
        for row in cursor.fetchall():
            # Convert Row to dict to handle missing columns
            row_dict = dict(row)
            note = {
                'id': row_dict['id'],
                'title': row_dict['title'] or 'Untitled',
                'text': row_dict['text'] or '',
                'created': self._bear_timestamp_to_datetime(row_dict['created']).isoformat() if row_dict['created'] else None,
                'modified': self._bear_timestamp_to_datetime(row_dict['modified']).isoformat() if row_dict['modified'] else None,
                'pinned': bool(row_dict.get('pinned', 0)),
                'tags': self._get_note_tags(row_dict['id'])
            }
            notes.append(note)

        return notes

    def _get_note_tags(self, note_id: int) -> List[str]:
        """Get tags for a specific note"""
        if self.version == 2:
            sql = """
                SELECT t.ZTITLE
                FROM ZSFNOTETAG t
                JOIN Z_5TAGS nt ON t.Z_PK = nt.Z_13TAGS
                WHERE nt.Z_5NOTES = ?
            """
        else:
            sql = """
                SELECT t.ZTITLE
                FROM ZSFNOTETAG t
                JOIN Z_7TAGS nt ON t.Z_PK = nt.Z_14TAGS
                WHERE nt.Z_7NOTES = ?
            """

        cursor = self.conn.cursor()
        cursor.execute(sql, [note_id])
        return [row[0] for row in cursor.fetchall()]

    def get_all_tags(self) -> List[str]:
        """Get all tags from Bear"""
        self.connect()
        cursor = self.conn.cursor()
        cursor.execute("SELECT ZTITLE FROM ZSFNOTETAG ORDER BY ZTITLE")
        return [row[0] for row in cursor.fetchall()]

    def get_note_by_id(self, note_id: str) -> Optional[Dict]:
        """Get a specific note by ID"""
        results = self.search_notes(query=note_id, limit=1)
        if results and str(results[0]['id']) == str(note_id):
            return results[0]
        return None

    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            self.conn = None


class BearAPI:
    """Interface to Bear via x-callback-url scheme"""

    @staticmethod
    def _execute_url(url: str, return_result: bool = False) -> Optional[str]:
        """Execute a Bear URL scheme command"""
        try:
            if return_result:
                # For commands that return data, we'd need a callback server
                # For now, just open the URL
                subprocess.run(['open', url], check=True)
                return None
            else:
                subprocess.run(['open', url], check=True)
                return None
        except subprocess.CalledProcessError as e:
            print(f"Error executing Bear command: {e}", file=sys.stderr)
            return None

    @staticmethod
    def create_note(title: str = "", text: str = "", tags: List[str] = None,
                   pin: bool = False, timestamp: bool = False,
                   open_note: bool = False) -> None:
        """Create a new note in Bear"""
        params = {}

        if title:
            params['title'] = title
        if text:
            params['text'] = text
        if tags:
            params['tags'] = ','.join(tags)
        if pin:
            params['pin'] = 'yes'
        if timestamp:
            params['timestamp'] = 'yes'

        params['open_note'] = 'yes' if open_note else 'no'
        params['show_window'] = 'yes' if open_note else 'no'

        query_string = urllib.parse.urlencode(params)
        url = f"bear://x-callback-url/create?{query_string}"

        BearAPI._execute_url(url)
        print(f"Created note: {title or 'Untitled'}")

    @staticmethod
    def open_note(note_id: str = None, title: str = None, edit: bool = False) -> None:
        """Open a note in Bear"""
        params = {}

        if note_id:
            params['id'] = note_id
        elif title:
            params['title'] = title
        else:
            raise ValueError("Either note_id or title must be provided")

        if edit:
            params['edit'] = 'yes'

        query_string = urllib.parse.urlencode(params)
        url = f"bear://x-callback-url/open-note?{query_string}"

        BearAPI._execute_url(url)

    @staticmethod
    def add_text(note_id: str = None, title: str = None, text: str = "",
                mode: str = "append", timestamp: bool = False) -> None:
        """Add text to an existing note"""
        params = {}

        if note_id:
            params['id'] = note_id
        elif title:
            params['title'] = title
        else:
            raise ValueError("Either note_id or title must be provided")

        params['text'] = text
        params['mode'] = mode  # append, prepend, replace

        if timestamp:
            params['timestamp'] = 'yes'

        query_string = urllib.parse.urlencode(params)
        url = f"bear://x-callback-url/add-text?{query_string}"

        BearAPI._execute_url(url)
        print(f"Added text to note")

    @staticmethod
    def search(term: str = "", tag: str = None, show_window: bool = False) -> None:
        """Open Bear's search UI"""
        params = {}

        if term:
            params['term'] = term
        if tag:
            params['tag'] = tag

        params['show_window'] = 'yes' if show_window else 'no'

        query_string = urllib.parse.urlencode(params)
        url = f"bear://x-callback-url/search?{query_string}"

        BearAPI._execute_url(url)


def main():
    parser = argparse.ArgumentParser(description='Bear Notes CLI for Claude Code')
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # Search command
    search_parser = subparsers.add_parser('search', help='Search notes')
    search_parser.add_argument('query', nargs='?', default='', help='Search query')
    search_parser.add_argument('--tag', help='Filter by tag')
    search_parser.add_argument('--limit', type=int, default=20, help='Maximum number of results')
    search_parser.add_argument('--format', choices=['json', 'text', 'markdown'], default='json',
                              help='Output format')

    # Read command
    read_parser = subparsers.add_parser('read', help='Read a specific note')
    read_parser.add_argument('note_id', help='Note ID to read')
    read_parser.add_argument('--format', choices=['json', 'text', 'markdown'], default='text',
                            help='Output format')

    # Create command
    create_parser = subparsers.add_parser('create', help='Create a new note')
    create_parser.add_argument('--title', default='', help='Note title')
    create_parser.add_argument('--text', default='', help='Note text')
    create_parser.add_argument('--tags', help='Comma-separated tags')
    create_parser.add_argument('--pin', action='store_true', help='Pin the note')
    create_parser.add_argument('--timestamp', action='store_true', help='Add timestamp')
    create_parser.add_argument('--open', action='store_true', help='Open note after creation')

    # Add text command
    add_parser = subparsers.add_parser('add', help='Add text to existing note')
    add_parser.add_argument('--id', help='Note ID')
    add_parser.add_argument('--title', help='Note title')
    add_parser.add_argument('text', help='Text to add')
    add_parser.add_argument('--mode', choices=['append', 'prepend', 'replace'],
                           default='append', help='How to add text')
    add_parser.add_argument('--timestamp', action='store_true', help='Add timestamp')

    # Tags command
    tags_parser = subparsers.add_parser('tags', help='List all tags')

    # Open command
    open_parser = subparsers.add_parser('open', help='Open a note in Bear')
    open_parser.add_argument('--id', help='Note ID')
    open_parser.add_argument('--title', help='Note title')
    open_parser.add_argument('--edit', action='store_true', help='Open in edit mode')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    try:
        db = BearDB()

        if args.command == 'search':
            notes = db.search_notes(args.query, args.tag, args.limit)

            if args.format == 'json':
                print(json.dumps(notes, indent=2))
            elif args.format == 'markdown':
                for note in notes:
                    tags_str = ' '.join(f"#{tag}" for tag in note['tags'])
                    print(f"## {note['title']}")
                    print(f"**ID:** {note['id']} | **Modified:** {note['modified']}")
                    if tags_str:
                        print(f"**Tags:** {tags_str}")
                    print(f"\n{note['text'][:200]}..." if len(note['text']) > 200 else note['text'])
                    print("\n---\n")
            else:  # text
                for note in notes:
                    tags_str = ' '.join(f"#{tag}" for tag in note['tags'])
                    print(f"[{note['id']}] {note['title']}")
                    if tags_str:
                        print(f"  Tags: {tags_str}")
                    print(f"  Modified: {note['modified']}")
                    print()

        elif args.command == 'read':
            note = db.get_note_by_id(args.note_id)
            if not note:
                print(f"Note {args.note_id} not found", file=sys.stderr)
                sys.exit(1)

            if args.format == 'json':
                print(json.dumps(note, indent=2))
            elif args.format == 'markdown':
                tags_str = ' '.join(f"#{tag}" for tag in note['tags'])
                print(f"# {note['title']}\n")
                if tags_str:
                    print(f"{tags_str}\n")
                print(f"**ID:** {note['id']}")
                print(f"**Created:** {note['created']}")
                print(f"**Modified:** {note['modified']}\n")
                print("---\n")
                print(note['text'])
            else:  # text
                print(note['text'])

        elif args.command == 'tags':
            tags = db.get_all_tags()
            for tag in tags:
                print(f"#{tag}")

        elif args.command == 'create':
            tags = args.tags.split(',') if args.tags else []
            BearAPI.create_note(
                title=args.title,
                text=args.text,
                tags=tags,
                pin=args.pin,
                timestamp=args.timestamp,
                open_note=args.open
            )

        elif args.command == 'add':
            if not args.id and not args.title:
                print("Either --id or --title must be provided", file=sys.stderr)
                sys.exit(1)

            BearAPI.add_text(
                note_id=args.id,
                title=args.title,
                text=args.text,
                mode=args.mode,
                timestamp=args.timestamp
            )

        elif args.command == 'open':
            if not args.id and not args.title:
                print("Either --id or --title must be provided", file=sys.stderr)
                sys.exit(1)

            BearAPI.open_note(
                note_id=args.id,
                title=args.title,
                edit=args.edit
            )

        db.close()

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
