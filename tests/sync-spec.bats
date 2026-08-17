#!/usr/bin/env bats
#
# sync-spec.sh is the only writer of spec/, which makes its refusals as
# important as its copying: the guards are what keep the vendored tree
# traceable to an upstream commit rather than merely present.
#
# Every test builds a fake specification repository and a fake pack, so nothing
# here touches the real vendored tree.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORK="$(mktemp -d)"

  # git needs an identity to commit, and the runner may not have one.
  export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.invalid"
  export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.invalid"

  # --- a fake upstream specification repository ---
  SRC="$WORK/cabuya.org"
  mkdir -p "$SRC/spec/schemas/0.1" "$SRC/spec/versions/0.1" \
           "$SRC/spec/examples/0.1/valid" "$SRC/spec/examples/0.1/invalid" \
           "$SRC/spec/vocab"
  printf '{"$id":"manifest"}\n' > "$SRC/spec/schemas/0.1/manifest.schema.json"
  printf '{"$id":"place-feed"}\n' > "$SRC/spec/schemas/0.1/place-feed.schema.json"
  printf '{"valid":true}\n' > "$SRC/spec/examples/0.1/valid/valid-minimal-core.json"
  printf '{"valid":false}\n' > "$SRC/spec/examples/0.1/invalid/invalid-1.json"
  printf '# dictionary\n' > "$SRC/spec/vocab/equivalence-dictionary.md"
  cat > "$SRC/spec/versions/0.1/7-normative-exclusions.md" <<'SPEC'
---
version: "0.1"
section: 7
---

# §7 — Normative exclusions

## §7.1 Person-level data

The protocol MUST NOT transport person-level entities.
SPEC
  git -C "$SRC" init -q .
  git -C "$SRC" add -A
  git -C "$SRC" commit -qm "spec"

  # --- a fake pack ---
  PACK="$WORK/pack"
  mkdir -p "$PACK/scripts" "$PACK/spec" "$PACK/examples"
  cp "$REPO_ROOT/scripts/sync-spec.sh" "$PACK/scripts/"
  cp "$REPO_ROOT/scripts/generate-checksums.sh" "$PACK/scripts/"
  cp "$REPO_ROOT/scripts/verify-integrity.sh" "$PACK/scripts/"
  git -C "$PACK" init -q .
  git -C "$PACK" add -A
  git -C "$PACK" commit -qm "pack"
}

teardown() {
  rm -rf "$WORK"
}

sync() { bash "$PACK/scripts/sync-spec.sh" "$@"; }

@test "--help works without a source" {
  run sync --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"only writer of spec/"* ]]
}

@test "vendors schemas, vocab, examples and §7" {
  run sync --from "$SRC"
  [ "$status" -eq 0 ]

  [ -f "$PACK/spec/schemas/manifest.schema.json" ]
  [ -f "$PACK/spec/schemas/place-feed.schema.json" ]
  [ -f "$PACK/spec/vocab/equivalence-dictionary.md" ]
  [ -f "$PACK/examples/valid/valid-minimal-core.json" ]
  [ -f "$PACK/examples/invalid/invalid-1.json" ]
  [ -f "$PACK/spec/EXCLUSIONS.md" ]
  [ -f "$PACK/spec/CHECKSUMS.txt" ]
}

@test "the vendored §7 is the body verbatim, with the frontmatter dropped" {
  run sync --from "$SRC"
  [ "$status" -eq 0 ]

  # Frontmatter is the website's rendering metadata, not normative text.
  run grep -c 'section: 7' "$PACK/spec/EXCLUSIONS.md"
  [ "$output" = "0" ]

  # The body starts at the heading and is unmodified.
  [ "$(head -1 "$PACK/spec/EXCLUSIONS.md")" = "# §7 — Normative exclusions" ]
  grep -q "MUST NOT transport person-level entities" "$PACK/spec/EXCLUSIONS.md"
}

@test "records provenance: repo, ref and commit" {
  run sync --from "$SRC"
  [ "$status" -eq 0 ]

  commit="$(git -C "$SRC" rev-parse HEAD)"
  grep -q "commit      $commit" "$PACK/spec/SOURCE"
  [ "$(cat "$PACK/spec/VERSION")" = "0.1" ]
}

@test "what it vendors passes the integrity check" {
  sync --from "$SRC"
  run bash "$PACK/scripts/verify-integrity.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"intact"* ]]
}

@test "running it twice produces no diff" {
  sync --from "$SRC"
  git -C "$PACK" add -A
  git -C "$PACK" commit -qm "vendor"

  run sync --from "$SRC"
  [ "$status" -eq 0 ]

  # The real assertion: git sees nothing to commit.
  run git -C "$PACK" status --porcelain
  [ "$output" = "" ]
}

@test "it refuses to run over uncommitted changes in the pack" {
  sync --from "$SRC"          # leaves spec/ dirty, uncommitted

  run sync --from "$SRC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted changes"* ]]
}

@test "a hand-edited vendored file is not silently overwritten" {
  sync --from "$SRC"
  git -C "$PACK" add -A
  git -C "$PACK" commit -qm "vendor"

  # Somebody edits the normative text directly, then re-syncs to "fix" it.
  echo "and one more rule I made up" >> "$PACK/spec/EXCLUSIONS.md"

  run sync --from "$SRC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"belongs upstream"* ]]
  # Still there, so the edit is visible in review rather than erased.
  grep -q "one more rule I made up" "$PACK/spec/EXCLUSIONS.md"
}

@test "it refuses a source whose spec/ is uncommitted" {
  echo "unreviewed change" >> "$SRC/spec/versions/0.1/7-normative-exclusions.md"

  run sync --from "$SRC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"source repository has uncommitted changes"* ]]
}

@test "a git URL without --ref is refused" {
  run sync --from "https://github.com/Cabuya/cabuya.org"
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs --ref"* ]]
}

@test "a source that is not the specification repository is refused" {
  mkdir -p "$WORK/random"
  run sync --from "$WORK/random"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No spec/ directory"* ]]
}

@test "a version that was never published is refused" {
  run sync --from "$SRC" --version 9.9
  [ "$status" -eq 1 ]
  [[ "$output" == *"No spec/versions/9.9"* ]]
}

@test "stale files from a previous version do not survive a re-sync" {
  sync --from "$SRC"
  echo '{"old":true}' > "$PACK/spec/schemas/retired.schema.json"
  git -C "$PACK" add -A
  git -C "$PACK" commit -qm "vendor plus a retired schema"

  run sync --from "$SRC"
  [ "$status" -eq 0 ]
  [ ! -f "$PACK/spec/schemas/retired.schema.json" ]
}

@test "an authored file in spec/ survives a re-sync" {
  # PROTOCOL_SUMMARY.md is written here, not vendored. Wiping it on every sync
  # would be a quiet, recurring data loss.
  printf '# distilled\n' > "$PACK/spec/PROTOCOL_SUMMARY.md"
  git -C "$PACK" add -A
  git -C "$PACK" commit -qm "summary"

  run sync --from "$SRC"
  [ "$status" -eq 0 ]
  [ -f "$PACK/spec/PROTOCOL_SUMMARY.md" ]
  grep -q "distilled" "$PACK/spec/PROTOCOL_SUMMARY.md"
  # …and it is checksummed alongside the vendored files.
  grep -q "spec/PROTOCOL_SUMMARY.md" "$PACK/spec/CHECKSUMS.txt"
}
