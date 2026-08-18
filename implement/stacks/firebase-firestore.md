# Firebase (Firestore + Hosting)

The volunteer-built shape: a Firestore database, Firebase Hosting in front,
often no server at all — the browser reads Firestore directly and security
rules are the only boundary. The discovery trap is the hosting rewrite, and
the PII risk is structural: Firestore documents grow fields freely, so the
collection almost certainly holds more than the UI shows.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.** Instructions cite the Firebase documentation
(<https://firebase.google.com/docs/hosting>).

## 1. Fingerprints

```
firebase.json              ← the signal, and where the trap lives
.firebaserc                  project aliases
firestore.rules              the real access-control story
functions/ (optional)        Cloud Functions, if a server exists at all
```

`firebase.json`'s `hosting.rewrites` is the first thing to read: an SPA here
ships `{ "source": "**", "destination": "/index.html" }` — every unknown
path returns the shell with a 200.

## 2. Where the data lives

Firestore has no schema; reliability comes from what constrains it:

1. **`firestore.rules`** — names the collections and hints at their shape;
   it is also the honest map of what is publicly readable *today*.
2. **Converter/type definitions** — `withConverter`, TypeScript interfaces,
   Zod schemas in the app code.
3. **Query call sites** — `grep -rn "collection(\|doc(" src/`.
4. **Sampled documents** — with the team, in the console. Fields vary per
   document; sample several, and treat every string field as a candidate
   free-text leak channel.

## 3. The mapping worksheet

Against an invented `ayuda_puntos` collection — the real fields will not
match:

```
Mapping: ayuda_puntos → place (Core profile)

  place field           ← document field       notes
  ───────────────────── ────────────────────── ─────────────────────────────
  id                    ← doc.id               stable, opaque — good
  publisher_id          ← (constant)           the registry token
  name                  ← nombre
  place_kind            ← tipo                 see mapping/place-kind.md
  municipality_code     ← municipio_codigo     verify: mapping/divipola.md
  address_text          ← direccion
  lifecycle_status      ← abierto              boolean → active | closed
  last_confirmed_at     ← verificado_en (Timestamp), or null
  source                ← (constant)
  public_url            ← (derived)            the app's detail page URL
```

Firestore's server timestamps (`updatedAt` via `serverTimestamp()`) are edit
timestamps — CR-1 forbids mapping one into `last_confirmed_at`. A real
confirmation event a human recorded, or `null`, on every record.

## 4. The PII gate here

The structural risk: **documents hold what any version of the app ever
wrote.** A `ayuda_puntos` document may carry `contacto`, `telefono`,
`creado_por` (a UID joining to `users`), an operator's note with a number in
it — fields the current UI never renders. So:

- The deny-list runs over **sampled real documents**, not over the interface.
- The export uses an explicit field list; never spread the whole document.
- A UID is a join key to a person. It does not travel, and neither does
  anything `users/{uid}` holds.
- If `firestore.rules` makes the collection publicly readable, say so: the
  feed is not widening access, but the browser-readable collection may
  already include the fields the gate just rejected — flag it to the human
  as its own finding.

## 5. The serializer

A scheduled Cloud Function writing a static file to Hosting via a build, or
— simpler and preferred — an export script run by CI on a schedule, writing
`public/cabuya/places.json` and redeploying Hosting
(<https://firebase.google.com/docs/hosting/full-config>):

```js
// scripts/export-cabuya.mjs  (runs in CI with a service account)
import { writeFile, mkdir } from "node:fs/promises";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp({ credential: cert(process.env.GOOGLE_APPLICATION_CREDENTIALS) });
const db = getFirestore();

const snap = await db.collection("ayuda_puntos")
  .select("nombre", "tipo", "direccion", "municipio_codigo",
          "abierto", "verificado_en")      // explicit list — the gate's teeth
  .orderBy("__name__")
  .get();

const places = snap.docs.map((doc) => {
  const d = doc.data();
  return {
    id: doc.id,
    publisher_id: "example-app",
    name: d.nombre,
    place_kind: kindFor(d.tipo),           // mapping/place-kind.md
    municipality_code: d.municipio_codigo,
    address_text: d.direccion,
    lifecycle_status: d.abierto ? "active" : "closed",
    last_confirmed_at: d.verificado_en ? d.verificado_en.toDate().toISOString() : null,
    source: { source_id: "example-app", source_kind: "first_party" },
    public_url: `https://app.example.invalid/puntos/${doc.id}`,
  };
});

// High-water mark of the data itself, at export time.
const highWater = snap.docs
  .map((d) => d.get("verificado_en"))
  .filter(Boolean)
  .map((t) => t.toDate())
  .sort((a, b) => a - b)
  .at(-1);

const feed = {
  protocol: { name: "cabuya", spec_version: "0.1.0" },
  publisher_id: "example-app",
  last_updated: highWater ? highWater.toISOString() : null,
  ttl: 86400,
  data: { places },
};

await mkdir("public/cabuya", { recursive: true });
await writeFile("public/cabuya/places.json", JSON.stringify(feed, null, 2));
console.log(`wrote ${places.length} places`);
```

A callable/HTTP function that queries Firestore per request is the shape
that fails BEH002 the moment somebody stamps the response with the current
time — and it pays reads on every fetch. Export to a file; let Hosting and
its CDN do what they are for.

## 6. The manifest and the catch-all

`public/.well-known/cabuya.json`, and then the rewrite: Firebase Hosting
serves existing static files **before** applying rewrites
(<https://firebase.google.com/docs/hosting/full-config#rewrites> — "priority
order"), so the file wins if the deploy actually shipped it. Verify by
fetching the deployed URL and checking `Content-Type: application/json` —
a 200 with `text/html` means the shell answered and the manifest is absent.

Headers are scoped in `firebase.json` — on the feed path, not `"**"`:

```json
{
  "hosting": {
    "headers": [
      {
        "source": "/cabuya/**",
        "headers": [
          { "key": "Access-Control-Allow-Origin", "value": "*" },
          { "key": "Content-Type", "value": "application/json" }
        ]
      }
    ]
  }
}
```

Add `robots.txt` to `public/` (200, `text/plain`) — SPA scaffolds usually
have none.

## 7. The validator loop

- **DSC001/DSC002** — the deploy did not include `.well-known` (check
  `hosting.ignore` patterns), or the rewrite answered first. Fetch and read
  the `Content-Type`.
- **BEH002** — someone replaced the export with an HTTP function stamping
  "now". Back to the scheduled export.
- **PII findings** — a sampled document carried a phone in `observaciones`.
  Halt, show the human; also flag whether the public rules expose the same
  field directly.

## 8. Hand-off

Left behind: the export script and its CI schedule, the manifest, the
`firebase.json` headers block, and
[`../templates/CABUYA.md`](../templates/CABUYA.md) filled in. Next step:
`publish-status` — with the human's yes on the registry PR.
