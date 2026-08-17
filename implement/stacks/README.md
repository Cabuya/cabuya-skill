# Stack guides

Four guides, one skeleton. Each takes the six-phase flow in
[`../SKILL.md`](../SKILL.md) and instantiates it for a family of applications —
same order, same guardrails, different code.

| Guide | For |
|---|---|
| [`nextjs-supabase.md`](nextjs-supabase.md) | Next.js App Router, Supabase or Prisma. A server exists. |
| [`vite-spa-supabase.md`](vite-spa-supabase.md) | Vite/React SPA, Supabase, static host. No server. |
| [`php-ssr.md`](php-ssr.md) | Laravel and plain PHP, Apache or nginx, shared hosting. |
| [`static-sheet.md`](static-sheet.md) | No backend and no developer. A spreadsheet becomes a feed. |

Not sure which? Run `bash ../../shared/context.sh` and read
[`../../shared/stack-detection.md`](../../shared/stack-detection.md).

## Reason, do not copy-paste

**The shape is fixed. The content is reasoned.**

Every serializer in these guides is written against an invented `albergues`
table with columns that will not match the app in front of you. That is
deliberate. Copying one wholesale and renaming columns until it compiles
produces a feed that is *shaped* right and *says* the wrong thing — and the
place it goes wrong is `last_confirmed_at`, every time, because the guide shows
a mapping and the real app has no confirmation event.

What is fixed, and must survive adaptation:

- the envelope's five required fields;
- `last_updated` from build or publish time, never per request;
- `Access-Control-Allow-Origin: *`, on the feed route specifically;
- `public_url` derived per record;
- `last_confirmed_at` **present on every record**, `null` when there is no
  confirmation event;
- `origin_category` carrying the publisher's own value, verbatim;
- an explicit column list in the query — never `select *`.

What is reasoned, per app: every mapping, every constant, and every decision
about a column the PII gate flagged.

## The skeleton

Every guide has these sections, in this order, because it is the order the
flow runs in:

1. **Fingerprints** — how to know you are in this stack.
2. **Where the data lives** — and how to read the model without guessing.
3. **The mapping worksheet** — the table you show the human in Phase 1.
4. **The PII gate for this stack** — where person-level columns actually hide
   here.
5. **The serializer** — real, runnable-shaped code with the fixed parts fixed.
6. **The manifest and the catch-all** — this stack's exact exclusion, from
   [`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md).
7. **The validator loop** — this stack's common failures and what each means.
8. **Hand-off** — what is left behind, and what to run next.

## Where the catch-all one-liners come from

[`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md) is **generated**
by `scripts/sync-spec.sh` from the validator package, and checksummed with the
rest of the vendored tree.

The same words ship in three other places: the validator CLI's
`init --framework`, cabuya.org's quickstart, and here. That is four copies of
one instruction, and the source file says what happens to four copies — one
drifts, and the one that drifts is the one somebody follows. Generating this
copy makes the drift a checksum failure instead of a discovery.

**So do not edit the exclusion text in a guide.** Quote it, or point at it. If
it is wrong, it is wrong in `packages/validator/src/spa-exclusions.ts` in the
website repository, and fixing it there fixes all four.

## Writing a new guide

New stacks are the most useful contribution this pack takes — they are tagged
`good-first-issue:stack` — and the bar is specific rather than high.

**A guide must:**

1. Follow the eight sections above, in order.
2. Name **fingerprints that distinguish**, not ones that merely match. "Has a
   `package.json`" is not a fingerprint.
3. Show where the data model actually lives in this stack, ranked by
   reliability. Migrations beat generated types beat call sites beat a sample
   response.
4. Say where person-level columns hide **in this stack specifically**. Every
   stack has a characteristic place: an auth table, a `profiles` view, a
   join model, an admin-only column that the ORM selects by default.
5. Carry a serializer that would run, with the fixed parts fixed. Not
   pseudocode.
6. Quote this stack's catch-all fix from the generated file rather than
   restating it.
7. List the failures **this stack** produces in the validator loop, and what
   each one means here.
8. Have been run at least once against a real application. Say which kind of
   app, and what broke.

**A guide must not:**

- Contain a phone number, an email address, or a person's name — not in a
  sample row, not in a comment, not in a placeholder. Sample data uses the
  `.invalid` TLD and organizational names.
- Map `updated_at` into `last_confirmed_at`, in any example, for any reason.
- Show `last_updated` generated inside a request handler.
- Claim a conformance level. Guides end at "run the validator", never at
  "you are now L2".
- Name a real publisher without their written opt-in. De-brand real
  configurations — the shape is the useful part, and the attribution is a
  commitment somebody else has to keep.

The tests in `tests/stack-guides.bats` check most of the "must not" list
mechanically. They will tell you before a reviewer does.
