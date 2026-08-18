# `municipality_code` — DIVIPOLA

`municipality_code` is REQUIRED and is the **scoping key for place identity**.
Five digits, DANE's official Colombian territorial coding.

## Why a code and not the string

Because the string does not work, and the evidence is specific: one app holds
*"Coliseo Mayor de Pereira"* **and** *"Coliseo Mayor de Manizales"*, while two
Pereira apps call theirs simply *"Coliseo Mayor"*. Without a municipality key,
a consumer deduping by name merges two buildings 50 km apart.

And because the observed municipality data is dirty in ways a code field
absorbs and a string field propagates: rows filed under Pereira whose address
is in Dosquebradas or in Dagua (Valle del Cauca); `"Pereira cuba"` as a
municipality value; bare numerics `"12"` and `"2"`.

DIVIPOLA specifically, rather than a new key, because the national aggregator
already normalises 257 sources to it. Any protocol introducing a competing
place key makes that system worse, not better.

## Keep the raw string too

```json
{
  "municipality_code": "66001",
  "municipality_text": "Pereira cuba"
}
```

`municipality_text` is optional but you should almost always map it. It is the
audit trail for the code you assigned, and it is where the dirt goes so that
the code stays clean.

## Codes for the Eje Cafetero

> **⚠ These are illustrative and NOT verified against the DANE source.** The
> founding record marks them `unverified` and the vendored equivalence
> dictionary states that codes **MUST be validated against the official DANE
> DIVIPOLA table before use**. They are reproduced here to make the shape and
> the department prefixes concrete — not to save you the check.

| Municipality | Department | Code (illustrative) |
|---|---|---|
| Pereira | Risaralda | `66001` |
| Dosquebradas | Risaralda | `66170` |
| Santa Rosa de Cabal | Risaralda | `66682` |
| La Virginia | Risaralda | `66400` |
| Manizales | Caldas | `17001` |
| Cartago | Valle del Cauca | `76147` |

The first two digits are the department (`66` Risaralda, `17` Caldas, `76`
Valle del Cauca), the last three the municipality. A department capital is
conventionally `001`.

## Verifying a code

Do this once per adopter; it takes a few minutes and it is the difference
between a required field being right and being plausible.

1. Get the current **DIVIPOLA** table from DANE (published as a spreadsheet;
   search "DANE DIVIPOLA códigos municipios"). Use the official source, not a
   third-party mirror — municipality codes change with administrative
   reorganisations, and mirrors go stale.
2. Match on the municipality **and** department name. Municipality names
   repeat across departments in Colombia; the pair is what is unique.
3. Record where you got it and when, in the adopter's `CABUYA.md`.
4. If you **cannot** verify — no network, no access — then say the code is
   unverified rather than presenting it as checked. An unverified code that is
   labelled unverified is a task for later; one presented as verified is a
   defect nobody will look for.

## Single-city apps

Most adopters in this ecosystem serve one municipality, so
`municipality_code` is a constant in the serializer. That is fine and normal —
but write it as a named constant with the source of the code in a comment,
not as a bare string in the middle of a mapping function. The day the app
expands to a second municipality, that constant is the thing that needs to
become a column.

## When the app has no municipality data at all

It is a required field, so it must come from somewhere:

- **One municipality served** → a constant. Confirm with the human.
- **Several, derivable from the address** → derive it, but flag the records
  where the derivation was ambiguous rather than picking the most common
  answer.
- **Several, not derivable** → those records cannot be Core-conforming. Report
  them; do not assign a code you are guessing. A wrong municipality code is
  worse than a missing record: it makes a record findable in the wrong place,
  by someone who needs it now.
