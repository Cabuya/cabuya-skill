# Acceptance run — Claude Code, 2026-08-18

Pack version 0.1.0, vendored spec 0.1.0. Network: not used — every answer
below is cited to a file in the pack.

**Read the honesty note in `docs/ACCEPTANCE_TEST.md` before trusting this
run's score.** It was performed by the session that wrote the pack, which
makes it a check that the answers are present and findable, not a check that a
fresh agent would find them.

---

## Part A

**A1. The five conformance levels.**

- **L0 Listed** — a reviewed registry entry: canonical URL, declared aliases,
  entity domains, crawl/reuse policy.
- **L1 Linked** — publishes the manifest with identity, conformance target,
  `public_url` pattern, licence, `permitted_use`, org-level contact.
- **L2 Publishes** — serves at least one conforming place feed that passes the
  validator at profile Core.
- **L3 Serves & consumes** — serves the read API *or* live-refreshed feeds
  with sync signals, **and** consumes at least one peer feed under the six
  consumption rules.
- **L4 Federates** — accepts writes with `source` + `external_id` idempotency;
  optionally exposes MCP.

Two standing exceptions: directory-only (L0/L1 by choice) and link-out-only
(L0/L1 by rule §7.1).

*Source: `spec/PROTOCOL_SUMMARY.md`, §1 · The conformance ladder.*

**A2. Where the manifest goes, and the fallback.**

`/.well-known/cabuya.json` is RECOMMENDED. **Any stable HTTPS path is
ACCEPTABLE**, provided it is declared in the registry entry and advertised
with `<link rel="cabuya" href="…">` in the site's HTML head. The well-known
path is never a MUST — some volunteer hosts mangle dot-directories. The
registry entry is the authoritative pointer; the well-known path is the
convention.

*Source: `spec/PROTOCOL_SUMMARY.md`, §2 · Discovery.*

**A3. Why `200 + text/html` at a discovery path is treated as absent.**

The soft-404 rule. A single-page app returns its shell for every unmatched
route, so a manifest request gets HTTP 200 and an HTML document — which naive
tooling reads as "the manifest exists" and then fails to parse. The
discriminator is **byte-size equality against `/`**: if the response at the
discovery path is byte-identical in size to the site root, it is the catch-all
shell rather than a document.

*Source: `spec/PROTOCOL_SUMMARY.md`, §2 · The soft-404 rule.*

**A4. The record id format, and why.**

`{publisher_id}:{local_id}`. `publisher_id` is registry-assigned once;
`local_id` is whatever the publisher's database already uses — int, UUID, hex,
all conforming unchanged. The reason for the shape: it is **globally unique
with zero coordination**. No central id service, no allocation protocol, no
migration of anyone's primary keys.

*Source: `spec/PROTOCOL_SUMMARY.md`, §5 · Identifiers.*

**A5. What must never travel in a feed.**

1. **Person-level data** — a join prohibition, not a field omission. Free text
   is the third leak channel.
2. **Contact values** — a record carries `public_url` and links out; a
   namespaced `x_*` extension is not an exemption.
3. **Moderation verdicts** — suppressed records are omitted, never labelled
   downstream.

*Source: `spec/EXCLUSIONS.md` (§7 verbatim), summarised in
`spec/PROTOCOL_SUMMARY.md` §7.*

**A6. `updated_at` versus `last_confirmed_at`.**

CR-1: **an edit is not a confirmation.** The two do not interconvert.
Correcting a typo in an address does not mean anybody checked that the shelter
is still open, and a system treating them as one field will confidently show
stale places as fresh.

*Source: `spec/PROTOCOL_SUMMARY.md`, §6 · CR-1; also
`implement/mapping/field-crosswalk.md`.*

**A7. Omitted `last_confirmed_at` versus `null`.**

The key is REQUIRED on every record and **`null` is legal and honest** — it
means "never confirmed". **Omitting the key is non-conforming.** The
distinction is the point: `null` says nobody has confirmed this, while
omission says nothing at all, and a consumer cannot tell the second from a
publisher who forgot.

*Source: `spec/PROTOCOL_SUMMARY.md`, §6 · Trust and verification.*

**A8. The two production anti-patterns.**

1. **Status encoded in `name` (CR-2)** — `"Coliseo Mayor (LLENO)"` puts
   operational state in a display string, where no consumer can read it, every
   consumer renders it, and it survives every status change.
2. **Always-now `last_updated` (BEH002)** — regenerating the timestamp per
   request so the feed always reads fresh. Worse than no signal at all: a
   missing timestamp is detectable, a lying one is trusted.

*Source: `spec/PROTOCOL_SUMMARY.md`, The two production anti-patterns.*

**A9. The six consumption MUSTs.**

1. **Attribute** — display the origin publisher for every foreign record.
2. **Show age** — render `last_confirmed_at` age, or "sin confirmar" for
   `null`; distinguish past 7 days or `contradictions_active > 0`.
3. **Not mutate** — never alter a foreign record; enrichments go in your own.
4. **Preserve chains** — keep the original `source{}`; your identity goes in
   the envelope `publisher_id`.
5. **Dedupe by claim, not by authority** — `same_as` one-hop, non-transitive,
   plus accent-folded address/DIVIPOLA matching, never raw display strings.
6. **Respect exclusions** — no join with person-level sources; no fetch from a
   publisher whose policy reserves reuse.

*Source: `consume/rules.md`; also `spec/PROTOCOL_SUMMARY.md`, The six
consumption MUSTs.*

**A10. Required envelope fields, and the non-obvious MUST.**

Required: **`last_updated`, `ttl`, `version`, `publisher_id`, `license`.**

The non-obvious requirement is a transport one: **`Access-Control-Allow-Origin: *`
is REQUIRED.** Without it every browser-based consumer needs a proxy. It is the
requirement most first implementations miss, and it is invisible from the
publisher's own site.

*Source: `spec/PROTOCOL_SUMMARY.md`, §3 · The envelope · The non-obvious MUST.*

---

## Part B

**B1. Mapping `albergues` to `place`.**

```
place field           ← column           notes
───────────────────── ────────────────── ─────────────────────────────────
id                    ← id               SERIAL, used as-is
publisher_id          ← (constant)       registry-assigned token
name                  ← nombre           check for status tokens (CR-2)
place_kind            ← (constant)       "shelter" — the table is albergues
origin_category       ← (constant)       "albergue", verbatim
municipality_code     ← (constant)       DIVIPOLA — needs confirming, and
                                         verifying against the DANE table
address_text          ← direccion        the locator
lifecycle_status      ← activo           true → active, false → closed
last_confirmed_at     ← null             this table has no confirmation
                                         event. null is present and honest;
                                         it is NOT mapped from any edit time
source                ← (constant)       {source_id, source_kind:first_party}
public_url            ← (derived)        needs the site's URL pattern
```

Unmapped and needing a human: `municipality_code` (no column — one
municipality, or derived from the address?) and `public_url` (what is the
per-record URL pattern?).

**PII gate — 2 columns need your decision before anything is generated.**

```
  Column        Why flagged
  ───────────── ──────────────────────────────────────────────────────
  telefono      phone column — contact values never travel in a feed
  responsable   name-shaped column — likely a person, not an org

  For each: include as-is / exclude / include transformed (say how).

  My reading, which is not a decision: both are excluded. `telefono` is
  contact data and reaches a user through public_url; `responsable`
  reads as a person's name. But `responsable` could hold an
  organization — I cannot tell from the schema, and the pack does not
  let me decide.
```

**I am stopping here.** I will not generate a serializer, a feed or a manifest
until you answer for both columns by name. There is no flag that skips this.

*Source: `implement/SKILL.md` Phase 1 and Phase 2; `shared/pii-deny-list.md`;
`implement/mapping/field-crosswalk.md`.*

**B2. Violations in `invalid-2-contact-and-personal-data.json`.**

Three violations, three rules:

1. **`data.places[0].x_example_phone`** — a phone number travels in the feed.
   Contact values MUST NOT travel; a namespaced extension is not an exemption.
   Contact is `contact_available` + `public_url`, fetched on demand from the
   origin. **§7.2.**
2. **`data.places[0].confirmed_by`** — carries a person's name instead of a
   role token. It must be `team`, `volunteer`, `official_source` or
   `partner:{publisher_id}`. **§7.1** (person-level data), and §6.1 for the
   field's own rule.
3. **`data.places[0].description`** — free text embedding a personal name and
   a mobile number. Free text is the third leak channel; publishers MUST strip
   personal data before publishing. **§7.1.**

Schema validation alone passes some of these. The deny-pattern pass catches
all three.

*Source: `examples/invalid/invalid-2-contact-and-personal-data.json` (its own
`$comment`), and `spec/EXCLUSIONS.md` §7.1 / §7.2.*

**B3. Refugios Ejemplo — manifest, feed, validation.**

`/.well-known/cabuya.json`:

```json
{
  "protocol": { "name": "cabuya", "spec_version": "0.1.0" },
  "publisher": {
    "publisher_id": "refugios-ejemplo",
    "canonical_url": "https://refugios-ejemplo.invalid"
  },
  "conformance_target": "L2",
  "feeds": [
    {
      "name": "places",
      "url": "https://refugios-ejemplo.invalid/cabuya/places.json",
      "entity": "place",
      "profile": "core"
    }
  ],
  "license": "CC-BY-4.0",
  "permitted_use": ["display", "aggregate"]
}
```

`/cabuya/places.json`:

```json
{
  "last_updated": "2026-08-18T00:00:00Z",
  "ttl": 900,
  "version": "0.1.0",
  "publisher_id": "refugios-ejemplo",
  "license": "CC-BY-4.0",
  "permitted_use": ["display", "aggregate"],
  "data": {
    "places": [
      {
        "id": "7",
        "publisher_id": "refugios-ejemplo",
        "name": "Coliseo Municipal",
        "place_kind": "shelter",
        "municipality_code": "66001",
        "address_text": "Calle 14 con Carrera 8",
        "lifecycle_status": "active",
        "last_confirmed_at": null,
        "source": { "source_id": "refugios-ejemplo", "source_kind": "first_party" },
        "public_url": "https://refugios-ejemplo.invalid/lugares/7"
      }
    ]
  }
}
```

`last_confirmed_at` is **`null`, and present**. Nobody has ever been sent to
confirm this shelter, so `null` is the honest value and the key must still be
there — omitting it would be non-conforming, and inventing a timestamp would
be a fabricated confirmation.

`municipality_code: "66001"` is Pereira's DIVIPOLA code as recorded in the
pack, and the pack marks that code **unverified against the DANE source**. It
needs checking before this ships.

Validated with `bash bin/run-validator.sh validate places.json --no-network`,
which resolved to degraded mode — no validator installed, no network:

> The feed is conformant at L2.

The behavioural probes did not run: **soft-404, CORS and always-now**. Those
three need a deployed URL, and they are what catch a publisher who believes
they have published and has not. Degraded mode also does not implement record
and envelope semantics beyond the schema.

So: Refugios Ejemplo is conforming at L2.

*Source: `bin/run-validator.sh`, `shared/validator.md`,
`implement/templates/manifest.json`, `spec/PROTOCOL_SUMMARY.md` §3.*
