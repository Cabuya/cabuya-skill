# Vite + React SPA + Supabase

The most common shape in this ecosystem, and the one where the discovery trap
actually bites. Written against a real deployed application of this kind, with
its identity removed — the configuration below is the shape that was observed,
not an illustration of one.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.**

## 1. Fingerprints

```
vite.config.ts                        + @vitejs/plugin-react in devDependencies
index.html at the repository root     + src/main.tsx
@supabase/supabase-js in dependencies
vercel.json | netlify.toml            ← the trap lives here
```

The distinguishing feature is not React. It is that **there is no server**:
the browser talks to Supabase directly with an anon key, and row-level
security is the only thing between that key and every row.

## 2. Where the data lives

In order of reliability:

1. **Supabase migrations** — `supabase/migrations/*.sql`, if the project keeps
   them in the repo. Authoritative.
2. **Generated types** — `src/types/database.ts` or similar, from
   `supabase gen types`. Accurate when regenerated; stale when hand-edited.
3. **Query call sites** — `grep -rn "\.from(" src/`. This is usually the most
   *honest* source in this stack, because it shows the columns the app really
   uses, which is a smaller set than the table has.
4. **The Supabase dashboard**, if you have access and nothing else exists.

```bash
grep -rn "createClient" src/          # where the client is built
grep -rn "\.from(" src/ | sed 's/.*\.from(//' | sort -u   # which tables
```

**A table you find only in the dashboard, never in the code, is a warning.**
It may be an import staging table, an admin table, or person-level data the
app does not display. Ask before you read it.

## 3. The mapping worksheet

```
Mapping: `centros` → place (Core profile)

  place field           ← column              notes
  ───────────────────── ───────────────────── ──────────────────────────────
  id                    ← id                  uuid, used as-is
  publisher_id          ← (constant)          registry token
  name                  ← nombre
  place_kind            ← categoria           see mapping/place-kind.md
  origin_category       ← categoria           verbatim, always
  municipality_code     ← (constant) 66001    verify — mapping/divipola.md
  address_text          ← direccion
  lat / lon             ← lat, lng            present on ~⅓ of rows
  lifecycle_status      ← estado              'activo'→active, else unknown
  last_confirmed_at     ← ???                 ← the question that matters
  source                ← (constant)          {source_id, first_party}
  public_url            ← (derived)           https://…/centro/{id}
```

**`last_confirmed_at` is the one to get right.** This stack usually has
`updated_at` from a Postgres trigger and no confirmation concept at all. Then
the answer is `null` — present, explicit, honest. Mapping the trigger's output
into it would tell every consumer that somebody physically checked the place
each time a row was touched.

## 4. The PII gate here

Where person-level data hides in this stack specifically:

- **`auth.users` and any `profiles` table.** Supabase creates the first one for
  you. It holds emails. It must never be joined into the feed query — and
  because it is in a different schema, an over-broad `select` will not reach it
  by accident, but a *view* built over it will.
- **A `reportes` or `solicitudes` table.** User-submitted reports frequently
  carry a contact field, because the form asked for one.
- **`select('*')`.** The single most likely way this stack leaks: it is
  convenient, it works, and it silently widens the day somebody adds a
  `telefono` column. Always list columns explicitly.
- **RLS policies.** If the anon key can already read a person-level table, that
  is a finding worth reporting even though it is outside this flow's scope —
  the feed is not the leak, but you found the leak.

Run the gate from [`../../shared/pii-deny-list.md`](../../shared/pii-deny-list.md)
and **stop**.

## 5. The serializer: a build-time export

No server means the feed is generated before the build. This is also the
*better* option here — `last_updated` becomes the build time, which is honest
by construction, and there is no request in which to regenerate it.

```js
// scripts/build-cabuya-feed.mjs
import { mkdir, writeFile } from 'node:fs/promises';
import { createClient } from '@supabase/supabase-js';

const PUBLISHER_ID = 'example-app';
const SITE = 'https://example.invalid';
const MUNICIPALITY_CODE = '66001'; // DIVIPOLA — verify against the DANE table

const KIND = { albergue: 'shelter', acopio: 'collection_center', agua: 'water_point' };

const supabase = createClient(
  process.env.SUPABASE_URL,
  // Build-time only. Never the service key in anything the browser loads.
  process.env.SUPABASE_SERVICE_KEY
);

const { data: rows, error } = await supabase
  .from('centros')
  // Explicit. `select('*')` would carry a `telefono` column into the feed the
  // day somebody adds one, and nothing here would fail.
  .select('id, nombre, categoria, direccion, lat, lng, estado, updated_at');

if (error) {
  // Fail the build. A feed generated from a failed query publishes an empty
  // list as though it were the truth.
  console.error('Cabuya feed: query failed —', error.message);
  process.exit(1);
}

const places = rows.map((row) => ({
  id: String(row.id),
  publisher_id: PUBLISHER_ID,
  name: row.nombre,
  place_kind: KIND[row.categoria] ?? 'other',
  origin_category: row.categoria,
  municipality_code: MUNICIPALITY_CODE,
  address_text: row.direccion,
  ...(row.lat != null && row.lng != null && { lat: row.lat, lon: row.lng }),
  lifecycle_status: row.estado === 'activo' ? 'active' : 'unknown',

  // This app has no confirmation event. `null` is the conforming, honest
  // value — and the key is still here, because omitting it is not.
  last_confirmed_at: null,

  source: { source_id: PUBLISHER_ID, source_kind: 'first_party' },
  public_url: `${SITE}/centro/${row.id}`,
}));

await mkdir('public/cabuya', { recursive: true });
await writeFile(
  'public/cabuya/places.json',
  JSON.stringify(
    {
      last_updated: new Date().toISOString(), // build time, not request time
      ttl: 900,
      version: '0.1.0',
      publisher_id: PUBLISHER_ID,
      license: 'CC-BY-4.0',
      permitted_use: ['display', 'aggregate', 'ai_answer'],
      data: { places },
    },
    null,
    2
  )
);

console.log(`Cabuya feed: ${places.length} places`);
```

```json
{ "scripts": { "build": "node scripts/build-cabuya-feed.mjs && vite build" } }
```

## 6. The manifest and the catch-all

**This is the step that fails silently in this stack.** A deployed application
of this kind ships:

```json
{ "rewrites": [{ "source": "/((?!api/).*)", "destination": "/index.html" }] }
```

Every path that is not `/api/…` returns the SPA shell — HTTP **200**, with
`text/html`. Request the manifest and you get an HTML document, which the
validator treats as **absent**.

The fix, from
[`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md):

> Place the file in `public/`, and exclude `/.well-known/*` from the SPA
> rewrite in your host config — the rewrite is what serves index.html for
> unknown paths.

Vite copies `public/` into `dist/` **including dot-directories**, so
`public/.well-known/cabuya.json` lands at `dist/.well-known/cabuya.json`. Both
Vercel and Netlify match static output before applying rewrites, so the file
wins once it exists.

Belt and braces — widen the negative lookahead so the rewrite never sees it:

```json
{
  "rewrites": [
    { "source": "/((?!api/|cabuya/|\\.well-known/).*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/(cabuya|\\.well-known)/(.*)",
      "headers": [{ "key": "Access-Control-Allow-Origin", "value": "*" }]
    }
  ]
}
```

Netlify equivalent:

```toml
# netlify.toml — order matters; the SPA fallback goes last.
[[redirects]]
  from = "/.well-known/*"
  to = "/.well-known/:splat"
  status = 200

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[[headers]]
  for = "/cabuya/*"
  [headers.values]
    Access-Control-Allow-Origin = "*"
```

**Then verify by fetching**, because until you do, success and failure look
identical:

```bash
curl -sI https://example.invalid/.well-known/cabuya.json   # expect application/json
curl -s  https://example.invalid/.well-known/cabuya.json | wc -c
curl -s  https://example.invalid/ | wc -c                  # must differ
curl -sI https://example.invalid/robots.txt                # 200, text/plain
```

## 7. The validator loop

Failures this stack produces, and what each means here:

| Finding | What it means in this stack |
|---|---|
| Manifest returns HTML | The rewrite still owns the path. Either the file is not in `public/`, or the deploy did not include it — check `dist/` after a local build. |
| CORS header missing | Static files take headers from host config, not from code. The `headers` block above, and it must match the path you actually used. |
| `last_confirmed_at` missing | The mapper omitted the key on some rows. It must be present on **every** record; `null` is the value, not the absence. |
| `robots.txt` 404 | No `public/robots.txt`. Two lines, and it is an L2 precondition. |
| Feed 404 after deploy | The build script did not run — check it is actually in the `build` script and not only in a local alias. |
| Empty `places[]` | The query returned nothing and the script did not fail. Add the error branch above. |

Eight iterations maximum, then stop and summarize.

## 8. Hand-off

Left behind: `scripts/build-cabuya-feed.mjs`, `public/.well-known/cabuya.json`,
the host-config change, a `robots.txt` if there was none, the `build` script
edit, and a filled-in `CABUYA.md`.

Next: `publish-status`, to set the conformance target and open the registry
entry. Report the level **the validator measured** — not one you inferred.
