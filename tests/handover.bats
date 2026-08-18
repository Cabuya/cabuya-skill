#!/usr/bin/env bats
#
# The methodology hand-off: registry as data, bundle as briefing.
#
# Two properties carry this path. The registry is the ONLY place a foreign
# methodology is named, so supporting a new one is a JSON entry. And the
# bundle cannot drift from the task spec, because a briefing that walks a
# different adoption than the spec is worse than no briefing.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  REGISTRY="$REPO/plan/methodologies.json"
  RENDER="$REPO/bin/render-handover.mjs"
}

bundle() {
  node "$RENDER" --stack-guide implement/stacks/nextjs-supabase.md \
    --publisher-id example-app --target L2 \
    --manifest-url https://app.example.invalid/.well-known/cabuya.json \
    --feed-path public/cabuya/places.json --stack node --framework nextjs "$@"
}

# --- the registry -------------------------------------------------------------

@test "the registry parses and every entry carries the required fields" {
  run node -e '
    const r = require(process.argv[1]);
    if (!Array.isArray(r.methodologies) || r.methodologies.length === 0)
      throw new Error("empty registry");
    for (const m of r.methodologies)
      for (const key of ["id", "name", "markers", "entry_command", "artifacts_path"])
        if (!(key in m)) throw new Error(`${m.id ?? "?"} lacks ${key}`);
    console.log("ok");
  ' "$REGISTRY"
  [ "$status" -eq 0 ]
}

@test "detection proposes, the human confirms — stated in the registry itself" {
  run node -e 'console.log(require(process.argv[1]).comment)' "$REGISTRY"
  [[ "$output" == *"the human confirms"* ]]
}

@test "no foreign methodology is named outside the registry" {
  # deepworkplan is the exception by design: it is the rendered path.
  # Everything else is data — a name in prose or shell would mean adding a
  # methodology is a code change again.
  ids="$(node -e '
    for (const m of require(process.argv[1]).methodologies)
      if (m.id !== "deepworkplan") { console.log(m.id); console.log(m.name); }
  ' "$REGISTRY")"
  while IFS= read -r word; do
    hits="$(find "$REPO" \( -name '*.md' -o -name '*.sh' \) -not -path '*/.git/*' \
      -not -path '*/tests/*' -not -path '*/node_modules/*' -print0 \
      | xargs -0 grep -Fli -- "$word" 2>/dev/null \
      | grep -v 'plan/methodologies.json' || true)"
    if [ -n "$hits" ]; then
      echo "'$word' is named outside the registry: $hits"
      return 1
    fi
  done <<< "$ids"
}

@test "every registry marker is detectable by detect-planning.sh" {
  # One fixture per entry: its first marker present resolves to its id.
  while IFS=$'\t' read -r id marker; do
    fixture="$BATS_TEST_TMPDIR/m-$id"
    mkdir -p "$fixture/$marker"
    git -C "$fixture" init -q
    run bash -c "cd '$fixture' && HOME='$BATS_TEST_TMPDIR/nohome' bash '$REPO/shared/detect-planning.sh'"
    [[ "$output" == *"\"$id\""* ]] || { echo "$id not detected via $marker"; return 1; }
  done < <(node -e '
    for (const m of require(process.argv[1]).methodologies)
      console.log(`${m.id}\t${m.markers[0]}`);
  ' "$REGISTRY")
}

# --- the bundle ---------------------------------------------------------------

@test "the bundle walks every task id from the spec, in the spec's order" {
  spec_ids="$(node -e '
    const s = require(process.argv[1]);
    console.log(s.tasks.filter(t => !t.optional).map(t => t.id).join("\n"));
  ' "$REPO/plan/tasks.json")"
  bundle_ids="$(bundle | grep -oE '^### [0-9]+\. `[a-z_]+`' | grep -oE '`[a-z_]+`' | tr -d '\`')"
  [ "$spec_ids" = "$bundle_ids" ]
}

@test "with --include-l3 the optional task joins the walk" {
  bundle --include-l3 | grep -q '`consume_peers`'
}

@test "the four non-negotiables travel verbatim" {
  out="$(bundle)"
  echo "$out" | grep -q 'decided_by: "human" and nothing else'
  echo "$out" | grep -q 'did not measure'
  echo "$out" | grep -q 'is never used, in any language'
  echo "$out" | grep -q 'Contact reaches users through public_url'
}

@test "no spec placeholder survives into the bundle" {
  bundle > "$BATS_TEST_TMPDIR/bundle.md"
  run grep -E '\{(stack_guide|feed_path|manifest_url|target_level)\}' "$BATS_TEST_TMPDIR/bundle.md"
  [ "$status" -ne 0 ]
}

@test "the machine-readable block is valid JSON with the same ids" {
  bundle | awk '/^```json/,/^```$/' | grep -v '^```' \
    | node -e '
      const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
      const spec = require(process.argv[1]);
      const want = spec.tasks.filter(t => !t.optional).map(t => t.id).join(",");
      const got = data.tasks.map(t => t.id).join(",");
      if (want !== got) throw new Error(`ids drifted: ${got}`);
    ' "$REPO/plan/tasks.json"
}

@test "a missing argument refuses rather than briefing with a hole" {
  run node "$RENDER" --target L2
  [ "$status" -eq 3 ]
  [[ "$output" == *"--manifest-url"* ]]
}

@test "the bundle ends at the validator, whoever planned" {
  bundle > "$BATS_TEST_TMPDIR/bundle.md"
  grep -q "run-validator.sh" "$BATS_TEST_TMPDIR/bundle.md"
  flowed "$BATS_TEST_TMPDIR/bundle.md" | grep -qi "the methodology owns the how; the validator owns the whether"
}

@test "the hand-off is reachable from the adopt flow" {
  grep -q "handover/README.md" "$REPO/adopt/SKILL.md"
  says "$REPO/adopt/handover/README.md" "following the adopter's instructions, not a built-in integration"
}
