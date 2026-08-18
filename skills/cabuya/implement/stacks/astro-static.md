# Astro (and static generators by analogy: Eleventy, Hugo)

The easiest stack in the ecosystem to make conform, because the protocol's
preferred shape — a static feed, generated at build time — is what these
tools already do. There is no catch-all in static output, `last_updated` is
honest by construction, and the whole adoption is usually two files and one
build hook.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.** Instructions cite the Astro documentation
(<https://docs.astro.build/>); the Eleventy/Hugo notes at the end map the
same moves onto their conventions.

## 1. Fingerprints

```
astro.config.mjs | astro.config.ts   ← the signal
src/pages/                             file-based routing
public/                                copied verbatim into dist/
@astrojs/* in dependencies
```

One distinction matters more than the framework: **static output vs an SSR
adapter** (`output: "server"` or an `adapter:` entry in the config). Static
output has no catch-all at all; an SSR adapter reintroduces the discovery
trap through middleware.

## 2. Where the data lives

In order of reliability:

1. **Content collections** — `src/content/` with a `config.ts` schema.
   Authoritative when present: the schema is typed and enforced at build.
2. **Data files** — `src/data/*.json|yaml`, or a CMS fetch in frontmatter.
3. **Query call sites** — `grep -rn "getCollection\|fetch(" src/`.
4. For an external CMS or sheet: the export the site already builds from.

## 3. The mapping worksheet

Against an invented `puntos` collection — the real fields will not match:

```
Mapping: src/content/puntos → place (Core profile)

  place field           ← frontmatter          notes
  ───────────────────── ────────────────────── ─────────────────────────────
  id                    ← slug                 stable while the file exists
  publisher_id          ← (constant)           the registry token
  name                  ← titulo
  place_kind            ← tipo                 see mapping/place-kind.md
  municipality_code     ← municipio            verify: mapping/divipola.md
  address_text          ← direccion
  lifecycle_status      ← estado               frontmatter enum → protocol enum
  last_confirmed_at     ← verificado, or null
  source                ← (constant)
  public_url            ← (derived)            the page the file already renders
```

Git mtime and file `updatedAt` frontmatter are edit timestamps —
CR-1: `last_confirmed_at` is a human's "I checked this place still operates"
or `null`, present on every record.

## 4. The PII gate here

Static sites feel safe and are not:

- **Frontmatter contact fields** — `contacto`, `telefono`, `responsable` in
  content files, put there so the page can render them. The page may; the
  feed may not. The deny-list runs over every frontmatter key and value.
- **The body text** — Markdown bodies hold phone numbers mid-sentence. If
  any body text maps into `description`, check the values.
- **Collaborator data in the repo** — `authors.json`, CODEOWNERS-style
  files. Nothing person-level travels, whatever file it lives in.

## 5. The serializer

An Astro endpoint, built at build time — this is Astro's own mechanism for
non-HTML output (<https://docs.astro.build/en/guides/endpoints/>), and in
static output it runs exactly once per build:

```ts
// src/pages/cabuya/places.json.ts
import { getCollection } from "astro:content";

export async function GET() {
  const puntos = await getCollection("puntos");

  const places = puntos.map(({ slug, data }) => ({
    id: slug,
    publisher_id: "example-app",
    name: data.titulo,
    place_kind: kindFor(data.tipo),            // mapping/place-kind.md
    municipality_code: data.municipio,
    address_text: data.direccion,
    lifecycle_status: data.estado,
    last_confirmed_at: data.verificado?.toISOString() ?? null,
    source: { source_id: "example-app", source_kind: "first_party" },
    public_url: `https://app.example.invalid/puntos/${slug}/`,
  }));

  // High-water mark of the data itself; at build this is also honest as
  // "the moment the data could last have changed".
  const highWater = puntos
    .map((p) => p.data.verificado)
    .filter(Boolean)
    .sort()
    .at(-1);

  return new Response(
    JSON.stringify({
      version: "0.1.0",
      publisher_id: "example-app",
      license: "CC-BY-4.0",
      last_updated: highWater ? highWater.toISOString() : null,
      ttl: 86400,
      data: { places },
    }),
    { headers: { "Content-Type": "application/json" } }
  );
}
```

Only the fields in the map travel — the collection schema may hold more
(including the contact fields the page renders), and this endpoint names
what leaves.

## 6. The manifest and the catch-all

From [`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md):

> Static output has no catch-all, so the file is served as-is. On an SSR
> adapter, confirm the middleware does not rewrite unmatched paths.

The manifest goes in `public/.well-known/cabuya.json` — Astro copies
`public/` verbatim into `dist/`. Then the failure moves to the **host**:
several static hosts hide dot-directories or serve JSON with the wrong
`Content-Type`, so verify by fetching the deployed URL and add the CORS
header per the host's recipe in [`../../spec/CORS.md`](../../spec/CORS.md)
(`_headers` on Netlify/Cloudflare Pages, `vercel.json` headers on Vercel) —
scoped to `/cabuya/*` and `/.well-known/*`, with
`Access-Control-Allow-Origin: *` on the feed, never a site-wide wildcard
block. `robots.txt` lives in `public/` too; verify 200 `text/plain`.

**Eleventy:** the same feed is a template with `permalink:
"/cabuya/places.json"`; `public/`'s role is played by passthrough copy.
**Hugo:** a custom output format writing to `static/`'s output; `static/`
is copied verbatim like Astro's `public/`.

## 7. The validator loop

- **DSC002 (wrong content type)** — the host served `.well-known` JSON as
  text or HTML. Fix the host's headers file, not the JSON.
- **ENV007 (CORS missing)** — the header block was added site-wide or not at
  all. Scope it to the feed path per the host recipe.
- **REC001** — the endpoint skipped `last_confirmed_at` when the frontmatter
  had none. The key is required; `null` is the value.

## 8. Hand-off

Left behind: the endpoint, the manifest in `public/.well-known/`, the host
headers entry, and [`../templates/CABUYA.md`](../templates/CABUYA.md)
filled in. Next step: `publish-status` — with the human's yes on the
registry PR.
