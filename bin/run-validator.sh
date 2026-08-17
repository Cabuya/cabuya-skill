#!/usr/bin/env bash
#
# run-validator.sh — find a validator, run it, and never pretend.
#
# Every sub-skill that measures anything goes through here, so this file is
# where "conformance is measured, never declared" either holds or quietly
# stops holding.
#
# Four resolution orders, most specific first:
#
#   1. $CABUYA_VALIDATOR_BIN   air-gapped or pinned environments
#   2. node_modules/.bin/cabuya-validator   in the adopter's repo
#   3. npx --yes @cabuya/validator@^X.Y     range from spec/VERSION, not hardcoded
#   4. degraded offline mode                schema + PII passes, run here
#
# Order 4 is the one that matters. When there is no validator and no network,
# the honest answer is a partial one — so it emits a report in the same shape
# with "degraded": true and the summary "schema-valid; conformance unmeasured",
# and it names the probes it could not run. It never emits the word
# "conforming", because the whole protocol rests on that word meaning something
# somebody measured.
#
# The validator's exit code passes through unchanged (blueprint §4.6): agents
# branch on it before parsing anything, and 1 (the feed is wrong) versus 3 (the
# network is wrong) is the difference between fixing data and rewriting correct
# code.
#
# Bash 3.2 compatible.

set -euo pipefail

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_DIR="$PACK_ROOT/spec"

say() { printf '%s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Run the Cabuya validator, whichever one is available.

  bash bin/run-validator.sh [--which] [validator arguments...]

  --which   Print the resolution that would be used, and exit. Nothing runs.

Everything else is passed through untouched:

  bash bin/run-validator.sh validate https://example.invalid/.well-known/cabuya.json
  bash bin/run-validator.sh validate feed.json --no-network --format json

Resolution order:
  1. $CABUYA_VALIDATOR_BIN
  2. ./node_modules/.bin/cabuya-validator
  3. npx --yes @cabuya/validator@^<spec version>
  4. degraded offline mode (schema + PII only; conformance NOT measured)

Exit codes are the validator's own: 0 conformant · 1 non-conformant ·
2 warnings with --strict · 3 transport · 4 usage · 5 internal.
See shared/validator.md.
USAGE
}

# --- the npx version range ----------------------------------------------------
#
# Derived from the vendored spec version, never hardcoded: a pack vendoring 0.1
# must not silently pull a validator built for 0.2, because the two disagree
# about what conforms and the pack would report the disagreement as the
# adopter's bug.

version_range() {
  if [ -f "$SPEC_DIR/VERSION" ]; then
    minor="$(tr -d ' \n\r' < "$SPEC_DIR/VERSION")"
    case "$minor" in
      [0-9]*.[0-9]*) printf '^%s.0' "$minor"; return 0 ;;
    esac
  fi
  # No VERSION file means nothing is vendored. Refuse to guess a range.
  printf ''
}

# --- resolution ---------------------------------------------------------------

resolve() {
  if [ -n "${CABUYA_VALIDATOR_BIN:-}" ]; then
    if [ -x "$CABUYA_VALIDATOR_BIN" ] || command -v "$CABUYA_VALIDATOR_BIN" >/dev/null 2>&1; then
      printf 'env\t%s' "$CABUYA_VALIDATOR_BIN"
      return 0
    fi
    # Set but unusable is a configuration error, not a reason to fall through.
    # Silently using something else would run a different validator than the
    # operator pinned, which is the whole point of pinning.
    printf 'error\t%s' "$CABUYA_VALIDATOR_BIN"
    return 0
  fi

  local_bin="./node_modules/.bin/cabuya-validator"
  if [ -x "$local_bin" ]; then
    printf 'local\t%s' "$local_bin"
    return 0
  fi

  range="$(version_range)"
  if [ -n "$range" ] && command -v npx >/dev/null 2>&1; then
    printf 'npx\t@cabuya/validator@%s' "$range"
    return 0
  fi

  printf 'degraded\t'
}

# --- degraded mode ------------------------------------------------------------

run_degraded() {
  say ""
  say "⚠  No validator available — running in DEGRADED mode."
  say ""
  say "   Schema and PII pattern checks run here, against the vendored"
  say "   schemas. The behavioural probes do NOT run:"
  say "     · soft-404   (is the manifest really there, or is it your SPA shell)"
  say "     · CORS       (can a browser-based consumer read the feed at all)"
  say "     · always-now (does last_updated advance on identical content)"
  say ""
  say "   Those three need the network and a deployed URL. This run cannot"
  say "   tell you whether your feed conforms — only whether it is well-formed."
  say ""

  if [ ! -d "$SPEC_DIR/schemas" ]; then
    say "   And spec/schemas/ is not vendored, so not even that. Nothing ran."
    exit 5
  fi

  if ! command -v node >/dev/null 2>&1; then
    say "   node is not available either, so nothing ran."
    exit 5
  fi

  node "$PACK_ROOT/bin/degraded-check.mjs" "$@"
}

# --- main ---------------------------------------------------------------------

WHICH="no"
if [ "${1:-}" = "--which" ]; then
  WHICH="yes"
  shift
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

resolution="$(resolve)"
mode="${resolution%%	*}"
target="${resolution#*	}"

if [ "$WHICH" = "yes" ]; then
  case "$mode" in
    env)      printf '1 env       %s\n' "$target" ;;
    local)    printf '2 local     %s\n' "$target" ;;
    npx)      printf '3 npx       %s\n' "$target" ;;
    degraded) printf '4 degraded  schema + PII only; conformance NOT measured\n' ;;
    error)    printf 'error       CABUYA_VALIDATOR_BIN is set but not executable: %s\n' "$target" ;;
  esac
  exit 0
fi

case "$mode" in
  env)
    exec "$target" "$@"
    ;;
  error)
    say "CABUYA_VALIDATOR_BIN is set to '$target', which is not executable."
    say ""
    say "Refusing to fall back to another validator: you pinned this one on"
    say "purpose, and running a different one would answer a question you did"
    say "not ask. Fix the path, or unset the variable to use the normal order."
    exit 4
    ;;
  local)
    exec "$target" "$@"
    ;;
  npx)
    exec npx --yes "$target" "$@"
    ;;
  degraded)
    run_degraded "$@"
    ;;
esac
