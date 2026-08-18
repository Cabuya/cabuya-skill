#!/usr/bin/env bats
#
# context.sh emits one line of JSON that every sub-skill reads. Two things can
# go wrong: it can emit something that is not JSON, and it can be confidently
# wrong about the repository. Both are tested here, including the cases where
# there is no git repository and where the path contains characters that would
# break naive string concatenation.

setup() {
  CONTEXT="$(cd "$BATS_TEST_DIRNAME/../skills/cabuya" && pwd)/shared/context.sh"
  TMP="$(mktemp -d)"
  # Detection must not be influenced by the agent running the test suite.
  unset CABUYA_AGENT_TOOL CABUYA_STACK CABUYA_FRAMEWORK CABUYA_MANIFEST_PATH
  unset CLAUDE_PLUGIN_ROOT CLAUDECODE CODEX_SESSION_ID CODEX_HOME
  unset CURSOR_SESSION_ID CURSOR_TRACE_ID OPENCLAW_SESSION
  unset GEMINI_SESSION_ID WINDSURF_SESSION_ID
}

teardown() {
  rm -rf "$TMP"
}

# Read one field out of the emitted JSON, with a real parser rather than a
# regex — the point of emitting JSON is that consumers parse it.
field() {
  printf '%s' "$1" | python3 -c "import json,sys; print(json.load(sys.stdin)['$2'])"
}

@test "emits a single line of valid JSON" {
  run bash "$CONTEXT"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | wc -l)" -eq 0 ]
  printf '%s' "$output" | python3 -c 'import json,sys; json.load(sys.stdin)'
}

@test "carries every field the contract promises" {
  run bash "$CONTEXT"
  [ "$status" -eq 0 ]
  for key in repo repo_root branch agent_tool stack framework manifest_path spec_version; do
    printf '%s' "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert '$key' in d, '$key missing'"
  done
}

@test "reports the spec version this pack implements" {
  run bash "$CONTEXT"
  [ "$(field "$output" spec_version)" = "0.1" ]
}

@test "degrades honestly outside a git repository" {
  mkdir -p "$TMP/plain"
  cd "$TMP/plain"
  run bash "$CONTEXT"
  [ "$status" -eq 0 ]
  # Not a crash, and not a fabricated branch name.
  [ "$(field "$output" branch)" = "unknown" ]
  [ "$(field "$output" repo)" = "plain" ]
}

@test "CABUYA_AGENT_TOOL wins over detection" {
  export CLAUDECODE=1
  export CABUYA_AGENT_TOOL="some-other-agent"
  run bash "$CONTEXT"
  [ "$(field "$output" agent_tool)" = "some-other-agent" ]
}

@test "detects the agent from its own environment variable" {
  export CURSOR_SESSION_ID="abc"
  run bash "$CONTEXT"
  [ "$(field "$output" agent_tool)" = "cursor" ]
}

@test "says unknown rather than guessing when no agent is detectable" {
  run bash "$CONTEXT"
  [ "$(field "$output" agent_tool)" = "unknown" ]
}

@test "recognises a Next.js repository and points the manifest at public/" {
  mkdir -p "$TMP/app"
  cd "$TMP/app"
  git init -q .
  printf '{}' > package.json
  printf 'export default {}' > next.config.js
  run bash "$CONTEXT"
  [ "$(field "$output" stack)" = "node" ]
  [ "$(field "$output" framework)" = "nextjs" ]
  [[ "$(field "$output" manifest_path)" == */public/.well-known/cabuya.json ]]
}

@test "recognises Django and points the manifest at static/" {
  mkdir -p "$TMP/dj"
  cd "$TMP/dj"
  printf '' > manage.py
  run bash "$CONTEXT"
  [ "$(field "$output" stack)" = "python" ]
  [ "$(field "$output" framework)" = "django" ]
  [[ "$(field "$output" manifest_path)" == */static/.well-known/cabuya.json ]]
}

@test "says unknown for a stack it does not recognise" {
  mkdir -p "$TMP/mystery"
  cd "$TMP/mystery"
  printf 'nothing familiar' > README.txt
  run bash "$CONTEXT"
  [ "$(field "$output" stack)" = "unknown" ]
  [ "$(field "$output" framework)" = "unknown" ]
}

@test "an override replaces a detected value" {
  mkdir -p "$TMP/app2"
  cd "$TMP/app2"
  printf '{}' > package.json
  CABUYA_FRAMEWORK=laravel run bash "$CONTEXT"
  [ "$(field "$output" framework)" = "laravel" ]
}

@test "a quote in the path does not produce broken JSON" {
  # The naive `printf` this script could have used would emit unparseable
  # output here, and the consumer is a program.
  weird="$TMP/it's \"quoted\""
  mkdir -p "$weird"
  cd "$weird"
  run bash "$CONTEXT"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | python3 -c 'import json,sys; json.load(sys.stdin)'
  [[ "$(field "$output" repo_root)" == *"it's \"quoted\""* ]]
}
