# Contributing to the Cabuya skill

This pack is the adoption engine for the protocol: it turns an afternoon of a
volunteer's time into twenty minutes of an agent's time plus one human
decision. Contributions that make that shorter, clearer or harder to get wrong
are the ones this repository wants.

## Ground rules

1. **A first pull request gets a review, not a redesign.** If the approach is
   wrong, that is a conversation before anybody is asked to rewrite anything.
   First response within 48 hours.
2. **Never hand-edit `spec/`.** It is a vendored copy of the protocol
   contracts, checksummed against the canonical source. A change there is a
   change to the standard, and the standard changes through an RFC in
   [`Cabuya/cabuya.org`](https://github.com/Cabuya/cabuya.org). CI will catch
   an edit; the RFC is the way to make one.
3. **The five rules are not negotiable in any code path.** No person-level
   data, no contact values in feeds, no scraping, honour crawl policy, never
   claim conformance the validator has not measured. A sub-skill that reasons
   its way around one of them is a bug, however useful the feature.
4. **Never weaken a check to make CI pass.** If a check is wrong, fix the
   check and say so in the pull request. If it is right, it found something.
5. **No placeholder content.** An absent file is honest; a file containing
   `TODO` is a promise nobody made.

## Where the work is

| Label | What it is |
|---|---|
| `good-first-issue:stack` | A guide for a stack you know — the highest-value thing an outsider can contribute on day one, because it needs *your* domain knowledge rather than project knowledge |
| `good-first-issue:example` | A worked example with a teaching comment |
| `good-first-issue:translation` | Spanish or English for a sub-skill's prose |
| `help-wanted:probe` | Reproduce a behaviour against a real stack, so a bug report becomes a fixture |

## Running the checks

Everything CI runs, runnable locally:

```bash
python3 skills/cabuya/scripts/validate-frontmatter.py   # frontmatter conventions on every SKILL.md
bash skills/cabuya/scripts/verify-integrity.sh          # the vendored spec matches upstream
shellcheck setup.sh skills/cabuya/scripts/*.sh          # shell hygiene (skips what does not exist yet)
bats tests/                                             # the shell surface
```

### The registry snapshot

`skills/cabuya/consume/registry-snapshot.json` is the offline copy of the
publisher list that `consume` starts from. It is **org-level data only** —
publisher ids, canonical URLs, entity domains, status — never contact values,
and never measured conformance state (that lives in the live registry and is
deliberately absent). Regenerate it from the website repository's
`registry/publishers/*.json` when publishers change: copy the org-level
fields, update `_provenance.retrieved_at`, and let
`tests/registry-snapshot.bats` check the rest.

`shellcheck` and `bats` come from your package manager (`apt install shellcheck
bats`, `brew install shellcheck bats-core`). `validate-frontmatter.py` needs
Python 3.11 and `pyyaml`.

### Shell compatibility

**Bash 3.2.** macOS still ships it, and a script that needs bash 4 fails on
half the machines this pack is meant to run on. No associative arrays, no
`mapfile`, no `${var,,}`. CI runs the smoke tests on both Linux and macOS for
exactly this reason.

## Commits

[Conventional commits](https://www.conventionalcommits.org/):
`type(scope): description`, English, imperative. Types: `feat fix docs
refactor test chore ci build security`.

### Developer Certificate of Origin

Sign off every commit:

```bash
git commit -s -m "type(scope): description"
```

That adds a `Signed-off-by:` trailer stating you have the right to contribute
the work, under the [DCO 1.1](https://developercertificate.org/). CI checks for
it; `git commit --amend -s` fixes the last one if you forget.

There is **no CLA**. There is no legal entity to assign rights to, and CLA
friction measurably deters exactly the drive-by contributions this project
depends on.

## Language

Write in Spanish or English, whichever you think in. **Code, comments, commit
messages, file names and frontmatter keys are English**, because the pack is
read by people who share no other language. **Prose an adopter reads is both**,
natively written in each. An issue in Spanish gets an answer in Spanish.

## The line that never moves

**No person-level data anywhere in this repository** — code, prose, fixtures,
examples, tests. No personal names, personal phone numbers, personal emails,
personal media. Organisation-level role addresses published by the
organisations themselves are the only exception.

This is not squeamishness about test data. The protocol's central design
decision is a join prohibition, and a repository containing person-level
examples teaches every agent that reads it that the line is softer than it is.

## Code of Conduct

The [Contributor Covenant 2.1](https://github.com/Cabuya/cabuya.org/blob/main/CODE_OF_CONDUCT.md),
adopted at the organisation level, with two additions: reports go to a role
held by maintainers from two different applications, never to an individual,
and a maintainer who is the subject of a report takes no part in handling it.
