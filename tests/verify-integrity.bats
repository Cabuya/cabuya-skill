#!/usr/bin/env bats
#
# The integrity check, exercised in every state it can be in.
#
# The one that matters is the hand-edit: a modified normative document must fail
# the build, because that is the failure the whole vendoring scheme exists to
# prevent. An agent taught a specification the working group never agreed to is
# worse than an agent with no specification at all.
#
# Every test runs against a scratch tree, never the real spec/.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORK="$(mktemp -d)"
  mkdir -p "$WORK/scripts" "$WORK/spec" "$WORK/examples/valid"
  cp "$REPO_ROOT/scripts/verify-integrity.sh" "$WORK/scripts/"
  cp "$REPO_ROOT/scripts/generate-checksums.sh" "$WORK/scripts/"
}

teardown() {
  rm -rf "$WORK"
}

verify() { bash "$WORK/scripts/verify-integrity.sh" "$@"; }
generate() { bash "$WORK/scripts/generate-checksums.sh"; }

@test "reports honestly when nothing is vendored yet" {
  run verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"No vendored files yet"* ]]
}

@test "passes when every file matches its checksum" {
  echo "normative text" > "$WORK/spec/EXCLUSIONS.md"
  generate
  run verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"intact"* ]]
}

@test "fails when a vendored document is edited" {
  echo "normative text" > "$WORK/spec/EXCLUSIONS.md"
  generate

  # One word changed in a specification nobody re-ratified.
  echo "normative text, but different" > "$WORK/spec/EXCLUSIONS.md"

  run verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"checksum mismatch"* ]]
}

@test "fails when a vendored file is deleted" {
  echo "normative text" > "$WORK/spec/EXCLUSIONS.md"
  generate
  rm "$WORK/spec/EXCLUSIONS.md"

  run verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing"* ]]
}

@test "fails when a file appears that nobody checksummed" {
  echo "normative text" > "$WORK/spec/EXCLUSIONS.md"
  generate
  echo "who put this here" > "$WORK/spec/EXTRA.md"

  run verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"not listed in CHECKSUMS.txt"* ]]
}

@test "fails when files exist with no checksums at all" {
  echo "normative text" > "$WORK/spec/EXCLUSIONS.md"
  run verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"no spec/CHECKSUMS.txt"* ]]
}

# The examples are vendored too. invalid-2 teaches three §7 violations, and an
# example quietly edited to be less wrong teaches the wrong lesson to every
# agent that reads it — so it is covered by the same check as the schemas.
@test "covers examples/, not only spec/" {
  echo "normative text" > "$WORK/spec/EXCLUSIONS.md"
  echo '{"teaching": "example"}' > "$WORK/examples/valid/valid-minimal-core.json"
  generate

  run verify --list
  [[ "$output" == *"examples/valid/valid-minimal-core.json"* ]]

  echo '{"teaching": "something else"}' > "$WORK/examples/valid/valid-minimal-core.json"
  run verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"checksum mismatch"* ]]
}

@test "--list names what is vendored, and nothing else" {
  echo "normative text" > "$WORK/spec/EXCLUSIONS.md"
  generate

  run verify --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec/EXCLUSIONS.md"* ]]

  # Every listed line must be a real path. An earlier version printed the
  # second word of each comment line in the header, which looked like a file
  # list and was not.
  while IFS= read -r line; do
    case "$line" in
      "Vendored files:") continue ;;
      "") continue ;;
    esac
    path="$(printf '%s' "$line" | sed 's/^ *//')"
    [ -f "$WORK/$path" ] || {
      echo "listed but not a file: '$path'"
      return 1
    }
  done <<< "$output"
}

@test "a .gitkeep is not mistaken for a vendored document" {
  touch "$WORK/spec/.gitkeep"
  run verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"No vendored files yet"* ]]
}
