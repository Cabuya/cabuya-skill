# §7 — Normative exclusions

## §7.1 Person-level data

The protocol MUST NOT transport person-level entities — missing persons,
individual cases, volunteer *identities*, personal names, personal phone
numbers, personal media. This is a **join prohibition, not a field
omission**: tooling MUST NOT combine protocol data with person-level sources,
and grants are entity-scoped — an app that holds both place and
missing-person data federates **only** its non-person entities, from surfaces
that do not co-serve person data. Free text is the third leak channel:
publishers MUST strip personal data from `description` / `warning_text`
before publishing.

People-domain integration is **link-out only, permanently** — and link-outs
SHOULD converge on the official channels: **Cruz Roja Colombiana
(Restablecimiento del Contacto Familiar)** for missing persons and the
**Registro Único de Damnificados (UNGRD)** for affected people. The registry
lists those channels as `official_source` entries.

## §7.2 Contact

Contact values MUST NOT travel in feeds. `public_url` + link-out is the
mechanism; `contact_available` carries the fact, never the value;
`institutional_contact` (Extended) is org-owned numbers only.

## §7.3 Scraping and consent

Data enters the network by **publication, never by scraping**. Consuming a
publisher requires its registry-declared consent (`permitted_use`).
Suppressed or moderated records are **omitted**, never labelled downstream —
a foreign moderation verdict republished without appeal is a
defamation-shaped risk.

## §7.4 Orderly wind-down

A departing publisher SHOULD: freeze feeds with a final `last_updated`,
publish `sunset_at` in its manifest, and either (a) transfer record custody
to a named publisher (records republished with chained provenance) or (b)
declare records archived. The registry marks the publisher `archived`; its
`publisher_id` is never reassigned.

## §7.5 Registry suspension (involuntary)

The maintainers MAY mark a publisher `suspended` — badge withdrawn, feeds
delisted, consumers SHOULD stop ingesting — for: publishing person-level
data, persistent fabricated places after notice, or impersonation.
Suspension follows the RFC process's lazy-consensus rules with a 48-hour
emergency path for PII incidents; the publisher gets a public, appealable
record — never a silent removal (the no-silent-verdicts principle of §7.3
applies to the registry itself). The `publisher_id` is still never
reassigned.
