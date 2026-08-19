#!/usr/bin/env bats
#
# The read-API step-up (Task 9 of PLAN_product_clarity_overhaul): the template
# exists and teaches the §3.2 equivalence, the flows point at it, and the
# router states honestly which transports the pack teaches.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/../skills/cabuya" && pwd)"
  TEMPLATE="$REPO/implement/templates/serializer-read-api.md"
}

@test "the read-api template exists and teaches the equivalence rule" {
  [ -f "$TEMPLATE" ]
  says "$TEMPLATE" "a static feed is a degenerate read API"
  says "$TEMPLATE" "byte-compatible"
  says "$TEMPLATE" "next_cursor"
  says "$TEMPLATE" "this is a transport, not a new pipeline"
}

@test "the template keeps the honesty rules in force" {
  says "$TEMPLATE" "last_updated still describes the data, never the response"
  says "$TEMPLATE" "the level it earns is whatever the validator measures"
}

@test "implement's serializer step offers the read-api step-up" {
  grep -q "serializer-read-api.md" "$REPO/implement/SKILL.md"
  says "$REPO/implement/SKILL.md" "Prefer build-time"
}

@test "the router scopes the four-transports claim to what the pack teaches" {
  says "$REPO/SKILL.md" "What the pack itself teaches, stated honestly"
  says "$REPO/SKILL.md" "the write API and MCP are specified by the protocol but not yet taught here"
}

@test "the four server-stack guides point at the read-api step-up" {
  for guide in nextjs-supabase express-node rails django; do
    grep -q "serializer-read-api.md" "$REPO/implement/stacks/$guide.md" \
      || { echo "missing pointer in $guide"; return 1; }
  done
}
