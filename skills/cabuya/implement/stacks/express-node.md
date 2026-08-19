# Express / plain Node service

The stack with the least convention, which makes it the one where detection
must be confirmed rather than assumed: an Express app is a `package.json`, a
router file named whatever the author liked, and a database client that could
be anything. The flow is the same six phases; the work here is finding where
things are.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.** Instructions cite the Express documentation
(<https://expressjs.com/>).

## 1. Fingerprints

```
package.json with "express" in dependencies   ← necessary, not sufficient
server.js | app.js | src/index.ts               with express() called
routes/ or a Router() grep hit
no next.config.*, no vite.config.*              ← distinguishes from the SPAs
```

Confirm with `grep -rn "express()" --include="*.js" --include="*.ts" .` —
a `package.json` mentioning express could be a dependency of a dependency.
State the guess and let the human correct it.

## 2. Where the data lives

In order of reliability:

1. **Migrations** — `migrations/`, `knexfile.js`, `prisma/schema.prisma`,
   `sequelize` models. Whichever exists is authoritative.
2. **Model/schema definitions** — Mongoose schemas
   (`grep -rn "new Schema" .`), Sequelize `define(`, Prisma models.
3. **Query call sites** — `grep -rnE "(query|find|select)\(" src/ routes/`.
4. A sample response from a running instance, if the team provides one.

With MongoDB there may be no schema at all: sample real documents (with the
team, never by connecting yourself) and treat every free-text field as the
third leak channel.

## 3. The mapping worksheet

Against an invented `puntos_de_acopio` collection — the real fields will not
match:

```
Mapping: puntos_de_acopio → place (Core profile)

  place field           ← field                notes
  ───────────────────── ────────────────────── ─────────────────────────────
  id                    ← _id | id             stringified, stable
  publisher_id          ← (constant)           the registry token
  name                  ← nombre
  place_kind            ← tipo                 see mapping/place-kind.md
  municipality_code     ← municipio_codigo     verify: mapping/divipola.md
  address_text          ← direccion
  lifecycle_status      ← activo               boolean → active | closed
  last_confirmed_at     ← ultima_verificacion, or null
  source                ← (constant)
  public_url            ← (derived)            the app's public detail page
```

Mongoose gives every document `updatedAt` when `timestamps: true`; it is an
edit timestamp and CR-1 forbids mapping it into `last_confirmed_at`. A real
confirmation event or `null`, the key present on every record.

## 4. The PII gate here

- **The users collection/table** — and every populated reference to it. An
  Express app that `populate("responsable")` into place documents will
  serialize a person's name and phone unless the projection excludes it.
- **Projection discipline is the gate's enforcement here**: MongoDB's
  `find({}, projection)` and SQL's explicit column list are the same rule —
  name what travels; never pass the whole document to `res.json`.
- **Free text** — `observaciones`, `detalle`, `notas` fields hold typed-in
  phone numbers. Check values.

## 5. The serializer

A build/export script, run by the deploy or a scheduler — not a request
handler, so freshness cannot be manufactured per request:

```js
// scripts/export-cabuya.mjs
import { writeFile, mkdir } from "node:fs/promises";
import { getDb } from "../src/db.js";

const db = await getDb();
const rows = await db
  .collection("puntos_de_acopio")
  .find({}, { projection: {                    // name what travels — only this
    _id: 1, nombre: 1, tipo: 1, direccion: 1,
    municipio_codigo: 1, activo: 1, ultima_verificacion: 1,
  } })
  .sort({ _id: 1 })
  .toArray();

const places = rows.map((r) => ({
  id: String(r._id),
  publisher_id: "example-app",
  name: r.nombre,
  place_kind: kindFor(r.tipo),                 // mapping/place-kind.md
  municipality_code: r.municipio_codigo,
  address_text: r.direccion,
  lifecycle_status: r.activo ? "active" : "closed",
  last_confirmed_at: r.ultima_verificacion?.toISOString() ?? null,
  source: { source_id: "example-app", source_kind: "first_party" },
  public_url: `https://app.example.invalid/puntos/${r._id}`,
}));

// High-water mark: the data's own newest confirmation, at export time.
const highWater = rows
  .map((r) => r.ultima_verificacion)
  .filter(Boolean)
  .sort()
  .at(-1);

const feed = {
  version: "0.1.0",
  publisher_id: "example-app",
  license: "CC-BY-4.0",
  last_updated: highWater ? highWater.toISOString() : null,
  ttl: 86400,
  data: { places },
};

await mkdir("public/cabuya", { recursive: true });
await writeFile("public/cabuya/places.json", JSON.stringify(feed, null, 2));
console.log(`wrote ${places.length} places`);
```

If the data changes faster than deploys, run the same script on a schedule.
Only reach for a live route when the team genuinely needs per-request
freshness — and then `last_updated` still comes from the data's high-water
mark, never from a clock read in the handler (BEH002).

## 6. The manifest and the catch-all

Express serves nothing it is not told to serve, so both discovery files are
explicit — and **route order decides everything**, because Express matches
in registration order (<https://expressjs.com/en/guide/routing.html>):

```js
// BEFORE any app.get("*") / SPA fallback / 404 handler:
app.use("/.well-known", express.static("public/.well-known", {
  setHeaders: (res) => res.type("application/json"),
}));
app.use("/cabuya", express.static("public/cabuya", {
  setHeaders: (res) => {
    res.type("application/json");
    // On the feed route specifically — not app.use(cors()) globally,
    // which would also widen any endpoint that serves person data.
    res.set("Access-Control-Allow-Origin", "*");
  },
}));
```

If the app has `app.get("*", ...)` serving an SPA shell, the manifest must be
registered **before** it, and then verified by fetching: a 200 with
`text/html` is an absent manifest. Serve a real `robots.txt` (200,
`text/plain`) the same way.

## 7. The validator loop

- **DSC001** — the SPA fallback or 404 handler registered before the
  well-known route. Reorder; re-fetch; check `Content-Type`.
- **BEH002** — `last_updated: new Date().toISOString()` in a handler; the
  probe sees the value advance between fetches. Move to the export's
  high-water mark.
- **ENV002 (content type)** — `express.static` without `setHeaders` served
  the JSON as `application/octet-stream` on some hosts. Set it explicitly.

## 8. Hand-off

Left behind: the export script, the two static mounts, the manifest,
`robots.txt` if it was missing, and
[`../templates/CABUYA.md`](../templates/CABUYA.md) filled in. Next step:
`publish-status` — with the human's yes on the registry PR. Stepping up to a
read API later is the same document from a route —
[`../templates/serializer-read-api.md`](../templates/serializer-read-api.md).
