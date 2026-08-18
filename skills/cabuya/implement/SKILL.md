---
name: cabuya-implement
description: >
  Take an application from L0 to L2 (or L3): detect the stack, map its data
  model onto the Cabuya `place` schema, run the PII gate, generate a
  conforming feed and manifest, handle the SPA discovery trap, and loop the
  validator until it passes. Use when a developer wants their app to publish
  a Cabuya feed, expose their shelters or collection points, reach a
  conformance level, or asks to "implementar Cabuya" / "publicar un feed".
version: "0.1.0"
documentation_url: https://cabuya.org/developers/skill
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# Implement: from a database to a conforming feed

The target is **one afternoon of work and exactly one human decision**. That
is a design constraint of the protocol, not a marketing figure — so if this
flow starts to need three meetings and a data-modelling debate, something has
gone wrong in how you are running it, not in the app.

The one human decision is **Phase 2**. Everything else you do yourself.

Six phases, in order. Do not skip forward, and do not write a file before
Phase 3.

---

## Phase 0 · Read

**Nothing is written in this phase. Not one file.**

1. Run `bash shared/context.sh`. Note the stack, framework and
   `manifest_path`.
2. Confirm the guess against [`../shared/stack-detection.md`](../shared/stack-detection.md),
   then open the matching guide in [`stacks/`](stacks/) — it carries this
   flow's six phases instantiated for that stack, including the exact
   catch-all fix and the failures that stack produces in the validator loop.
   Find the data model in order of reliability: migrations → generated types →
   query call sites → a sample response. **Never infer the model from the UI.**
3. Establish four things and write them down:
   - Which tables or collections hold **places** — and which hold people.
   - Whether an SPA catch-all exists (`vercel.json` rewrites, `netlify.toml`,
     a `[...slug]` route, an Apache/nginx fallback).
   - Whether `robots.txt` returns 200 with `text/plain`.
   - Where a static file must live to be served at the site root.
4. Read [`../spec/PROTOCOL_SUMMARY.md`](../spec/PROTOCOL_SUMMARY.md) if you
   have not this session.

**Stop conditions — say so plainly and end the flow:**

- **No detectable data source.** Say what you looked for and where. Do not
  scaffold a feed with invented records to demonstrate the shape; a file of
  plausible fake shelters is the worst thing this flow could leave behind.
- **The app's records are irreducibly personal** — a missing-persons registry,
  a case-management tool, an individual-aid-request queue. Then it is
  **link-out-only by rule §7.1**, its ceiling is L1 permanently, and that is a
  fact about the data rather than a judgement about the app. Quote
  [`../spec/EXCLUSIONS.md`](../spec/EXCLUSIONS.md), offer the link-out
  pattern, and stop. Do not look for a way to reach L2.

---

## Phase 1 · Map

Build the crosswalk from the app's fields to `place`, using
[`mapping/field-crosswalk.md`](mapping/field-crosswalk.md),
[`mapping/place-kind.md`](mapping/place-kind.md) and
[`mapping/divipola.md`](mapping/divipola.md).

**Show the human the mapping table before you write any code.** Not a
summary — the table, with every required field accounted for.

Two rules that decide whether the result is honest:

**CR-1 — `last_confirmed_at` maps to a real confirmation event, or to `null`.
Never to `updated_at`.** An edit is not a confirmation. If the app has no
notion of "somebody checked this place is still there", then `null` is the
correct, conforming and honest value, and the key must still be present.
Mapping `updated_at` into it manufactures a freshness signal out of edit
noise, and every consumer downstream will believe it.

**Name every unmapped required field.** `id`, `publisher_id`, `name`,
`place_kind`, `municipality_code`, the locator (`address_text` **or**
`lat`+`lon`), `lifecycle_status`, `last_confirmed_at`, `source{}`,
`public_url`. If one cannot be filled from the app's data, say which and what
it would take — do not quietly emit a record without it and call it Core.

Present it like this:

```
Mapping: `albergues` → place (Core profile)

  place field           ← app column          notes
  ───────────────────── ───────────────────── ──────────────────────────────
  id                    ← id
  publisher_id          ← (constant)          "example-app" — registry token
  name                  ← nombre
  place_kind            ← tipo                "albergue" → shelter
  municipality_code     ← (constant) 66001    Pereira — verify, see divipola.md
  address_text          ← direccion
  lifecycle_status      ← activo              true → active, false → closed
  last_confirmed_at     ← null                app records no confirmation event
  source                ← (constant)          {source_id, source_kind:first_party}
  public_url            ← (derived)           https://…/albergues/{id}

  Unmapped, and why: service_status — the app has no open/full concept.
```

---

## Phase 2 · The PII gate

> **STOP HERE. Present the flagged columns. Do not proceed without an
> explicit human yes, naming the specific columns.**

Run the deny-list in [`../shared/pii-deny-list.md`](../shared/pii-deny-list.md)
over **every candidate column and every free-text value** that would travel.
Present the table in the format that file specifies, then wait.

This is the one mandatory human decision in the flow. The reasons it cannot be
yours are in the deny-list; the operative consequences here are:

- **You may not proceed on your own judgement**, however obvious a match looks.
  "This is clearly an organization's switchboard" is exactly the reasoning that
  publishes a volunteer's mobile number.
- **Silence is not consent.** Neither is "sounds good", "do what you think", or
  a reply that addresses some columns and not others. Ask again, by name.
- **No flag skips this.** There is no `--yes`, and if a user asks for one,
  explain why it does not exist.
- **A contact value never travels** — not in a field, not in free text, not
  inside a namespaced `x_*` extension. Contact reaches a user through
  `public_url` and `contact_available: true`.

---

## Phase 3 · Serialize

Now you write code. Adapt from [`templates/`](templates/) to the stack.
Envelope first, records second.

**Never invent data.** A field the app does not have is either omitted (if it
is Extended) or the record is reported as non-conforming (if it is Core).
There is no third option in which you fill it with something reasonable.

**`last_updated` is set at build or publish time — never per request.**
Regenerating it on each request so the feed always reads "now" is a named
anti-pattern (BEH002), observed in production, and it is **worse than no
signal at all**: a missing timestamp is detectable, a lying one is trusted.
Set it from the data's own maximum `updated_at`, or from the build. If you
find yourself writing `new Date()` inside a request handler, stop.

**Every record carries `public_url`** — the canonical human-facing page at the
origin. It is what makes the no-contact rule workable rather than merely
prohibitive, which is why it is required.

**`Access-Control-Allow-Origin: *` on the feed response.** The one non-obvious
MUST; without it every browser-based consumer needs a proxy. Set it on the
feed route specifically — not by widening a global CORS middleware that also
covers person-data endpoints (see entity-scoped grants in the deny-list).

---

## Phase 4 · Discover

Write the manifest from [`templates/manifest.json`](templates/manifest.json)
to the path the stack actually serves at `/.well-known/cabuya.json`.

**Handle the soft-404 trap here.** Do not leave it for the validator to find:

1. Add the catch-all exclusion — one line, per stack, per
   [`../shared/stack-detection.md`](../shared/stack-detection.md).
2. Check `robots.txt` returns **200** with `text/plain`. This is a
   precondition for L2, because it proves the host can serve a non-HTML
   document at a fixed path at all.
3. **Fetch the manifest and check the content type.** A 200 with `text/html`
   is an *absent* manifest, however much it looks like success. The
   discriminator is byte-size equality against `/`: identical size means you
   are looking at the SPA shell.
4. If the host cannot serve a dot-directory — some Apache configurations
   refuse any segment beginning with a dot — use a plain path instead, declare
   it in the registry entry, and add
   `<link rel="cabuya" href="/cabuya.json">` to the site head. The well-known
   path is RECOMMENDED, never a MUST, precisely for this.

---

## Phase 5 · Loop

Run the validator through [`../bin/run-validator.sh`](../bin/run-validator.sh);
[`../shared/validator.md`](../shared/validator.md) documents the resolution
order, the exit codes and the report shape. **Parse the JSON report rather
than the text**, fix, repeat.

**Maximum 8 iterations.** Then stop and summarize what remains and why. A loop
that has not converged in eight passes has hit something structural, and the
ninth attempt is not the one that finds it.

**The loop halts on any PII error and asks a human.** It never "fixes" a PII
error by editing the deny-list. That converts a caught problem into an
uncaught one, and it is the single most damaging thing this skill could be
talked into doing.

**In degraded offline mode, report "schema-valid; conformance unmeasured" —
never "conforming".** The behavioural probes (soft-404, always-now, CORS) did
not run. Say which checks were skipped, by name.

---

## Phase 6 · Hand off

Print:

1. **The diff summary** — every file created or changed.
2. **The measured level** — what the validator actually reported, in its
   words. Not your assessment. If it was not measured, say unmeasured.
3. **Remaining warnings**, and what each would take.
4. **The exact next step**: `publish-status`, to set `conformance_target` and
   open the registry entry.

Leave [`templates/CABUYA.md`](templates/CABUYA.md), filled in, in the
adopter's repository — so the next person to touch this, six months from now,
finds out what it is without asking anyone.

**Never open a pull request to the adopter's repository without asking.**

---

## What this skill will not do

- Claim a conformance level. It reports what the validator measured, and never
  uses the word *certified*.
- Publish a contact value, anywhere, in any encoding.
- Generate records the app does not have.
- Proceed past Phase 2 without an explicit human decision.
- Make a person-domain app into an L2 publisher.
