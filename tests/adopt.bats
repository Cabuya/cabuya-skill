#!/usr/bin/env bats
#
# The front door: /cabuya-adopt and the planning detector.
#
# What these pin is the precedence contract — resume, then the adopter's own
# methodology, then DeepWorkPlan, then the offer, then plan mode — and the
# rule that makes a second session trustworthy: nothing recorded is re-asked.

setup() {
  load helpers
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  REPO="$ROOT/skills/cabuya"
  ADOPT="$REPO/adopt/SKILL.md"
  ROUTER="$REPO/SKILL.md"
  DETECT="$REPO/shared/detect-planning.sh"
}

# A scratch repo the detector can be pointed at.
make_fixture() {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIXTURE"
  git -C "$FIXTURE" init -q
}

detect() {
  (cd "$FIXTURE" && HOME="$BATS_TEST_TMPDIR/nohome" bash "$DETECT")
}

# --- routing ------------------------------------------------------------------

@test "the router lists Adopt first, before Implement" {
  adopt_line="$(grep -n 'adopt/SKILL.md' "$ROUTER" | head -1 | cut -d: -f1)"
  implement_line="$(grep -n 'implement/SKILL.md' "$ROUTER" | grep -v adopt | head -1 | cut -d: -f1)"
  [ -n "$adopt_line" ]
  [ "$adopt_line" -lt "$implement_line" ]
}

@test "ambiguous intent routes to Adopt, which writes nothing" {
  says "$ROUTER" "if the intent is ambiguous, route to Adopt"
}

@test "adopt duplicates no procedure that lives in another sub-skill" {
  # The six phase headings belong to implement/SKILL.md and nowhere else.
  for heading in "Phase 0 · Read" "Phase 1 · Map" "Phase 2 · The PII gate" \
                 "Phase 3 · Serialize" "Phase 4 · Discover" "Phase 5 · Loop"; do
    if grep -q "$heading" "$ADOPT"; then
      echo "adopt/SKILL.md carries a phase that belongs to implement: $heading"
      return 1
    fi
  done
}

# --- the precedence contract --------------------------------------------------

@test "the precedence order is stated, in order" {
  flowed "$ADOPT" | grep -qi \
    "Resume what exists → the adopter's own methodology → DeepWorkPlan if installed → offer to install it → the agent's own plan mode"
}

@test "the methodology question comes before the DWP offer" {
  question_line="$(grep -n "Do you already have a spec-driven development methodology" "$ADOPT" | head -1 | cut -d: -f1)"
  offer_line="$(grep -n "^## Step 4 · DeepWorkPlan, offered" "$ADOPT" | head -1 | cut -d: -f1)"
  [ -n "$question_line" ] && [ -n "$offer_line" ]
  [ "$question_line" -lt "$offer_line" ]
}

@test "the DWP offer includes its onboarding, and is made once" {
  says "$ADOPT" "install it and run its onboarding"
  says "$ADOPT" "no second pitch"
}

@test "the DWP hand-off names a command that exists" {
  grep -q "/dwp-execute cabuya_adoption" "$ADOPT"
}

@test "the declined path routes to plan-mode.md, which carries the honest cost" {
  grep -q "plan-mode.md" "$ADOPT"
  says "$REPO/adopt/plan-mode.md" "the decisions will survive in the ledger; the task detail lives in this session"
}

@test "every path ends at the validator" {
  says "$ADOPT" "the methodology owns the how; the validator owns the whether"
  grep -q "run-validator.sh validate" "$ADOPT"
}

@test "no methodology is named outside the registry" {
  # plan/methodologies.json is the single naming site, so adding one is a
  # JSON entry. DeepWorkPlan is the exception by design: it is the rendered
  # path, not a registry lookup.
  for name in "spec kit" speckit kiro bmad; do
    if grep -qil -- "$name" "$ADOPT" "$ROUTER" "$REPO/shared/detect-planning.sh"; then
      echo "a methodology is named outside plan/methodologies.json: $name"
      return 1
    fi
  done
}

# --- never re-ask -------------------------------------------------------------

@test "recorded decisions are never re-asked" {
  says "$ADOPT" "recorded methodology.*that answer stands"
  says "$ADOPT" "never re-ask what is written"
}

@test "the edge cases are written down: newer major, publisher mismatch, existing plan" {
  says "$ADOPT" "read it and explain it; never write to it"
  says "$ADOPT" "stop and ask which is right"
  says "$ADOPT" "never regenerate or overwrite"
}

# --- the detector -------------------------------------------------------------

@test "detector: a repo with no planning surface reports everything absent" {
  make_fixture
  run detect
  [ "$status" -eq 0 ]
  [[ "$output" == *'"dwp_installed":false'* ]]
  [[ "$output" == *'"candidates":[]'* ]]
  [[ "$output" == *'"ledger":"absent"'* ]]
  [[ "$output" == *'"plan_present":false'* ]]
}

@test "detector: an installed DeepWorkPlan is found at the repo level" {
  make_fixture
  mkdir -p "$FIXTURE/.agents/skills/deepworkplan"
  run detect
  [[ "$output" == *'"dwp_installed":true'* ]]
}

@test "detector: a foreign methodology marker becomes a candidate, not a decision" {
  make_fixture
  mkdir -p "$FIXTURE/.specify"
  run detect
  [[ "$output" == *'"candidates":["github-spec-kit"]'* ]]
  # And the prose treats it as evidence to confirm:
  says "$ADOPT" "the human confirms"
}

@test "detector: a ledger's recorded answers surface so they are not re-asked" {
  make_fixture
  mkdir -p "$FIXTURE/.cabuya"
  cp "$REPO/plan/examples/valid/adoption.json" "$FIXTURE/.cabuya/adoption.json"
  run detect
  [[ "$output" == *'"ledger":"present"'* ]]
  [[ "$output" == *'"methodology_recorded":"deepworkplan"'* ]]
  [[ "$output" == *'"pii_decided":"true"'* ]]
}

@test "detector: a newer contract major is flagged read-only" {
  make_fixture
  mkdir -p "$FIXTURE/.cabuya"
  printf '{"contract":"2.0","created_at":"2026-08-18T00:00:00Z","updated_at":"2026-08-18T00:00:00Z"}' \
    > "$FIXTURE/.cabuya/adoption.json"
  run detect
  [[ "$output" == *'"ledger_newer_major":true'* ]]
}

@test "detector: an existing rendered plan is reported for resume" {
  make_fixture
  mkdir -p "$FIXTURE/.dwp/plans/PLAN_cabuya_adoption"
  run detect
  [[ "$output" == *'"plan_present":true'* ]]
}

@test "detector output is valid JSON" {
  make_fixture
  detect | node -e "JSON.parse(require('fs').readFileSync(0,'utf8'))"
}

# --- installation surface -----------------------------------------------------

@test "setup.sh links adopt with the other sub-skills" {
  grep -q 'SUBSKILLS="adopt ' "$ROOT/setup.sh"
}

@test "TRUST.md names both files the pack may write, and how to remove them" {
  says "$REPO/TRUST.md" ".cabuya/adoption.json"
  says "$REPO/TRUST.md" "PLAN_cabuya_adoption"
  says "$REPO/TRUST.md" "only with your consent"
  says "$REPO/TRUST.md" "rm -r .cabuya/"
}
