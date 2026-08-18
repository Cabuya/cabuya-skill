# The adoption, as an ordered task spec

This file mirrors [`tasks.json`](tasks.json) for a human reader. The JSON is
the source of truth — a renderer, a planning methodology, or an agent's own
plan mode consumes it; this page is for the person deciding whether to run it.
`tests/plan-spec.bats` fails if the two drift.

**The shape:** twelve tasks, in order. One — the PII gate — blocks on a human
and cannot be answered by an agent; the ledger schema enforces that
structurally. One — consuming peers — is optional, and only matters at L3.
Validation commands use placeholders (`{manifest_url}`, `{feed_path}`,
`{stack_guide}`, `{target_level}`) that whatever plans the work instantiates
from the stack recipe.

**What this file deliberately does not say:** which planning tool to use. The
spec is methodology-neutral — it carries goals, acceptance criteria,
validation commands and stop conditions, and any methodology that can walk an
ordered list can execute it.

---

## 1. `read_and_detect` — Read the repository; write nothing

Establish the stack, the data model, and the four hosting facts before a
single file is written. Stops honestly if there is no detectable data source,
or if the records are irreducibly personal — then the ceiling is L1
permanently by rule 7.1 of the specification's exclusions, stated as a fact
about the data.

## 2. `map` — Build the field crosswalk

Map the application's fields onto `place`. The full table goes in front of the
human before any code exists. `last_confirmed_at` maps to a real confirmation
event or to `null` — never to an edit timestamp.

## 3. `pii_gate` — The one human decision

Run the deny-list over every candidate column and free-text value, present the
findings, and wait for an explicit human yes that names the specific columns.
The only task that blocks on a human, and the ledger records the answer with
`decided_by: "human"` — the schema accepts nothing else.

## 4. `serialize` — Generate the feed

Envelope first, records second, only from data the application has.
`last_updated` at build time, `public_url` on every record, CORS on the feed
route.

## 5. `serve` — Serve the manifest and survive discovery

The manifest where the host actually serves it, the catch-all defeated,
`robots.txt` real. A 200 that returns the SPA shell is an absent manifest.

## 6. `validate_loop` — Loop the validator to convergence

Parse the JSON report, fix, repeat — at most 8 iterations, then an honest
stop. Halts on any PII finding. A degraded offline run reports
"schema-valid; conformance unmeasured", never "conforming".

## 7. `publish_status` — Set the conformance target honestly

`conformance_target` never exceeds the last measured level. Every manifest
write shows the diff first.

## 8. `registry_pr` — Open the registry entry

With the human's approval, never by surprise. Inclusion is listing, not
endorsement.

## 9. `consume_peers` — Consume peer feeds (optional, L3)

The six consumption rules, shaping the code rather than retrofitted onto it.

## 10. `handoff` — Hand off

`CABUYA.md` in the adopter's repository, the measured level in the
validator's words, each remaining warning with what it would take.

## 11. `pii_audit` — Final PII audit

The deny patterns over everything the adoption created, including the ledger
itself. Any finding halts.

## 12. `report` — Report what is true

Every claim traces to the ledger or the validator report. No conformance
language beyond `measured_level`, and never the word *certified*.
