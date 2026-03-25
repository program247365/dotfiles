---
name: visual-explainer
description: |
  Create self-contained visual HTML explainers for any topic, concept, or codebase
  pattern. Saves to Bear as a new note with the HTML attached. Use when a markdown
  explanation isn't enough and the user needs a visual to reduce cognitive load.
---

# Visual Explainer

Generate a self-contained HTML page that visually explains a topic, then save it as a Bear note with the HTML attached.

## When to Use

Invoke explicitly with `/visual-explainer`. This skill does NOT auto-trigger.

Good candidates:

- Architecture overviews, data flows, system diagrams
- Concept explainers (how X works, mental models)
- Code diffs and PR summaries with visual context
- Decision trees, state machines, pipelines
- Anything where a wall of markdown creates more cognitive debt than it resolves

## Workflow

### Step 1: Think (before writing any HTML)

Pause and decide:

1. **Who is the audience?** (me reviewing later, a teammate, a stakeholder)
2. **What is the ONE thing this visual must make obvious?** If you can't name it, you don't understand the topic yet.
3. **What rendering approach fits?**
   - Topology / flowchart / pipeline → **Mermaid.js** with ELK layout
   - Text-heavy architecture / concept → **CSS Grid cards** with SVG flow arrows
   - Data comparison / metrics → **HTML `<table>`** with KPI summary cards
   - Process / decision tree → **Mermaid.js** flowchart or CSS-based tree
   - Mixed content → Combine approaches in sections
4. **Pick a color palette.** Do NOT reuse the last one. See the palette rules below.

### Step 2: Build the HTML

Write a **single self-contained HTML file**. All CSS inline via `<style>` tags. No external stylesheets. No build steps.

**External dependencies allowed (CDN only):**

- `mermaid` (via `https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js`) — for diagrams
- `chart.js` (via `https://cdn.jsdelivr.net/npm/chart.js`) — for charts/graphs, only when needed

**Everything else must be inline.** Images as base64 data URIs if needed. The file must work offline and render correctly months from now.

Save to: `/tmp/visual-explainer-<slug>.html` (where `<slug>` is a short kebab-case descriptor).

### Step 3: Save to Bear

Always create a new Bear note for each visual explainer.

1. **Create the note** with `bcli create`:
   - Title: descriptive name of what's being explained
   - Body: brief markdown summary (5-15 lines) of what the visual covers and why it exists
   - Tags: at minimum `#visual-explainer`. Add context tags based on the topic (e.g. `#learn/agents` if it's about work).
   - Capture the note ID from `bcli create ... --quiet`

2. **Attach the HTML file** via Bear URL scheme:

```bash
NOTE_ID="<captured-id>"
FILENAME="<slug>.html"
FILE_B64=$(base64 -i "/tmp/visual-explainer-<slug>.html")
python3 -c "
import urllib.parse, subprocess
url = ('bear://x-callback-url/add-file'
    + '?id=' + urllib.parse.quote('$NOTE_ID')
    + '&filename=' + urllib.parse.quote('$FILENAME')
    + '&file=' + urllib.parse.quote('''$FILE_B64'''))
subprocess.run(['open', url])
"
```

3. **Open the HTML in browser** so the user can see it immediately:

```bash
open "/tmp/visual-explainer-<slug>.html"
```

4. **Tell the user** what was created: note title, tags, and that it's been attached and opened.

## Design System

### Typography

Pick a font pairing that fits the content. Load from Google Fonts CDN.

**Good pairings:**

- IBM Plex Sans + IBM Plex Mono (technical, neutral)
- Source Serif 4 + Source Code Pro (editorial, readable)
- DM Sans + JetBrains Mono (modern, clean)
- Space Grotesk + Space Mono (geometric, distinctive)
- Literata + Fira Code (warm, bookish)

**Banned:** Inter, Roboto, Open Sans as primary. These are the "I didn't think about typography" defaults.

### Color Palettes

Every explainer must have a distinct palette. Do not repeat the same palette twice in a row. Use CSS custom properties for all colors.

**Palette construction rules:**

- Define `--bg`, `--surface`, `--surface2`, `--border`, `--text`, `--text-muted`, `--accent` at minimum
- Support both light and dark mode via `@media (prefers-color-scheme: dark/light)` OR commit to one (dark is fine for technical content)
- Accent color must have a `-dim` variant at ~12% opacity for backgrounds
- Status colors (green/amber/red/blue) must be defined for any content with state

**Example palettes (use as starting points, vary them):**

```
Warm Slate:    bg:#1c1917  surface:#292524  accent:#f59e0b  text:#e7e5e4
Ocean Deep:    bg:#0c1222  surface:#162032  accent:#38bdf8  text:#e2e8f0
Forest:        bg:#0f1a0f  surface:#1a2e1a  accent:#4ade80  text:#e2e8e0
Terracotta:    bg:#1a1412  surface:#2a211c  accent:#e87040  text:#e8e0d8
Plum:          bg:#1a0f1e  surface:#2a1c32  accent:#c084fc  text:#e8e0f0
```

### Forbidden Patterns (AI Slop)

Do NOT produce any of these. They signal "an AI made this with zero taste":

- Tailwind indigo/violet as the accent on a dark background
- Gradient text on headings
- Uniform card grids with no visual hierarchy (every card same size, same weight)
- Animated glowing box-shadows or pulsing elements
- `border-radius: 9999px` on everything
- Gratuitous blur/glassmorphism backgrounds
- Rainbow or neon color schemes unless the topic is literally about color

### Layout Rules

- **Max width:** 960px centered. Content-first, not decoration-first.
- **Sections:** Clear visual separation. Use border-top or background shifts, not just spacing.
- **Cards:** Vary sizes by importance. The most important thing should be visually largest.
- **Flow arrows:** Use inline `<svg>` for connecting elements. Mermaid for complex flows.
- **Tables:** Use real `<table>` elements with proper `<thead>`/`<tbody>`. Sticky headers for scrollable tables. Alternating row backgrounds.

### CSS Gotchas (avoid these bugs)

- **Never use `.node` as a class name** — Mermaid uses `.node` internally for SVG positioning. Use `.ve-card` or similar namespaced classes.
- **Use CSS `zoom` instead of `transform: scale()`** for Mermaid containers — zoom changes layout size, transform only changes appearance and causes clipping.
- **Add `min-width: 0` on flex/grid children** — prevents them from overflowing their container.
- **Never `display: flex` on `<li>` for markers** — creates anonymous flex items that overflow.

### Responsive

- Collapse grid to single column below 640px
- Hide decorative SVG arrows on mobile
- Use `clamp()` for font sizes: `font-size: clamp(14px, 2.5vw, 18px)`
- Test that the page is readable at 375px width

### Accessibility

- All text must meet WCAG AA contrast (4.5:1 for body text, 3:1 for large text)
- Respect `@media (prefers-reduced-motion: reduce)` — disable all animations
- Mermaid diagrams should include a text summary or alt description nearby
- Interactive elements need visible focus states

### Mermaid.js Specifics

When using Mermaid diagrams:

- Use `layout: 'elk'` in mermaid config for better node positioning on complex graphs
- Keep diagrams to 15-20 nodes max. Use `subgraph` blocks for larger systems.
- Add zoom controls (+/-/reset buttons) with pan capability
- Quote node labels containing special characters: `A["handleRequest(ctx)"]`
- Use semi-transparent hex fills that work in both light and dark: `fill:#b5761433`
- Initialize with:

```html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
  mermaid.initialize({
    startOnLoad: true,
    theme: 'dark',
    flowchart: { curve: 'basis', padding: 20 },
    themeVariables: {
      primaryColor: 'var(--accent)',
      primaryTextColor: 'var(--text)',
      lineColor: 'var(--border)',
      fontSize: '14px'
    }
  });
</script>
```

### Chart.js Specifics

When using Chart.js for time-series, bar charts, or dashboards:

- Load via: `<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>`
- Match chart colors to the page palette using CSS custom property values
- Always include axis labels and a legend
- Use `responsive: true` and `maintainAspectRatio: false` with a fixed-height container

## Quality Checklist

Before delivering, verify:

- [ ] Opens and renders correctly in browser
- [ ] Self-contained (no broken external dependencies besides CDN JS)
- [ ] Color palette is distinct from the last explainer you made
- [ ] No AI-slop patterns (check the forbidden list)
- [ ] Responsive at 375px, 768px, 960px widths
- [ ] The ONE thing this visual must make obvious — is it obvious?
- [ ] Bear note created with HTML attached
- [ ] User can open the HTML attachment from Bear and see the visual

## Example Output Structure

```
Bear Note: "How Agents Stream Data"
Tags: #visual-explainer #learn/agents 
Body: Brief markdown summary of the concept

Attached: agent-streaming.html
  - Self-contained HTML
  - Mermaid flow diagram showing the streaming pipeline
  - CSS Grid cards for each component
  - Color-coded status indicators
  - Dark theme, Space Grotesk + Space Mono fonts
```
