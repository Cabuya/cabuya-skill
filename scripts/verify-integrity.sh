#!/usr/bin/env bash
#
# verify-integrity.sh — the vendored specification is the one upstream published.
#
# `spec/` is a copy of the protocol contracts from Cabuya/cabuya.org. It is
# here so the pack works with no network: an agent that has to fetch a standard
# will invent one when the fetch fails, and it will invent it confidently.
#
# A vendored copy nobody verifies is a fork nobody declared. So every file
# carries a SHA-256 in `spec/CHECKSUMS.txt`, and this script proves the tree
# still matches — which also means a hand-edit to a normative document fails
# CI instead of quietly teaching every adopter a specification the working
# group never agreed to.
#
# Bash 3.2 compatible: macOS still ships it, and half the machines this pack
# runs on are laptops.
#
# Usage:
#   bash scripts/verify-integrity.sh          # verify
#   bash scripts/verify-integrity.sh --list   # show what is vendored

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKSUMS="$REPO_ROOT/spec/CHECKSUMS.txt"

# Kept identical to generate-checksums.sh: the two must agree about what counts
# as vendored, or one of them is silently not checking something.
VENDORED_ROOTS="spec examples"

# --- portable sha256 ---------------------------------------------------------
# Linux has sha256sum; macOS has shasum. Neither is guaranteed, so failing with
# a name is better than failing with "command not found" from inside a loop.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "ERROR: neither sha256sum nor shasum is available" >&2
    exit 2
  fi
}

# --- nothing vendored yet ----------------------------------------------------
# Explicit, not a silent pass. The pack is built over several tasks and this
# script exists from the first one so that the day the spec lands, the check
# is already wired into CI rather than being remembered.
vendored_files() {
  roots=""
  for root in $VENDORED_ROOTS; do
    [ -d "$REPO_ROOT/$root" ] && roots="$roots $REPO_ROOT/$root"
  done
  [ -n "$roots" ] || return 0
  # $roots is a space-separated list of directories built above. Splitting it
  # is the intent: quoting would pass one nonexistent path named
  # "/repo/spec /repo/examples".
  # shellcheck disable=SC2086
  find $roots -type f | sort
}

# "Nothing vendored yet" is only true if nothing has *ever* been vendored. If a
# CHECKSUMS.txt exists, it lists files that are supposed to be here, and their
# absence is the loudest possible failure — not a reason to skip the check.
# (Found by the deletion test: without this ordering, removing the last vendored
# file passed silently.)
if [ ! -f "$CHECKSUMS" ] \
   && [ -z "$(vendored_files | grep -v '\.gitkeep$' | head -1)" ]; then
  echo "No vendored files yet — nothing to verify."
  echo "This is expected until the specification is vendored."
  exit 0
fi

if [ ! -f "$CHECKSUMS" ]; then
  echo "ERROR: vendored files exist but there is no spec/CHECKSUMS.txt." >&2
  echo "A vendored specification without checksums is a fork nobody declared." >&2
  echo "Generate them with: bash scripts/generate-checksums.sh" >&2
  exit 1
fi

# --- list mode ---------------------------------------------------------------
if [ "${1:-}" = "--list" ]; then
  echo "Vendored files:"
  # Skip the comment header and any blank line — printing $2 of a prose line
  # produces a list of stray words that looks like a list of files.
  awk '/^[0-9a-f]{64}[[:space:]]/ { print "  " $2 }' "$CHECKSUMS"
  exit 0
fi

# --- verify ------------------------------------------------------------------
failures=0
checked=0

while read -r expected path; do
  [ -z "$expected" ] && continue
  case "$expected" in \#*) continue ;; esac

  full="$REPO_ROOT/$path"
  if [ ! -f "$full" ]; then
    echo "  ✗ $path — listed in CHECKSUMS.txt but missing" >&2
    failures=$((failures + 1))
    continue
  fi

  actual="$(sha256_of "$full")"
  if [ "$actual" != "$expected" ]; then
    echo "  ✗ $path — checksum mismatch" >&2
    echo "      expected $expected" >&2
    echo "      actual   $actual" >&2
    failures=$((failures + 1))
  fi
  checked=$((checked + 1))
done < "$CHECKSUMS"

# A file present in spec/ but absent from CHECKSUMS.txt is the other half of
# the same question: a document an adopter would read that nobody signed.
while IFS= read -r found; do
  [ -n "$found" ] || continue
  relative="${found#"$REPO_ROOT"/}"
  case "$relative" in
    spec/CHECKSUMS.txt) continue ;;
    *.gitkeep) continue ;;
  esac
  if ! grep -q " $relative\$" "$CHECKSUMS"; then
    echo "  ✗ $relative — vendored but not listed in CHECKSUMS.txt" >&2
    failures=$((failures + 1))
  fi
done <<EOF
$(vendored_files)
EOF

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "❌ $failures integrity problem(s) in the vendored specification." >&2
  echo "" >&2
  echo "If you edited spec/ by hand: don't. It is a copy of the normative" >&2
  echo "text, and changing the standard goes through an RFC in" >&2
  echo "Cabuya/cabuya.org. If you re-vendored a new upstream version," >&2
  echo "regenerate the checksums in the same commit." >&2
  exit 1
fi

echo "✅ vendored files intact — $checked file(s) match CHECKSUMS.txt"
