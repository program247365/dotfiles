# Conversion rules for indie landing pages

Distilled from: Pieter Levels (Nomad List → Photo AI → Interior AI, the same
page copied across products: ~1% → ~4% conversion on Nomad List), Marc Lou
(ShipFast and friends), Corey Haines' `marketingskills` (copywriting, cro),
and Paldom's `landing-page-structure`. Directional, not law — the funnel
numbers on *this* page win any argument.

## The page is one argument

Write it as one sentence before laying out anything:

> **[Who]** loses **[stakes]** because **[problem]**. **[Product]** fixes it by
> **[mechanism]** — and here's **[proof]**. **[Action]**.

Every section advances that sentence. Features are narrated *inside* the
argument where they answer an objection, never dumped as an icon grid.

**Reorder test:** if you can shuffle the sections without hurting
comprehension, there's no argument. Fix the order before adding anything.

## First screen (most visitors never scroll)

Answers four questions with no scroll:

1. **What is it** — headline, outcome not category. "Never lose a domain to a
   missed renewal", not "Domain management, reimagined".
2. **Who is it for** — subhead names the person and the situation.
3. **Why trust it** — one trust cue: a specific number, the founder's face +
   one sentence, one real quote, or a visible mechanism ("checks the
   registry directly").
4. **What do I do** — ONE primary CTA. At most one soft secondary
   ("See how it works"). Three equal buttons is the anti-pattern.

Plus a **real product shot**. The product is the proof for an indie tool.

## Levels' scannable formula

People scan, they don't read. For small products this beats a long story:

1. **Headline** — very short, the value and the USP.
2. **Description** — one or two sentences with specific numbers, reasons why.
3. **3–5 bullets** — each a concrete benefit with a number or a specific
   noun. No adjectives doing the work nouns should do.
4. **CTA** right under it. Unified: signup and login are the same action.
5. Later, when real: testimonials with faces, press, live counts.

## Indie-specific levers (what solo founders actually have)

- **The founder.** A face, a first-person line, why you built it. Big
  companies can't do this; it is the strongest trust cue a solo product has.
- **Specificity.** "Checks 1,200+ TLDs via RDAP" beats "works everywhere".
  Real numbers only.
- **Build in public proof.** Changelog dates, "shipped v0.4 last week",
  GitHub stars — only if real and current.
- **Honest scope.** Saying what it *doesn't* do (no accounts, no cloud)
  is positioning, and it pre-empts the objection.
- **Price clarity.** If there's a price, show it near the CTA. Hidden
  price reads as expensive. If price is undecided, omit it — don't tease.

## Copy rules

- Benefits over features; specific over vague; active voice; second person.
- The visitor's words, not yours. Mine the problem phrasing from where they
  complain (Reddit, HN, reviews, Kevin's own notes).
- CTA label names the result: "Get launch access", "Download for Mac" — not
  "Submit", "Learn more", "Get started" with nothing after it.
- Final CTA carries reassurance microcopy: "One email at launch. No spam."
- Banned: elevate, seamless, unleash, supercharge, game-changer, revolutionize,
  next-gen, effortless, "in today's world", "reimagined", "all-in-one".
- No eyebrows/kickers above headings. No fake urgency, no countdowns that
  reset, no "Only 3 spots left".

## Proof placement

- Proof goes **next to the claim it supports** and next to the CTA, never
  exiled to a testimonials block or the footer.
- Cap distinct proof types at 3–5.
- Zero proof yet? Demonstrate instead: the live product shot, the mechanism
  explained in one sentence, the founder's own use. Never fabricate.

## Structure by page length

- **Pre-launch / waitlist:** hero → problem (2–3 lines) → how it works
  (3 steps or one annotated product shot) → objections (FAQ, 3–5 real ones)
  → final CTA. 4–6 sections.
- **Low-price utility (< $20):** hero → demo → 3–5 benefits → price + CTA →
  FAQ. Short. Buying decision is cheap; don't make the page expensive.
- **Subscription / higher price:** add comparison vs. the status quo,
  pricing table, more objection handling, a second CTA mid-page.

## Forms

- Waitlist = **one field** (email). Every extra field costs signups.
- Inline validation, inline success state ("You're on the list — one email
  at launch."), inline error naming the recovery.
- Honeypot field for bots, not a CAPTCHA.

## CRO review checklist (run on the built page)

1. Value prop clear in 5 seconds? (Show the first screen to someone cold.)
2. Headline = outcome, not category?
3. One primary CTA, visible above the fold and repeated at the end?
4. Every claim either specific or backed by adjacent proof?
5. Top 3 objections answered before the final CTA?
6. Friction: field count, load time, layout shift, mobile tap targets?
7. Anything invented? Remove it.

## First experiment to run

Headline. It moves conversion more than anything else on a small page.
Ship two headlines (outcome-led vs. problem-led), split traffic, read the
`waitlist_submit` event per variant after ~100 conversions each, not before.
