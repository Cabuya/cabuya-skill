# Changelog

All notable changes to the Cabuya skill pack. Format:
[Keep a Changelog](https://keepachangelog.com/); versioning: SemVer, with the
pack's supported specification versions declared in the router's frontmatter.

## [Unreleased]

### Added

- Repository skeleton, Apache-2.0 licence, and the standards layer: CI running
  frontmatter validation, shellcheck, bats and a Markdown link check;
  issue-form templates; dependabot; a pull-request checklist.
- `scripts/validate-frontmatter.py` — the frontmatter conventions every
  `SKILL.md` in this pack must satisfy, including the Cabuya addition
  `metadata.protocol.supported_spec_versions`.
- `scripts/verify-integrity.sh` — checksum verification for the vendored
  specification. Reports honestly that nothing is vendored yet rather than
  passing silently.

**Nothing here is installable yet.** The router, the five sub-skills and the
vendored specification land in the tasks that follow.
