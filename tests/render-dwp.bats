#!/usr/bin/env bats
#
# The DWP renderer: plan/tasks.json in, a real DeepWorkPlan out.
#
# "Real" is the property under test — not a plan-shaped folder. The anatomy
# assertions here mirror DWP's own guide: checkbox links in the README, the
# required sections in every task file, PROGRESS.md, and nothing left of the
# template machinery in the output.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURE="$BATS_TEST_TMPDIR/adopter"
  mkdir -p "$FIXTURE"
  PLAN="$FIXTURE/.dwp/plans/PLAN_cabuya_adoption"
}

render() {
  node "$REPO/bin/render-dwp.mjs" --repo "$FIXTURE" \
    --stack-guide implement/stacks/nextjs-supabase.md \
    --publisher-id example-app --target L2 \
    --manifest-url https://app.example.invalid/.well-known/cabuya.json \
    --feed-path public/cabuya/places.json \
    --stack node --framework nextjs "$@"
}

@test "rendering produces the full DWP anatomy" {
  run render
  [ "$status" -eq 0 ]
  [ -f "$PLAN/README.md" ]
  [ -f "$PLAN/PROGRESS.md" ]
  [ -d "$PLAN/analysis_results" ]
}

@test "the README lists one checkbox with a resolvable link per task" {
  render
  count="$(grep -c '^- \[ \] Task' "$PLAN/README.md")"
  files="$(ls "$PLAN" | grep -c '^[0-9]*\.task_.*\.md$')"
  [ "$count" -eq "$files" ]
  # every linked file exists
  for link in $(grep -oE '[0-9]+\.task_[a-z_]+\.md' "$PLAN/README.md" | sort -u); do
    [ -f "$PLAN/$link" ] || { echo "dead link: $link"; return 1; }
  done
}

@test "every task file carries the required sections" {
  render
  for f in "$PLAN"/[0-9]*.task_*.md; do
    for section in "## 1. Context" "## 3. Goal" "## 4. Instructions" \
                   "## 5. Acceptance Criteria" "## 6. Validation" \
                   "## 7. Execution Checklist" "## 8. Completion & Log"; do
      grep -q "$section" "$f" || { echo "$f lacks: $section"; return 1; }
    done
  done
}

@test "numbering runs 1..N with the two finals last" {
  render
  last_two="$(ls "$PLAN" | grep -E '^[0-9]+\.task' | sort -t. -k1 -n | tail -2 | sed 's/^[0-9]*\.task_//;s/\.md$//' | tr '\n' ' ')"
  [ "$last_two" = "pii_audit report " ]
  n="$(ls "$PLAN" | grep -cE '^[0-9]+\.task')"
  for i in $(seq 1 "$n"); do
    ls "$PLAN/$i".task_*.md >/dev/null 2>&1 || { echo "missing number $i"; return 1; }
  done
}

@test "no template placeholder survives rendering" {
  render
  run grep -rn '{{' "$PLAN"
  [ "$status" -ne 0 ]
  run grep -rn '{manifest_url}\|{feed_path}\|{stack_guide}\|{target_level}' "$PLAN"
  [ "$status" -ne 0 ]
}

@test "every validation is a runnable command or an explicit human check" {
  render
  for f in "$PLAN"/[0-9]*.task_*.md; do
    section="$(awk '/^## 6. Validation/,/^## 7\./' "$f")"
    case "$section" in
      *'```bash'*|*"Human check — no command can satisfy this."*) : ;;
      *) echo "$f has neither a command nor a named human check"; return 1 ;;
    esac
  done
}

@test "the PII gate stops the plan for a human" {
  render
  gate="$(ls "$PLAN"/*task_pii_gate.md)"
  flowed "$gate" | grep -qi "THE PLAN STOPS HERE until a human decides"
}

@test "the README says the level is measured, never declared" {
  render
  says "$PLAN/README.md" "measured"
  says "$PLAN/README.md" "never a declaration"
  # "certified" may appear only inside its own prohibition
  [ "$(flowed "$PLAN/README.md" | grep -o -i "certified" | wc -l)" -le 1 ]
  flowed "$PLAN/README.md" | grep -qi "never use the word certified"
}

@test "the optional L3 task is a follow-up by default, included on request" {
  render
  run ls "$PLAN"/*task_consume_peers.md
  [ "$status" -ne 0 ]
  says "$PLAN/README.md" "follow-up"
  rm -rf "$FIXTURE/.dwp"
  render --include-l3
  ls "$PLAN"/*task_consume_peers.md
}

@test "re-rendering over an existing plan is refused, with resume instructions" {
  render
  echo "human work" > "$PLAN/1.task_read_and_detect.md"
  run render
  [ "$status" -eq 2 ]
  [[ "$output" == *"resume"* ]]
  # and nothing was touched
  [ "$(cat "$PLAN/1.task_read_and_detect.md")" = "human work" ]
}

@test "a missing argument is a refusal, not a hole in the plan" {
  run node "$REPO/bin/render-dwp.mjs" --repo "$FIXTURE" --target L2
  [ "$status" -eq 3 ]
  [[ "$output" == *"--manifest-url"* ]]
  [ ! -d "$PLAN" ]
}

@test "an unknown stack guide is a refusal" {
  run render --stack-guide implement/stacks/does-not-exist.md
  [ "$status" -eq 3 ]
}

@test "a ledger's completed steps arrive pre-marked — the ledger is the transfer" {
  # plan-mode.md promises the upgrade path; the acceptance run found the
  # renderer ignored the ledger. Now a repo that walked three steps in plan
  # mode renders with those three checked and the rest open.
  mkdir -p "$FIXTURE/.cabuya"
  cat > "$FIXTURE/.cabuya/adoption.json" <<'JSON'
{ "contract": "1.0", "created_at": "2026-08-18T10:00:00Z",
  "updated_at": "2026-08-18T10:20:00Z",
  "steps": [
    { "id": "read_and_detect", "status": "done", "completed_at": "2026-08-18T10:05:00Z" },
    { "id": "map", "status": "done", "completed_at": "2026-08-18T10:15:00Z" },
    { "id": "pii_gate", "status": "done", "completed_at": "2026-08-18T10:20:00Z" }
  ] }
JSON
  render
  [ "$(grep -c '^- \[x\]' "$PLAN/README.md")" -eq 3 ]
  grep -q '\[x\] Task 3: The PII gate' "$PLAN/README.md"
  grep -q '^- \[ \] Task 4' "$PLAN/README.md"
  grep -q 'done (from the ledger)' "$PLAN/PROGRESS.md"
}

@test "a value carrying shell metacharacters is refused at render time" {
  # The rendered Validation blocks are commands an agent later executes; a
  # poisoned argument must die here, not detonate there.
  run node "$REPO/bin/render-dwp.mjs" --repo "$FIXTURE" \
    --stack-guide implement/stacks/nextjs-supabase.md \
    --publisher-id example-app --target L2 \
    --manifest-url 'https://a.invalid/m.json;rm -rf /' \
    --feed-path public/cabuya/places.json
  [ "$status" -eq 3 ]
  [[ "$output" == *"rendered shell command"* ]]
  [ ! -d "$PLAN" ]
}
