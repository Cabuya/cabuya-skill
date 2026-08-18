#!/usr/bin/env bats
#
# Explain: grounded or silent, never a guess.
#
# The property under test is groundedness — every cited source exists in the
# pack, the honesty sentences are present, and the sub-skill cannot write.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/../skills/cabuya" && pwd)"
  EXPLAIN="$REPO/explain/SKILL.md"
  QUESTIONS="$REPO/explain/QUESTIONS.md"
}

@test "explain is routed from the router and offered from adopt" {
  grep -q "explain/SKILL.md" "$REPO/SKILL.md"
  grep -q "explain/SKILL.md" "$REPO/adopt/SKILL.md"
}

@test "trigger phrases exist in both languages" {
  says "$EXPLAIN" "what is Cabuya"
  says "$EXPLAIN" "qué es Cabuya"
  says "$EXPLAIN" "explícame el protocolo"
}

@test "every cited source in QUESTIONS.md exists in the pack" {
  run bash -c "grep -oE '\`(spec|plan|shared|validate)/[A-Za-z0-9_./-]+\`' '$QUESTIONS' | tr -d '\`' | sort -u"
  [ -n "$output" ]
  while IFS= read -r path; do
    [ -e "$REPO/$path" ] || { echo "cited but missing: $path"; return 1; }
  done <<< "$output"
}

@test "every question is asked in both languages" {
  # Each numbered entry carries the interpunct separating EN · ES.
  n_entries="$(grep -cE '^## [0-9]+\.' "$QUESTIONS")"
  n_bilingual="$(grep -E '^## [0-9]+\.' "$QUESTIONS" | grep -c '·')"
  [ "$n_entries" -ge 12 ]
  [ "$n_entries" -eq "$n_bilingual" ]
}

@test "explain cannot write — enforced by allowed-tools" {
  head -20 "$EXPLAIN" | grep "allowed-tools" | grep -qv "Write"
  head -20 "$EXPLAIN" | grep "allowed-tools" | grep -qv "Edit"
}

@test "the read-only preview carries the no-write rule verbatim" {
  says "$EXPLAIN" "This preview writes nothing"
  says "$EXPLAIN" "not a file, not a scaffold, not a sample"
}

@test "the draft-status sentence is present" {
  says "$EXPLAIN" "the specification is 0.1, a draft"
  says "$QUESTIONS" "0.1, a draft"
}

@test "the listing sentence is present" {
  says "$EXPLAIN" "inclusion is not endorsement"
}

@test "certified appears only inside its own prohibition" {
  for f in "$EXPLAIN" "$QUESTIONS"; do
    while IFS= read -r line; do
      echo "$line" | grep -qiE "no |never|there is no" \
        || { echo "affirmative use in $f: $line"; return 1; }
    done < <(grep -i "certified\|certificado" "$f" || true)
  done
}

@test "unanswerable questions point at the website, never at memory" {
  says "$QUESTIONS" "never fill the gap from training data"
  says "$EXPLAIN" "explains a protocol that does not exist"
}

@test "answers end with a next step" {
  says "$EXPLAIN" "End with the one next step"
  grep -q "adopt/SKILL.md" "$EXPLAIN"
}
