#!/usr/bin/env bats
#
# The offline registry snapshot: it exists (consume/SKILL.md imports it),
# parses, carries provenance, and holds org-level data only — no key on the
# pack's own PII deny-list, no contact value, no hand-written measured state.

setup() {
  load helpers
  REPO="$(cd "$BATS_TEST_DIRNAME/../skills/cabuya" && pwd)"
  SNAPSHOT="$REPO/consume/registry-snapshot.json"
}

@test "the snapshot the consume flow imports actually exists" {
  [ -f "$SNAPSHOT" ]
  grep -q "registry-snapshot.json" "$REPO/consume/SKILL.md"
}

@test "the snapshot parses and carries publishers plus provenance" {
  run python3 - "$SNAPSHOT" << 'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert isinstance(d["publishers"], list) and d["publishers"], "publishers empty"
p = d["_provenance"]
assert p["source"] and p["retrieved_at"], "provenance incomplete"
assert "never in this snapshot" in p["note"], "measured-state disclaimer missing"
for e in d["publishers"]:
    assert e["publisher_id"] and e["canonical_url"] and e["status"], "org fields missing"
print("ok")
PY
  [ "$status" -eq 0 ]
}

@test "the snapshot is org-level only — no deny-listed key, no contact value" {
  run python3 - "$SNAPSHOT" << 'PY'
import json, re, sys
raw = open(sys.argv[1]).read()
raw = re.sub(r"\d{4}-\d{2}-\d{2}", "", raw)  # ISO dates are not phone numbers
d = json.load(open(sys.argv[1]))
deny = ["telefono", "phone", "whatsapp", "email", "correo", "cedula",
        "contact_value", "nombre_persona", "person_name"]
def keys(o):
    if isinstance(o, dict):
        for k, v in o.items():
            yield k.lower(); yield from keys(v)
    elif isinstance(o, list):
        for v in o:
            yield from keys(v)
bad = [k for k in keys(d) for t in deny if t in k]
assert not bad, f"deny-listed keys: {bad}"
assert not re.search(r"\+?\d[\d .-]{7,}\d", raw), "phone-shaped value present"
assert not re.search(r"[\w.+-]+@[\w-]+\.[\w.]+", raw), "email-shaped value present"
for e in d["publishers"]:
    for k in e:
        assert k in {"publisher_id", "canonical_url", "manifest_url",
                     "crawl_policy_url", "entity_domains", "status", "added"}, \
            f"unexpected field {k} — measured state and prose stay out"
print("ok")
PY
  [ "$status" -eq 0 ]
}
