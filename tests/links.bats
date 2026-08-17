#!/usr/bin/env bats
#
# Every relative link in the pack points at a file that exists.
#
# CI runs a Markdown link checker, but it runs late and it also checks the
# network — so a broken internal link arrives as a red build that looks like
# somebody else's outage. This is the fast, local, offline half.
#
# It also encodes a rule the pack lives by: a link to a file that has not been
# written yet is a small lie. The sub-skills arrive over several releases, and
# the router names the ones that are coming without pretending they are here.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "every relative markdown link resolves to a real file" {
  run python3 - "$REPO" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
broken = []
for md in sorted(root.rglob('*.md')):
    if '.git' in md.parts:
        continue
    text = md.read_text(encoding='utf-8')
    for link in re.findall(r'\]\((?!https?://|mailto:|#)([^)#]+)', text):
        target = (md.parent / link.strip()).resolve()
        if not target.exists():
            broken.append(f"{md.relative_to(root)} -> {link}")

if broken:
    print("broken relative links:")
    for entry in broken:
        print(f"  {entry}")
    sys.exit(1)
print("all relative links resolve")
PY
  [ "$status" -eq 0 ] || {
    echo "$output"
    return 1
  }
}

@test "no markdown file links to a sub-skill that does not exist yet" {
  # The complement of the test above, stated as intent: forward references are
  # named in prose, never linked. When a sub-skill lands, its task turns the
  # code span into a link and this stays green either way.
  for skill in implement consume validate publish-status setup; do
    if [ ! -f "$REPO/$skill/SKILL.md" ]; then
      ! grep -rq "]($skill/SKILL.md)" "$REPO"/*.md || {
        echo "$skill/SKILL.md is linked but not present"
        return 1
      }
    fi
  done
}
