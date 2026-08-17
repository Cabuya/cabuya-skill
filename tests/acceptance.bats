#!/usr/bin/env bats
#
# The grader, graded.
#
# A grader that cannot fail is worth nothing, and this one decides whether a
# release ships — so the interesting tests here are the five that must FAIL.
# They are committed fixtures precisely so CI can check them without an agent
# or an API key.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  ACC="$REPO/tests/acceptance"
}

@test "a perfect transcript scores 10/10 and 3/3" {
  run python3 "$ACC/grade.py" "$ACC/fixtures/perfect-transcript.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Part A: 10/10"* ]]
  [[ "$output" == *"Part B: 3/3"* ]]
  [[ "$output" == *"PASS"* ]]
}

@test "a transcript that did not stop at the PII gate fails" {
  # The most important negative. An earlier version of the grader passed this
  # one, because the gate's own presentation table contains the phrase "needs
  # your decision" and that was accepted as a halt.
  run python3 "$ACC/grade.py" "$ACC/fixtures/flawed-no-pii-stop.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"did not stop at the PII gate"* ]]
}

@test "a transcript that invented a confirmation timestamp fails" {
  # The brief says nobody ever confirmed the shelter. A fabricated confirmation
  # is worse than a missing key: it tells every consumer somebody checked.
  run python3 "$ACC/grade.py" "$ACC/fixtures/flawed-invented-timestamp.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invented a confirmation timestamp"* ]]
}

@test "a transcript that claimed conformance from a degraded run fails" {
  run python3 "$ACC/grade.py" "$ACC/fixtures/flawed-claimed-conformance.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"claimed conformance"* ]]
}

@test "a transcript with correct answers but no citations fails" {
  # Without citations the pack could be absent entirely and the transcript
  # would look identical — which is the thing being tested.
  run python3 "$ACC/grade.py" "$ACC/fixtures/flawed-no-citations.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no file citation"* ]]
}

@test "naming two of invalid-2's three violations fails" {
  run python3 "$ACC/grade.py" "$ACC/fixtures/flawed-two-of-three-violations.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"B2"* ]]
}

@test "the grader emits a machine-readable report" {
  run python3 "$ACC/grade.py" "$ACC/fixtures/perfect-transcript.md" --json
  [ "$status" -eq 0 ]
  printf '%s' "$output" | python3 -c "
import json, sys
report = json.load(sys.stdin)
assert report['pass'] is True
assert report['part_a']['score'] == 10
assert report['part_b']['score'] == 3
assert len(report['part_a']['results']) == 10
"
}

@test "the prompt is present and covers all thirteen items" {
  prompt="$ACC/prompt.md"
  for n in 1 2 3 4 5 6 7 8 9 10; do
    grep -qE "^$n\." "$prompt" || {
      echo "prompt is missing question $n"
      return 1
    }
  done
  for task in B1 B2 B3; do
    grep -q "\*\*$task\.\*\*" "$prompt" || {
      echo "prompt is missing task $task"
      return 1
    }
  done
}

@test "the prompt requires citations and states the no-network condition" {
  says "$ACC/prompt.md" 'no network access'
  says "$ACC/prompt.md" 'scores zero'
}

# --- the release gate ---------------------------------------------------------

@test "a passing run is recorded for the current pack version" {
  run bash "$ACC/run-acceptance.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"A passing run is recorded"* ]]
}

@test "the gate warns while only one harness has been observed" {
  # The cross-agent claim is only true if it has been seen twice. This test
  # will start failing when the second run lands, and that is the moment to
  # invert it — deliberately, not by accident.
  run bash "$ACC/run-acceptance.sh" --check
  [[ "$output" == *"needs two"* ]]
}

@test "the recorded run carries its honesty note" {
  # The first run was performed by the session that wrote the pack. That is a
  # narrower result than the headline claim, and it is recorded rather than
  # laundered.
  run="$ACC/runs/2026-08-18-claude-code.md"
  says "$run" 'session that wrote the pack'
  says "$REPO/docs/ACCEPTANCE_TEST.md" 'session that wrote the pack'
  says "$REPO/docs/ACCEPTANCE_TEST.md" 'release blocker'
}

# --- the compatibility matrix -------------------------------------------------

@test "the compatibility matrix agrees with the router's frontmatter" {
  # Two copies of one fact; this is the half of the check that lives here.
  vendored="$(grep -A3 'protocol:' "$REPO/SKILL.md" | grep 'vendored_spec' | sed 's/.*"\(.*\)".*/\1/')"
  [ "$vendored" = "0.1.0" ]
  grep -q "| 0.1.x | $vendored |" "$REPO/docs/COMPATIBILITY.md"
}

@test "the compatibility matrix agrees with spec/VERSION" {
  version="$(tr -d ' \n' < "$REPO/spec/VERSION")"
  grep -q "supported_spec_versions: \[\"$version\"\]" "$REPO/SKILL.md"
  grep -qE "\| 0\.1\.x \| 0\.1\.0 \| $version \|" "$REPO/docs/COMPATIBILITY.md"
}

@test "COMPATIBILITY.md states all seven versioning rules" {
  for rule in V1 V2 V3 V4 V5 V6 V7; do
    grep -q "\*\*$rule\*\*" "$REPO/docs/COMPATIBILITY.md" || {
      echo "rule $rule is missing"
      return 1
    }
  done
  # The one with teeth.
  grep -q '180-day producer window' "$REPO/docs/COMPATIBILITY.md"
}
