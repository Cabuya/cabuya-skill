#!/usr/bin/env bats
#
# Contract tests for the two sub-skills that touch other people's data and
# other people's repositories. As with the implement tests, the prose is the
# implementation, so these pin the sentences whose removal changes behaviour.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/../skills/cabuya" && pwd)"
  RULES="$REPO/consume/rules.md"
  CONSUME="$REPO/consume/SKILL.md"
  PUBLISH="$REPO/publish-status/SKILL.md"
  POLICY="$REPO/shared/crawl-policy.md"
}


# --- the six rules ------------------------------------------------------------

@test "rules.md carries all six consumption MUSTs" {
  for rule in 'Attribute' 'Show age' 'Do not mutate' 'Preserve chains' \
              'Dedupe by claim' 'Respect exclusions'; do
    says "$RULES" "$rule" || {
      echo "consume/rules.md no longer covers: $rule"
      return 1
    }
  done
}

@test "every rule carries a self-test, not just a description" {
  # A rule that lives only in a comment survives exactly one refactor.
  run grep -c '^\*\*Self-test:\*\*' "$RULES"
  [ "$output" -ge 6 ]
}

@test "rule 2 pins the three renderings and the 7-day threshold" {
  says "$RULES" 'sin confirmar'
  says "$RULES" '7 days'
  says "$RULES" 'contradictions_active'
  # Absence of data is not evidence of closure.
  says "$RULES" 'not silently hide'
}

@test "rule 5 forbids name matching and transitive same_as" {
  says "$RULES" 'never on name'
  says "$RULES" 'non-transitive'
  # The evidence, kept with the rule so nobody relaxes it as a heuristic.
  says "$RULES" '100 %'
}

@test "rule 6 demands refusal by construction, not by convention" {
  says "$RULES" 'by construction'
  says "$RULES" 'join prohibition'
}

# --- the crawl policy ---------------------------------------------------------

@test "the crawl policy carries the even-if-asked clause" {
  # The clause most likely to be argued with, because the request will always
  # sound reasonable.
  says "$POLICY" 'even if a human asks'
  says "$POLICY" 'do not comply'
}

@test "the crawl policy says absent is not permission" {
  says "$POLICY" 'Absent is not permission'
}

@test "the crawl policy filters before fetching, and says why" {
  says "$POLICY" 'Filter before you fetch'
  says "$POLICY" 'already taken the thing it was meant to protect'
}

@test "the crawl policy refuses scraping outright" {
  says "$POLICY" 'Do not fetch a site that has not published a feed'
  says "$POLICY" 'reconstruct a feed from HTML'
}

# --- consume ------------------------------------------------------------------

@test "consume states the join-prohibition refusal with the rule" {
  says "$CONSUME" 'join prohibition'
  says "$CONSUME" 'EXCLUSIONS.md'
  says "$CONSUME" 'link out'
}

@test "consume tells the agent to generate the self-tests with the code" {
  says "$CONSUME" 'Generate the self-tests with the code'
}

@test "consume does not claim a level" {
  ! grep -niE 'you are now L[0-4]|now L3|certified' "$CONSUME"
}

@test "consume keeps moderation verdicts local" {
  says "$CONSUME" 'verdicts stay local'
  says "$CONSUME" 'defamation-shaped'
}

# --- publish-status -----------------------------------------------------------

@test "publish-status refuses a target above the measured level" {
  says "$PUBLISH" 'may not exceed'
  says "$PUBLISH" 'measured_level'
  # And it must be useful about it, not merely negative.
  says "$PUBLISH" 'blockers_for_next_level'
}

@test "publish-status refuses to publish from a degraded run" {
  says "$PUBLISH" 'unmeasured is not a level'
}

@test "publish-status allows a target below the measured level" {
  # A publisher may declare less than they achieved. Pushing them up would be
  # this skill inventing a claim on their behalf.
  says "$PUBLISH" 'below the measured level is allowed'
}

@test "publish-status never opens a pull request unasked" {
  says "$PUBLISH" 'Never open this pull request unasked'
  # And gh must not be presented as a blocker.
  says "$PUBLISH" 'web interface works just as well'
}

@test "publish-status covers every wind-down step" {
  for step in 'sunset_at' 'custody transfer' 'archived' 'never reassigned'; do
    says "$PUBLISH" "$step" || {
      echo "wind-down no longer covers: $step"
      return 1
    }
  done
  # The reason the frozen timestamp matters after sunset.
  says "$PUBLISH" 'abandoned feed look maintained'
}

@test "publish-status keeps contact_org organizational" {
  says "$PUBLISH" 'role address only'
  says "$PUBLISH" 'Never a person'
}

@test "publish-status keeps measured badge state out of git" {
  says "$PUBLISH" 'never in git'
}

# --- across both --------------------------------------------------------------

@test "neither sub-skill uses the word certified" {
  for file in "$CONSUME" "$PUBLISH" "$RULES" "$POLICY"; do
    # Except where it is explicitly forbidden.
    offenders="$(grep -ni 'certified' "$file" | grep -vi 'never\|no certification\|not use' || true)"
    [ -z "$offenders" ] || {
      echo "$(basename "$file"): $offenders"
      return 1
    }
  done
}

@test "no example in either sub-skill uses a resolvable host or a real contact" {
  for file in "$CONSUME" "$PUBLISH" "$RULES" "$POLICY"; do
    ! grep -nE "https://example\.(com|org|net)\b" "$file" || {
      echo "$(basename "$file") uses a resolvable example host"
      return 1
    }
    ! grep -nE "\b3[0-9]{9}\b|\+?57[ -]?3[0-9]{2}[ -]?[0-9]{3}[ -]?[0-9]{4}" "$file" || {
      echo "$(basename "$file") contains a phone-shaped value"
      return 1
    }
  done
}

@test "the router links every one of the five sub-skills" {
  for skill in implement consume validate publish-status setup; do
    grep -q "]($skill/SKILL.md)" "$REPO/SKILL.md" || {
      echo "the router does not link $skill"
      return 1
    }
  done
  # And nothing is still marked as unreleased.
  ! grep -q 'next release' "$REPO/SKILL.md"
}

# --- the display pattern (Task 7 of PLAN_product_clarity_overhaul) -------------

@test "the canonical display shape carries origin and place together" {
  says "$CONSUME" "{name} — by {publisher} · {municipality_text}, {neighborhood_text}"
  says "$RULES" "{name} — by {publisher} · {municipality_text}, {neighborhood_text}"
}

@test "action buttons link out to the origin, never synthesized contact UI" {
  says "$CONSUME" "never to contact UI you synthesize"
  says "$RULES" "never to a contact UI the consumer synthesizes"
}
