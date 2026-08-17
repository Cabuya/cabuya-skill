#!/usr/bin/env bats
#
# The installer touches the developer's home directory, which is the one place
# a skill pack can do real damage. These tests run it against a temporary HOME
# and a temporary copy of the pack, so what is asserted is the behaviour, not
# the current state of the repository — the sub-skills arrive over several
# releases, and a test that breaks when one lands is a test that gets deleted.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  export HOME="$TMP/home"
  mkdir -p "$HOME"

  # A pack with every sub-skill present, so the linking logic is exercised in
  # full regardless of which ones the real repository currently ships.
  PACK="$TMP/pack"
  mkdir -p "$PACK"
  cp "$REPO_ROOT/setup.sh" "$PACK/setup.sh"
  cp "$REPO_ROOT/SKILL.md" "$PACK/SKILL.md"
  mkdir -p "$PACK/scripts"
  cp "$REPO_ROOT/scripts/verify-integrity.sh" "$PACK/scripts/"
  for skill in implement consume validate publish-status setup; do
    mkdir -p "$PACK/$skill"
    printf -- '---\nname: cabuya-%s\n---\n' "$skill" > "$PACK/$skill/SKILL.md"
  done
}

teardown() {
  rm -rf "$TMP"
}

@test "--help explains itself and exits clean" {
  run bash "$PACK/setup.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--host"* ]]
  [[ "$output" == *"cabuya-implement"* ]]
  # The warning that matters: symlinks, not copies.
  [[ "$output" == *"Symlinks, not copies"* ]]
}

@test "--host claude links the router and all five sub-skills" {
  run bash "$PACK/setup.sh" --host claude
  [ "$status" -eq 0 ]

  [ -L "$HOME/.claude/skills/cabuya" ]
  for skill in implement consume validate publish-status setup; do
    [ -L "$HOME/.claude/skills/cabuya-$skill" ]
    [ -f "$HOME/.claude/skills/cabuya-$skill/SKILL.md" ]
  done
}

@test "--host cursor links into cursor's directory, not claude's" {
  run bash "$PACK/setup.sh" --host cursor
  [ "$status" -eq 0 ]
  [ -L "$HOME/.cursor/skills/cabuya" ]
  [ ! -e "$HOME/.claude/skills/cabuya" ]
}

@test "running it twice changes nothing and fails nothing" {
  run bash "$PACK/setup.sh" --host claude
  [ "$status" -eq 0 ]
  first="$(readlink "$HOME/.claude/skills/cabuya-implement")"

  run bash "$PACK/setup.sh" --host claude
  [ "$status" -eq 0 ]
  second="$(readlink "$HOME/.claude/skills/cabuya-implement")"

  [ "$first" = "$second" ]
}

@test "it refuses to replace a real directory somebody else put there" {
  mkdir -p "$HOME/.claude/skills/cabuya-implement"
  printf 'somebody was working here\n' > "$HOME/.claude/skills/cabuya-implement/notes.md"

  run bash "$PACK/setup.sh" --host claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"a real file or directory is already there"* ]]

  # Still theirs, still intact.
  [ ! -L "$HOME/.claude/skills/cabuya-implement" ]
  [ -f "$HOME/.claude/skills/cabuya-implement/notes.md" ]
}

@test "--dry-run writes nothing at all" {
  run bash "$PACK/setup.sh" --host claude --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run"* ]]
  [ ! -e "$HOME/.claude/skills/cabuya" ]
}

@test "an unknown --host is an error, not a silent no-op" {
  run bash "$PACK/setup.sh" --host emacs
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown agent"* ]]
}

@test "an unknown flag is rejected rather than ignored" {
  run bash "$PACK/setup.sh" --hosts claude
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "--host with no value fails instead of defaulting" {
  run bash "$PACK/setup.sh" --host
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing value"* ]]
}

@test "auto-detect says so plainly when no agent is installed" {
  run bash "$PACK/setup.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No agent found"* ]]
  [[ "$output" == *"--host all"* ]]
}

@test "auto-detect finds an agent by its config directory" {
  mkdir -p "$HOME/.cursor"
  run bash "$PACK/setup.sh"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.cursor/skills/cabuya" ]
}

@test "a sub-skill this version does not ship is reported, not linked" {
  rm -rf "$PACK/consume"
  run bash "$PACK/setup.sh" --host claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"cabuya-consume — not in this version"* ]]
  [ ! -e "$HOME/.claude/skills/cabuya-consume" ]
}

@test "it refuses to run from outside the pack" {
  cp "$PACK/setup.sh" "$TMP/stray-setup.sh"
  run bash "$TMP/stray-setup.sh" --host claude
  [ "$status" -ne 0 ]
  [[ "$output" == *"No SKILL.md"* ]]
}
