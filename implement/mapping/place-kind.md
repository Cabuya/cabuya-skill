# Mapping the app's categories onto `place_kind`

The machine-readable crosswalk is vendored at
[`../../spec/vocab/place-kind-crosswalk.json`](../../spec/vocab/place-kind-crosswalk.json),
with the reasoning in
[`../../spec/vocab/equivalence-dictionary.md`](../../spec/vocab/equivalence-dictionary.md).
**Read the JSON rather than trusting this page** — it is the vendored,
checksummed artefact and it carries per-publisher rows with evidence. This page
is how to use it.

## Why this exists at all

Production write paths **without** a shared vocabulary have been observed
destroying the two most decision-critical categories in a disaster: water
collapsed into food, shelter collapsed into "other". No two apps' category
enums in this ecosystem are compatible, and none is a superset of another —
which is why a shared closed vocabulary is the only way a consumer can act on
type at all.

## The eleven canonical values

```
collection_center   shelter        hospital       health_post    water_point
food_point          distribution_point            warehouse      info_point
command_post        other
```

That is the whole enum. It is deliberately small.

## The procedure

1. **Look up the publisher in the crosswalk JSON.** If the app is one of the
   ecosystem's known publishers, its category mapping is already recorded,
   with evidence, and you should use it rather than re-deriving one.
2. **Map each category to a canonical value.**
3. **Always populate `origin_category` with the app's raw value, verbatim.**
   Every time, even when the mapping is obvious. It preserves what the enum
   loses and it makes the crosswalk auditable after the fact — without it, a
   wrong mapping is undetectable downstream.
4. **A kind the enum does not carry maps to `other` plus a namespaced
   `place_kind_ext`** — never silently into a near-neighbour bucket. Pet-care
   points and open businesses are the recurring real examples:

   ```json
   { "place_kind": "other",
     "place_kind_ext": "x_example_pet_point",
     "origin_category": "mascotas" }
   ```

   Recurring extension kinds are 0.2 enum candidates, via RFC. That is the
   route by which the vocabulary grows — not by widening a mapping locally.

5. **A category that is not a place at all does not map.** Several of the
   ecosystem's category enums mix entities: needs, offers, rental notices,
   damage reports. Those are 0.2 entities and they do not belong in a `place`
   feed. Exclude them and say so.

## Three cases that need a human

**A category that is person-level.** `Buscan`, `missing`, and anything else
naming people, is **excluded by §7.1** — not deferred to 0.2, excluded
permanently. Do not map it, do not extension-map it, and say which rule you
are refusing under.

**A category that is really several kinds.** One observed value covers
collection centres, shelters *and* command posts in a single string. It is not
resolvable without the publisher. Ask; if the app has the distinction anywhere
else, use it; if it does not, `place_kind_secondary[]` carries the genuine
multi-function cases, and the rest need a human. Do not guess the modal value.

**A category whose polarity is inverted.** `hidratacion_necesita` — a place
that *needs* water — is not the same claim as a place that *provides* it.
Map to the kind, preserve the polarity in `origin_category`, and flag it. If
the app's list is mostly need-shaped, the honest answer may be that its
categories are a needs vocabulary reused for places, and the mapping should
come from the underlying place object instead.

## A recorded editorial tension

The founding crosswalk tables use `health_point`, `pet_point` and
`open_business` for some targets. The ratified schema enum carries
`health_post` and no pet or business kinds.

**Follow the schema** — it is the normative artefact. `health_point` →
`health_post`; pet and business kinds → `other` + a namespaced extension,
pending a 0.2 RFC. This is recorded rather than hidden because it is exactly
the sort of drift that becomes invisible once someone "just fixes" one side.

## Where corrections live

Crosswalks live **in the registry layer, not in feeds**, so a correction never
requires a publisher to redeploy. Lossy joins are flagged in the registry
rather than silently applied. If you find a mapping in the vendored JSON that
is wrong, that is a registry pull request in `Cabuya/cabuya.org` — not an edit
to the vendored file, which would fail the integrity check for good reason.
