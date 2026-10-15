# Deploying a landing page with the Vercel CLI

Rules: **preview by default**; `--prod` only when Kevin says production.
Ask before the first deploy of a new Vercel project (it creates the project).
Never print tokens or decrypt env values.

## 0. Preflight

```bash
# Not globally installed on Kevin's machines: when `command -v vercel` fails,
# write every `vercel` below as `npx -y vercel@latest` (aliases don't expand
# in agent shells).
vercel whoami             # if this fails, ask Kevin to run: ! npx vercel login
vercel teams ls           # pick scope; pass --scope <slug> on every command
```

Kevin's personal scope is `program247365s-projects` (Hobby). Hobby matters:
custom Web Analytics events and some features are plan-gated.

## 1. Choose the deploy root

The deploy root is the marketing directory itself, never the product app.

| Repo shape | Deploy root | Notes |
|---|---|---|
| Single-app repo | `marketing/` | Self-contained static dir. |
| Monorepo, static or Astro marketing app with no workspace deps | `apps/marketing` | Deploy the dir directly with `--cwd`. |
| Monorepo, marketing app imports workspace packages | repo root | Vercel must see the whole repo. Set the project's **Root Directory** to `apps/marketing` and deploy from the root (below). |

## 2a. Self-contained dir (most landing pages)

```bash
# First time: creates + links a project; writes <dir>/.vercel/project.json
vercel link --cwd apps/marketing --yes --project <product>-marketing --scope <team>

# Every time: preview deploy, prints the URL
vercel deploy --cwd apps/marketing --scope <team>
```

`.vercel/` must be gitignored (`vercel link` adds it to the dir's
`.gitignore`; check it did).

## 2b. Monorepo with workspace deps

```bash
# From the repo root. Links every app in the repo to its own project;
# writes .vercel/repo.json at the root.
vercel link --repo --scope <team>
```

Then set the marketing project's Root Directory to `apps/marketing` (prompted
during link, or Project → Settings → Build and Deployment). Deploy from the
root with `vercel deploy --scope <team>` and pick the project when asked. For
Turborepo, the build command is usually `turbo run build --filter=<name>`;
Vercel infers this for Turborepo projects.

## 3. Static dir + function layout

Vercel needs no config for this — HTML is served as-is, `api/*.js` becomes
a Node function:

```
marketing/
  index.html            # or variant chooser
  a/index.html  b/index.html  c/index.html
  assets/...
  api/waitlist.js       # export default async function handler(req, res) {}
  vercel.json           # only if you need cleanUrls/headers/redirects
```

Plain static deploys under 10 HTML files and 5 MB go live without a build step.

## 4. Analytics

Enable Web Analytics on the project (dashboard → Analytics → Enable). The
dashboard's "Get Started" only shows framework/npm recipes (`inject()` from
`@vercel/analytics`); for a no-build static site use the equivalent tag.
`@vercel/analytics` 2.0.1's `inject()` defaults to `/_vercel/insights/script.js`
(the docs' `/<unique-path>/script.js` is an optional ad-blocker-resistant path):

```html
<script>
  window.va = window.va || function () { (window.vaq = window.vaq || []).push(arguments); };
</script>
<script defer src="/_vercel/insights/script.js"></script>
```

The script 404s until the first deploy *after* enabling — redeploy, then
`curl -sI <prod-url>/_vercel/insights/script.js` should be 200.

Custom event on CTA success: `va('event', { name: 'waitlist_submit', data: { variant: 'a' } })`.
Custom events may be plan-gated — check the project's Analytics tab before
promising funnel data. Read results with the Vercel MCP `count_events` /
`aggregate_events` tools.

## 5. Verify the deploy

```bash
vercel inspect <url> --scope <team>       # state should be READY
curl -sI <url> | head -1                  # 200 (401 = Deployment Protection on)
curl -s -X POST <url>/api/waitlist -d 'email=test@example.com' -i | head -1
```

Preview URLs are behind Vercel Authentication by default (plain `curl`
gets a 302/401). Verified 2026-10-15 on Hobby:

- `vercel curl <path> --deployment <url> --scope <team> -- <curl args>`
  (run from inside the linked dir; it rejects `--cwd`) gets through for
  **GET** — use it to check pages, assets, and that `api/*` answers 405.
- **POST through protection returned 401.** Test form submission against the
  handler locally (import it and call with a mock req/res) rather than
  disabling protection.
- For Kevin's phone: dashboard → deployment → Share creates a bypass link.
  The Vercel MCP `get_access_to_vercel_url` only works when the MCP
  connection is authorized for that team (it 403'd for
  `program247365s-projects`).

`vercel link --cwd <dir>` also writes `<dir>/.env.local` with a
`VERCEL_OIDC_TOKEN` and gitignores `.vercel` and `.env*` in that dir. Check
the `.gitignore` before committing.

## 6. Production + custom domain (only on request)

Order matters (learned 2026-10-15): `vercel domains add <domain> <project>`
fails with "latest production deployment has errored" until the project
has a READY production deployment — a preview-only project counts as errored.
Production deploys also need Kevin's explicit OK (the auto-mode classifier
blocks them otherwise), so ask before step 2.

```bash
# 1. Before checking DNS, confirm the registrar from the registry, not memory:
curl -s https://rdap.org/domain/<domain>   # registrar, nameservers, creation date
# 2. Production deploy (Kevin approves)
vercel deploy --cwd <root> --prod --scope <team>
# 3. Attach apex + www (www redirects to apex: set in Project → Domains)
vercel domains add <domain> <project> --scope <team>
vercel domains add www.<domain> <project> --scope <team>
vercel domains inspect <domain> --scope <team>   # shows intended nameservers
```

DNS at the registrar — prefer **Vercel nameservers** (`ns1.vercel-dns.com`,
`ns2.vercel-dns.com`): one change at the registrar, then every later record
(Resend's DKIM/SPF, verification TXT) is `vercel dns add` from the CLI.
Cost: the registrar's email forwarding MX records go away. Alternative that
keeps registrar DNS: apex `A 76.76.21.21`, `www CNAME cname.vercel-dns.com`.

Namecheap: Domain List → Manage → Nameservers → Custom DNS. Kevin has an
official Namecheap MCP (`https://mcp.namecheap.com/mcp`, http) configured
only in the stoa-mono project; otherwise use the dashboard (Chrome extension
or Kevin by hand).
