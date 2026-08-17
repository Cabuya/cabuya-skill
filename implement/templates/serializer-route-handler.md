# Route handler

For apps that already serve requests: Next.js, Laravel, Django, Express.

The advantage over a build-time export is freshness. The risk it introduces is
**BEH002** — the always-now anti-pattern — because now there *is* a request in
which to regenerate `last_updated`, and the obvious code does exactly that.

## The rule that this file exists for

**`last_updated` describes the data, not the response.**

```js
// ✗ Non-conforming. Named anti-pattern, observed in production.
last_updated: new Date().toISOString()
```

The feed then always reads as fresh. A stalled pipeline is indistinguishable
from a healthy one — which is **worse than having no timestamp at all**, since
a missing signal is detectable and a lying one is trusted.

```js
// ✓ From the data's own high-water mark.
const lastUpdated = rows.reduce(
  (max, row) => (row.updated_at > max ? row.updated_at : max),
  rows[0]?.updated_at ?? BUILD_TIME
);
```

If the rows carry no timestamp at all, use the build time — inject it as a
constant at build, not read at request. An empty feed's `last_updated` is the
build time too: "there are no places" is a fact with a date, not an absence.

## Next.js App Router

```ts
// app/cabuya/places.json/route.ts
//
// Cabuya place feed. See CABUYA.md.

import { NextResponse } from 'next/server';

import { prisma } from '@/lib/prisma';

const PUBLISHER_ID = 'example-app';
const SITE = 'https://example.org';
const MUNICIPALITY_CODE = '66001'; // DIVIPOLA — verify against the DANE table

// Revalidate on a schedule rather than per request. The feed's ttl and this
// number are the same contract stated twice; keep them in step.
export const revalidate = 900;

export async function GET() {
  const rows = await prisma.shelter.findMany({
    // Select explicitly. A later migration adding `phone` must not silently
    // widen the feed.
    select: {
      id: true,
      name: true,
      category: true,
      address: true,
      lat: true,
      lon: true,
      isActive: true,
      updatedAt: true,
      confirmedAt: true,
    },
  });

  const places = rows.map((row) => ({
    id: String(row.id),
    publisher_id: PUBLISHER_ID,
    name: row.name,
    place_kind: KIND[row.category] ?? 'other',
    origin_category: row.category,
    municipality_code: MUNICIPALITY_CODE,
    address_text: row.address,
    ...(row.lat != null && row.lon != null && { lat: row.lat, lon: row.lon }),
    lifecycle_status: row.isActive ? 'active' : 'closed',

    // This app HAS a confirmation event, so it maps. If it did not, the value
    // would be null — never row.updatedAt (CR-1: an edit is not a
    // confirmation).
    last_confirmed_at: row.confirmedAt?.toISOString() ?? null,
    confirmed_by: 'team', // a role token, never a person's name

    updated_at: row.updatedAt.toISOString(),
    source: { source_id: PUBLISHER_ID, source_kind: 'first_party' },
    public_url: `${SITE}/albergues/${row.id}`,
  }));

  const lastUpdated = rows.reduce<Date | null>(
    (max, row) => (!max || row.updatedAt > max ? row.updatedAt : max),
    null
  );

  return NextResponse.json(
    {
      last_updated: (lastUpdated ?? new Date(BUILD_TIME)).toISOString(),
      ttl: 900,
      version: '0.1.0',
      publisher_id: PUBLISHER_ID,
      license: 'CC-BY-4.0',
      permitted_use: ['display', 'aggregate', 'ai_answer'],
      data: { places },
    },
    {
      headers: {
        // The one non-obvious MUST. On this route specifically — do not widen
        // a global CORS rule that also covers person-data endpoints.
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'public, max-age=900',
      },
    }
  );
}
```

**Check `middleware.ts`.** A broad `matcher` will intercept this route and the
manifest. That is the same soft-404 family of problem as an SPA catch-all, and
it is invisible until somebody outside your site tries to fetch it.

## Laravel

```php
<?php
// routes/web.php
Route::get('/cabuya/places.json', [CabuyaController::class, 'places']);
```

```php
<?php
// app/Http/Controllers/CabuyaController.php

namespace App\Http\Controllers;

use App\Models\Albergue;
use Illuminate\Http\JsonResponse;

class CabuyaController extends Controller
{
    private const PUBLISHER_ID = 'example-app';
    private const SITE = 'https://example.org';
    private const MUNICIPALITY_CODE = '66001'; // DIVIPOLA — verify with DANE

    public function places(): JsonResponse
    {
        $rows = Albergue::query()
            ->select(['id', 'nombre', 'tipo', 'direccion', 'activo', 'updated_at'])
            ->get();

        $places = $rows->map(fn ($a) => [
            'id' => (string) $a->id,
            'publisher_id' => self::PUBLISHER_ID,
            'name' => $a->nombre,
            'place_kind' => self::KINDS[$a->tipo] ?? 'other',
            'origin_category' => $a->tipo,
            'municipality_code' => self::MUNICIPALITY_CODE,
            'address_text' => $a->direccion,
            'lifecycle_status' => $a->activo ? 'active' : 'closed',
            // Present and null. Omitting the key would be non-conforming.
            'last_confirmed_at' => null,
            'source' => ['source_id' => self::PUBLISHER_ID, 'source_kind' => 'first_party'],
            'public_url' => self::SITE . '/albergues/' . $a->id,
        ])->all();

        return response()
            ->json([
                // The data's high-water mark, not now().
                'last_updated' => $rows->max('updated_at')?->toIso8601ZuluString()
                    ?? config('cabuya.build_time'),
                'ttl' => 900,
                'version' => '0.1.0',
                'publisher_id' => self::PUBLISHER_ID,
                'license' => 'CC-BY-4.0',
                'permitted_use' => ['display', 'aggregate'],
                'data' => ['places' => $places],
            ])
            // On this route only. A global CORS middleware that also covers
            // person-data endpoints is how the exclusion becomes theoretical.
            ->header('Access-Control-Allow-Origin', '*');
    }
}
```

## Before you call it done

- Request the feed twice, a minute apart, without changing any data.
  **`last_updated` must be identical.** If it moved, you have shipped BEH002.
- `curl -I` the feed and confirm the CORS header is present.
- Confirm the route is not shadowed by middleware or a catch-all.
