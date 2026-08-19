# The questions a newcomer actually asks

One entry per question, in both languages, each with the vendored sections
that ground its answer. This file is a map, not a script: answer in your own
words, **short first**, but every factual claim must trace to a source below —
`tests/explain.bats` verifies each cited path exists in the pack.

If a question is not here and not answerable from the vendored spec, say so
and point at <https://cabuya.org> — never fill the gap from training data.

---

## 1. What is Cabuya? · ¿Qué es Cabuya?

One entity — `place` — and four equivalent ways to serve it, so emergency-aid
applications can read each other's shelters, collection centres and service
points. Conformance is measured by a published validator, never self-declared.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (The one-paragraph version).

## 2. Why a protocol, and not one more aggregator? · ¿Por qué un protocolo y no otro agregador?

An aggregator centralizes data and dies with its operator; a protocol lets
every app keep its own data and speak a shared format. The network has no
centre on purpose — the registry lists, it does not host.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (The one-paragraph version, §6).

## 3. What do I have to build? · ¿Qué tengo que implementar?

For L2: a manifest at `/.well-known/cabuya.json` and one conforming `place`
feed. The ordered work is the pack's task spec; "what would this mean *here*"
is answerable per stack.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§2, §3) · `plan/TASKS.md` · `spec/schemas/manifest.schema.json` · `spec/schemas/place-feed.schema.json`.

## 4. What are the levels, and who decides them? · ¿Qué son los niveles y quién los decide?

A five-rung ladder, L0–L4, cumulative, **not a gate** — every level is a
respected membership class. The validator decides: there is no
self-assessment and no *certified*.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§1, §8 Conformance is measured).

## 5. What data can never travel — and why a join prohibition? · ¿Qué datos nunca viajan y por qué una prohibición de cruce?

Person-level entities: missing persons, cases, volunteer identities, personal
names, phones, media. It is a join prohibition, not a field omission, because
no list of banned fields makes a feed of people safe — tooling must not
combine protocol data with person-level sources at all.

**Sources:** `spec/EXCLUSIONS.md` (§7.1) · `spec/PROTOCOL_SUMMARY.md` (§7).

## 6. So how does someone contact a place? · ¿Y cómo contacta alguien un lugar?

Contact values never travel in feeds. Every record carries `public_url` — the
publisher's own page — and `contact_available` carries the fact, never the
value. Org-owned institutional numbers are the one Extended exception.

**Sources:** `spec/EXCLUSIONS.md` (§7.2).

## 7. What is the registry — is being listed an endorsement? · ¿Qué es el registro — estar listado es un aval?

A reviewed list of publishers with measured badge states, re-measured on
schedule. Inclusion is listing, never endorsement: a directory lists, a
registry measures.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§6, §8 badge states).

## 8. Who governs this, and how does it change? · ¿Quién gobierna esto y cómo cambia?

By RFC against the spec repository, with a rule that keeps the spec honest:
a release candidate becomes normative only after at least one publisher ships
it publicly. The pack never edits its vendored copy; it points at the RFC
process.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§8) · `spec/SOURCE`.

## 9. How much work is it? · ¿Cuánto trabajo es?

L0 is one pull request; L1 is a static JSON file, under an hour; **L2 is one
afternoon** for a small app — and that bar is a design constraint of the
protocol, not marketing. One human decision (the PII gate) is mandatory.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§1 Typical effort) · `shared/pii-deny-list.md`.

## 10. How stable is this? · ¿Qué tan estable es esto?

The specification is **0.1, normative** — the first published version, early
but no longer a draft. Say the version whenever stability is asked. SemVer,
two supported MAJORs at most, 180 days of producer runway on a MAJOR bump,
and unknown members never fail validation.

**Sources:** `spec/VERSION` · `spec/PROTOCOL_SUMMARY.md` (Status line, §8).

## 11. How do I check conformance? · ¿Cómo verifico la conformidad?

Run the validator; report what it measured, in its words. Offline, degraded
mode says "schema-valid; conformance unmeasured" and names the probes that
did not run — it never says "conforming".

**Sources:** `shared/validator.md` · `validate/SKILL.md`.

## 12. What happens to person-domain apps? · ¿Qué pasa con las apps de dominio personal?

Link-out-only, permanently, by rule — their ceiling is L1, and that is a fact
about the data, not a verdict on the app. Link-outs converge on the official
channels the registry lists.

**Sources:** `spec/EXCLUSIONS.md` (§7.1) · `spec/PROTOCOL_SUMMARY.md` (§1 standing exceptions).

## 13. Why the name? · ¿Por qué el nombre?

Cabuya is the fique cord — the fibre rope of the Colombian countryside;
«coger la cabuya» is to catch the thread of something. The protocol is the
shared thread. The story lives on the website, not in the spec.

**Sources:** none in the vendored spec — answer briefly and point at <https://cabuya.org/about>.

## 14. Do I have to change my app's database? · ¿Tengo que cambiar la base de datos de mi app?

No. The pack builds a **crosswalk** from the fields the app already has to
`place`, and a serializer that emits the published copy — no migration of
anyone's primary keys, no schema change, no new tables required. The internal
model stays the publisher's own; the protocol standardizes only what is
published.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§5 ids: "no migration of anyone's primary keys"; The two premises) · the crosswalk itself: `implement/mapping/field-crosswalk.md`.

## 15. Is the feed a file or an endpoint? · ¿El feed es un archivo o un endpoint?

Either — they are the same feed. A static feed is a degenerate read API,
byte-compatible per record, and the manifest declares whichever URL you
serve. `places.json` is an example filename, not a rule; the only rule is a
stable HTTPS URL declared in the manifest.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§3) · `spec/schemas/manifest.schema.json` (`feeds[].url`).

## 16. How do consumers display my records? · ¿Cómo muestran mis registros las otras apps?

With origin and place in the same view — the canonical shape is
`{name} — by {publisher} · {municipality_text}, {neighborhood_text}`, so a
record republished in another city still says where it is and whose it is.
Action buttons go to the record's `public_url` — the origin app — because
contact values never travel in feeds.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (§6 Trust: contact and link-out) · `spec/schemas/place-feed.schema.json` (geography fields, `public_url`).

## 17. What about help requests and donations? · ¿Y los pedidos de ayuda y las donaciones?

0.1 carries `place` only. Help requests and offers (`need`/`offer`, with
quantities) and damage reports are **proposed for v0.2 in RFC 0002 — a draft,
not shipped**; do not promise dates. Goods requests will be org-level
("shelter X needs 50 blankets"), never person-level. Money never travels
through the protocol — donations are a link-out to the origin app.

**Sources:** `spec/PROTOCOL_SUMMARY.md` (The one-paragraph version, §6) — the proposal itself is not vendored; point at <https://cabuya.org/rfcs>.

## 18. How should I organize my app's data? · ¿Cómo debería organizar los datos de mi app?

Your internal model is yours — the spec requires only what you publish. But
if the app is still being built, or can adapt, the pack carries a
**reference data model** whose five recommendations make the crosswalk nearly
the identity function: structural PII separation, protocol-shaped entities,
native honesty fields, geography as code + text from day one, and stable
public ids with a `public_url` per record.

**Sources:** `implement/mapping/reference-model.md` · `shared/pii-deny-list.md`.
