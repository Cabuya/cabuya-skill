# Changelog

All notable changes to the Cabuya skill pack. Format:
[Keep a Changelog](https://keepachangelog.com/); versioning: SemVer, with the
pack's supported specification versions declared in the router's frontmatter.

## [Unreleased]

**Specification versions supported by this release: 0.1** (vendored copy
`0.1.0`). Rule V7: every release states this, so an adopter reading one file
knows whether the pack applies to them.

### Added

- `SKILL.md` — the router. Maps intent to a sub-skill, answers "what is
  Cabuya?" directly from the vendored summary, and states the five rules that
  never bend before any procedure.
- `TRUST.md` — what the pack will and will not do on your machine, with a
  self-audit section: five commands that check the claims rather than
  restating them.
- `setup.sh` — multi-agent installer. Links rather than copies; refuses to
  replace anything that is not its own symlink.
- `shared/context.sh` — one line of JSON describing the repository, the
  detected stack, and where `/.well-known/cabuya.json` would actually be
  served from.
- `spec/` — the vendored protocol layer: the schemas, the vocabulary, §7
  verbatim as `EXCLUSIONS.md`, and `PROTOCOL_SUMMARY.md`, the distilled
  payload that makes the pack useful with no network.
- `examples/` — the five teaching examples, vendored and checksummed with
  everything else.
- `consume/SKILL.md` + `consume/rules.md` — reading the network without
  breaking its rules. The six MUSTs, each with the self-test that keeps it
  true after the next refactor.
- `publish-status/SKILL.md` — the manifest is a claim; this keeps it true. It
  refuses a `conformance_target` above the measured level, and makes winding
  down a supported path rather than an outage.
- `shared/crawl-policy.md` — the honour rule, including the clause that holds
  even when a human asks directly.
- `validate/SKILL.md` — run the validator, parse the JSON report, present
  findings grouped by what to do next. Declares no `Edit` or `Write`:
  measuring does not change anything.
- `setup/SKILL.md` — the doctor. Diagnoses; never installs.
- `bin/run-validator.sh` — four-order resolution, with the npx range derived
  from `spec/VERSION` rather than hardcoded.
- `bin/degraded-check.mjs` — the offline partial answer. Reports
  "schema-valid; conformance unmeasured", never "conforming", and names both
  the probes it could not run and the checks it does not implement.
- `shared/validator.md`, `shared/error-codes.md` — the report shape, the exit
  codes, and what each check-id family means in a fix loop.
- `scripts/sync-spec.sh` — the only writer of `spec/`. Records provenance,
  refuses to run over uncommitted work at either end, and regenerates
  checksums.
- `shared/spec-paths.md` — what is vendored versus authored, the V1–V7
  versioning rules, and the resolution order when sources disagree.
- `implement/stacks/` — four guides: Next.js + Supabase/Prisma, Vite SPA +
  Supabase, PHP server-rendered, and a spreadsheet with no backend at all
  (the HXL on-ramp). One skeleton each, and a guide-authoring contract for
  contributors.
- `spec/SPA_EXCLUSIONS.md` — the catch-all fixes, **generated** from the
  validator package rather than copied, so the pack's copy cannot become the
  one that drifts.
- Repository skeleton, Apache-2.0 licence, and the standards layer: CI running
  frontmatter validation, shellcheck, bats and a Markdown link check;
  issue-form templates; dependabot; a pull-request checklist.
- `scripts/validate-frontmatter.py` — the frontmatter conventions every
  `SKILL.md` in this pack must satisfy, including the Cabuya addition
  `metadata.protocol.supported_spec_versions`.
- `scripts/verify-integrity.sh` — checksum verification for the vendored
  specification. Reports honestly that nothing is vendored yet rather than
  passing silently.

**All five sub-skills are in.** An agent can take an app from a database to a
measured feed, read its peers' feeds under the six consumption rules, publish
a level it has actually earned, and wind down without stranding anybody. What
remains before a release is the acceptance test — the procedure that decides
whether an installed pack really does teach an offline agent the protocol.
