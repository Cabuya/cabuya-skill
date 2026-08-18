# Cabuya skill

The installable agent pack for the **[Cabuya Protocol](https://cabuya.org)** —
an open interoperability standard for emergency-aid applications.

Install it and your coding agent knows the schema, the conformance levels, the
exclusions and the validator's check ids. It works with **no network at all**,
because the specification travels inside the pack rather than being fetched.

> **Status: in development.** The skeleton and its standards layer are here;
> the router, the sub-skills and the vendored specification land in the tasks
> that follow. Nothing here is installable yet, and this README will stop
> saying so on the day it is.

---

## Why it vendors the specification

An agent that has to fetch a standard will invent one when the fetch fails, and
it will invent it confidently. A specification on disk cannot be hallucinated.

So `spec/` holds the protocol contracts, checksummed against the canonical
copy in [`Cabuya/cabuya.org`](https://github.com/Cabuya/cabuya.org), and
`scripts/verify-integrity.sh` proves the copy has not drifted. That check runs
in CI on every push, because a vendored standard nobody verifies is a
standard that quietly becomes a fork.

## What it will not do

Five rules, stated before any procedure in the pack itself, because these are
the ones an agent must not reason its way around:

1. **No person-level data.** Ever, in any field, under any profile.
2. **No contact values in feeds.** `public_url` and a link-out; the fact that
   somebody can be reached, never the number.
3. **No scraping.** It does not acquire another publisher's data by any means
   they did not publish for that purpose.
4. **Honour crawl policy.** Declared `permitted_use` and `robots.txt` are
   respected in the code it writes, not in a comment.
5. **Never claim conformance the validator has not measured.** It will not
   write a compatibility badge into your README. It will run the validator and
   show you what it found.

Beyond those: every write to your repository, every fetch of a third-party
feed, and every person-level-data decision asks first. `TRUST.md` describes
exactly what the pack touches, with a self-audit you can run.

## Repository map

| Path | What is in it |
|---|---|
| `SKILL.md` | The router. Maps intent to a sub-skill and runs nothing itself |
| `TRUST.md` | What this pack will and will not do on your machine |
| `adopt/` | The front door: orient, ask who plans, hand off — resume without re-asking |
| `plan/` | The adoption as a machine-readable task spec; the ledger contract |
| `implement/` | From your data model to a conforming feed — stacks, mapping, templates |
| `consume/` | The six consumption rules as generated code with self-tests |
| `validate/` | Run the validator, parse the JSON report, group by what to do next |
| `publish-status/` | Manifest level, orderly wind-down, the registry pull request |
| `setup/` | The doctor: toolchain, validator, paths, network |
| `shared/` | Notes several sub-skills read: the deny-list, crawl policy, stack detection |
| `spec/` | The vendored protocol contracts. **Never hand-edited** — see below |
| `examples/` | Worked examples and per-stack serializer sketches |
| `addons/` | Opt-in extras. Declining one leaves a fully working pack |
| `scripts/` | Repository tooling — frontmatter validation, integrity verification |
| `tests/` | bats tests for the shell surface |

## Installing it

The four supported paths, with the reasoning behind each, are documented at
**[cabuya.org/developers/skill](https://cabuya.org/developers/skill)**. The
short version, once the pack ships:

```bash
git clone --depth 1 https://github.com/Cabuya/cabuya-skill \
  .agents/skills/cabuya && rm -rf .agents/skills/cabuya/.git
```

Vendored into your own repository is the recommended path: reviewable in a pull
request, pinned to a commit, and offline.

Cloned somewhere else? `bash setup.sh` links the pack and each sub-skill into
every agent it finds on the machine — `--host claude` to pick one, `--dry-run`
to see what it would do first. It links rather than copies, so `git pull`
updates every agent at once, and it will not replace a real file that is
already sitting where a symlink would go.

**There is no `curl … | bash` one-liner here, and there will not be.** A pipe
streams, so a truncated download executes a partial script — and in a shell
without `pipefail` a failed download exits `0`, reporting success while
installing nothing. The installer is offered as download, verify, run.

## The name and the badge

The protocol is open; the name and the conformance badge are not. They are
gated on passing the public validator, free forever, and revocable — the full
policy is [`TRADEMARK.md`](https://github.com/Cabuya/cabuya.org/blob/main/TRADEMARK.md)
in the website repository.

Practically, for this pack: it never writes a compatibility claim into your
project, and it never uses the word *certified*, because nobody certifies
anything here.

## Licensing

- **Code: Apache-2.0** — this repository, the scripts, the templates.
- **`spec/`: CC0-1.0** — the vendored protocol contracts carry the licence of
  the specification itself. Public domain, fork it freely.

Contributions are under the [DCO](CONTRIBUTING.md#developer-certificate-of-origin),
not a CLA.

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md). The short version: sign off your commits
with `git commit -s`, run the checks below before opening a pull request, and
never hand-edit anything under `spec/`.

```bash
python3 scripts/validate-frontmatter.py   # SKILL.md frontmatter conventions
bash scripts/verify-integrity.sh          # the vendored spec matches upstream
shellcheck scripts/*.sh                   # shell hygiene
bats tests/                               # the shell surface
```
