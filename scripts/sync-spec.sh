#!/usr/bin/env bash
#
# sync-spec.sh — vendor the protocol contracts from the specification repo.
#
# **This script is the only writer of `spec/`.** That is rule V6, and it is not
# a style preference: the vendored copy is what an offline agent will teach
# people, so the difference between "a copy of the standard" and "a fork nobody
# declared" is precisely whether every byte can be traced to an upstream commit.
# Hand-edit a vendored file and `verify-integrity.sh` fails the build.
#
#   bash scripts/sync-spec.sh --from /path/to/cabuya.org
#   bash scripts/sync-spec.sh --from https://github.com/Cabuya/cabuya.org --ref v0.1.0
#   bash scripts/sync-spec.sh --from ../cabuya.org --version 0.1
#
# What it vendors, and why each piece:
#
#   spec/schemas/       the JSON Schemas — what the validator actually enforces
#   spec/vocab/         the equivalence dictionary the mapping flow reads
#   spec/EXCLUSIONS.md  §7 verbatim — the lines that don't move, unparaphrased
#   spec/VERSION        the spec MINOR this copy is
#   spec/SOURCE         repo, ref and commit, so provenance is one file away
#   examples/           the five teaching examples, at the repo root per §3.2
#
# It does NOT write spec/PROTOCOL_SUMMARY.md. That file is distilled by hand for
# an offline agent, is authored here rather than upstream, and is checksummed
# alongside the vendored files so that changing it also requires regenerating
# checksums in the same commit — visible in review, like everything else here.
#
# Idempotent: running it twice against the same source produces no diff.
#
# Bash 3.2 compatible (macOS default).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_DIR="$REPO_ROOT/spec"
EXAMPLES_DIR="$REPO_ROOT/examples"

SOURCE=""
REF=""
VERSION="0.1"
TMP_CLONE=""

cleanup() {
  [ -n "$TMP_CLONE" ] && [ -d "$TMP_CLONE" ] && rm -rf "$TMP_CLONE"
  return 0
}
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Vendor the protocol contracts from the specification repository.

Usage:
  bash scripts/sync-spec.sh --from <path-or-git-url> [--ref <tag>] [--version <minor>]

Options:
  --from <src>       A local checkout of Cabuya/cabuya.org, or a git URL to
                     clone shallowly.
  --ref <ref>        Tag, branch or commit to vendor from. Required for a URL;
                     for a local path, defaults to whatever is checked out.
  --version <minor>  Spec MINOR to vendor. Default: 0.1
  --help, -h         This text.

This is the only writer of spec/. Never hand-edit a vendored file: run this,
and commit the regenerated CHECKSUMS.txt in the same commit.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --from) [ $# -ge 2 ] || die "Missing value for --from"; SOURCE="$2"; shift 2 ;;
    --from=*) SOURCE="${1#--from=}"; shift ;;
    --ref) [ $# -ge 2 ] || die "Missing value for --ref"; REF="$2"; shift 2 ;;
    --ref=*) REF="${1#--ref=}"; shift ;;
    --version) [ $# -ge 2 ] || die "Missing value for --version"; VERSION="$2"; shift 2 ;;
    --version=*) VERSION="${1#--version=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
done

[ -n "$SOURCE" ] || { usage >&2; die ""; }

# --- refuse to run over uncommitted work -------------------------------------
#
# V6's audit trail is the whole point. If spec/ has uncommitted changes, either
# somebody hand-edited a vendored file — which this would silently erase, hiding
# the very thing the integrity check exists to catch — or a previous sync is
# half-committed. Both want a human, not an overwrite.

if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- spec examples 2>/dev/null)" ]; then
    say "spec/ or examples/ has uncommitted changes:" >&2
    git -C "$REPO_ROOT" status --short -- spec examples >&2
    say "" >&2
    say "Commit or discard them first. If you hand-edited a vendored file," >&2
    say "that change belongs upstream in Cabuya/cabuya.org, behind an RFC —" >&2
    say "this script would erase it and the audit trail with it." >&2
    exit 1
  fi
fi

# --- resolve the source ------------------------------------------------------

if [ -d "$SOURCE" ]; then
  SRC_ROOT="$(cd "$SOURCE" && pwd)"
  if [ -n "$REF" ]; then
    git -C "$SRC_ROOT" rev-parse --verify "$REF" >/dev/null 2>&1 \
      || die "Ref '$REF' not found in $SRC_ROOT"
    say "Note: --ref is recorded, but a local path is vendored as checked out."
  fi
else
  TMP_CLONE="$(mktemp -d)"
  [ -n "$REF" ] || die "A git URL needs --ref: vendoring a moving branch is not provenance."
  say "Cloning $SOURCE at $REF …"
  git clone --quiet --depth 1 --branch "$REF" "$SOURCE" "$TMP_CLONE/src" \
    || die "Could not clone $SOURCE at $REF"
  SRC_ROOT="$TMP_CLONE/src"
fi

SRC_SPEC="$SRC_ROOT/spec"
[ -d "$SRC_SPEC" ] || die "No spec/ directory in $SRC_ROOT — is that the specification repository?"
[ -d "$SRC_SPEC/versions/$VERSION" ] || die "No spec/versions/$VERSION in the source."

# The source's spec/ must be committed too.
#
# Otherwise SOURCE records a commit hash while the files copied are somebody's
# working tree — provenance that reads as precise and is false, which is worse
# than none. This is the same argument as the destination-side check above,
# pointed the other way.
if git -C "$SRC_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -n "$(git -C "$SRC_ROOT" status --porcelain -- spec 2>/dev/null)" ]; then
    say "The source repository has uncommitted changes under spec/:" >&2
    git -C "$SRC_ROOT" status --short -- spec >&2
    say "" >&2
    say "Vendoring now would record a commit hash for files that are not in it." >&2
    say "Commit them upstream first." >&2
    exit 1
  fi
fi

SRC_COMMIT="$(git -C "$SRC_ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown')"
SRC_REMOTE="$(git -C "$SRC_ROOT" remote get-url origin 2>/dev/null || printf '%s' "$SOURCE")"
SRC_DESCRIBE="$(git -C "$SRC_ROOT" describe --tags --always 2>/dev/null || printf 'unknown')"

say "Vendoring spec $VERSION from $SRC_REMOTE @ ${SRC_COMMIT:0:12}"

# --- clear what we own, keep what we author ----------------------------------
#
# Everything below is regenerated, so stale files from a previous version do not
# linger. PROTOCOL_SUMMARY.md is authored here and survives.

rm -rf "$SPEC_DIR/schemas" "$SPEC_DIR/vocab"
rm -f "$SPEC_DIR/EXCLUSIONS.md" "$SPEC_DIR/VERSION" "$SPEC_DIR/SOURCE" "$SPEC_DIR/CHECKSUMS.txt"
rm -rf "$EXAMPLES_DIR/valid" "$EXAMPLES_DIR/invalid"

mkdir -p "$SPEC_DIR/schemas" "$SPEC_DIR/vocab" "$EXAMPLES_DIR/valid" "$EXAMPLES_DIR/invalid"

# --- schemas -----------------------------------------------------------------

count=0
for schema in "$SRC_SPEC/schemas/$VERSION"/*.json; do
  [ -f "$schema" ] || continue
  cp "$schema" "$SPEC_DIR/schemas/"
  count=$((count + 1))
done
[ "$count" -gt 0 ] || die "No schemas found under $SRC_SPEC/schemas/$VERSION"
say "  schemas:  $count"

# --- vocabulary --------------------------------------------------------------

count=0
if [ -d "$SRC_SPEC/vocab" ]; then
  for entry in "$SRC_SPEC/vocab"/*; do
    [ -f "$entry" ] || continue
    cp "$entry" "$SPEC_DIR/vocab/"
    count=$((count + 1))
  done
fi
say "  vocab:    $count"

# --- examples ----------------------------------------------------------------

count=0
for kind in valid invalid; do
  src="$SRC_SPEC/examples/$VERSION/$kind"
  [ -d "$src" ] || continue
  for entry in "$src"/*.json; do
    [ -f "$entry" ] || continue
    cp "$entry" "$EXAMPLES_DIR/$kind/"
    count=$((count + 1))
  done
done
[ "$count" -gt 0 ] || die "No examples found under $SRC_SPEC/examples/$VERSION"
say "  examples: $count"

# --- §7, byte-verbatim -------------------------------------------------------
#
# Only the YAML frontmatter is dropped — it is the website's rendering metadata,
# not normative text. Everything after it is copied exactly: these are the lines
# that don't move, and paraphrasing them here would be the most consequential
# possible place to introduce drift.

EXCLUSIONS_SRC="$SRC_SPEC/versions/$VERSION/7-normative-exclusions.md"
[ -f "$EXCLUSIONS_SRC" ] || die "No §7 at $EXCLUSIONS_SRC"

awk '
  NR == 1 && $0 == "---" { in_fm = 1; next }
  in_fm && $0 == "---"   { in_fm = 0; skip_blank = 1; next }
  in_fm                  { next }
  skip_blank && $0 == "" { skip_blank = 0; next }
  { skip_blank = 0; print }
' "$EXCLUSIONS_SRC" > "$SPEC_DIR/EXCLUSIONS.md"

[ -s "$SPEC_DIR/EXCLUSIONS.md" ] || die "Extracted EXCLUSIONS.md is empty — check the source format."
say "  §7:       $(wc -l < "$SPEC_DIR/EXCLUSIONS.md" | tr -d ' ') lines"

# --- the catch-all exclusions -------------------------------------------------
#
# Derived, not authored. `SPA_EXCLUSIONS` lives in the validator package
# because three surfaces need the same words — the CLI's `init --framework`,
# the website's quickstart, and this pack's stack guides — and the source file
# says so itself: "a copy in each is three copies that drift, and the one that
# drifts is the one somebody follows."
#
# So this is the fourth copy, and it is generated. Drift becomes a checksum
# failure rather than a note in a maintenance list.
#
# Extracted by loading the TypeScript module rather than parsing it, so a
# reformat upstream cannot silently produce a half-empty table. Skipped with a
# warning when node is unavailable — the guides still work, they just carry the
# copy from the last sync.

EXCLUSIONS_SRC="$SRC_ROOT/packages/validator/src/spa-exclusions.ts"

if [ -f "$EXCLUSIONS_SRC" ] && command -v node >/dev/null 2>&1; then
  if node --experimental-strip-types \
       "$REPO_ROOT/scripts/lib/extract-spa-exclusions.mjs" \
       "$EXCLUSIONS_SRC" > "$SPEC_DIR/SPA_EXCLUSIONS.md" 2>/dev/null; then
    say "  spa:      $(grep -c '^### ' "$SPEC_DIR/SPA_EXCLUSIONS.md") frameworks"
  else
    rm -f "$SPEC_DIR/SPA_EXCLUSIONS.md"
    say "  spa:      SKIPPED — could not load $EXCLUSIONS_SRC" >&2
  fi
else
  say "  spa:      SKIPPED — node or the source module is unavailable" >&2
fi

# --- provenance --------------------------------------------------------------

printf '%s\n' "$VERSION" > "$SPEC_DIR/VERSION"

cat > "$SPEC_DIR/SOURCE" <<EOF
# Where this vendored copy came from.
#
# Written by scripts/sync-spec.sh. Do not edit by hand — every field here is
# what makes the copy traceable rather than merely present.

repo        $SRC_REMOTE
ref         ${REF:-$SRC_DESCRIBE}
commit      $SRC_COMMIT
spec_version $VERSION

# Vendored verbatim from the repository above:
#   spec/schemas/       spec/vocab/       spec/EXCLUSIONS.md
#   examples/valid/     examples/invalid/
#
# Generated from that repository (derived, never hand-edited):
#   spec/SPA_EXCLUSIONS.md  <- packages/validator/src/spa-exclusions.ts
#
# Authored in this repository, checksummed alongside them:
#   spec/PROTOCOL_SUMMARY.md
EOF

say "  source:   recorded"

# --- checksums ---------------------------------------------------------------

bash "$REPO_ROOT/scripts/generate-checksums.sh"

say ""
say "Done. Verify with: bash scripts/verify-integrity.sh"
say "Commit spec/ and examples/ together with CHECKSUMS.txt."
