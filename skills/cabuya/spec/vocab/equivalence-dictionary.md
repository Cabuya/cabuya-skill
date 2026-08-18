# The equivalence dictionary (vocabulario de equivalencias)

The shared vocabulary crosswalk — the cheapest, highest-leverage
interoperability deliverable (the mesa técnica's roadmap step 1). It exists
because production write paths **without** a shared vocabulary have been
observed destroying the two most decision-critical categories in a disaster
(water collapsed into food; shelter collapsed into "other").

- **Canonical tokens** are `place_kind` values from
  [`place-feed.schema.json`](https://cabuya.org/schemas/0.1/place-feed.schema.json):
  `collection_center` · `shelter` · `hospital` · `health_post` ·
  `water_point` · `food_point` · `distribution_point` · `warehouse` ·
  `info_point` · `command_post` · `other`.
- Kinds a source vocabulary carries that the enum does not (e.g. pet care
  points, open businesses) map to `other` **plus a namespaced
  `place_kind_ext`** (e.g. `x_{publisher}_pet_point`) — never silently into a
  wrong bucket. Recurring ext kinds are v0.2 enum candidates via RFC.
- Crosswalks live **in the registry layer, not in feeds**, so corrections
  never require a publisher redeploy. Lossy joins are marked and MUST be
  flagged in the registry rather than silently applied.
- The machine-readable form is
  [`place-kind-crosswalk.json`](./place-kind-crosswalk.json); per-publisher
  rows with evidence live in the founding record
  (`docs/context/ENTITY_MODEL.md` §4.2).

## Known editorial tension (recorded, not hidden)

The founding crosswalk tables use `health_point`/`pet_point`/`open_business`
for some targets; the ratified schema enum carries `health_post` and no
pet/business kinds. This dictionary follows **the schema** (the normative
artifact): `health_point` → `health_post`; pet and business kinds → `other` +
ext, pending a v0.2 RFC. Flagged for the working group.

## Territorial coding

Municipality coding is **DIVIPOLA** (DANE's official Colombian territorial
key) — adopted because the national aggregation practice already normalizes
to it. Publishers keep their raw string in `municipality_text`; the code
field absorbs observed dirt (wrong-municipality filings, bare numerics).
Codes MUST be validated against the official DANE table — the founding
record's example codes are explicitly marked unverified.
