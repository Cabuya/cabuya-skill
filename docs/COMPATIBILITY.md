# Compatibility

Two independent SemVer streams. The mistake this page exists to prevent is a
pack whose version number implies a specification version.

## The matrix

| Pack | Vendored spec | Supports | Validator range |
|---|---|---|---|
| 0.1.x | 0.1.0 | 0.1 | `^0.1` |

Read it as: pack 0.1.x carries a copy of specification 0.1.0 in `spec/`, can
implement and validate against specification MINOR 0.1, and resolves a
validator in the `^0.1` range.

The pack's own `version` says nothing about which specification it knows. That
is what `metadata.protocol` in the router's frontmatter is for:

```yaml
metadata:
  protocol:
    supported_spec_versions: ["0.1"]   # every MINOR this pack can work with
    vendored_spec: "0.1.0"             # the exact copy in spec/
```

Both are validated by `scripts/validate-frontmatter.py` on every push.

## The rules

| Rule | Statement |
|---|---|
| **V1** | The pack's `version` is its own. It never mirrors the specification version. |
| **V2** | `supported_spec_versions` lists every specification MINOR the pack can implement and validate against; `vendored_spec` names the exact copy in `spec/`. |
| **V3** | Adding support for a new specification MINOR is a pack **MINOR** bump. |
| **V4** | Dropping support for a specification MAJOR is a pack **MAJOR** bump — and may not happen inside the specification's **180-day producer window**. |
| **V5** | The pack supports at most **two specification MAJORs** at once, matching the specification's own rule. |
| **V6** | `scripts/sync-spec.sh` is the only writer of `spec/`; CI verifies `CHECKSUMS.txt` on every pull request. A hand-edited vendored schema fails the build. |
| **V7** | `CHANGELOG.md` states, for every release, which specification versions it supports — so an adopter reading one file knows whether it applies to them. |

V4 is the one with teeth. The specification gives producers 180 days on a
MAJOR bump, and a pack that dropped support faster would strand publishers
inside a window the specification promised them.

## Which validator this pack resolves

`bin/run-validator.sh` derives the range from `spec/VERSION` rather than
carrying a literal. A pack vendoring 0.1 resolves
`npx @cabuya/validator@^0.1.0`.

This matters more than it looks: a 0.2 validator disagrees with a 0.1 pack
about what conforms, and the pack would report that disagreement to the
adopter as their own bug. Proven by a test that changes `spec/VERSION` and
asserts the range follows.

## Keeping this page and the website in step

The same matrix is published at
<https://cabuya.org/developers/skill#compatibility>. Two copies, and the usual
consequence: one drifts.

The half of the check that lives in this repository is
`tests/compatibility.bats` — it asserts that the matrix here agrees with the
router's frontmatter and with `spec/VERSION`, so this page cannot drift from
the pack it describes. The website's half compares its rendered page against
the pack's frontmatter, which it can read directly from this repository.

If you change what this pack supports, the order is: frontmatter → `spec/`
(via `sync-spec.sh`) → this page → `CHANGELOG.md`. The tests will tell you
which one you forgot.
