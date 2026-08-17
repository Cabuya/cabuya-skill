#!/usr/bin/env bats
#
# The guide contract, enforced.
#
# Stack guides are the pack's main contributor surface, which means most of
# them will be written by somebody who has read one existing guide and is
# working from memory. These tests are the half of review that should not need
# a reviewer — they check the rules in stacks/README.md that can be checked
# without judgement, so a contributor finds out before a human does.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  STACKS="$REPO/implement/stacks"
}

guides() {
  find "$STACKS" -name '*.md' ! -name 'README.md' | sort
}



@test "the four v0.1 guides exist" {
  for guide in nextjs-supabase vite-spa-supabase php-ssr static-sheet; do
    [ -f "$STACKS/$guide.md" ] || {
      echo "missing guide: $guide.md"
      return 1
    }
  done
}

@test "every guide follows the eight-section skeleton, in order" {
  while IFS= read -r guide; do
    order="$(grep -o '^## [1-8]\.' "$guide" | grep -o '[1-8]' | tr -d '\n')"
    [ "$order" = "12345678" ] || {
      echo "$(basename "$guide"): sections are '$order', expected '12345678'"
      return 1
    }
  done < <(guides)
}

@test "every guide points at the README's reason-do-not-copy-paste rule" {
  while IFS= read -r guide; do
    grep -q 'reason, do not' "$guide" || {
      echo "$(basename "$guide") does not carry the copy-paste warning"
      return 1
    }
  done < <(guides)
}

# --- the rules that protect the data ------------------------------------------

@test "no guide maps updated_at into last_confirmed_at" {
  # CR-1, and the single most likely thing for a contributor to get wrong,
  # because every stack has an updated_at and almost none has a confirmation
  # event. Catch the assignment in the shapes the four languages write it.
  while IFS= read -r guide; do
    ! grep -nE "last_confirmed_at['\"]?[[:space:]]*[:=>]+[[:space:]]*[\$a-zA-Z_.>-]*updated_?[aA]t" "$guide" || {
      echo "$(basename "$guide") maps updated_at into last_confirmed_at"
      return 1
    }
  done < <(guides)
}

@test "every guide keeps last_confirmed_at present, and says null is the value" {
  while IFS= read -r guide; do
    grep -q 'last_confirmed_at' "$guide" || {
      echo "$(basename "$guide") never mentions last_confirmed_at"
      return 1
    }
    flowed "$guide" | grep -qi 'null' || {
      echo "$(basename "$guide") does not discuss the null case"
      return 1
    }
  done < <(guides)
}

@test "no guide generates last_updated inside a request handler" {
  # BEH002. `new Date()` and `now()` are fine in a build script and wrong in a
  # handler; the guides that use a handler must show the high-water mark.
  for guide in "$STACKS/nextjs-supabase.md" "$STACKS/php-ssr.md"; do
    flowed "$guide" | grep -qi 'high-water mark' || {
      echo "$(basename "$guide") does not show the high-water-mark pattern"
      return 1
    }
    # In code only, and `new Date()` with no argument. `new Date(0)` is the
    # deliberate epoch these guides use for an empty feed — obviously wrong on
    # sight, which is the point.
    offenders="$(code_only "$guide" | grep -nE "last_updated.*new Date\(\)|last_updated.*\bnow\(\)" || true)"
    [ -z "$offenders" ] || {
      echo "$(basename "$guide") sets last_updated from a request-time clock:"
      echo "$offenders"
      return 1
    }
  done
  return 0
}

@test "every guide sets CORS on the feed route, not globally" {
  while IFS= read -r guide; do
    grep -q 'Access-Control-Allow-Origin' "$guide" || {
      echo "$(basename "$guide") never sets the CORS header"
      return 1
    }
  done < <(guides)
}

@test "no guide uses an unqualified select star" {
  # The leak that widens by itself: it works today and carries a `telefono`
  # column the day somebody adds one.
  #
  # Known limit, stated rather than implied: this catches the *written* forms
  # — `select('*')`, `SELECT *`, `Model::all()`. It cannot catch an ORM whose
  # select-everything is an *omitted* clause, which is exactly Prisma's shape.
  # The test below covers that guide's specific risk instead.
  while IFS= read -r guide; do
    # Code only, and comment lines within it stripped — a guide warning that
    # "SELECT * is the same trap in every language" must not trip the check
    # for SELECT *. `Collection::all()` is excluded deliberately: it converts
    # an already-mapped collection to an array. The risky one is
    # `Model::all()`, which selects every column.
    offenders="$(code_only "$guide" \
                 | grep -vE "^[[:space:]]*(//|#|\*|--)" \
                 | grep -nE "select\('\*'\)|SELECT \*|\b[A-Z][A-Za-z]+::all\(\)" || true)"
    [ -z "$offenders" ] || {
      echo "$(basename "$guide") shows an unqualified select:"
      echo "$offenders"
      return 1
    }
  done < <(guides)
}

@test "the ORM guides warn about the risk grep cannot see" {
  # Prisma and Eloquent select everything by omission, not by a `*`. There is
  # nothing for the check above to match, so the guides must say it in words
  # and those words are what is pinned here.
  flowed "$STACKS/nextjs-supabase.md" | grep -qi 'no include' || {
    echo "the Next.js guide does not warn about include"
    return 1
  }
  flowed "$STACKS/php-ssr.md" | grep -qi 'toArray()' || {
    echo "the PHP guide does not warn about Eloquent's default serialization"
    return 1
  }
}

@test "no guide claims a conformance level" {
  while IFS= read -r guide; do
    ! grep -niE "you are now L[0-4]|now (fully )?conformant|certified" "$guide" || {
      echo "$(basename "$guide") claims a level"
      return 1
    }
  done < <(guides)
}

# --- no person-level data, including in samples -------------------------------

@test "no guide contains a phone-shaped or email-shaped value" {
  while IFS= read -r guide; do
    # Colombian mobile shapes and any real-looking email address. The .invalid
    # TLD is reserved by RFC 2606 and is what sample data must use.
    ! grep -nE "\+?57[ -]?3[0-9]{2}[ -]?[0-9]{3}[ -]?[0-9]{4}|\b3[0-9]{9}\b" "$guide" || {
      echo "$(basename "$guide") contains a phone-shaped value"
      return 1
    }
    # users.noreply.github.com is a bot address that routes nowhere, and a
    # scheduled workflow cannot commit without one. Everything else is a
    # finding.
    emails="$(grep -nE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.(com|org|net|co|es)\b" "$guide" \
              | grep -v 'users.noreply.github.com' || true)"
    [ -z "$emails" ] || {
      echo "$(basename "$guide") contains an email-shaped value:"
      echo "$emails"
      return 1
    }
  done < <(guides)
}

@test "sample hosts use the reserved .invalid TLD" {
  # So that no example in the pack can ever resolve to somebody's real site.
  while IFS= read -r guide; do
    ! grep -nE "https://example\.(com|org|net)\b" "$guide" || {
      echo "$(basename "$guide") uses a resolvable example host"
      return 1
    }
  done < <(guides)
}

# --- the generated exclusion table --------------------------------------------

@test "the catch-all fixes come from the generated file" {
  # Four copies of this instruction exist; three of them are elsewhere. A guide
  # that restates it instead of quoting it becomes the copy that drifts.
  for guide in nextjs-supabase vite-spa-supabase php-ssr; do
    grep -q 'SPA_EXCLUSIONS.md' "$STACKS/$guide.md" || {
      echo "$guide.md does not reference the generated exclusion table"
      return 1
    }
  done
}

@test "the generated exclusion table covers every framework the source ships" {
  generated="$REPO/spec/SPA_EXCLUSIONS.md"
  [ -f "$generated" ] || skip "spec/SPA_EXCLUSIONS.md not vendored yet"

  # It is generated by loading the module rather than parsing it, so a short
  # table means the extraction silently half-worked.
  run grep -c '^### ' "$generated"
  [ "$output" -ge 7 ]

  grep -q 'Generated by' "$generated"
  grep -qi 'do not edit' "$generated"
}

@test "the generated exclusion table is checksummed" {
  [ -f "$REPO/spec/SPA_EXCLUSIONS.md" ] || skip "not vendored yet"
  grep -q 'spec/SPA_EXCLUSIONS.md' "$REPO/spec/CHECKSUMS.txt"
}

# --- the HXL guide's specific obligations -------------------------------------

@test "the sheet guide drops contact columns and says so" {
  sheet="$STACKS/static-sheet.md"
  grep -q '#contact+phone' "$sheet"
  flowed "$sheet" | grep -qi 'drops contact columns'
  flowed "$sheet" | grep -qi 'declared institutional'
}

@test "the sheet guide states that conversion is not conformance" {
  sheet="$STACKS/static-sheet.md"
  flowed "$sheet" | grep -qi 'conversion is not a conformance measurement'
  flowed "$sheet" | grep -qi 'behavioural probes still apply'
}

@test "the stacks README states the guide-authoring contract" {
  readme="$STACKS/README.md"
  flowed "$readme" | grep -qi 'a guide must'
  flowed "$readme" | grep -qi 'a guide must not'
  flowed "$readme" | grep -qi 'good-first-issue:stack'
  # The rule that keeps the four copies in step.
  flowed "$readme" | grep -qi 'do not edit the exclusion text in a guide'
}
