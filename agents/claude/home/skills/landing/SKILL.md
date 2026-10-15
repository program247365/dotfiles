---
name: landing
description: Use when Kevin wants a landing page, marketing site, waitlist page, or launch page for an indie product or side project — building one, generating variants to compare, or shipping it to Vercel. Covers placing it in a monorepo (apps/marketing) or a single-app repo, writing conversion copy from real product facts, handing visual direction to impeccable, wiring a working CTA, and preview-deploying with the Vercel CLI.
---

# Landing — indie landing pages that ship and convert

One job: get a small product from "it works" to "a stranger can understand it,
trust it, and act" on a live URL, in one session. Speed over ceremony; truth
over persuasion tricks.

This skill orchestrates. It owns **placement, argument, copy, CTA wiring, and
deploy**. It hands **visual direction and craft** to the `impeccable` skill.

## 1. Find (or make) the home for the page

Never build the landing page inside the product app. It ships, caches, and
fails on its own schedule.

1. Detect repo shape: `pnpm-workspace.yaml`, `package.json` `workspaces`,
   `turbo.json`, `nx.json`.
2. Reuse an existing marketing app if there is one: `apps/marketing`,
   `apps/www`, `apps/site`, `apps/landing` (check its package.json before
   assuming).
3. Workspace monorepo, no marketing app → create `apps/marketing`. Match
   sibling naming (`@scope/marketing` if siblings are scoped), `"private": true`.
4. Single-app repo → create `marketing/` at the repo root. Do not add it to any
   workspace or build pipeline.

Stack, in order of preference:

| Need | Stack |
|---|---|
| One page (+ maybe a privacy page) | **Static HTML + one CSS file.** No build, best LCP, deploys in seconds. |
| Blog, changelog, docs, >3 pages | **Astro** (static output). |
| Must import shared packages from the monorepo (`@scope/ui`) | The repo's existing framework, as its own app. |

Default to static. Complexity has to earn its place — a landing page is not
where it earns it.

## 2. Collect product truth (never invent it)

Read, in order: `PRODUCT.md`, `DESIGN.md`, `README.md`, the app's real UI.
Missing `PRODUCT.md` → run `/impeccable init` first; it interviews for it.

Then ask **at most three** questions with the structured question tool, only
for what the files don't settle:

- **The one action** — waitlist, buy, download, App Store, start free. One.
- **Price** — stated, or deliberately omitted.
- **Proof on hand** — real users, numbers, quotes, press, the founder's own
  usage. If none: say so; the page leans on demonstration instead.

Hard rule: no fabricated testimonials, user counts, logos, ratings, or
"as seen on". An honest page with no social proof beats a fake one — and the
founder's own usage is real proof ("I built this after losing a domain").

## 3. Build the argument, then the copy

Read `references/conversion.md` before writing a word. Short version:

- The page is **one argument** (problem → stakes → mechanism → proof → action),
  not a stack of default sections. Run the reorder test.
- First screen answers: what is it, who is it for, why trust it, what do I do.
  One headline, one subhead, one CTA, one trust cue, a real product shot.
- Product shot = real screenshot, short muted loop, or a faithful HTML
  replica of the real UI built from DESIGN.md tokens. Never stock art, never a
  generic device mockup with an invented UI.

## 4. Hand design to impeccable

Invoke the `impeccable` skill on the target file (e.g.
`--target apps/marketing/index.html`). It loads PRODUCT.md/DESIGN.md and runs
its persuade-mode rules and craft floor. Tell it:

- This is a **Persuade** surface for the product, not product UI.
- DESIGN.md describes the *app*. Brand commitments (icon, accent, name, voice)
  carry to the page; the app's density and type-ramp limits bind only the
  product replica, not the page around it — unless DESIGN.md says otherwise.
- The argument and copy from step 3 are the content contract.

When Kevin wants to compare, build **2–3 variants** that differ in argument and
structure, not just color — e.g. *plain indie* (Levels-style scannable),
*brand-world* (the product's own visual world carries the page),
*problem-led* (story first). Serve them as `/a/`, `/b/`, `/c/` with a bare
index linking each, so one preview URL judges all of them. Same facts, same CTA
in every variant, so the comparison is about the page.

## 5. Make the CTA real

A button that goes nowhere is a broken page. Wire the action:

- **Waitlist:** a progressive-enhancement `<form method="post">` to a Vercel
  function (`api/waitlist.js`), with inline success/error states and a
  honeypot field. Kevin's default store is **Resend** (he already uses it):
  the function first tries `POST /contacts/{email}/segments/{segmentId}`
  and only on 404 creates the contact (`POST /contacts` with
  `segments: [{ id }]`; Segments replaced Audiences). Never re-create an
  existing contact: verified 2026-10-15 that re-creating resets
  `unsubscribed` to false, so anyone could re-subscribe a stranger. Driven by
  `RESEND_API_KEY` + `RESEND_SEGMENT_ID`; set them up with the official CLI
  (`npx resend-cli`, `segments create`, `api-keys create`). Production must
  503 when unconfigured, never silently drop signups. Other stores: Vercel runtime logs (stub —
  say so out loud; Hobby log retention is short, so it's for previews
  only), a webhook env var (Buttondown/Loops/Resend audience), or Vercel
  Marketplace KV. Never claim emails are stored if they aren't. A static dir
  with ESM functions needs a `package.json` with `"type": "module"`.
- **Buy/download/App Store:** real URL, or a clearly marked TODO in the
  handoff — never `href="#"` shipped silently.
- **Measure it.** Add Vercel Web Analytics — see `references/deploy.md` for
  the plain-HTML snippet — and fire `va('event', { name: 'waitlist_submit' })`
  on CTA success. Pieter Levels' rule: measure every change against the funnel.

## 6. Verify before showing anyone

One batched pass, then stop:

- `impeccable detect --json <files>` once.
- Screenshot desktop (1440) and mobile (390) for every variant with
  Playwright (`chromium.launch({ channel: 'chrome' })`, real `viewport`),
  and log `document.documentElement.scrollWidth` — anything above the
  viewport width is real horizontal overflow. Don't use
  `chrome --headless --window-size=390`: it clamps to a wider minimum and
  fakes overflow. Full-page captures can drop absolutely-positioned animated
  elements; confirm the hero with a plain viewport screenshot.
- Submit the form against the local function: success state and error state.
- Check the head: `<title>`, meta description, OG image/title, favicon,
  `lang`, viewport.

## 7. Deploy with the Vercel CLI

Read `references/deploy.md`. Defaults: **preview, never production unless Kevin
says "prod"**, and ask before the first deploy of a new project (it creates a
Vercel project — outward-facing).

## Handoff

Report: preview URL(s), which variant you'd pick and why (be critical), what's
stubbed (storage, App Store link, OG image), and the one experiment worth
running first.
