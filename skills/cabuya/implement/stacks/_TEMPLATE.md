# _TEMPLATE — writing a stack guide

Copy this file to `<stack>.md`, replace every `⟨…⟩`, delete this paragraph and
the per-section coaching, and check the result against
[`README.md`](README.md) ("Reason, do not copy-paste" — your guide must carry
that pointer too) and `tests/stack-guides.bats`, which enforces mechanically
most of what follows. A guide that guesses is worse than no guide: every
instruction comes from the framework's own documentation, **cited in the
guide**, or from a deployment you actually observed.

The eight sections, in this order — the order the six-phase flow runs in:

## 1. Fingerprints

⟨The files and dependencies that mean this stack and no other. Distinguish:
a fingerprint two stacks share is not a fingerprint. Show a short tree or
list, and name which single file is the strongest signal.⟩

## 2. Where the data lives

⟨In order of reliability, numbered: migrations → generated types/schema →
query call sites → a sample response. Give the exact grep or command per
step. Never the UI.⟩

## 3. The mapping worksheet

⟨The table shown to the human in Phase 1, against an invented table whose
columns will NOT match the real app — say so. Must include
`last_confirmed_at` mapped to a real confirmation event **or `null`**, with
one sentence on why an edit timestamp is neither.⟩

## 4. The PII gate here

⟨Where person-level columns hide in THIS stack: the auth tables, the
join-table trap, the free-text columns. Name the specific places the
deny-list must be run over, and the stack's characteristic leak channel.⟩

## 5. The serializer

⟨Runnable-shaped code. The fixed parts, fixed: the envelope's five required
fields; `last_updated` from build/publish time or the data's own high-water
mark — never a request-time clock; `public_url` derived per record; an
explicit column list — never a select-everything; `last_confirmed_at`
present on every record. Show BOTH exports where the stack supports them:
build-time (preferred — honest by construction) and scheduled.⟩

## 6. The manifest and the catch-all

⟨Where a static file must sit to be served at `/.well-known/cabuya.json`,
and this stack's exact catch-all exclusion. If the stack has an entry in
[`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md), QUOTE it —
never restate it. State the `Content-Type` the manifest must return, and the
CORS story: `Access-Control-Allow-Origin: *` on the feed route specifically,
per [`../../spec/CORS.md`](../../spec/CORS.md), never a widened global
middleware.⟩

## 7. The validator loop

⟨The two or three findings this stack characteristically produces, by check
id, with what each actually means here and the fix. DSC* is usually the
catch-all; BEH002 is usually a request-time clock; name this stack's
version of each.⟩

## 8. Hand-off

⟨What is left behind in the adopter's repository (the serializer, the
manifest, `CABUYA.md`), and the exact next step.⟩
