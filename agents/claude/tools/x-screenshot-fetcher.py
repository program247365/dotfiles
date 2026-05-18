#!/usr/bin/env python3
"""x-screenshot-fetcher — render tweet cards via the X embed widget and save PNGs.

Tier 3 of the tweet-enrichment pipeline. Use when a tweet has no embedded media
(syndication API returned `photos=[]`) and we still want a visual capture of the
tweet card for the Bear note attachment.

Input: JSON array on stdin
  [{"note_id": "...", "tweet_id": "..."}, ...]

Output: one PNG per item at /tmp/tweet_<note_id>.png

Uses https://platform.twitter.com/embed/Tweet.html?id=<tweet_id> — the same widget
third-party sites embed. No auth, no login wall.
"""

import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

EMBED_URL = "https://platform.twitter.com/embed/Tweet.html?id={tid}&theme=light&hideCard=false&hideThread=true&lang=en"
SELECTOR = "article"
VIEWPORT = {"width": 600, "height": 900}
NAV_TIMEOUT_MS = 15000
RENDER_TIMEOUT_MS = 8000


def screenshot_one(page, item):
    tid = item["tweet_id"]
    note_id = item["note_id"]
    out = Path(f"/tmp/tweet_{note_id}.png")

    try:
        page.goto(EMBED_URL.format(tid=tid), timeout=NAV_TIMEOUT_MS, wait_until="domcontentloaded")
        # The widget renders inside an <iframe> that loads `article`. Wait for it.
        page.wait_for_selector(SELECTOR, timeout=RENDER_TIMEOUT_MS)
        # Brief settle for fonts / images.
        page.wait_for_timeout(400)
        el = page.query_selector(SELECTOR)
        if not el:
            return {"note_id": note_id, "status": "no_article"}
        el.screenshot(path=str(out), omit_background=False)
        size = out.stat().st_size
        if size < 1000:
            return {"note_id": note_id, "status": "too_small", "bytes": size}
        return {"note_id": note_id, "status": "ok", "bytes": size, "path": str(out)}
    except PWTimeout as e:
        return {"note_id": note_id, "status": "timeout", "error": str(e)}
    except Exception as e:
        return {"note_id": note_id, "status": "error", "error": str(e)}


def main():
    items = json.load(sys.stdin)
    if not items:
        print("no items", file=sys.stderr)
        return 0

    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport=VIEWPORT, device_scale_factor=2)
        page = context.new_page()
        for item in items:
            r = screenshot_one(page, item)
            results.append(r)
            status = r["status"]
            tid = item["tweet_id"]
            nid = item["note_id"][:8]
            if status == "ok":
                print(f"ok {nid} tid={tid} bytes={r['bytes']}")
            else:
                detail = r.get("error") or r.get("bytes") or ""
                print(f"{status} {nid} tid={tid} {detail}")
        context.close()
        browser.close()

    ok = sum(1 for r in results if r["status"] == "ok")
    print(f"SUMMARY ok={ok} total={len(results)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
