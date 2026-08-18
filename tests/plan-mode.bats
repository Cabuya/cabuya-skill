#!/usr/bin/env bats
#
# Plan mode: the declined-DWP path.
#
# The property under test is that this path is grounded — its sequence IS the
# task spec, not a paraphrase of it — and that its two hard rules (the human
# gate, the honest one-sentence difference) are in the prose an agent reads.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  MODE="$REPO/adopt/plan-mode.md"
  SPEC="$REPO/plan/tasks.json"
}

@test "plan mode is reachable from the adopt flow" {
  grep -q "plan-mode.md" "$REPO/adopt/SKILL.md"
}

@test "its sequence is the task spec's, in the spec's order" {
  spec_ids="$(node -e 'console.log(require(process.argv[1]).tasks.map(t=>t.id).join("\n"))' "$SPEC")"
  file_ids="$(awk '/^## The sequence/,/^## Resume/' "$MODE" \
    | grep -oE '^[0-9]+\. `[a-z_]+`' | grep -oE '`[a-z_]+`' | tr -d '\`')"
  [ -n "$file_ids" ]
  [ "$spec_ids" = "$file_ids" ]
}

@test "the human gate cannot be read out of it" {
  says "$MODE" "Stop at pii_gate and ask the human"
  says "$MODE" 'decided_by: "human"'
  says "$MODE" "never resolve one by editing the deny-list"
}

@test "the difference from DWP is one honest sentence, said once" {
  says "$MODE" "the decisions will survive in the ledger; the task detail lives in this session"
  says "$MODE" "once, at the start"
}

@test "planning writes nothing" {
  says "$MODE" "write nothing to the repository while planning"
}

@test "resume reads the ledger and never re-asks a recorded decision" {
  says "$MODE" "rebuild the plan from the first step that is not"
  says "$MODE" "never re-asked"
}

@test "the upgrade path is documented, and the ledger is the transfer" {
  says "$MODE" "the ledger is the transfer"
  grep -q "render-dwp.md" "$MODE"
}
