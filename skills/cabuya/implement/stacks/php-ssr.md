# PHP, server-rendered — Laravel and plain

Often on shared hosting, often with Apache, and with one failure mode that
belongs to no other stack: **the host refuses to serve a dot-directory at
all**, and the deploy does not warn you.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.**

## 1. Fingerprints

```
composer.json                              → PHP
artisan + app/Models/ + routes/web.php     → Laravel
public/index.php + .htaccess               → a front controller, and the trap
public/ as document root                   → placement usually just works
```

Plain PHP without a framework is common in this family and is not a lesser
case. It reaches L2 the same way, often faster, because there is no routing
layer to fight.

## 2. Where the data lives

1. **`database/migrations/`** — authoritative. The columns are here, with
   types and nullability, in the order they were added.
2. **`app/Models/*.php`** — read `$fillable`, `$hidden` and `$casts`.
   **`$hidden` is a gift**: it lists the fields the team already decided should
   not leave the application. Treat every one of them as PII-gate input.
3. **Existing API resources** — `app/Http/Resources/`. If one exists, somebody
   has already thought about what is public.
4. **`SHOW COLUMNS`**, for a legacy database with no migrations.

```bash
ls database/migrations/ | tail -20
grep -rn 'protected \$hidden\|protected \$fillable' app/Models/
```

## 3. The mapping worksheet

```
Mapping: Albergue → place (Core profile)

  place field           ← column              notes
  ───────────────────── ───────────────────── ──────────────────────────────
  id                    ← id                  auto-increment int, fine as-is
  publisher_id          ← (constant)          registry token
  name                  ← nombre
  place_kind            ← tipo                see mapping/place-kind.md
  origin_category       ← tipo                verbatim
  municipality_code     ← (constant) 66001    verify — mapping/divipola.md
  address_text          ← direccion
  lifecycle_status      ← activo              tinyint(1) → active | closed
  last_confirmed_at     ← ???                 usually null in this stack
  source                ← (constant)
  public_url            ← (derived)
```

Watch the timestamps. Laravel gives every model `created_at` and `updated_at`
for free, which means **`updated_at` always exists and never means
confirmation**. It is the most available wrong answer in this stack. Map it to
`updated_at`, and leave `last_confirmed_at` as `null` unless there is a real
confirmation event.

## 4. The PII gate here

- **`$hidden` on the model.** Everything in it, without exception. The team
  already decided.
- **A `contacto` or `telefono` column on the place table.** Very common; the
  admin panel uses it. It does not travel.
- **`users` and any `created_by` foreign key.**
- **Eloquent's default `toArray()`.** `return response()->json($albergues)`
  serializes **every** attribute, including ones added by a later migration.
  This is the leak in this stack: it works, it is one line, and it widens
  silently. Map explicitly, always.
- **`with()` eager loads.** Same problem as Prisma's `include`.

Present the table, then **stop**.

## 5. The serializer

### Laravel

```php
<?php
// routes/web.php
//
// Registered before any SPA fallback route. Order decides who answers.
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
    private const SITE = 'https://example.invalid';
    private const MUNICIPALITY_CODE = '66001'; // DIVIPOLA — verify with DANE

    private const KINDS = [
        'albergue' => 'shelter',
        'acopio' => 'collection_center',
    ];

    public function places(): JsonResponse
    {
        $rows = Albergue::query()
            // Explicit columns. `Albergue::all()` plus `toArray()` would
            // serialize every attribute, including whichever one the next
            // migration adds.
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

            // No confirmation event in this app. Present and null.
            'last_confirmed_at' => null,

            'updated_at' => $a->updated_at?->toIso8601ZuluString(),
            'source' => [
                'source_id' => self::PUBLISHER_ID,
                'source_kind' => 'first_party',
            ],
            'public_url' => self::SITE . '/albergues/' . $a->id,
        ])->all();

        return response()
            ->json([
                // The data's high-water mark, never now().
                'last_updated' => $rows->max('updated_at')?->toIso8601ZuluString()
                    ?? '1970-01-01T00:00:00Z',
                'ttl' => 900,
                'version' => '0.1.0',
                'publisher_id' => self::PUBLISHER_ID,
                'license' => 'CC-BY-4.0',
                'permitted_use' => ['display', 'aggregate'],
                'data' => ['places' => $places],
            ])
            // This route only. A global CORS middleware covering person-data
            // endpoints is how the exclusion becomes theoretical.
            ->header('Access-Control-Allow-Origin', '*');
    }
}
```

### Plain PHP

```php
<?php
// public/cabuya/places.json.php  (or a static file written by a cron script)

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

const PUBLISHER_ID = 'example-app';
const SITE = 'https://example.invalid';

$pdo = new PDO($dsn, $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

// Named columns. `SELECT *` is the same trap in every language.
$stmt = $pdo->query(
    'SELECT id, nombre, tipo, direccion, activo, updated_at FROM albergues'
);

$places = [];
$lastUpdated = null;

foreach ($stmt as $row) {
    if ($lastUpdated === null || $row['updated_at'] > $lastUpdated) {
        $lastUpdated = $row['updated_at'];
    }
    $places[] = [
        'id' => (string) $row['id'],
        'publisher_id' => PUBLISHER_ID,
        'name' => $row['nombre'],
        'place_kind' => KINDS[$row['tipo']] ?? 'other',
        'origin_category' => $row['tipo'],
        'municipality_code' => '66001',
        'address_text' => $row['direccion'],
        'lifecycle_status' => $row['activo'] ? 'active' : 'closed',
        'last_confirmed_at' => null,
        'source' => ['source_id' => PUBLISHER_ID, 'source_kind' => 'first_party'],
        'public_url' => SITE . '/albergue.php?id=' . $row['id'],
    ];
}

echo json_encode([
    'last_updated' => gmdate('Y-m-d\TH:i:s\Z', strtotime($lastUpdated ?? '@0')),
    'ttl' => 900,
    'version' => '0.1.0',
    'publisher_id' => PUBLISHER_ID,
    'license' => 'CC-BY-4.0',
    'permitted_use' => ['display', 'aggregate'],
    'data' => ['places' => $places],
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
```

`JSON_UNESCAPED_UNICODE` matters here: without it every `ñ` and every accent
becomes a `\uXXXX` escape. Still valid JSON, still parses — but unreadable to
the human who has to debug the feed, in a country where the place names carry
accents.

## 6. The manifest and the catch-all

From [`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md):

> **Laravel** — Register the route before the SPA fallback, or drop the file
> under `public/.well-known/` — Laravel serves that directory directly.
>
> **PHP / Apache** — Add `RewriteCond %{REQUEST_URI} !^/\.well-known/` above
> the front-controller rule in `.htaccess`. Without it the router answers,
> with a 200 and HTML.

```apache
# public/.htaccess — above the front-controller rule.
RewriteEngine On

RewriteCond %{REQUEST_URI} !^/\.well-known/
RewriteCond %{REQUEST_URI} !^/cabuya/
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [L]
```

### The dot-directory problem

**Some shared hosts refuse any path segment beginning with a dot**, at the
server config level, above your `.htaccess`. The file exists, the permissions
are right, and the request 403s or 404s.

This is not a bug to work around silently — it is exactly why §2 makes the
well-known path RECOMMENDED rather than required. When it happens:

1. Serve the manifest from a plain path: `/cabuya.json`.
2. Declare that path in the registry entry. **The registry entry is the
   authoritative pointer**; the well-known path is only the convention.
3. Add the fallback to the site's `<head>`:
   ```html
   <link rel="cabuya" href="/cabuya.json">
   ```

A publisher using the fallback is fully conforming. Two of twenty observed
hosts could not serve a well-known path honestly, which is why the fallback is
in the specification rather than in a troubleshooting page.

## 7. The validator loop

| Finding | What it means in this stack |
|---|---|
| Manifest 403 or 404, file present | The host is blocking dot-directories. Use the plain-path fallback. |
| Manifest returns HTML | The front-controller rule is above the exclusion in `.htaccess`, or `mod_rewrite` order. |
| CORS header missing | Set per route. Some shared hosts strip headers set from PHP — set it in `.htaccess` instead. |
| Personal data detected | Almost always `toArray()` on a model, or a `$hidden` field that stopped being hidden. |
| Accented characters mangled | Missing `JSON_UNESCAPED_UNICODE`, or a connection charset that is not `utf8mb4`. |
| `last_updated` is 1970 | The table is empty, or `updated_at` is null across the board. Say which; both are real answers. |

Eight iterations maximum, then stop and summarize.

## 8. Hand-off

Left behind: the controller or script, the route registration, the `.htaccess`
change, `public/.well-known/cabuya.json` (or the plain-path fallback plus the
`<link rel>`), and a filled-in `CABUYA.md`.

**Record the fallback decision in `CABUYA.md` if you used it**, with the reason.
The next person will otherwise "fix" the path back to the well-known one and
break discovery.
