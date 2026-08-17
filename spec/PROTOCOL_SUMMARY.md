# The Cabuya Protocol, 0.1 — distilled

This is the offline payload: everything an agent needs to implement, consume
and reason about the protocol without a network connection. It is **distilled,
not normative**. Where this file and the specification differ, the
specification wins — and where a line is one that must not move, it is not
paraphrased here at all but reproduced verbatim in
[`EXCLUSIONS.md`](EXCLUSIONS.md).

Full text: <https://cabuya.org/developers/spec/0.1>. Provenance of this copy:
[`SOURCE`](SOURCE). Status: **0.1 draft**.

---

## The one-paragraph version

Emergency-aid applications each hold their own list of shelters, collection
centres and service points, and none of them can read each other's. Cabuya
defines one entity — `place` — and four equivalent ways to serve it: a static
feed, a read API, a write API, and MCP. A publisher climbs a five-rung ladder
at whatever pace it can. **Conformance is measured by a published validator
and never self-declared**, because manifests lie and behaviour does not.

---

## §1 · The conformance ladder

A ladder, **not a gate**. Every level is a respected membership class; levels
are cumulative.

| Level | Name | What it requires | Badge |
|---|---|---|---|
| **L0** | Listed | A reviewed registry entry: canonical URL, declared aliases, entity domains, crawl/reuse policy. | `listed` |
| **L1** | Linked | Publishes the **manifest** (§2) — identity, conformance target, `public_url` pattern, license, `permitted_use`, org-level contact. Links out to peers. | `linked` |
| **L2** | Publishes | Serves ≥ 1 conforming **place feed** (§3) that passes the validator at profile `Core`. | `publishes` |
| **L3** | Serves & consumes | Serves the **read API** *or* live-refreshed feeds with sync signals, **and** consumes ≥ 1 peer feed under the six consumption rules. | `interop` |
| **L4** | Federates | Accepts **writes** with `source` + `external_id` idempotency; optionally exposes MCP. | `federates` |

Two standing exceptions, both respected rather than tolerated:

- **Directory-only** — apps whose records are irreducibly personal, or who
  simply choose not to publish. L0/L1 forever, stated plainly.
- **Link-out-only** — people-domain apps. L0/L1 **by rule** (§7.1), not by
  choice.

**Typical effort:** L0 is one pull request. L1 is a static JSON file, under an
hour. **L2 is one afternoon** for a small app — that bar is a design
constraint, not an observation, and a normative change that raises it needs an
RFC naming the cost.

### Preconditions for L2 and above

From observed production failures — the "discovery trap":

- A real `robots.txt` (HTTP 200, `text/plain`).
- **The manifest path excluded from SPA catch-all routing.**

### The HXL/CSV on-ramp (below L2)

An HXL-tagged spreadsheet at a stable URL is an accepted **generator input**.
Conversion tooling produces the conforming feed; conformance is measured on
the produced feed, never on the spreadsheet. **The converter MUST drop contact
columns** unless they are declared institutional.

---

## §2 · Discovery

**A publisher MUST expose a manifest** conforming to `manifest.schema.json`.

**Where it goes.** `/.well-known/cabuya.json` is RECOMMENDED. **Any stable
HTTPS path is ACCEPTABLE**, provided it is declared in the registry entry and
advertised with `<link rel="cabuya" href="…">` in the site's HTML head. The
well-known path is never a MUST — some volunteer hosts mangle dot-directories.
**The registry entry is the authoritative pointer; the well-known path is the
convention.**

**What it carries.** `protocol` (name + `spec_version`), `publisher{}`
(registry `publisher_id`, canonical URL, declared aliases, org-level contact),
`conformance_target` (L0–L4), `feeds[]` (`{name, url, entity, profile}`),
`api{}` (base URL at L3+), `mcp{}`, `license`, `permitted_use[]`,
`crawl_policy_url`, `events[]`, `languages[]` (BCP 47).

**The registry** is a git-tracked collection of publisher entries, updated by
pull request with human review. **Keys are canonical URL + declared aliases,
never slugs** — the same app has shipped under three different names in
production. The registry records each publisher's crawl/reuse policy, and
**tooling, including this skill, MUST honour it**: never fetch from a publisher
whose declared policy reserves reuse.

**Why both mechanisms.** A registry outage must not break
publisher-to-publisher reads, so well-known paths exist. Catch-all SPAs and
host limitations rule out a well-known-only requirement — 2 of 20 observed
hosts could not serve one honestly. Both, each doing what it is good at.

### The soft-404 rule

**`200 + text/html` at a discovery path is treated as absent.** A single-page
app returns its shell for every unmatched route, so a manifest request gets
HTTP 200 and an HTML document — which naive tooling reads as "the manifest
exists" and then fails to parse.

**The discriminator is byte-size equality against `/`.** If the response at
the discovery path is byte-identical in size to the site root, it is the
catch-all shell, not a document. This is why `robots.txt` returning 200 +
`text/plain` is a precondition: it proves the host can serve a non-HTML
document at a fixed path at all.

---

## §3 · The feed (L2)

### The envelope

```json
{
  "last_updated": "2026-08-16T04:00:00Z",
  "ttl": 300,
  "version": "0.1.0",
  "publisher_id": "example-app",
  "license": "CC-BY-4.0",
  "permitted_use": ["display", "aggregate", "ai_answer"],
  "data": { "places": [] }
}
```

**Required envelope fields: `last_updated`, `ttl`, `version`, `publisher_id`,
`license`.**

- **`last_updated`** (RFC 3339 UTC) is the feed-level generation timestamp.
  Without it a consumer cannot distinguish "nothing changed" from "the pipeline
  died".
- **`ttl`** is the caching contract.
- **`version`** is the spec version implemented.
- **`license` is REQUIRED** — an unlicensed feed does not conform, because its
  absence blocks every consumer's legal review.
- **`permitted_use`** carries consent-to-reuse in the envelope. Closed enum:
  `display` | `aggregate` | `redistribute` | `ai_answer` | `ai_train`.

### The non-obvious MUST

**`Access-Control-Allow-Origin: *` is REQUIRED.** Transport is HTTPS, UTF-8,
`Content-Type: application/json` — and without the CORS header every
browser-based consumer needs a proxy. This is the single requirement most
first implementations miss, and it is invisible until somebody else tries to
read the feed.

### Records

Records follow the `place` model in `place-feed.schema.json`:

- **Three-axis status** — and **names MUST NOT encode operational state**
  (CR-2).
- **The verification block** (§6).
- **Structured `source{}`**.
- **`public_url` REQUIRED.**
- **The locator rule:** `address_text` **OR** `lat`+`lon`. Both RECOMMENDED;
  **neither is non-conforming.**

**Localization.** Human-readable strings MAY be `[{text, language}]` arrays;
a plain string is interpreted as `es`. **`es` is the required baseline, `en`
RECOMMENDED.** Machine tokens are never translated.

**Size.** One file SHOULD stay ≤ 5 MB / ≤ 10 000 records. Beyond that, shard by
DIVIPOLA municipality and list the shards in the manifest's `feeds[]`. **No
pagination inside static files.**

### Static ≡ API equivalence

The feed's `data.places[]` and the read API's items **MUST be byte-compatible
per record**. A static feed is a degenerate read API; the same schema tests
both. This is the rule that makes "four transports, one protocol" true rather
than aspirational.

---

## §5 · Identifiers

**`{publisher_id}:{local_id}`.**

`publisher_id` is registry-assigned once, human-readable, reviewed by pull
request. `local_id` is **whatever the publisher's database already uses** —
int, UUID, hex, all conforming unchanged.

**Why this shape: it is globally unique with zero coordination.** No central
id service, no allocation protocol, no migration of anyone's primary keys.
That is the entire argument, and it is why the rule is cheap enough to
actually be followed.

Ids MUST be stable across edits, MUST NOT embed personal data, one id system
per entity per publisher, and **never minted in another publisher's
namespace** — the write API answers **409** to an attempt.

**Survivability:** a `publisher_id` is never reassigned, even after a
publisher winds down and its entry is archived. References stay resolvable.

---

## §6 · Trust and verification

Three ecosystem teams invented this block independently, which is why it is
Core rather than an extension.

- **`last_confirmed_at`** — **the key is REQUIRED on every record, and `null`
  is legal and honest** ("never confirmed"). **Omitting the key is
  non-conforming.** The distinction is the point: `null` says "nobody has
  confirmed this", omission says nothing at all, and a consumer cannot tell
  the second from a publisher who forgot.
- **`confirmed_by`** — a **role token**: `team` | `volunteer` |
  `official_source` | `partner:{publisher_id}`. **Never a personal name.**
- **`confirmation_method`** — closed enum.
- **`confirmations_24h`**, **`contradictions_active`**.
- **`last_reported_absent_at`** — **negative confirmation is first-class.**
  "Somebody went and it was not there" is information, and most schemas have
  nowhere to put it.

### CR-1: `updated_at` ≠ `last_confirmed_at`

**An edit is not a confirmation.** Freshness semantics do not interconvert.
Correcting a typo in an address does not mean anybody checked that the shelter
is still open, and a system that treats the two as one field will confidently
show stale places as fresh.

### No signatures in 0.1

Key management is the one cost volunteer teams reliably fail at. The dominant
threat — poisoned place data — is mitigated at the **registry** layer
(reviewed publishers, canonical URLs) and the **write** layer (moderation
queues), not by record signatures. The upgrade path exists: manifest-published
keys plus detached feed signatures, opt-in per publisher; the envelope already
carries `publisher_id`, so the trust anchor is there.

---

## The two production anti-patterns

Both were observed in production. Both are `MUST NOT`, and the validator
probes for both behaviourally — they cannot be caught by reading a schema.

1. **Status encoded in `name` (CR-2).** `"Coliseo Mayor (LLENO)"` puts
   operational state in a display string, where no consumer can read it,
   every consumer renders it, and it survives every status change. Status
   belongs in the three status axes.
2. **Always-now `last_updated`.** Regenerating the timestamp per request so
   the feed always reads as fresh. **This is worse than no signal at all**: a
   missing `last_updated` is detectable, while a lying one is trusted.

---

## The six consumption MUSTs (L3+)

A consuming app MUST:

1. **Attribute** — display the origin publisher for every foreign record;
   machine-checkable via `source.source_id`, and honour
   `attribution_required`.
2. **Show age** — render `last_confirmed_at` age (or "sin confirmar" for
   `null`) wherever a foreign record can direct a person somewhere. When age
   exceeds **7 days** OR `contradictions_active > 0`, visually distinguish the
   record — and SHOULD NOT silently hide it, because **absence of data is not
   evidence of closure**.
3. **Not mutate** — never alter a foreign record's content. Enrichments live
   in the consumer's own records, with `same_as` claims.
4. **Preserve chains** — an aggregator republishing MUST keep the **original**
   `source{}` intact. Its own identity goes in the envelope's `publisher_id`,
   never in the record's provenance.
5. **Dedupe by claim, not by authority** — cluster via `same_as` (one-hop,
   non-transitive) plus accent-folded address/DIVIPOLA matching, never raw
   display strings. Publish clusters only as the consumer's own records.
6. **Respect exclusions** — never join place data with person-level sources
   (§7.1); never fetch from a publisher whose declared policy reserves reuse.

---

## §7 · What must never travel

Summarised here; **normative and verbatim in [`EXCLUSIONS.md`](EXCLUSIONS.md)**,
which is the file to quote from.

1. **Person-level data.** No missing persons, individual cases, volunteer
   identities, personal names, personal phones, personal media. This is a
   **join prohibition, not a field omission**: tooling MUST NOT combine
   protocol data with person-level sources, and grants are entity-scoped.
   **Free text is the third leak channel** — strip personal data from
   `description` and `warning_text` before publishing. People-domain
   integration is **link-out only, permanently**.
2. **Contact values.** A record carries `public_url` and links out. Contact is
   fetch-on-demand from the origin, not replicated across every consumer's
   cache. A namespaced `x_*` extension **does not** exempt contact data.
3. **Moderation verdicts.** Suppressed records are omitted, never labelled
   downstream — a "flagged as false" travelling through an aggregator is a
   defamation-shaped risk carried by whoever displays it.

---

## §8 · Versioning and conformance

**SemVer** for the spec; `version` in every envelope; supported versions span
**≤ 2 MAJORs**; producers get **180 days** on a MAJOR bump; deprecated terms
warn for one release, then error.

**A release candidate becomes normative only after ≥ 1 publisher ships it
publicly.** The spec never outruns its implementers.

**Profiles.** `Core` is the manifest plus one conforming `places` feed with
the required field set. `Extended` adds capacity, needs, hours, media,
institutional contact. Editorial rule: **a MUST that a script cannot validate
SHOULD be a SHOULD.**

**Extensibility.** Unknown members MUST be preserved and MUST NOT fail
validation. `x_{publisher}_{field}` extensions are always allowed. Shared
extension sets become versioned Profiles at public URIs.

### Conformance is measured

**Conformance = passing the published validator, never self-declaration.** The
evidence is production adapter registries that *declare* capabilities they
never implemented.

Registry badge states, re-measured on schedule:

| State | Meaning |
|---|---|
| `conforming` | The validator passed, at the last measurement. |
| `stale` | Validator passing, but `last_updated` is beyond **7 × `ttl`**. |
| `failing` | The validator did not pass. |
| `unreachable` | Could not be fetched. |
| `archived` | Wound down; ids remain valid references. |

There is no `certified`. There is no self-assessment. **An agent may report
what the validator measured and must not award a level** — including its own.

---

## Appendix · Traceability

The acceptance test asks ten questions of an agent with no network and no
context but this pack. Each is answerable from a section above,
`EXCLUSIONS.md`, or the vendored schemas — this table is the map, and it is
here so a gap is visible rather than discovered during a release.

| # | Question | Answered in |
|---|---|---|
| 1 | The five levels and what each requires | §1 · The conformance ladder |
| 2 | Where the manifest goes, and the fallback | §2 · Discovery |
| 3 | Why `200 + text/html` at a discovery path means absent | §2 · The soft-404 rule |
| 4 | The record id format, and why | §5 · Identifiers |
| 5 | What must never travel in a feed | §7 + [`EXCLUSIONS.md`](EXCLUSIONS.md) |
| 6 | `updated_at` vs `last_confirmed_at` | §6 · CR-1 |
| 7 | Omitted `last_confirmed_at` vs `null` | §6 · Trust and verification |
| 8 | The two production anti-patterns | The two production anti-patterns |
| 9 | The six consumption MUSTs | The six consumption MUSTs |
| 10 | Required envelope fields, and the non-obvious MUST | §3 · The envelope · The non-obvious MUST |

Worked examples for the capability half: [`../examples/valid/`](../examples/valid/)
and [`../examples/invalid/`](../examples/invalid/). Each invalid example carries
a `$comment` naming every violation and the rule behind it — read the example
before answering a question about it, rather than reasoning from these
summaries.
