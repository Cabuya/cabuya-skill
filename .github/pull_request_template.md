## What this changes

<!-- One or two sentences. What is different after this merges, and why. -->

## Checks

- [ ] `python3 skills/cabuya/scripts/validate-frontmatter.py` passes
- [ ] `bash skills/cabuya/scripts/verify-integrity.sh` passes
- [ ] `shellcheck` clean on every script this touches
- [ ] `bats tests/` passes
- [ ] Commits signed off (`git commit -s`)

## The rules this pack does not bend

- [ ] No person-level data anywhere — code, prose, fixtures, examples, tests
- [ ] No contact values in a feed; `public_url` and link-out only
- [ ] Nothing here claims conformance the validator has not measured
- [ ] `spec/` was not hand-edited (a change to the standard goes through an RFC
      in `Cabuya/cabuya.org`; re-vendoring regenerates checksums in the same
      commit)
- [ ] No placeholder content — `TODO`, `TBD`, an empty file standing in for a
      real one

## Anything a reviewer should know

<!-- A decision you were unsure about, a trade-off you made, something you -->
<!-- could not test. This section is more useful than the checkboxes. -->
