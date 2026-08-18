#!/usr/bin/env bash
#
# run-acceptance.sh — prepare the sandbox, then grade whatever came out of it.
#
# This script does NOT drive an agent. Driving one requires a harness and an
# API key, and pretending otherwise would produce a green check for a test
# nobody ran — which is the failure this whole project is an argument against.
#
# What it does:
#   --prepare   build a clean sandbox: temp dir, empty repo, pack copied in
#   --grade     score a transcript against the key
#   --check     verify a recorded run exists and matches the current version
#
# The human (or the CI harness, where one exists) runs the agent in between.
#
# Usage:
#   bash tests/acceptance/run-acceptance.sh --prepare
#   # …paste prompt.md into a fresh agent session in that sandbox, with no
#   #   network and no other context; save its reply…
#   bash tests/acceptance/run-acceptance.sh --grade transcript.md
#   bash tests/acceptance/run-acceptance.sh --check
#
# Bash 3.2 compatible.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PACK_ROOT="$(cd "$HERE/../../skills/cabuya" && pwd)"
RUNS="$HERE/runs"

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

pack_version() {
  # From the router's frontmatter, which is the version an adopter installs.
  grep -m1 '^version:' "$PACK_ROOT/SKILL.md" | sed 's/version: *"\{0,1\}//; s/"\{0,1\}$//'
}

prepare() {
  sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/repo/.agents/skills"

  # A copy, not a symlink: the agent must see the pack as an adopter receives
  # it, and a symlink out of the sandbox is a path to everything else.
  cp -R "$PACK_ROOT" "$sandbox/repo/.agents/skills/cabuya"
  rm -rf "$sandbox/repo/.agents/skills/cabuya/.git"
  ( cd "$sandbox/repo" && git init -q . )

  say "Sandbox ready: $sandbox/repo"
  say ""
  say "Now, in a FRESH agent session:"
  say "  1. cd $sandbox/repo"
  say "  2. Disable network access. Really disable it — this is the test."
  say "     Linux:  unshare -rn <your agent command>"
  say "     macOS:  a firewall rule, or an offline machine."
  say "  3. Give it $HERE/prompt.md verbatim, in one message."
  say "  4. Save the reply to a file."
  say "  5. bash $0 --grade <that file>"
  say ""
  say "No other context. No prior conversation. No other skills installed."
  say "The claim under test is that the pack alone is enough."
}

grade() {
  [ -n "${1:-}" ] || die "usage: $0 --grade <transcript>"
  python3 "$HERE/grade.py" "$1"
}

check() {
  version="$(pack_version)"
  say "Pack version: $version"

  # Glob rather than `ls`: run files are named YYYY-MM-DD-harness.md, so glob
  # order is chronological, and a glob copes with whatever a filename contains.
  latest=""
  for candidate in "$RUNS"/*.md; do
    [ -f "$candidate" ] && latest="$candidate"
  done
  if [ -z "$latest" ]; then
    say "✗ No recorded run in tests/acceptance/runs/." >&2
    say "  A release without one is a release of an untested claim." >&2
    exit 1
  fi

  say "Most recent recorded run: $(basename "$latest")"

  if ! grep -q "Pack version $version" "$latest"; then
    say "✗ The recorded run does not name the current pack version ($version)." >&2
    say "  Re-run the acceptance test before releasing." >&2
    exit 1
  fi

  if ! python3 "$HERE/grade.py" "$latest" >/dev/null 2>&1; then
    say "✗ The recorded run does not pass." >&2
    python3 "$HERE/grade.py" "$latest" >&2 || true
    exit 1
  fi

  say "✓ A passing run is recorded for $version."

  # Two harnesses, per the release rule. Counted rather than assumed.
  harnesses=0
  for candidate in "$RUNS"/*.md; do
    [ -f "$candidate" ] && harnesses=$((harnesses + 1))
  done
  if [ "$harnesses" -lt 2 ]; then
    say ""
    say "⚠ Only $harnesses recorded run(s). A MINOR release needs two, on two"
    say "  different agent harnesses — the cross-agent claim is only true if it"
    say "  has been observed twice."
  fi
}

case "${1:-}" in
  --prepare) prepare ;;
  --grade)   shift; grade "${1:-}" ;;
  --check)   check ;;
  -h|--help)
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) die "usage: $0 [--prepare | --grade <file> | --check | --help]" ;;
esac
