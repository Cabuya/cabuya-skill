# Build-time export

For static sites, SPAs, and anything without a server. **The default choice.**

A script queries the data source, writes a JSON file into the published
directory, and runs before the build. `last_updated` is the build time, which
is honest by construction — there is no request in which to regenerate it, so
the always-now anti-pattern is not reachable from here.

## Node + Supabase

Runs before `vite build` / `next build`. Writes into `public/`, which every
one of those toolchains copies to the output root — including
dot-directories.

```js
// scripts/build-cabuya-feed.mjs
//
// Generates the Cabuya place feed. Run before the build:
//   "build": "node scripts/build-cabuya-feed.mjs && vite build"
//
// Reads from Supabase, writes public/cabuya/places.json.

import { mkdir, writeFile } from 'node:fs/promises';
import { createClient } from '@supabase/supabase-js';

const PUBLISHER_ID = 'example-app';
const SITE = 'https://example.org';

// DIVIPOLA, DANE's official territorial coding. Verify against the DANE table
// before shipping — see implement/mapping/divipola.md.
const MUNICIPALITY_CODE = '66001'; // Pereira

const supabase = createClient(
  process.env.SUPABASE_URL,
  // The service-role key stays server-side. This script runs at build time,
  // never in the browser.
  process.env.SUPABASE_SERVICE_KEY
);

const KIND_BY_CATEGORY = {
  albergue: 'shelter',
  acopio: 'collection_center',
  agua: 'water_point',
  // A category the enum does not carry maps to `other` plus a namespaced
  // extension — never silently into a near neighbour.
  mascotas: 'other',
};

const KIND_EXT_BY_CATEGORY = {
  mascotas: 'x_example_pet_point',
};

function toPlace(row) {
  return {
    id: String(row.id),
    publisher_id: PUBLISHER_ID,
    name: row.nombre,
    place_kind: KIND_BY_CATEGORY[row.tipo] ?? 'other',
    ...(KIND_EXT_BY_CATEGORY[row.tipo] && {
      place_kind_ext: KIND_EXT_BY_CATEGORY[row.tipo],
    }),
    // The publisher's own value, verbatim. Always. It preserves what the enum
    // loses and makes the crosswalk auditable afterwards.
    origin_category: row.tipo,

    municipality_code: MUNICIPALITY_CODE,
    address_text: row.direccion,
    ...(row.lat != null && row.lon != null && { lat: row.lat, lon: row.lon }),

    lifecycle_status: row.activo ? 'active' : 'closed',

    // CR-1: an edit is not a confirmation. This app has no confirmation event,
    // so the honest value is null — and the KEY MUST STILL BE PRESENT.
    // Mapping row.updated_at here would manufacture a trust signal out of
    // edit noise, and every consumer downstream would render it as freshness.
    last_confirmed_at: null,

    source: { source_id: PUBLISHER_ID, source_kind: 'first_party' },

    // How contact reaches a user without travelling in the feed.
    public_url: `${SITE}/albergues/${row.id}`,
  };
}

const { data: rows, error } = await supabase
  .from('albergues')
  // Select explicitly. `select('*')` will happily carry a `telefono` column
  // into the feed the day somebody adds one.
  .select('id, nombre, tipo, direccion, lat, lon, activo');

if (error) {
  // Fail the build. A feed silently generated from a failed query is worse
  // than no feed: it publishes an empty list as though it were the truth.
  console.error('Cabuya feed: query failed —', error.message);
  process.exit(1);
}

const feed = {
  // Build time, not request time (BEH002).
  last_updated: new Date().toISOString(),
  ttl: 900,
  version: '0.1.0',
  publisher_id: PUBLISHER_ID,
  license: 'CC-BY-4.0',
  permitted_use: ['display', 'aggregate', 'ai_answer'],
  data: { places: rows.map(toPlace) },
};

await mkdir('public/cabuya', { recursive: true });
await writeFile('public/cabuya/places.json', JSON.stringify(feed, null, 2));
console.log(`Cabuya feed: ${feed.data.places.length} places`);
```

## Wiring it in

```json
{
  "scripts": {
    "build": "node scripts/build-cabuya-feed.mjs && vite build"
  }
}
```

## The CORS header

A static file's headers come from the host, not the code. Set it where the
host reads it, and **scope it to the feed path** rather than widening a global
rule that also covers person-data routes.

```
# public/_headers  — Netlify, Cloudflare Pages
/cabuya/*
  Access-Control-Allow-Origin: *
  Content-Type: application/json; charset=utf-8
```

```json
// vercel.json
{
  "headers": [
    {
      "source": "/cabuya/(.*)",
      "headers": [{ "key": "Access-Control-Allow-Origin", "value": "*" }]
    }
  ]
}
```

## Python + Django, same shape

```python
# manage.py export_cabuya_feed  (a management command)
import json
from datetime import datetime, timezone
from pathlib import Path

from django.core.management.base import BaseCommand

from shelters.models import Albergue

PUBLISHER_ID = "example-app"
SITE = "https://example.org"
MUNICIPALITY_CODE = "66001"  # DIVIPOLA — verify against the DANE table


class Command(BaseCommand):
    help = "Generate the Cabuya place feed."

    def handle(self, *args, **options):
        places = [
            {
                "id": str(a.pk),
                "publisher_id": PUBLISHER_ID,
                "name": a.nombre,
                "place_kind": "shelter",
                "origin_category": a.tipo,
                "municipality_code": MUNICIPALITY_CODE,
                "address_text": a.direccion,
                "lifecycle_status": "active" if a.activo else "closed",
                # Present and null: "never confirmed", stated honestly.
                "last_confirmed_at": None,
                "source": {"source_id": PUBLISHER_ID, "source_kind": "first_party"},
                "public_url": f"{SITE}/albergues/{a.pk}",
            }
            for a in Albergue.objects.all()
        ]

        feed = {
            "last_updated": datetime.now(timezone.utc).isoformat(
                timespec="seconds"
            ).replace("+00:00", "Z"),
            "ttl": 900,
            "version": "0.1.0",
            "publisher_id": PUBLISHER_ID,
            "license": "CC-BY-4.0",
            "permitted_use": ["display", "aggregate"],
            "data": {"places": places},
        }

        out = Path("static/cabuya/places.json")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(feed, ensure_ascii=False, indent=2))
        self.stdout.write(f"Cabuya feed: {len(places)} places")
```

## Before you call it done

- Fetch the deployed feed and check `content-type` is `application/json`.
- Fetch it cross-origin, or `curl -I` it, and confirm the CORS header is
  actually there — this is the requirement most first implementations miss,
  and it is invisible from the publisher's own site.
- Confirm `last_updated` changes when you rebuild, and **does not** change
  when you merely re-request.
