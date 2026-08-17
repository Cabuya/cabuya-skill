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
- `scripts/sync-spec.sh` — the only writer of `spec/`. Records provenance,
  refuses to run over uncommitted work at either end, and regenerates
  checksums.
- `shared/spec-paths.md` — what is vendored versus authored, the V1–V7
  versioning rules, and the resolution order when sources disagree.
- Repository skeleton, Apache-2.0 licence, and the standards layer: CI running
  frontmatter validation, shellcheck, bats and a Markdown link check;
  issue-form templates; dependabot; a pull-request checklist.
- `scripts/validate-frontmatter.py` — the frontmatter conventions every
  `SKILL.md` in this pack must satisfy, including the Cabuya addition
  `metadata.protocol.supported_spec_versions`.
- `scripts/verify-integrity.sh` — checksum verification for the vendored
  specification. Reports honestly that nothing is vendored yet rather than
  passing silently.

**Installable, but not yet complete.** The router, the trust contract, the
installer and the vendored specification are in — an agent that installs the
pack can already answer questions about the protocol offline. The five
sub-skills that *do* the work (implement, consume, validate, publish-status,
setup) land in the releases that follow, and `setup.sh` reports each one as
"not in this version" until it does.
