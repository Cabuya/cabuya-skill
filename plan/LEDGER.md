# The ledger: `.cabuya/adoption.json`

One small JSON file in the adopter's repository, holding the state of the
adoption: the stack that was detected, who plans the work, which tasks are
done, the one human decision, and the last thing the validator measured.

## Why it exists

Sessions end; the file does not. Whatever plans the adoption — DeepWorkPlan,
the team's own spec-driven methodology, or the agent's own plan mode — the
ledger is the part that survives: re-entering `/cabuya` reads it, reports what
is done, and never re-asks a recorded decision. It is also the transfer
mechanism between paths: a team that starts in plan mode and later installs a
planning tool gets its completed steps carried over, because they were never
in the session to begin with.

## Why it is committed

Because the next person to touch the repository needs it more than you do.
An adoption whose state lives in one developer's chat history is an adoption
that gets redone. The file is small, holds **no person-level data by schema**
(free text is capped, columns are recorded by *name* only, and there is no
field that could hold a personal name, phone, email or document), and reads as
documentation of what was decided.

## What the schema refuses to represent

Two things, deliberately, at [`adoption.schema.json`](adoption.schema.json):

1. **An unmeasured level.** A conformance level exists only inside
   `last_measured`, alongside the sha256 of the validator report that measured
   it. `mode: "offline"` forbids `level` entirely — a degraded run is
   schema-valid-at-best, and the ledger cannot even hold the claim.
2. **An agent's PII decision.** `pii_decision.decided_by` is the constant
   `"human"`. There is no value an agent could honestly write there.

Check a ledger with:

```bash
node bin/check-ledger.mjs path/to/.cabuya/adoption.json
```

## Contract versioning

`contract` is `major.minor`. A reader that finds a newer **major** than it
knows reads and explains, but never writes — the shape may have changed under
it. Minor bumps are additive only.

## How to remove it

Delete `.cabuya/` and commit. Nothing else references it; the feed, the
manifest and the registry entry are unaffected. The pack will simply treat the
repository as un-started next time, and re-ask what it no longer knows.
