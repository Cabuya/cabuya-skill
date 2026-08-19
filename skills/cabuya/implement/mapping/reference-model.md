# The reference data model — for apps still being built

**Non-normative, and says so up front:** the specification requires only what
you publish — the manifest and the feed. Nothing here is a conformance
requirement, and an app that ignores this file entirely can still reach L2.
This file exists for the other case: the app is being built right now, or can
adapt, and its team would rather organize the data so that publishing is
nearly free. Follow the five recommendations and the crosswalk in
[`field-crosswalk.md`](field-crosswalk.md) becomes close to the identity
function.

The authoritative published shape is the vendored schema,
[`../../spec/schemas/place-feed.schema.json`](../../spec/schemas/place-feed.schema.json).
Where this file and the schema differ, the schema wins.

## 1. Separate what travels from what never travels

Put contact and any person-adjacent data in tables the feed query cannot
reach — different tables, no join key used by the serializer. That makes §7
compliance structural rather than a filter someone can forget
([`../../spec/EXCLUSIONS.md`](../../spec/EXCLUSIONS.md); the deny-list with no
override is [`../../shared/pii-deny-list.md`](../../shared/pii-deny-list.md)).

| Travels (feed tables) | Never travels (separate tables) |
|---|---|
| `places(id, name, kind, municipality_code, …)` | `place_contacts(place_id, phone, email, person_name)` |
| `place_confirmations(place_id, confirmed_at, method, role)` | `volunteers(…)`, `cases(…)`, any person table |

The serializer reads only the left column's tables. There is no query that
touches both sides.

## 2. Shape core entities like the protocol's

Name and type the aid-point table's columns after `place`'s fields where you
have a choice — `place_kind` from the eleven-value enum, three status axes
instead of one overloaded string, `origin_category` kept verbatim. Today the
protocol carries one entity, `place`. Requests and offers (`need`/`offer`)
are **proposed for v0.2 in RFC 0002 — a draft, not shipped**: if you model
them internally, keep them org-level ("shelter X needs 50 blankets", with
`quantity_required`/`quantity_covered` columns) so the proposal, if accepted,
costs you a serializer and not a migration.

| Recommended column | Feed field it becomes |
|---|---|
| `kind` (enum-valued) | `place_kind` |
| `category_raw` (verbatim) | `origin_category` |
| `lifecycle` / `service` (two columns) | `lifecycle_status` / `service_status` |

## 3. Make honesty native

Carry a **real confirmation event** — a `confirmations` table or a
`confirmed_at` column written only when a human verified the place — because
`last_confirmed_at` maps from a confirmation event or is `null`, **never**
from `updated_at` (CR-1 in [`field-crosswalk.md`](field-crosswalk.md)). And
keep status out of names: `name = "Coliseo Mayor"` plus
`service_status = "full"`, never `"Coliseo Mayor (LLENO)"` (CR-2). An app
born with these two habits never hits the two most common conformance
failures.

| Recommended | Instead of |
|---|---|
| `confirmed_at` written by a verification action | reusing `updated_at` |
| `service_status` column | state markers inside `name` |

## 4. Geography as code + text + coordinates + precision, from day one

Store the DIVIPOLA municipality code **and** the raw municipality text, the
neighborhood verbatim, coordinates when you truly have them, and how you got
them (`geo_precision`). This is what lets a record travel: a consumer in
another city renders `{name} — by {publisher} · {municipality_text},
{neighborhood_text}` from these fields alone.

| Recommended column | Feed field |
|---|---|
| `municipality_code` (DIVIPOLA, nullable) | `municipality_code` |
| `municipality_raw`, `neighborhood_raw` | `municipality_text`, `neighborhood_text` |
| `lat`, `lon`, `geo_precision` | same |

## 5. Stable public ids, and a public page per record

The feed's `id` is your primary key, unchanged — so make it stable across
edits and free of personal data from the start
([`../../spec/PROTOCOL_SUMMARY.md`](../../spec/PROTOCOL_SUMMARY.md) §5). And
give every record a canonical human-facing page: `public_url` is REQUIRED,
and it is the entire contact mechanism — the origin page is where a person
lands when another app's button links out.

| Recommended | Feed field |
|---|---|
| Immutable `id` (int, UUID — anything stable) | `id` |
| A route like `/lugares/{id}` | `public_url` |

---

**If the app already exists and cannot adapt:** none of this applies — go
back to [`field-crosswalk.md`](field-crosswalk.md) and map what is there. The
crosswalk exists precisely so no one has to rebuild an app to join the
network.
