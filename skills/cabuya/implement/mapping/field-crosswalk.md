# App field → `place` field

The authoritative field list is the vendored schema,
[`../../spec/schemas/place-feed.schema.json`](../../spec/schemas/place-feed.schema.json).
This file is how you get from a real database to it.

**Two on-ramps.** An existing app maps what it has: build the crosswalk below,
column by column. A **new or adaptable app** starts from
[`reference-model.md`](reference-model.md) instead — organize the internal
model along its five recommendations and the crosswalk becomes nearly the
identity function.

`REQ`: **R** = required in Core · **C** = conditionally required · **O** =
optional · **E** = Extended profile.

## Identity and classification

| `place` field | REQ | What it is | Where it usually comes from |
|---|---|---|---|
| `id` | **R** | The publisher's stable identifier, unique within the publisher. Opaque to consumers. | The table's primary key, unchanged. Int, UUID, hex — all conform as-is. **MUST NOT embed personal data.** |
| `publisher_id` | **R** | The registry-assigned publisher token. | A constant. If the app is not registered yet, use the token it will request and note that `publish-status` confirms it. |
| `name` | **R** | The name of the place, as the publisher holds it. | `nombre`, `name`, `titulo`. **MUST NOT encode operational state** — see CR-2 below. |
| `place_kind` | **R** | One of eleven enum values. | The app's category column, through [`place-kind.md`](place-kind.md). |
| `place_kind_secondary[]` | O | When a place genuinely serves two functions — a shelter that is also a collection centre. | A multi-select category, if the app has one. |
| `place_kind_ext` | O | Namespaced token for a kind the enum lacks, e.g. `x_example_pet_point`. Always with `place_kind: "other"`. | A category with no canonical target. |
| `origin_category` | O | **The publisher's own category value, verbatim, untranslated.** | The raw column. Always map this when you map `place_kind` — it preserves what the enum loses and makes the crosswalk auditable afterwards. |
| `description` | O | Free text. | `descripcion`, `notas`. **Screen it in Phase 2** — free text is the third leak channel. |

### CR-2 — status does not belong in the name

`"Coliseo Mayor (LLENO)"` is non-conforming. Operational state in a display
string is unreadable to every consumer, rendered by every consumer, and
survives every status change.

If the app's names carry state, **do not silently strip it** — that is
inventing data in the other direction. Flag it in Phase 1, propose the split
(`name: "Coliseo Mayor"` + `service_status: "full"`), and let the human
confirm the mapping of each marker.

## Location

| `place` field | REQ | What it is | Where it usually comes from |
|---|---|---|---|
| `municipality_code` | **R** | DIVIPOLA code, 5 digits. The scoping key for place identity. | See [`divipola.md`](divipola.md). Often a constant for a single-city app. |
| `municipality_text` | O | The publisher's raw municipality string, preserved for audit. | The raw column, verbatim — **including the dirty values**. That is what it is for. |
| `address_text` | **C** | Street address, or an unambiguous reference ("junto a la cancha del parque principal"). | `direccion`, `address`, `ubicacion`. |
| `neighborhood_text` | O | Barrio, verbatim. Uncontrolled by design in 0.1. | `barrio`, `comuna`. |
| `lat` / `lon` | **C** | WGS 84 decimal degrees, ideally 6 decimal places. | Separate columns, a PostGIS point, or a `[lat, lng]` array. |
| `geo_precision` | O | `exact` \| `approximate` \| `centroid` \| `unknown`. | Map it if the app distinguishes; **approximate is not the same as absent**, and saying which is useful. |

> **The locator rule:** every record MUST carry `address_text` **or** both
> `lat` and `lon`. Both is recommended. **Neither is non-conforming** — and a
> record with neither must be reported, not emitted.
>
> Coordinates are deliberately not required instead: in the ecosystem's
> best-specified dataset only 78 of 214 points (36 %) carry them, so requiring
> them would discard two thirds of the reference implementation. Address
> matching, meanwhile, succeeded on 100 % of observed duplicate cases where
> name matching failed — which is why the locator is required at all.

### Mapping location columns honestly

Location is what lets a record travel: a consumer in another city renders
`{name} — by {publisher} · {municipality_text}, {neighborhood_text}`, so what
you map here is what every downstream reader will show.

- **Free-text city column only** (`ciudad`, `municipio`, no code): map it
  verbatim to `municipality_text` and set `municipality_code: null` — the
  schema's escape hatch (a `null` code requires the text). Resolve codes
  later via [`divipola.md`](divipola.md); **never guess a code**.
- **Neighborhood** (`barrio`, `comuna`): `neighborhood_text`, verbatim,
  dirty values included — it is uncontrolled by design in 0.1.
- **Never claim a precision you don't have:** a map-click pin is
  `geo_precision: "approximate"`; a geocoded address is `"centroid"` or
  `"approximate"` per the geocoder's own answer; only device GPS or a
  surveyed point is `"exact"`; and `"unknown"` is honest. Manufacturing
  `"exact"` from a geocoder does downstream harm the same way mapping
  `updated_at` into `last_confirmed_at` does (CR-1).

## Status — three orthogonal axes

| `place` field | REQ | Values | Notes |
|---|---|---|---|
| `lifecycle_status` | **R** | `active` \| `closed` \| `planned` \| `unknown` | Does this place exist as an aid point at all? A boolean `activo` maps cleanly; anything absent maps to `unknown`, **not** to `active`. |
| `service_status` | O | `open` \| `full` \| `paused` \| `unknown` | Can it take what you are bringing right now? Separate axis, because a shelter can be `active` **and** `full`. |
| `closed_at` | O | timestamp | When it stopped operating, if known. |
| `expires_at` | O | timestamp | For inherently temporary places, after which the record should be treated as unconfirmed. |
| *moderation* | — | **no field exists** | A publisher's internal trust verdict has nowhere to go, by design. Suppressed records are **omitted from the feed**, never labelled — a "flagged as false" travelling downstream is a defamation-shaped risk carried by whoever displays it. |

## Verification and freshness — the trust core

| `place` field | REQ | Notes |
|---|---|---|
| `last_confirmed_at` | **R** | timestamp **or `null`**. When a human last confirmed the place was there and operating as described. **The key must always be present; `null` is legal and honest.** Omitting it is non-conforming. |
| `confirmed_by` | O | A **role token**: `team`, `volunteer`, `official_source`, `partner:{publisher_id}`. **Never a person's name.** |
| `confirmation_method` | O | `in_person` \| `phone` \| `official_source` \| `partner_report` \| `user_report` \| `unverified`. |
| `confirmations_24h` | O | Distinct positive confirmations in the last 24 h. |
| `contradictions_active` | O | Active reports that the place was **not** there. |
| `last_reported_absent_at` | O | When somebody last reported "ya no está". Negative confirmation is first-class — a place can be `active` per the publisher and carry a recent absence report, and a consumer must be able to show that tension. |
| `updated_at` | O | When the record last changed, for any reason. |
| `published_at` | O | When the record first appeared. |

### CR-1 — the mapping mistake that matters most

**`updated_at` and `last_confirmed_at` do not interconvert.** An edit is not a
confirmation.

Almost every app has an `updated_at`. Almost none has a confirmation event.
Mapping the first into the second is the single most tempting shortcut in this
whole flow, and it manufactures a trust signal out of edit noise — every
consumer downstream will render "confirmed 2 hours ago" because somebody fixed
a typo.

**If the app has no confirmation concept, `last_confirmed_at` is `null`.** That
is a conforming feed. A live shelter shipping with `ultima_validacion: null`
already exists in production, and it is the honest value, not a bug.

## Provenance — structured, never prose

| `place` field | REQ | Notes |
|---|---|---|
| `source` | **R** | `{ source_id, source_url?, retrieved_at?, source_kind? }`. For first-party data: `{source_id: "<your publisher_id>", source_kind: "first_party"}`. |
| `source_authority` | O | `government` \| `ngo` \| `community` \| `volunteer` \| `commercial`. A municipal record carries authority a volunteer record does not, and consumers should render that honestly. |
| `attribution_required` | O | Mirrors the publisher's licence terms at record level. |

> `source` is structured rather than free text **because a free-text
> provenance field leaked publisher personal names in production**, in an
> otherwise careful open API. An id that refers to a registry entry cannot
> contain a person's name. If the app has a prose `fuente` column, map it to
> `source.source_id` only if it is a token; otherwise flag it in Phase 2.

## Linking out — and what never travels

| `place` field | REQ | Notes |
|---|---|---|
| `public_url` | **R** | The canonical human-facing page for this record at the origin. Usually derived: `https://example.org/lugares/{id}`. |
| `contact_available` | O | Boolean. Carries the **fact** that the origin holds a contact route — never the value. |
| `institutional_contact` | **E** | Extended only, and only for an **organization's** number or address. Never a natural person's. |
| `media[]` | **E** | URLs referencing media **at the origin**. Consumers must reference, never mirror, so a takedown propagates. |

**Nothing else about contact travels.** Not `telefono`, not `whatsapp`, not
`email`, and not `x_yourapp_phone` — a namespaced extension is for a field the
vocabulary lacks, not an exemption from §7.2.

## Cross-reference

| `place` field | REQ | Notes |
|---|---|---|
| `same_as[]` | O | Fully-qualified ids (`{publisher_id}:{id}`) **claimed** to be the same physical place. A claim, never an authority; one-hop, non-transitive. |
| `merged_into` | O | Superseded by another record **from the same publisher**. |
| `cluster_size` | **E** | When a record is the product of automatic clustering, how many observations it represents. |

## Extended profile

Map these only if the app genuinely has them. Do not reach.

`capacity_total` / `capacity_used` (the occupancy model — exactly what
somebody deciding where to send a family needs) · `needs[]`
(`{category, priority, quantity?, unit?}`) · `hours_text` (free text in 0.1,
deliberately) · `languages[]` (BCP 47) · `accessibility_text` ·
`warning_text` (a publisher-authored caution — **screen it in Phase 2**, it is
free text).

## Fields the app has and the protocol does not

Three honest destinations, in order of preference:

1. **`origin_category`** — for the raw category value. Always.
2. **`x_{publisher}_{field}`** — a namespaced extension. Always allowed;
   unknown members must be preserved by consumers and must not fail
   validation. **Not for contact data.**
3. **Nothing.** Leave it out. Not every column belongs in a public feed, and
   the ones that most want to be there are often the ones Phase 2 flagged.

Recurring extensions become candidates for a 0.2 Profile, via RFC.
