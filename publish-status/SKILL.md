---
name: cabuya-publish-status
description: >
  Keep the manifest honest and the registry entry current: update
  conformance_target, feeds, api, licence and permitted_use; open the registry
  pull request; and handle an orderly wind-down. Refuses to declare a level
  above the one the validator last measured. Use when a developer says
  "publish our level", "update the manifest", "abre el PR del registro", or
  "we're shutting down".
version: "0.1.0"
documentation_url: https://cabuya.org/developers/registry
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# Publish status

The manifest is a **claim**. This skill's job is keeping it true.

Two behaviours define it, and both are refusals:

1. **It will not declare a level the validator has not measured.**
2. **It will not let an app disappear silently.** Winding down is a supported,
   dignified path with steps, not an outage.

## Before anything: measure

```bash
bash ../bin/run-validator.sh validate <manifest-url> --format json
```

Read `measured_level`. Everything below depends on it, and **a stale
measurement is not a measurement** — if the feed changed since the last run,
run it again.

If the validator cannot run at all, say so and stop. Degraded mode reports
"schema-valid; conformance unmeasured", and **unmeasured is not a level**. You
cannot publish a conformance target on the strength of it.

## Updating the manifest

Fields this skill maintains:

| Field | Notes |
|---|---|
| `conformance_target` | **Gated — see below.** |
| `feeds[]` | `{name, url, entity, profile}`, plus `municipality_code` for a shard. |
| `api{}` | `base_url` at L3+. |
| `mcp{}` | Endpoint, if any. |
| `license` | Required. Changing it is a decision with consequences for existing consumers. |
| `permitted_use[]` | Closed enum. **Narrowing it is a breaking change** for anyone already using the data. |
| `languages[]` | BCP 47. `es` is the ecosystem baseline. |
| `sunset_at` | Wind-down only. |

**Every write asks first**, showing the diff. Per [`../TRUST.md`](../TRUST.md),
this pack does not modify a repository on its own initiative.

Two changes deserve a louder confirmation than the others, because they are
promises to third parties rather than statements about you: narrowing
`permitted_use`, and changing `license`. Somebody may already be relying on
what is there. Say that out loud before you write it.

### The measured-level gate

> **`conformance_target` may not exceed `measured_level`.**

If the developer asks for L3 and the validator measured L1, refuse — and be
useful about it:

```
Cannot set conformance_target: L3. The validator measured L1 on 2026-08-18.

  Why this is refused: the whole protocol rests on conformance being
  measured rather than declared. Production adapter registries that let
  publishers declare capabilities ended up full of declarations nobody
  implemented — manifests lie, behaviour does not. This gate is the one
  place that stays true.

  Blocking L2:
    ENV007  the envelope has no licence
    REC001  /data/places/0  last_confirmed_at is missing

  Fix those two and re-run; L2 becomes available immediately.
  For L3 after that: a read API or live-refreshed feeds with sync
  signals, plus one peer feed consumed under the six rules (`consume`).
```

Naming the blockers turns a refusal into a route. `blockers_for_next_level`
from the report is exactly that list.

**A target *below* the measured level is allowed** and needs no argument. A
publisher may be at L3 and choose to declare L2 while they stabilise. Do not
push them up.

## The registry entry

The registry is git-tracked and reviewed by pull request. **Measured badge
state is never in git** — it is written by the scheduled re-validation, which
is what keeps the badge a measurement rather than a claim.

Generate the entry, validate it locally, then show it:

```json
{
  "publisher_id": "example-app",
  "canonical_url": "https://example.invalid",
  "aliases": ["https://www.example.invalid"],
  "manifest_url": "https://example.invalid/.well-known/cabuya.json",
  "entity_domains": ["place"],
  "declared_target": "L2",
  "crawl_policy_url": "https://example.invalid/uso-de-datos",
  "contact_org": "datos@example.invalid",
  "status": "proposed",
  "added": "2026-08-18"
}
```

- **`canonical_url` + `aliases`, never a slug.** One app in this ecosystem
  answers to three different names; two others have names that differ by a
  word. The URL is what is unique.
- **`contact_org` is an organizational role address only.** Never a person's.
- **`status: "proposed"`** on a new entry. A human reviewer moves it to
  `active`.
- **`publisher_id` is assigned once and never reassigned**, even after archive
  — references stay resolvable.

Then, **with the developer's explicit yes**:

```bash
gh pr create --repo Cabuya/cabuya.org \
  --title "registry: add example-app" \
  --body "..."
```

**Never open this pull request unasked.** Show the entry, show the command,
and wait. If `gh` is not installed, give them the file and the URL — the web
interface works just as well, and a developer who does not want GitHub's CLI
on their machine is not blocked from publishing.

## Orderly wind-down

Apps end. An app that vanishes takes its records with it and leaves every
consumer showing places nobody can confirm — so the protocol makes ending
properly a supported path.

When a publisher is shutting down:

1. **Set `sunset_at`** in the manifest and the registry entry — a date, in the
   future, so consumers can see it coming.
2. **Freeze the feeds with a final, honest `last_updated`.** Do not keep
   regenerating the timestamp on unchanged data: that is the always-now
   anti-pattern, and after sunset it is worse, because it makes an abandoned
   feed look maintained forever.
3. **Decide, and record, which of two things happens to the records:**
   - **custody transfer** — another publisher takes them on, with their own
     `publisher_id` in the envelope and the original `source{}` preserved on
     every record; or
   - **archived** — the records stand as a historical statement. Say so
     plainly, so consumers show them as archived rather than current.
4. **Set `status: "archived"`** in the registry entry, by pull request.
5. **Keep the ids valid.** `publisher_id` is never reassigned. References from
   other publishers' `same_as` claims stay resolvable, which is the whole
   reason for the rule.

Say this to the team in their terms: **winding down well is a contribution.**
The alternative — a feed that goes stale silently — is the failure this step
exists to prevent, and it lands on somebody looking for a shelter.

## What this skill will not do

- Declare a level above the measured one, for any reason.
- Publish a target from a degraded run. Unmeasured is not a level.
- Open a pull request without an explicit yes.
- Put a person's contact in `contact_org`.
- Use the word *certified*. There is no certification — there is a published
  validator and whatever it measured last.
