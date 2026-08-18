#!/usr/bin/env bats
#
# The adoption task spec and the ledger contract.
#
# plan/tasks.json is the file every path reads — the DWP renderer, a foreign
# methodology's briefing, an agent's own plan mode — so what these tests pin
# is the property those paths depend on: one spec, methodology-neutral, with
# the human gate structural rather than conventional.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TASKS="$REPO/plan/tasks.json"
  TASKS_MD="$REPO/plan/TASKS.md"
  SCHEMA="$REPO/plan/adoption.schema.json"
  CHECK="$REPO/bin/check-ledger.mjs"
  EXAMPLES="$REPO/plan/examples"
}

# --- the task spec ------------------------------------------------------------

@test "tasks.json parses, with twelve tasks each carrying the required fields" {
  run node -e '
    const spec = require(process.argv[1]);
    if (spec.tasks.length !== 12) throw new Error(`${spec.tasks.length} tasks`);
    for (const t of spec.tasks) {
      for (const key of ["id","title","goal","blocks_on_human","optional",
                         "reads","acceptance","validation","ledger","stop_conditions"]) {
        if (!(key in t)) throw new Error(`${t.id ?? "?"} lacks ${key}`);
      }
      if (!t.validation.command && !t.validation.human)
        throw new Error(`${t.id}: validation is neither a command nor a named human check`);
      if (t.acceptance.length === 0) throw new Error(`${t.id}: no acceptance criteria`);
    }
    console.log("ok");
  ' "$TASKS"
  [ "$status" -eq 0 ]
}

@test "exactly one task blocks on a human, and it is the PII gate" {
  run node -e '
    const spec = require(process.argv[1]);
    const blocking = spec.tasks.filter((t) => t.blocks_on_human);
    if (blocking.length !== 1 || blocking[0].id !== "pii_gate")
      throw new Error(blocking.map((t) => t.id).join(",") || "none");
    console.log("ok");
  ' "$TASKS"
  [ "$status" -eq 0 ]
}

@test "exactly one task is optional, and it is consuming peers" {
  run node -e '
    const spec = require(process.argv[1]);
    const optional = spec.tasks.filter((t) => t.optional);
    if (optional.length !== 1 || optional[0].id !== "consume_peers")
      throw new Error(optional.map((t) => t.id).join(",") || "none");
    console.log("ok");
  ' "$TASKS"
  [ "$status" -eq 0 ]
}

@test "TASKS.md walks the same ids in the same order" {
  json_ids="$(node -e 'console.log(require(process.argv[1]).tasks.map(t=>t.id).join("\n"))' "$TASKS")"
  md_ids="$(grep -oE '^## [0-9]+\. `[a-z_]+`' "$TASKS_MD" | grep -oE '`[a-z_]+`' | tr -d '\`')"
  [ "$json_ids" = "$md_ids" ]
}

@test "every pack file a task reads actually exists" {
  run node -e '
    const { existsSync } = require("fs");
    const { join } = require("path");
    const spec = require(process.argv[1]);
    const root = process.argv[2];
    for (const t of spec.tasks)
      for (const path of t.reads) {
        if (path.startsWith("{")) continue; // placeholder, instantiated later
        if (!existsSync(join(root, path))) throw new Error(`${t.id} reads missing ${path}`);
      }
    console.log("ok");
  ' "$TASKS" "$REPO"
  [ "$status" -eq 0 ]
}

@test "the spec names no planning tool — any methodology can execute it" {
  # The whole reason tasks.json exists once is that every planner consumes it.
  # A planner's name inside it would quietly privilege one path.
  for word in deepworkplan dwp "spec kit" speckit kiro bmad; do
    if grep -qi -- "$word" "$TASKS" "$TASKS_MD"; then
      echo "the task spec names a planner: $word"
      return 1
    fi
  done
}

@test "every placeholder used by a task is declared" {
  run node -e '
    const spec = require(process.argv[1]);
    const declared = Object.keys(spec.placeholders);
    const used = JSON.stringify(spec.tasks).match(/\{[a-z_]+\}/g) ?? [];
    for (const p of new Set(used))
      if (!declared.includes(p)) throw new Error(`undeclared placeholder ${p}`);
    console.log("ok");
  ' "$TASKS"
  [ "$status" -eq 0 ]
}

# --- the ledger contract ------------------------------------------------------

@test "the valid example ledger conforms" {
  run node "$CHECK" "$EXAMPLES/valid/adoption.json"
  [ "$status" -eq 0 ]
}

@test "a level with no report digest is rejected" {
  run node "$CHECK" "$EXAMPLES/invalid/level-no-digest.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"report_digest"* ]]
}

@test "an offline run carrying a level is rejected" {
  # Degraded mode cannot measure; the ledger cannot even hold the claim.
  run node "$CHECK" "$EXAMPLES/invalid/offline-with-level.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"/last_measured/level"* ]]
}

@test "a PII decision recorded by an agent is rejected" {
  run node "$CHECK" "$EXAMPLES/invalid/agent-decided.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *'"human"'* ]]
}

@test "an unknown field is rejected — the schema is closed" {
  tmp="$BATS_TEST_TMPDIR/extra-key.json"
  node -e '
    const ledger = require(process.argv[1]);
    ledger.operator_phone = "3001234567";
    console.log(JSON.stringify(ledger));
  ' "$EXAMPLES/valid/adoption.json" > "$tmp"
  run node "$CHECK" "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"operator_phone"* ]]
}

@test "the checker refuses schemas it cannot fully check" {
  # The guard exists so a future keyword fails loudly instead of half-passing.
  grep -q "unsupportedKeywords" "$CHECK"
  grep -q "process.exit(5)" "$CHECK"
}

@test "a missing ledger file is a usage error, not a validation result" {
  run node "$CHECK" "$BATS_TEST_TMPDIR/does-not-exist.json"
  [ "$status" -eq 4 ]
}

# --- the documentation --------------------------------------------------------

@test "LEDGER.md explains the two structural refusals and how to remove the file" {
  says "$REPO/plan/LEDGER.md" "decided_by"
  says "$REPO/plan/LEDGER.md" "offline.*forbids.*level"
  says "$REPO/plan/LEDGER.md" "delete .cabuya"
}

@test "no example carries a person-level value" {
  # Names of columns are data-model metadata; values would be a leak. The
  # deny-list families over every example file, plus the .invalid TLD rule.
  run grep -rEn '3[0-9]{9}|[a-z0-9._%+-]+@[a-z0-9.-]+\.(com|org|net|co)\b' "$EXAMPLES"
  [ "$status" -ne 0 ]
  run grep -rn 'example\.\(com\|org\)' "$EXAMPLES"
  [ "$status" -ne 0 ]
}
