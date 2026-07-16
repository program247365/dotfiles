---
name: feature-video
description: Record a demo video of a web app feature using Playwright with video recording. Use when the user asks to record a demo, create a feature video, capture a walkthrough, show off a feature, or make a PR video. Also use when the user says "record this", "demo video", "show this working", or wants visual proof of a feature for a PR or Slack.
---

# Feature Video Recording

Record browser-based demo videos of web app features using Playwright's built-in
video recording and ffmpeg for conversion. No LLM API key needed — the flow is
scripted, not AI-driven.

## Prerequisites

- Python 3.12+ (via `uv run --python 3.12`)
- Playwright (`pip install playwright && python -m playwright install chromium`)
- ffmpeg (for webm → mp4 conversion)

Install if missing:
```bash
pip install playwright && python -m playwright install chromium
```

## How It Works

1. Write a Python script using Playwright's `async_api` with `record_video_dir`
2. Script navigates the app and performs actions (click, type, wait)
3. Playwright records the browser as a `.webm` file
4. ffmpeg converts to `.mp4`

## Script Template

Write the script to `/tmp/demo-recording/record.py`:

```python
# /// script
# requires-python = ">=3.11,<3.14"
# dependencies = ["playwright"]
# ///
import asyncio
import subprocess
from pathlib import Path
from playwright.async_api import async_playwright

async def main():
    output_dir = Path("/tmp/demo-recording/output")
    output_dir.mkdir(parents=True, exist_ok=True)
    for f in output_dir.iterdir():
        f.unlink()

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=False,
            args=["--window-size=1400,900"],
        )
        context = await browser.new_context(
            viewport={"width": 1400, "height": 900},
            record_video_dir=str(output_dir),
            record_video_size={"width": 1400, "height": 900},
        )
        page = await context.new_page()

        # --- YOUR STEPS HERE ---
        # await page.goto("http://localhost:3001", wait_until="networkidle")
        # await asyncio.sleep(3)
        # await page.click('text=Button')
        # await page.locator("textarea").first.type("hello", delay=60)
        # await page.keyboard.press("Enter")
        # await asyncio.sleep(10)
        # --- END STEPS ---

        video_path = await page.video.path()
        await context.close()
        await browser.close()

    # Convert to mp4
    video_file = Path(video_path)
    mp4_path = output_dir / "demo.mp4"
    subprocess.run(["ffmpeg", "-y", "-i", str(video_file), str(mp4_path)], capture_output=True)
    if mp4_path.exists():
        print(f"Video: {mp4_path} ({mp4_path.stat().st_size / 1024 / 1024:.1f} MB)")

if __name__ == "__main__":
    asyncio.run(main())
```

Run with: `uv run --python 3.12 /tmp/demo-recording/record.py`

## Key Patterns

### Authentication
For apps that need login, navigate to the auto-login URL first:
```python
await page.goto("http://localhost:3000/dev/auto_login", wait_until="load")
await asyncio.sleep(2)
```

### OAuth Popups
If the demo involves OAuth (popup windows), use `launch_persistent_context`
instead of `launch` + `new_context` so cookies persist across the main page
and popup:
```python
context = await p.chromium.launch_persistent_context(
    user_data_dir="/tmp/demo-recording/chrome-profile",
    headless=False,
    viewport={"width": 1400, "height": 900},
    record_video_dir=str(output_dir),
    record_video_size={"width": 1400, "height": 900},
)
page = context.pages[0] if context.pages else await context.new_page()
```
The user may need to manually log into the OAuth provider in the browser
window before the scripted flow begins. Add a wait step:
```python
print("Log into [service] in the browser. You have 60 seconds...")
await asyncio.sleep(60)
```

### Clicking Elements
```python
await page.click('text=New task')           # by text
await page.click('button:has-text("Send")') # button with text
await page.locator("textarea").first.click() # first textarea
```

### Typing Slowly (for demo effect)
```python
await page.keyboard.type("hello world", delay=60)  # 60ms per char
```

### Waiting for Dynamic Content
```python
# Wait for an element to appear
btn = page.locator('button:has-text("Connect")').first
await btn.wait_for(state="visible", timeout=30000)

# Scroll into view before clicking
await btn.scroll_into_view_if_needed()
await btn.click(force=True)
```

### Fixed Waits (for recording pacing)
```python
await asyncio.sleep(5)  # pause so viewer can see the state
```

## Common Issues

- **`text=X` not found**: The text might be translated (i18n). Navigate directly
  to the URL instead of clicking nav links, or use a more specific selector.
- **OAuth popup fails**: Playwright's fresh browser has no cookies. Use
  `launch_persistent_context` and pre-login to the OAuth provider.
- **Click timeout**: Element may be off-screen. Use `scroll_into_view_if_needed()`
  and `click(force=True)`.
- **Python 3.14 errors**: Playwright and langchain have compatibility issues with
  3.14. Always use `--python 3.12`.
- **video_path is a string**: Use `Path(video_path)` if you need `.stat()`.

## Output

The video saves as `/tmp/demo-recording/output/demo.mp4`. To share:
- Drag into Slack
- Upload to a PR description via GitHub
- `open /tmp/demo-recording/output/` to view in Finder
