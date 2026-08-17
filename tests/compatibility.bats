#!/usr/bin/env bats
#
# The compatibility matrix, and the version strings it has to agree with.
#
# The same fact — which specification version this pack implements — is stated
# in four places: `spec/VERSION`, the router's frontmatter, the matrix in
# `docs/COMPATIBILITY.md`, and the validator range the runner derives. Four
# copies of one fact is three opportunities for drift, and the one that drifts
# is the one an adopter reads.
#
# This is the half of the check that lives in this repository. The website's
# half compares its published `/developers/skill#compatibility` page against
# the same frontmatter, which it can read from here directly.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  VERSION="$(tr -d ' \n\r' < "$REPO/spec/VERSION")"
}

@test "spec/VERSION is a MAJOR.MINOR string" {
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]
}

@test "the router declares the version that is actually vendored" {
  grep -q "supported_spec_versions: \[\"$VERSION\"\]" "$REPO/SKILL.md"
  grep -q "vendored_spec: \"$VERSION\.[0-9]" "$REPO/SKILL.md"
}

@test "the compatibility matrix names the same version" {
  says "$REPO/docs/COMPATIBILITY.md" "| $VERSION |"
}

@test "the runner derives its validator range rather than hardcoding one" {
  # A pack vendoring 0.1 must not pull a validator built for 0.2: the two
  # disagree about what conforms, and the pack would report the disagreement
  # to the adopter as their own bug.
  run bash "$REPO/bin/run-validator.sh" --which
  [[ "$output" == *"@cabuya/validator@^$VERSION."* ]]
}

@test "COMPATIBILITY states all seven versioning rules" {
  for rule in V1 V2 V3 V4 V5 V6 V7; do
    says "$REPO/docs/COMPATIBILITY.md" "$rule" || {
      echo "rule $rule is missing"
      return 1
    }
  done
}

@test "the CHANGELOG says which spec versions this release supports (V7)" {
  # So an adopter reading one file knows whether the release applies to them.
  says "$REPO/CHANGELOG.md" "Specification versions supported"
  says "$REPO/CHANGELOG.md" "$VERSION"
}

@test "the install commands name the repository that exists" {
  # `Cabuya/skill` appears in the founding blueprint; the repository is
  # `Cabuya/cabuya-skill`, and an install command that 404s is the worst
  # possible first impression.
  grep -q 'Cabuya/cabuya-skill' "$REPO/SKILL.md"
  ! grep -qE 'github\.com/Cabuya/skill\b' "$REPO"/*.md
}

@test "AGENTS.md and CLAUDE.md are the same document" {
  # Other agents read AGENTS.md; Claude Code reads CLAUDE.md. Two files would
  # be two sets of instructions.
  [ -L "$REPO/CLAUDE.md" ]
  [ "$(readlink "$REPO/CLAUDE.md")" = "AGENTS.md" ]
}
