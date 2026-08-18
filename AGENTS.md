# AGENTS.md — working on this repository

For any AI coding assistant, and for humans, operating on `cabuya-skill`.
This is about **building the pack**. Using it is [`SKILL.md`](SKILL.md); what
it will and will not do on a machine is [`TRUST.md`](TRUST.md).

## What this repository is

An installable agent pack that teaches any coding agent the **Cabuya
Protocol** — an open interoperability standard for emergency-aid
applications — and works with no network at all.

It is **Markdown, one Python script, and some Bash.** There is no build step,
no bundler, and no runtime dependency. That is a constraint worth defending:
the pack has to run inside somebody else's agent, on somebody else's machine,
possibly offline, during an emergency.

The prose *is* the implementation. An agent reads these files at runtime, so a
sentence that changes meaning changes behaviour — which is why the tests
assert on sentences and why review here is closer to editing than to code
review.

## Layout

```
SKILL.md              the router — routes and does nothing else
TRUST.md              what it will and will not do, with a self-audit
setup.sh              multi-agent installer; links, never copies
implement/            the adoption flow — the six phases and the PII gate
  mapping/            field crosswalk, place_kind, DIVIPOLA
  stacks/             four per-stack guides
  templates/          manifest, serializers, the adopter's CABUYA.md
consume/              reading the network — the six MUSTs, with self-tests
validate/             run the validator, read the report
publish-status/       the manifest is a claim; keep it true
setup/                the doctor
plan/                 the adoption as a machine-readable task spec, and the
  tasks.json            ledger contract (.cabuya/adoption.json) every
  adoption.schema.json  planning path writes to
shared/               notes several sub-skills read
  pii-deny-list.md    the gate that has no override
  crawl-policy.md     the rule that holds even when asked
  validator.md        resolution order, exit codes, the report shape
  spec-paths.md       vendored vs authored, and the resolution order
bin/                  run-validator.sh, degraded-check.mjs
spec/                 VENDORED — never hand-edited
examples/             VENDORED — the five teaching examples
scripts/              sync, checksums, frontmatter validation
tests/                bats
```

## The rules that do not bend

These are in `SKILL.md` for the agent running the pack. They apply equally to
anyone editing it, and the tests enforce them.

1. **No person-level data.** Not in prose, not in an example, not in a
   fixture, not in a test. Sample data uses the `.invalid` TLD and
   organisational names. The one exception is
   `examples/invalid/invalid-2-contact-and-personal-data.json`, which is
   vendored from upstream and whose entire purpose is to teach the rule; its
   name and number are transparently fictional.
2. **No contact values in a feed** — including inside a namespaced `x_*`
   extension. Namespacing is for fields the vocabulary lacks, not an
   exemption.
3. **No scraping**, and no code that scrapes.
4. **Honour the crawl policy**, even when a human asks directly.
5. **Never claim conformance the validator has not measured**, and never use
   the word *certified*.

## Never hand-edit `spec/` or `examples/`

Rule **V6**. `scripts/sync-spec.sh` is the only writer, and
`scripts/verify-integrity.sh` fails CI on any drift.

This is not bureaucracy. The vendored copy is what an offline agent will teach
people, so the difference between "a copy of the standard" and "a fork nobody
declared" is exactly whether every byte traces to an upstream commit.

**To change the protocol**, open an RFC in `Cabuya/cabuya.org`. Nothing about
the standard changes here.

**To take a new upstream version:**

```bash
bash scripts/sync-spec.sh --from https://github.com/Cabuya/cabuya.org --ref v0.2.0
bash scripts/verify-integrity.sh
```

Commit the vendored files and the regenerated `CHECKSUMS.txt` **in the same
commit** — a checksum update in a separate commit is a window in which the
check passes and the tree is wrong.

**If the integrity check fails, do not regenerate the checksums to make it
stop.** That converts a detected problem into an undetected one.

## Writing prose here

- **Second person, imperative, present tense.** "Stop and ask", not "the agent
  should stop".
- **State the rule as an instruction**, not as a description. "Phase 2: STOP.
  Present this table. Do not proceed without an explicit human yes" is a
  rule an agent follows; "a PII check is performed" is not.
- **Give the reason once, where it matters.** The rules here cost adopters
  time, and a rule whose reason is invisible is a rule somebody routes around.
- **Never paraphrase §7.** Quote `spec/EXCLUSIONS.md`. It is vendored verbatim
  precisely so refusals cite text nobody rewrote.
- **English.** Code, comments, commits, check ids, file names. Routing
  triggers are bilingual because the organisations this exists for work in
  Spanish, and an agent that only routes on English has excluded them.

## Frontmatter

Every `SKILL.md` carries it, and a host reads it to decide what a skill may be
invoked as and which tools it may use. `scripts/validate-frontmatter.py`
enforces:

| Key | Rule |
|---|---|
| `name` | kebab-case, starts with `cabuya` |
| `description` | non-empty — it is what the router matches intent against |
| `version` | a **quoted** SemVer string. Unquoted `1.0` parses as a float and reaches the host as `"1"` |
| `documentation_url` | where a human goes when the skill is wrong |
| `user-invocable` | a real boolean. `"false"` is a string, and truthy |
| `allowed-tools` | present. An absent list is not "no restrictions" to a reviewer, but it is to a host |
| `metadata.protocol.*` | router only: which spec versions this pack knows |

The validator carries a small YAML reader for machines without PyYAML, and
**cross-checks the two parsers wherever both exist** — a construct they
disagree about fails CI rather than somebody's laptop months later.

## Tests

```bash
bats tests/                              # everything
python3 scripts/validate-frontmatter.py
bash scripts/verify-integrity.sh
npx --yes shellcheck -f gcc setup.sh shared/*.sh scripts/*.sh bin/*.sh
```

**Contract tests over prose are the norm here**, not an oddity — they fail
when `cedula` leaves the deny-list or the PII stop softens into a
recommendation. Three false-failure modes were found while writing them, each
of which would have pushed an author to make the documentation *worse*: line
wraps, inline emphasis, blockquote markers. `tests/helpers.bash` handles all
three; use `says()` rather than a bare `grep`.

**Seed-test a new check**: break the thing it guards, confirm it goes red,
restore. A check that has never failed is a check nobody has verified.

Shell scripts are **bash 3.2 compatible** — macOS still ships it, and half the
machines this runs on are laptops. No associative arrays, no `mapfile`, no
`${var^^}`, and no expansion of a possibly-empty array under `set -u`.

## Adding a stack guide

The most useful contribution this pack takes, tagged
`good-first-issue:stack`. The bar is specific rather than high, and it is in
[`implement/stacks/README.md`](implement/stacks/README.md) — eight sections in
order, fingerprints that *distinguish*, where person-level columns hide in
that stack, a serializer that would run, and the catch-all fix **quoted from
`spec/SPA_EXCLUSIONS.md` rather than restated**.

`tests/stack-guides.bats` checks most of it mechanically, including that no
guide maps `updated_at` into `last_confirmed_at` and that no sample carries a
phone- or email-shaped value.

## Before a release

- `bats tests/` green
- `verify-integrity.sh` green
- Frontmatter valid, and `CHANGELOG.md` states which **spec** versions this
  release supports (rule V7)
- **The acceptance test passes on two harnesses** —
  [`docs/ACCEPTANCE_TEST.md`](docs/ACCEPTANCE_TEST.md). 10/10 and 3/3, or it
  does not ship. The cross-agent claim is only true if it has been observed
  twice.

## Commits

`type(scope): description` — `feat fix docs refactor test chore ci security`.
Scopes: `router implement consume validate publish-status setup spec stacks
shared tests ci`.

English, imperative, **signed off** (`git commit -s`). CI enforces the DCO.
