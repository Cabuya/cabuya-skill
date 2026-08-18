# CABUYA.md — the note left in the adopter's repository

Fill this in and commit it at the root of the adopter's repo. Replace every
angle-bracket placeholder; delete any section that does not apply. **Do not
leave a placeholder in the file you commit** — an unfilled template is worse
than no file, because it reads as documentation.

The audience is the person who finds a `cabuya` directory eight months from
now and has no idea what it is. That person is often the same developer.

---

```markdown
# Cabuya

This app publishes a [Cabuya](https://cabuya.org) feed — the open format that
lets emergency-aid applications read each other's data.

**Measured level: <L2>, on <YYYY-MM-DD>.** Conformance is measured by the
published validator, never declared. Re-measure with the command below.

## What is published

| | |
|---|---|
| Manifest | `<https://example.org/.well-known/cabuya.json>` |
| Feed | `<https://example.org/cabuya/places.json>` |
| Profile | `<core>` |
| Publisher id | `<example-app>` |
| Licence | `<CC-BY-4.0>` |
| Municipality | `<66001>` (DIVIPOLA — <verified against the DANE table on YYYY-MM-DD / NOT YET VERIFIED>) |

## How it is generated

`<scripts/build-cabuya-feed.mjs>`, run `<before every build, via the "build"
npm script>`.

Source: `<the `albergues` table in Supabase>`.

**`last_updated` is set at `<build>` time, never per request.** Regenerating it
on each request would make the feed always read as fresh, which is a named
anti-pattern — a stalled pipeline would be indistinguishable from a healthy
one.

## What deliberately does not travel

- **No contact values.** No phone, email, or personal address, in any field,
  including namespaced `x_*` extensions. Contact reaches a user through
  `public_url` — they follow the link and get it from us, under our own
  consent model.
- **No person-level data**, in any form. `<Note here which columns were
  excluded at the PII gate, and why.>`
- **No moderation verdicts.** Suppressed records are omitted from the feed,
  never labelled.

`<If any column was excluded at the PII gate, name it here. The next person
to extend the feed needs to know it was a decision, not an oversight.>`

## Fields worth knowing about

- `last_confirmed_at` is `<null on every record — we have no confirmation
  event>`. This is conforming and honest. **It is not `updated_at`**, and must
  never be mapped from it: an edit is not a confirmation.
- `origin_category` carries our own category value verbatim, so the mapping to
  `place_kind` stays auditable.
- `<any x_ extension we emit, and what it means>`

## Re-validating

```bash
npx cabuya-validator https://example.org/.well-known/cabuya.json
```

Run this after any change to the feed generator, and after any change to the
hosting configuration — the discovery path is easy to break from the
deployment side without touching the code.

## Changing our published status

Use the `publish-status` skill. It refuses to declare a level above the one the
validator last measured, which is the point.

## When something looks wrong

The feed is generated from `<the albergues table>`. If a record looks wrong in
another app, it is wrong here first — fix it at the source and the next
`<build>` propagates it.

If the feed itself will not validate, run the validator and read the report;
it names the rule behind each failure. Protocol questions:
<https://cabuya.org/developers>.
```

---

## Notes for the agent filling this in

- **Every angle bracket must go.** If you cannot fill one, that is a question
  for the human, not a placeholder to commit.
- **State the measured level and its date, or say it was not measured.** In
  degraded offline mode write "schema-valid; conformance unmeasured
  (behavioural probes not run: soft-404, always-now, CORS)".
- **Record the PII gate's outcome.** Which columns were flagged, and what the
  human decided. That record is the reason the next developer does not undo
  the decision by accident.
- If the DIVIPOLA code was not verified against the DANE table, **say so in
  the file**. A code presented as checked when it was not is a defect nobody
  will go looking for.
