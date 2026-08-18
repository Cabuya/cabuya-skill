# Recognising the app you have been pointed at

`shared/context.sh` gives you a first guess in one line of JSON. This file is
the detail behind it: how to confirm the guess, where the data actually lives,
and — the part that decides whether the first feed works — **where a file has
to sit to be served at `/.well-known/cabuya.json`**.

Detect, then **say what you detected and let the human correct you**. A wrong
guess stated confidently costs more than a question.

---

## The nine families

### 1. Vite + React SPA (often + Supabase, often on Vercel/Netlify)

**Fingerprint:** `vite.config.ts` · `@vitejs/plugin-react` in devDependencies ·
`index.html` at the repo root · `src/main.tsx`.

**Data layer:** `@supabase/supabase-js` in dependencies, with a client built
somewhere under `src/` — search for `createClient(`. Table names appear as
`.from('...')` calls. There is often no server: the browser queries Supabase
directly with an anon key, and **row-level security is the only thing standing
between the anon key and every row**.

**Manifest goes in:** `public/.well-known/cabuya.json`. Vite copies the whole
`publicDir` into `dist/`, dot-directories included — verified, not assumed:
a `public/.well-known/cabuya.json` lands at `dist/.well-known/cabuya.json` on
a stock `vite build`.

**⚠ The catch-all is the trap here.** A `vercel.json` like this is real, and
is what a deployed app in this ecosystem actually ships:

```json
{ "rewrites": [{ "source": "/((?!api/).*)", "destination": "/index.html" }] }
```

Every path that is not `/api/…` returns the SPA shell — HTTP **200**, with
`text/html`. Request the manifest and you get an HTML document, which is
exactly the soft-404 condition (§2, and §1.2's precondition).

The static file wins **if it exists**: Vercel and Netlify both match static
output before applying rewrites. So the fix is to ship the file, then
**verify by fetching it**, because the failure mode looks identical to success
until you check the content type.

**Generating the feed.** No server means one of:
- a build-time export — a script that queries Supabase and writes
  `public/cabuya/places.json` before `vite build`; simplest, and the
  `last_updated` is honest by construction (build time, not request time);
- a serverless function (`api/places.ts` on Vercel) — needed only if the data
  changes faster than deploys;
- a Supabase Edge Function or a scheduled job writing to storage.

Prefer the build-time export unless the data genuinely changes between
deploys. It is the cheapest thing that conforms, and it cannot accidentally
implement the always-now anti-pattern.

Guide: [`vite-spa-supabase.md`](../implement/stacks/vite-spa-supabase.md).

### 2. Next.js (App Router)

**Fingerprint:** `next.config.{js,mjs,ts}` · `next` in dependencies ·
`app/` or `pages/`.

**Data layer:** Prisma (`prisma/schema.prisma` — read it; it is the cleanest
data model you will get), Drizzle (`drizzle.config.ts`), or a Supabase client.

**Manifest goes in:** `public/.well-known/cabuya.json`. Next serves `public/`
from the root and does not route it through middleware matchers by default —
but **check `middleware.ts`**: a broad `matcher` can intercept it, and a
catch-all `[...slug]` route can shadow it.

**Feed:** a route handler, `app/api/cabuya/places/route.ts`, with
`export const dynamic = 'force-static'` or an explicit `revalidate`. Set
`last_updated` from the data's own maximum `updated_at`, or from build time —
never `new Date()` at request time.

Guide: [`nextjs-supabase.md`](../implement/stacks/nextjs-supabase.md).

### 3. PHP server-rendered (often Laravel)

**Fingerprint:** `composer.json` · `artisan` (Laravel) · `public/index.php`.

**Data layer:** Eloquent models in `app/Models/`, migrations in
`database/migrations/` — the migrations are the authoritative column list.

**Manifest goes in:** `public/.well-known/cabuya.json`. The document root is
`public/`, so this works with no routing changes.

**⚠ Apache and dot-directories.** Some shared hosts ship an Apache config
that denies any path segment beginning with a dot. If the manifest 403s or
404s while the file plainly exists, that is why — and it is exactly the case
§2 anticipates by making the well-known path RECOMMENDED rather than
required. Serve it from a plain path instead (`/cabuya.json`), declare that
path in the registry entry, and add the `<link rel="cabuya">` fallback.

**Feed:** a controller returning `response()->json($payload)` with the CORS
header set explicitly. Do not rely on a global CORS middleware — see the
entity-scoped grants rule in the deny-list.

Guide: [`php-ssr.md`](../implement/stacks/php-ssr.md).

### 4. Django

**Fingerprint:** `manage.py` · `settings.py` · `requirements.txt` or
`pyproject.toml` with `django`.

**Data layer:** `models.py` — read the field definitions directly.

**Manifest goes in:** whatever `STATIC_ROOT`/`STATICFILES_DIRS` produces at
the site root, which in practice means a `static/.well-known/cabuya.json`
plus a URL pattern, **or** a tiny view. In production Django usually is not
serving static files at all — nginx or WhiteNoise is — so confirm which, and
check that the dot-directory is not filtered.

**Feed:** a view returning `JsonResponse`, cached; or a management command
writing a file on a schedule.

Guide: [`django.md`](../implement/stacks/django.md).

### 5. Ruby on Rails

**Fingerprint:** `config/application.rb` (decisive) · `Gemfile` with `rails` ·
`db/schema.rb`.

**Data layer:** `db/schema.rb` is the whole model in one authoritative file;
`app/models/` for meaning. **Manifest goes in:** `public/.well-known/` —
Rails serves `public/` before routing; verify the deployed origin because a
reverse proxy may hide dot-directories. Guide: [`rails.md`](../implement/stacks/rails.md).

### 6. Express / plain Node service

**Fingerprint:** `express` in `package.json` dependencies **and** a
`express()` call site (`server.js`, `app.js`, `src/index.*`) — the
dependency alone is not sufficient. No `next.config.*`, no `vite.config.*`.

**Data layer:** whatever the migrations or schema files say — `knexfile.js`,
`prisma/schema.prisma`, Mongoose `new Schema`. **Manifest:** an explicit
`express.static` mount registered **before** any catch-all; route order is
the whole mechanism. Guide: [`express-node.md`](../implement/stacks/express-node.md).

### 7. Astro / static generators

**Fingerprint:** `astro.config.mjs|ts` (Astro) · `.eleventy.js` (Eleventy) ·
`hugo.toml`/`config.toml` + `layouts/` (Hugo).

**The one distinction that matters:** static output vs an SSR adapter —
static output has no catch-all at all. **Manifest:** `public/` (Astro),
passthrough copy (Eleventy), `static/` (Hugo); then verify the *host* serves
dot-directories. Guide: [`astro-static.md`](../implement/stacks/astro-static.md).

### 8. Firebase (Firestore + Hosting)

**Fingerprint:** `firebase.json` (decisive) · `.firebaserc` ·
`firestore.rules`.

**Data layer:** schemaless — `firestore.rules` names the collections;
converters and call sites hint the shape; sampled documents are the truth.
**The trap:** `hosting.rewrites` with `"source": "**"`; static files win
over rewrites, so ship the file and verify by fetching. Guide:
[`firebase-firestore.md`](../implement/stacks/firebase-firestore.md).

### 9. Static site / no application server

**Fingerprint:** `index.html` and no framework config · Jekyll (`_config.yml`)
· Hugo (`config.toml`) · Astro (`astro.config.mjs`) · plain files.

**Data source:** frequently a Google Sheet, a CSV, or a JSON file in the repo.
An HXL-tagged spreadsheet at a stable URL is an accepted generator input
(§1.3): convert it, and **the converter must drop contact columns** unless
they are declared institutional.

**Manifest and feed:** both are just files. This is the easiest L2 in the
ecosystem — write two JSON files and commit them. The only real work is
keeping `last_updated` honest, which means regenerating on a schedule rather
than by hand.

---

Guide: [`static-sheet.md`](../implement/stacks/static-sheet.md).

## Finding the data model, in order of reliability

1. **Migrations or schema files** — `prisma/schema.prisma`,
   `database/migrations/`, `models.py`, `drizzle/`, `*.sql`. Authoritative,
   because the database was built from them.
2. **Type definitions** — `types/database.ts`, Supabase's generated types.
   Accurate when generated; stale when hand-written.
3. **Query call sites** — `.from('tabla').select('a, b, c')`. Reveals which
   columns are actually used, which is often a smaller and more honest set
   than the schema.
4. **A sample response** — the app's own public API, if it has one. Last
   resort, because optional fields absent from one sample look like fields
   that do not exist.

**Never infer the model from the UI.** A rendered card shows what is
displayed, not what is stored, and the columns that matter for the PII gate
are precisely the ones the UI does not show.

---

## Where the discovery trap actually bites

Run this check in Phase 4 for every stack, before you believe the manifest
works:

```bash
# Does a non-HTML document survive at a fixed path at all?
curl -sI https://example.org/robots.txt | head -3

# The manifest itself: status, content type, and size.
curl -sI https://example.org/.well-known/cabuya.json

# The discriminator: is the response byte-identical in size to the site root?
# If it is, you are looking at the SPA shell, not your file.
curl -s https://example.org/.well-known/cabuya.json | wc -c
curl -s https://example.org/ | wc -c
```

A 200 with `content-type: text/html` **is an absent manifest**, no matter how
much it looks like a success. Two of twenty observed hosts could not serve a
well-known path honestly at all — that is why the fallback exists, and why
using it is a normal outcome rather than a failure.

---

## Detection is a hypothesis

State it, with the evidence, and offer the correction:

> Detected: Vite + React SPA, Supabase, deployed on Vercel. Evidence:
> `vite.config.ts`, `@supabase/supabase-js`, `vercel.json` with a catch-all
> rewrite. That rewrite means `/.well-known/cabuya.json` currently returns
> the SPA shell — I will put the file in `public/` and verify the content
> type after deploy. Correct me if the deployment target is different.

If you cannot find a data source at all, **say so and stop.** Do not scaffold
a feed with invented records to "show the shape". A file full of plausible
fake shelters is the single worst artefact this flow could leave behind.
