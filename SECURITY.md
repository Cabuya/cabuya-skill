# Security policy

## Reporting

**Open a [private security advisory](https://github.com/Cabuya/cabuya-skill/security/advisories/new)
on this repository.** It is visible only to repository administrators, it does
not create a public issue, and it gives us a place to answer you.

Write in Spanish or English. Both get the same response.

| | |
|---|---|
| Acknowledgement | Within **48 hours**, naming who is handling it |
| First assessment | Within **7 days** |
| Disclosure window | **90 days**, or sooner if a fix ships sooner |
| Credit | Named in the advisory if you want it, anonymous if you prefer |

## Why this pack is a security surface at all

It is a set of instructions that a coding agent executes inside somebody else's
repository, with their credentials, against their production data pipeline. The
interesting failures here are not memory-safety bugs. They are:

**Anything that makes the pack write something the adopter did not consent to.**
Every write to a repository, every fetch of a third-party feed, and every
person-level-data decision is supposed to ask first. A path that skips one of
those confirmations is a serious finding even if what it writes is correct.

**Anything that gets person-level data into a feed.** The protocol's central
promise is a join prohibition, and this pack is what most implementations will
be built by. A mapping that lets a personal phone number reach a published feed
is the worst bug this repository can have.

**Anything that lets a false conformance claim be published.** The pack must
never write a compatibility badge; it runs the validator and reports what it
found. A path that asserts conformance without a measurement defeats the only
mechanism the protocol has.

**Anything that makes the vendored specification untrustworthy.** `spec/` is
checksummed against the canonical source. A way to defeat that check means an
agent could be taught a standard nobody wrote.

## Out of scope

- Vulnerabilities in an adopter's own application. Report those to them.
- Vulnerabilities in the agent host (Claude Code, Cursor, Codex, …). Report
  those to the vendor; tell us too if the pack makes them reachable.
- Findings that require the adopter to have already granted write access to a
  hostile party.

## Supported versions

Only the latest release. There is no backport branch, and pretending otherwise
would be a maintenance promise this project cannot keep.

## What the pack promises

The full posture, with a self-audit you can run, is in `TRUST.md`. In short: it
reads your repository, it writes only where you agreed, it fetches only what
you asked it to fetch, and it holds no credential of yours at any point.
