#!/usr/bin/env bats
#
# The integrity check, exercised in the three states it can be in.
#
# The one that matters is the third: a hand-edited normative document must fail,
# because that is the failure mode the whole vendoring scheme exists to prevent.
# An agent taught a specification the working group never agreed to is worse
# than an agent with no specification at all.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # A scratch copy, so a test never touches the real spec/ directory.
  WORK="$(mktemp -d)"
  mkdir -p "$WORK/scripts" "$WORK/spec"
  cp "$REPO_ROOT/scripts/verify-integrity.sh" "$WORK/scripts/"
  cp "$REPO_ROOT/scripts/generate-checksums.sh" "$WORK/scripts/"
}

teardown() {
  rm -rf "$WORK"
}

@test "reports honestly when nothing is vendored yet" {
  run bash "$WORK/scripts/verify-integrity.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no vendored files yet"* ]]
}

@test "passes when every file matches its checksum" {
  echo "normative text" > "$WORK/spec/0-introduction.md"
  bash "$WORK/scripts/generate-checksums.sh"

  run bash "$WORK/scripts/verify-integrity.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"intact"* ]]
}

@test "fails when a vendored document is edited" {
  echo "normative text" > "$WORK/spec/0-introduction.md"
  bash "$WORK/scripts/generate-checksums.sh"

  # The whole point: one word changed in a specification nobody re-ratified.
  echo "normative text, but different" > "$WORK/spec/0-introduction.md"

  run bash "$WORK/scripts/verify-integrity.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"checksum mismatch"* ]]
}

@test "fails when a vendored file is deleted" {
  echo "normative text" > "$WORK/spec/0-introduction.md"
  bash "$WORK/scripts/generate-checksums.sh"
  rm "$WORK/spec/0-introduction.md"

  run bash "$WORK/scripts/verify-integrity.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing"* ]]
}

@test "fails when a file appears that nobody checksummed" {
  echo "normative text" > "$WORK/spec/0-introduction.md"
  bash "$WORK/scripts/generate-checksums.sh"
  # A document an adopter would read that nobody signed.
  echo "surprise" > "$WORK/spec/9-extra.md"

  run bash "$WORK/scripts/verify-integrity.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not listed"* ]]
}

@test "fails when files exist with no checksums at all" {
  echo "normative text" > "$WORK/spec/0-introduction.md"

  run bash "$WORK/scripts/verify-integrity.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no CHECKSUMS.txt"* ]]
}

@test "--list names what is vendored" {
  echo "normative text" > "$WORK/spec/0-introduction.md"
  bash "$WORK/scripts/generate-checksums.sh"

  run bash "$WORK/scripts/verify-integrity.sh" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"0-introduction.md"* ]]
}
