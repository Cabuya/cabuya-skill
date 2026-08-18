#!/usr/bin/env bats
#
# Contract tests over the prose.
#
# The pack's "code" is Markdown an agent reads at runtime, so the things that
# can silently break are sentences. These tests pin the ones whose removal
# would change what the agent does: the deny-list's pattern families, the PII
# stop, the CR-1 rule, and the anti-patterns.
#
# They are deliberately grep-shaped. A test that tried to judge whether the
# prose still *means* the right thing would be a worse test than one that
# fails loudly when `cedula` disappears from the deny-list.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/../skills/cabuya" && pwd)"
  DENY="$REPO/shared/pii-deny-list.md"
  IMPL="$REPO/implement/SKILL.md"
}


# --- the deny-list ------------------------------------------------------------

@test "the deny-list names every mandatory pattern family" {
  # Each of these has a production leak behind it. Dropping one is not a
  # tidy-up; it is removing a check.
  for token in nombre apellido telefono celular whatsapp correo email \
               cedula documento direccion_casa foto contacto responsable; do
    grep -qi -- "$token" "$DENY" || {
      echo "deny-list no longer mentions: $token"
      return 1
    }
  done
}

@test "the deny-list carries value-level regexes, not just column names" {
  # A column called `notas` holding a phone number is the third leak channel,
  # and only a value-level pattern catches it.
  grep -q '3\\d{9}' "$DENY"                      # bare Colombian mobile
  grep -q '@' "$DENY"                            # email shape
  grep -qi 'preguntar por\|contactar a' "$DENY"  # name-adjacent free text
}

@test "the deny-list states that matches are never auto-resolved" {
  says "$DENY" 'never auto-resolve'
}

@test "the deny-list forbids widening itself to silence an error" {
  says "$DENY" 'never widen the deny-list'
}

@test "the deny-list says a namespaced extension is not an exemption" {
  says "$DENY" 'x_example_phone'
  says "$DENY" 'namespacing is for fields the vocabulary lacks'
}

@test "the deny-list explains entity-scoped grants and the CORS trap" {
  says "$DENY" 'entity-scoped grants'
  says "$DENY" 'Access-Control-Allow-Origin'
}

# --- the implement flow -------------------------------------------------------

@test "the PII stop is impossible to read as optional" {
  says "$IMPL" 'STOP HERE'
  says "$IMPL" 'do not proceed without an explicit human yes'
  says "$IMPL" 'silence is not consent'
  # And there is explicitly no escape hatch.
  says "$IMPL" 'there is no --yes'
}

@test "all six phases are present, in order" {
  run grep -c '^## Phase [0-5] ·\|^## Phase 6 ·' "$IMPL"
  [ "$output" -eq 7 ]

  # Order matters: an agent reading this top to bottom must not map before it
  # reads, or serialize before the gate.
  order="$(grep -o '^## Phase [0-6]' "$IMPL" | grep -o '[0-6]' | tr -d '\n')"
  [ "$order" = "0123456" ]
}

@test "CR-1 is stated where the mapping happens" {
  says "$IMPL" 'CR-1'
  says "$IMPL" 'an edit is not a confirmation'
  says "$IMPL" 'never to updated_at'
}

@test "the always-now anti-pattern is named in the serialize phase" {
  says "$IMPL" 'never per request'
  says "$IMPL" 'BEH002'
}

@test "the loop is bounded and halts on PII errors" {
  says "$IMPL" 'maximum 8 iterations'
  says "$IMPL" 'halts on any PII error'
}

@test "degraded mode never reports conforming" {
  says "$IMPL" 'schema-valid; conformance unmeasured'
  says "$IMPL" 'never "conforming"'
}

@test "it refuses to invent data and says so" {
  says "$IMPL" 'never invent'
  says "$IMPL" 'do not scaffold a feed with invented records'
}

@test "it will not open a pull request unasked" {
  says "$IMPL" 'never open a pull request'
}

@test "the person-domain refusal is a stop condition, not a warning" {
  says "$IMPL" 'irreducibly personal'
  says "$IMPL" 'link-out-only'
  says "$IMPL" 'do not look for a way to reach L2'
}

# --- mapping references -------------------------------------------------------

@test "the DIVIPOLA codes are labelled unverified, not presented as checked" {
  # Rule 0: never publish a claim you cannot back. The founding record marks
  # these unverified and the vendored dictionary requires validation against
  # the DANE table — so this page must not quietly upgrade them.
  says "$REPO/implement/mapping/divipola.md" 'not verified against the DANE source'
  says "$REPO/implement/mapping/divipola.md" \
    'MUST be validated against the official DANE'
}

@test "place-kind mapping points at the vendored crosswalk rather than copying it" {
  says "$REPO/implement/mapping/place-kind.md" 'spec/vocab/place-kind-crosswalk.json'
  says "$REPO/implement/mapping/place-kind.md" \
    'read the JSON rather than trusting this page'
}

@test "the field crosswalk names every Core-required field" {
  cross="$REPO/implement/mapping/field-crosswalk.md"
  for field in id publisher_id name place_kind municipality_code \
               lifecycle_status last_confirmed_at source public_url; do
    grep -q "\`$field\`" "$cross" || {
      echo "field crosswalk no longer covers: $field"
      return 1
    }
  done
  # The locator rule is conditional and easy to lose.
  grep -qi 'locator rule' "$cross"
}

# --- templates ----------------------------------------------------------------

@test "the manifest template is valid JSON with the schema's required keys" {
  manifest="$REPO/implement/templates/manifest.json"
  python3 -c "
import json, sys
m = json.load(open('$manifest'))
for key in ('protocol', 'publisher', 'conformance_target', 'license'):
    assert key in m, f'manifest template is missing {key}'
assert m['protocol']['name'] == 'cabuya'
assert 'publisher_id' in m['publisher'] and 'canonical_url' in m['publisher']
"
}

@test "no template carries a contact field in a record" {
  # The most consequential possible copy-paste. A phone number in a template
  # is a phone number in production.
  ! grep -rniE '"(telefono|phone|celular|whatsapp|email|correo)"' \
    "$REPO/implement/templates/"
}

@test "every serializer template sets the CORS header" {
  for template in "$REPO"/implement/templates/serializer-*.md; do
    grep -q 'Access-Control-Allow-Origin' "$template" || {
      echo "no CORS header in $(basename "$template")"
      return 1
    }
  done
}

@test "every serializer template keeps last_confirmed_at present" {
  for template in "$REPO"/implement/templates/serializer-*.md; do
    grep -q 'last_confirmed_at' "$template" || {
      echo "no last_confirmed_at in $(basename "$template")"
      return 1
    }
  done
}

@test "the CABUYA.md template leaves no placeholder in the committed file" {
  says "$REPO/implement/templates/CABUYA.md" \
    'do not leave a placeholder in the file you commit'
  says "$REPO/implement/templates/CABUYA.md" 'every angle bracket must go'
}
