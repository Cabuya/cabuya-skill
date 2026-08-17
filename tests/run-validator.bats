#!/usr/bin/env bats
#
# The runner decides which validator answers, and degraded mode decides what
# the pack says when none can. Both are where "conformance is measured, never
# declared" either holds or quietly stops holding — so each resolution order is
# proven, and the honest phrase is pinned to the byte.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  # A scratch pack, so a fake `npx` on PATH cannot reach the real repository.
  PACK="$TMP/pack"
  mkdir -p "$PACK/bin" "$PACK/spec/schemas"
  cp "$REPO/bin/run-validator.sh" "$PACK/bin/"
  cp "$REPO/bin/degraded-check.mjs" "$PACK/bin/"
  cp "$REPO"/spec/schemas/*.json "$PACK/spec/schemas/"
  cp "$REPO/spec/VERSION" "$PACK/spec/"

  # Somewhere to put fakes, ahead of everything real.
  BIN="$TMP/bin"
  mkdir -p "$BIN"
  export PATH="$BIN:$PATH"

  cd "$TMP"
  unset CABUYA_VALIDATOR_BIN
}

teardown() {
  cd /
  rm -rf "$TMP"
}

run_validator() { bash "$PACK/bin/run-validator.sh" "$@"; }

# A stand-in that reports how it was called and exits with a chosen code.
fake_validator() {
  local path="$1" label="$2" code="${3:-0}"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<FAKE
#!/usr/bin/env bash
echo "$label \$*"
exit $code
FAKE
  chmod +x "$path"
}

# --- order 1: the pinned binary ----------------------------------------------

@test "order 1: CABUYA_VALIDATOR_BIN wins over everything" {
  fake_validator "$BIN/pinned" "PINNED"
  fake_validator "$TMP/node_modules/.bin/cabuya-validator" "LOCAL"
  fake_validator "$BIN/npx" "NPX"
  export CABUYA_VALIDATOR_BIN="$BIN/pinned"

  run run_validator --which
  [[ "$output" == *"1 env"* ]]

  run run_validator validate feed.json
  [[ "$output" == "PINNED validate feed.json" ]]
}

@test "order 1: a pinned binary that is not executable is an error, not a fallback" {
  # Silently using order 2 or 3 here would run a different validator than the
  # operator pinned — which is the entire point of pinning.
  fake_validator "$TMP/node_modules/.bin/cabuya-validator" "LOCAL"
  export CABUYA_VALIDATOR_BIN="$TMP/does-not-exist"

  run run_validator validate feed.json
  [ "$status" -eq 4 ]
  [[ "$output" == *"Refusing to fall back"* ]]
  [[ "$output" != *"LOCAL"* ]]
}

# --- order 2: the adopter's own install --------------------------------------

@test "order 2: a local node_modules bin is found" {
  fake_validator "$TMP/node_modules/.bin/cabuya-validator" "LOCAL"
  fake_validator "$BIN/npx" "NPX"

  run run_validator --which
  [[ "$output" == *"2 local"* ]]

  run run_validator validate feed.json --format json
  [[ "$output" == "LOCAL validate feed.json --format json" ]]
}

@test "order 2: arguments pass through untouched" {
  fake_validator "$TMP/node_modules/.bin/cabuya-validator" "LOCAL"
  run run_validator validate https://example.invalid/f.json --level L2 --strict
  [[ "$output" == "LOCAL validate https://example.invalid/f.json --level L2 --strict" ]]
}

@test "order 2: the validator's exit code passes through unchanged" {
  # Agents branch on the code before parsing anything; a runner that
  # normalised 1 and 3 would send fix loops to rewrite correct code.
  for code in 1 2 3 4 5; do
    fake_validator "$TMP/node_modules/.bin/cabuya-validator" "LOCAL" "$code"
    run run_validator validate feed.json
    [ "$status" -eq "$code" ] || {
      echo "expected exit $code, got $status"
      return 1
    }
  done
}

# --- order 3: npx, with a derived range --------------------------------------

@test "order 3: npx is used with a range derived from spec/VERSION" {
  fake_validator "$BIN/npx" "NPX"

  run run_validator --which
  [[ "$output" == *"3 npx"* ]]
  # spec/VERSION is 0.1, so the range must be ^0.1.0 — a 0.2 validator
  # disagrees with a 0.1 pack about what conforms.
  [[ "$output" == *"@cabuya/validator@^0.1.0"* ]]
}

@test "order 3: the range follows spec/VERSION rather than being hardcoded" {
  printf '0.9\n' > "$PACK/spec/VERSION"
  fake_validator "$BIN/npx" "NPX"

  run run_validator --which
  [[ "$output" == *"@cabuya/validator@^0.9.0"* ]]
}

@test "order 3: no VERSION file means no guessed range — degraded instead" {
  rm -f "$PACK/spec/VERSION"
  fake_validator "$BIN/npx" "NPX"

  run run_validator --which
  [[ "$output" == *"4 degraded"* ]]
}

# --- order 4: degraded, and honest -------------------------------------------

@test "order 4: degraded fires when nothing else resolves" {
  # No pinned bin, no local bin, and npx absent from PATH.
  PATH="$TMP/empty:/usr/bin:/bin" run bash "$PACK/bin/run-validator.sh" --which
  [[ "$output" == *"4 degraded"* ]]
  [[ "$output" == *"conformance NOT measured"* ]]
}

@test "degraded mode emits the exact honest phrase on a clean file" {
  cp "$REPO/examples/valid/valid-minimal-core.json" "$TMP/feed.json"

  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"schema-valid; conformance unmeasured"* ]]
}

@test "degraded mode never says conforming, passes, or certified" {
  cp "$REPO/examples/valid/valid-minimal-core.json" "$TMP/feed.json"
  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json"

  # "unmeasured" contains no forbidden substring; these would.
  [[ "$output" != *"is conforming"* ]]
  [[ "$output" != *"conformant"* ]]
  [[ "$output" != *"certified"* ]]
  [[ "$output" != *"passes"* ]]
  [[ "$output" != *"looks good"* ]]
}

@test "degraded mode names the probes it did not run" {
  cp "$REPO/examples/valid/valid-minimal-core.json" "$TMP/feed.json"
  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json"

  # These three are what catch a publisher who believes they have published.
  [[ "$output" == *"soft_404"* ]]
  [[ "$output" == *"cors"* ]]
  [[ "$output" == *"always_now"* ]]
}

@test "degraded mode names the checks it does not implement" {
  # One vendored teaching example is genuinely non-conformant and passes
  # degraded mode. Without this list, that clean run reads as approval.
  cp "$REPO/examples/invalid/invalid-3-status-in-name-and-always-now.json" "$TMP/feed.json"

  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Checks not implemented in degraded mode"* ]]
  [[ "$output" == *"CR-2 status-in-name"* ]]
  [[ "$output" == *"well-formed, not conforming"* ]]
}

@test "degraded mode sets degraded:true and no measured level in JSON" {
  cp "$REPO/examples/valid/valid-minimal-core.json" "$TMP/feed.json"
  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json" --format=json
  [ "$status" -eq 0 ]

  printf '%s' "$output" | python3 -c "
import json, sys
report = json.load(sys.stdin)
assert report['degraded'] is True, 'degraded flag missing'
assert report['measured_level'] is None, 'degraded mode must not state a level'
assert report['summary']['outcome'] == 'schema-valid; conformance unmeasured'
assert report['probes_not_run'] == ['soft_404', 'cors', 'always_now']
assert report['checks_not_run'], 'must name what it did not check'
"
}

# --- degraded mode actually catches things -----------------------------------

@test "degraded mode catches the missing confirmation key, with the parenthetical" {
  cp "$REPO/examples/invalid/invalid-1-missing-confirmation-key.json" "$TMP/feed.json"

  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"required property 'last_confirmed_at' is missing"* ]]
  # The parenthetical is the design: it names the honest alternative so an
  # agent cannot "fix" this by inventing a confirmation timestamp.
  [[ "$output" == *"did you mean to publish last_confirmed_at: null?"* ]]
}

@test "degraded mode catches all three PII violations, one message each" {
  cp "$REPO/examples/invalid/invalid-2-contact-and-personal-data.json" "$TMP/feed.json"

  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json" --format=json
  [ "$status" -eq 1 ]

  printf '%s' "$output" | python3 -c "
import json, sys
report = json.load(sys.stdin)
ids = sorted(f['id'] for f in report['findings'])
assert ids == ['PII001', 'PII002', 'PII003'], f'expected three distinct PII ids, got {ids}'
"
}

@test "degraded mode never echoes the personal value it objected to" {
  cp "$REPO/examples/invalid/invalid-2-contact-and-personal-data.json" "$TMP/feed.json"
  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json" --format=json

  # Reporting the value would copy the thing we are objecting to into a log,
  # a terminal, and an agent transcript.
  [[ "$output" != *"3000000000"* ]]
  [[ "$output" != *"+57 300 000 0000"* ]]
}

@test "degraded mode refuses a URL rather than pretending to fetch it" {
  run node "$PACK/bin/degraded-check.mjs" https://example.invalid/feed.json
  [ "$status" -eq 3 ]
  [[ "$output" == *"cannot fetch"* ]]
}

@test "degraded mode exits 5 rather than half-checking an unknown keyword" {
  # Silently ignoring a keyword it does not implement is how a partial
  # validator becomes a wrong one.
  python3 - "$PACK/spec/schemas/place-feed.schema.json" <<'PY'
import json, sys
path = sys.argv[1]
schema = json.load(open(path))
schema['dependentRequired'] = {'lat': ['lon']}
json.dump(schema, open(path, 'w'))
PY
  cp "$REPO/examples/valid/valid-minimal-core.json" "$TMP/feed.json"

  run node "$PACK/bin/degraded-check.mjs" "$TMP/feed.json"
  [ "$status" -eq 5 ]
  [[ "$output" == *"dependentRequired"* ]]
  [[ "$output" == *"did not fully check"* ]]
}

# --- the documented contract --------------------------------------------------

@test "the honest phrase is identical in the code and in the documentation" {
  # Taken from the code rather than retyped here, so this test cannot be the
  # thing that drifts. Three files state the phrase; if they ever disagree,
  # one of them is what somebody quotes at an adopter.
  #
  # Case-insensitive on purpose: the docs use it sentence-initially, which is
  # ordinary English and not a different phrase. Everything after the first
  # letter must match byte for byte.
  phrase="$(grep -o "const UNMEASURED = '[^']*'" "$REPO/bin/degraded-check.mjs" \
            | sed "s/.*= '//; s/'$//")"
  [ -n "$phrase" ] || {
    echo "could not find UNMEASURED in degraded-check.mjs"
    return 1
  }
  [ "$phrase" = "schema-valid; conformance unmeasured" ] || {
    echo "the honest phrase changed: '$phrase'"
    return 1
  }

  for doc in shared/validator.md validate/SKILL.md implement/SKILL.md; do
    grep -qi -- "$phrase" "$REPO/$doc" || {
      echo "$doc does not carry the phrase the code emits"
      return 1
    }
  done
}

@test "shared/validator.md documents every exit code" {
  for code in 0 1 2 3 4 5; do
    grep -q "\`$code\`" "$REPO/shared/validator.md" || {
      echo "exit code $code is not documented"
      return 1
    }
  done
  # And the distinction that earns its keep.
  grep -qi 'the feed is wrong.*the network is wrong' "$REPO/shared/validator.md"
}

@test "error-codes.md maps every check family the validator emits" {
  for family in DSC ENV REC PII BEH API WRT LIC; do
    grep -q "\`$family\`" "$REPO/shared/error-codes.md" || {
      echo "family $family is not documented"
      return 1
    }
  done
}

@test "no skill tells anybody to run a command the CLI does not have" {
  # `convert` was written into a guide before this check existed; the CLI ships
  # validate/explain/checks/init and nothing else. A CTA to a command that does
  # not exist is the same failure as a CTA to a page that does not exist.
  offenders="$(grep -rn 'cabuya-validator convert\|run-validator.sh convert' \
                 --include='*.md' "$REPO" || true)"
  [ -z "$offenders" ] || {
    echo "$offenders"
    return 1
  }
}
