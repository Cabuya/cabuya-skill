# Next.js App Router + Supabase or Prisma

A server exists, which makes freshness easy and makes one specific mistake
available that the serverless stacks cannot reach: regenerating `last_updated`
per request.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.**

## 1. Fingerprints

```
next.config.{js,mjs,ts}   + next in dependencies
app/ (App Router)  or  pages/ (Pages Router — same ideas, different file)
prisma/schema.prisma | drizzle.config.ts | @supabase/supabase-js
middleware.ts             ← check its matcher
```

## 2. Where the data lives

1. **`prisma/schema.prisma`** — the cleanest data model you will get in any
   stack. Read it end to end; it names the relations too, which is how you find
   the person-level tables.
2. **`drizzle/schema.ts`** — same role.
3. **Supabase generated types**, if that is the client.
4. **Query call sites** — `prisma.<model>.findMany(...)`, `.from('...')`.

```bash
sed -n '1,200p' prisma/schema.prisma
grep -rn "prisma\.\w*\.findMany\|\.from(" app/ lib/ | head -20
```

**Read the relations, not only the models.** A `Shelter` with a
`reportedBy User` relation is one careless `include` away from putting a name
in the feed — and `include` is exactly what somebody writes when they want the
reporter's display name in an admin view.

## 3. The mapping worksheet

```
Mapping: Shelter → place (Core profile)

  place field           ← model field         notes
  ───────────────────── ───────────────────── ──────────────────────────────
  id                    ← id
  publisher_id          ← (constant)          registry token
  name                  ← name
  place_kind            ← category            see mapping/place-kind.md
  origin_category       ← category            verbatim
  municipality_code     ← municipalityCode    already a DIVIPOLA column here
  address_text          ← address
  lat / lon             ← lat, lon
  lifecycle_status      ← isActive            true→active, false→closed
  last_confirmed_at     ← confirmedAt         a REAL confirmation event ✓
  confirmed_by          ← (constant) 'team'   role token, never a name
  updated_at            ← updatedAt           the record's own edit time
  source                ← (constant)
  public_url            ← (derived)
```

This stack more often *does* have a confirmation event — a "verificado"
button, a moderation queue, a volunteer check-in. **Confirm that it is one.**
A field named `verifiedAt` that is set once at creation and never again is not
a confirmation event; it is a creation timestamp with an optimistic name, and
mapping it produces records that claim to have been confirmed years ago.

If it is real, map it. If it is not, `null`. Never `updatedAt` (CR-1).

## 4. The PII gate here

- **The `User` model and every relation to it.** `reportedBy`, `createdBy`,
  `owner`, `volunteer`. Prisma's `include` is how they reach a serializer.
- **`select` objects that grew.** A `select` written for an admin view and
  reused for the feed carries whatever the admin view needed.
- **Free-text `notes` / `description`.** The third leak channel, and this stack
  usually has a rich-text field somewhere.
- **`contactPhone` on the place itself.** Common and reasonable for the app's
  own UI — and it does not travel. `contact_available: true` plus
  `public_url` is the conforming shape.

Present the table, then **stop**.

## 5. The serializer: a route handler

```ts
// app/cabuya/places.json/route.ts

import { NextResponse } from 'next/server';

import { prisma } from '@/lib/prisma';

const PUBLISHER_ID = 'example-app';
const SITE = 'https://example.invalid';

// Regenerate on a schedule, not per request. This number and the feed's `ttl`
// are the same promise stated twice — keep them in step.
export const revalidate = 900;

const KIND: Record<string, string> = {
  albergue: 'shelter',
  acopio: 'collection_center',
};

export async function GET() {
  const rows = await prisma.shelter.findMany({
    // Explicit select. No `include`. A relation pulled in here is how a
    // volunteer's name reaches a public feed.
    select: {
      id: true,
      name: true,
      category: true,
      address: true,
      lat: true,
      lon: true,
      municipalityCode: true,
      isActive: true,
      confirmedAt: true,
      updatedAt: true,
    },
  });

  const places = rows.map((row) => ({
    id: String(row.id),
    publisher_id: PUBLISHER_ID,
    name: row.name,
    place_kind: KIND[row.category] ?? 'other',
    origin_category: row.category,
    municipality_code: row.municipalityCode,
    address_text: row.address,
    ...(row.lat != null && row.lon != null && { lat: row.lat, lon: row.lon }),
    lifecycle_status: row.isActive ? 'active' : 'closed',

    // A real confirmation event, confirmed to be one. If it were not, this
    // would be `null` — never row.updatedAt.
    last_confirmed_at: row.confirmedAt?.toISOString() ?? null,
    confirmed_by: 'team',

    updated_at: row.updatedAt.toISOString(),
    source: { source_id: PUBLISHER_ID, source_kind: 'first_party' },
    public_url: `${SITE}/albergues/${row.id}`,
  }));

  // The data's own high-water mark. `new Date()` here would be BEH002: the
  // feed always reads fresh, so a stalled pipeline looks identical to a
  // healthy one.
  const lastUpdated = rows.reduce<Date | null>(
    (max, row) => (!max || row.updatedAt > max ? row.updatedAt : max),
    null
  );

  return NextResponse.json(
    {
      last_updated: (lastUpdated ?? new Date(0)).toISOString(),
      ttl: 900,
      version: '0.1.0',
      publisher_id: PUBLISHER_ID,
      license: 'CC-BY-4.0',
      permitted_use: ['display', 'aggregate', 'ai_answer'],
      data: { places },
    },
    {
      headers: {
        // On this route. Not in a global middleware that also covers the
        // person-data endpoints.
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'public, max-age=900',
      },
    }
  );
}
```

> `new Date(0)` for an empty feed is deliberate and visible: an epoch
> timestamp reads as obviously wrong, which is what you want when the feed has
> no data to describe. If the app prefers a build constant, inject one — but
> do not reach for `new Date()`, because that is the anti-pattern arriving
> through the back door.

## 6. The manifest and the catch-all

From [`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md):

> Files under `public/` are served before the catch-all route, so placement is
> the whole fix. Verify anyway: a custom `rewrites` entry can still capture it.

So: `public/.well-known/cabuya.json`, and then check the two things that can
still take it away.

**`middleware.ts`.** A broad matcher intercepts static paths:

```ts
export const config = {
  matcher: [
    // Exclude the discovery path and the feed explicitly. A matcher written
    // for auth will happily swallow both.
    '/((?!api|_next/static|_next/image|favicon.ico|\\.well-known|cabuya).*)',
  ],
};
```

**A catch-all route.** `app/[...slug]/page.tsx` does not shadow `public/`, but
a `rewrites` entry in `next.config.js` can. Read it.

Then fetch:

```bash
curl -sI https://example.invalid/.well-known/cabuya.json   # application/json
curl -sI https://example.invalid/cabuya/places.json        # + CORS header
curl -sI https://example.invalid/robots.txt                # 200, text/plain
```

## 7. The validator loop

| Finding | What it means in this stack |
|---|---|
| `last_updated` moves between identical requests | BEH002. `new Date()` is in the handler. Use the data's high-water mark. |
| Manifest returns HTML | `middleware.ts` matcher, or a `rewrites` entry in `next.config.js`. |
| CORS header missing | Set on the response, not in `next.config.js` headers for a different path. |
| Personal data detected | A relation was `include`d, or a `select` was reused from an admin view. Stop; do not narrow the deny-list. |
| Feed 500s in production but not locally | Usually a missing env var at build. The route is static-rendered at build time by default. |
| `place_kind` invalid | A category the enum lacks was mapped to a near neighbour. `other` + `place_kind_ext`. |

Eight iterations maximum, then stop and summarize.

## 8. Hand-off

Left behind: the route handler, `public/.well-known/cabuya.json`, the
middleware matcher edit, and a filled-in `CABUYA.md`.

If the app has a read API already, L3 is close: it needs byte-compatible
records with the feed and one peer feed consumed under the six consumption
rules — the step-up path is
[`../templates/serializer-read-api.md`](../templates/serializer-read-api.md).
`consume` handles the second half. Report the level the validator
measured.
