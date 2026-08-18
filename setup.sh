#!/usr/bin/env bash
#
# setup.sh — link the Cabuya pack and its sub-skills into your agent(s).
#
# The pack is just files; this script makes them discoverable. It creates
# symlinks, so the installed copy and the repository stay the same thing —
# `git pull` updates every agent at once, and there is one copy to audit
# rather than six.
#
#   bash setup.sh                  # detect installed agents and link into each
#   bash setup.sh --host claude    # one agent, explicitly
#   bash setup.sh --host all       # every known agent, whether detected or not
#   bash setup.sh --dry-run        # print what would happen, change nothing
#   bash setup.sh --verify         # verify the vendored spec and exit
#   bash setup.sh --help
#
# It is idempotent: run it as often as you like. It refuses to replace a real
# file or directory — only its own symlinks — because the thing sitting at
# ~/.claude/skills/cabuya might be somebody's work.
#
# Bash 3.2 compatible (macOS default): no associative arrays, no `mapfile`,
# no `${var^^}`, and no expansion of a possibly-empty array under `set -u`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACK_NAME="cabuya"

# The pack root is this repository root — SKILL.md sits beside this script.
PACK_DIR="$SCRIPT_DIR"

# Sub-skills, in the order the router lists them. A directory with no SKILL.md
# is skipped rather than linked: the pack is built in stages, and a symlink to
# a skill that does not exist yet is worse than no symlink.
SUBSKILLS="adopt explain implement consume validate publish-status setup"

DRY_RUN="no"
HOST=""

# --- helpers -----------------------------------------------------------------

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Link the Cabuya skill pack into your AI coding agent(s).

Usage:
  bash setup.sh [--host <agent>] [--dry-run]
  bash setup.sh --verify
  bash setup.sh --help

Options:
  --host <agent>  claude | cursor | codex | windsurf | copilot | cline |
                  gemini | opencode | openclaw | antigravity | auto | all
                  Default: auto (link into every agent found on this machine).
  --dry-run       Print what would be linked; change nothing.
  --verify        Verify the vendored specification against CHECKSUMS.txt.
  --help, -h      This text.

What it creates, per agent:
  <skills dir>/cabuya                  -> the pack (the router)
  <skills dir>/cabuya-implement        -> implement/
  <skills dir>/cabuya-consume          -> consume/
  <skills dir>/cabuya-validate         -> validate/
  <skills dir>/cabuya-publish-status   -> publish-status/
  <skills dir>/cabuya-setup            -> setup/

Symlinks, not copies: `git pull` updates every agent at once. Existing real
files are never replaced — those are reported and skipped.
USAGE
}

# Where each agent looks for skills.
resolve_skills_dir() {
  case "$1" in
    claude)      printf '%s\n' "$HOME/.claude/skills" ;;
    cursor)      printf '%s\n' "$HOME/.cursor/skills" ;;
    codex)       printf '%s\n' "$HOME/.codex/skills" ;;
    windsurf)    printf '%s\n' "$HOME/.codeium/windsurf/skills" ;;
    copilot)     printf '%s\n' "$HOME/.copilot/skills" ;;
    cline)       printf '%s\n' "$HOME/.cline/skills" ;;
    gemini)      printf '%s\n' "$HOME/.gemini/skills" ;;
    opencode)    printf '%s\n' "$HOME/.config/opencode/skills" ;;
    openclaw)    printf '%s\n' "$HOME/.openclaw/skills" ;;
    antigravity) printf '%s\n' "$HOME/.antigravity/skills" ;;
    *)           printf '%s\n' "" ;;
  esac
}

ALL_AGENTS="claude cursor codex windsurf copilot cline gemini opencode openclaw antigravity"

# Which of them are actually on this machine. Printed one per line; the caller
# reads it with a `while read` loop rather than an array, so an empty result is
# an empty loop instead of a bash 3.2 unbound-variable error.
detect_agents() {
  for agent in $ALL_AGENTS; do
    dir="$(resolve_skills_dir "$agent")"
    # The parent config dir, not the skills dir: an agent that has never
    # installed a skill still has no skills/ directory, and it is still here.
    parent="$(dirname "$dir")"
    if [ -d "$parent" ]; then
      printf '%s\n' "$agent"
    fi
  done
}

# One symlink. Reports what it did, and refuses to clobber anything real.
link_one() {
  target="$1"
  destination="$2"
  label="$3"

  if [ -e "$destination" ] && [ ! -L "$destination" ]; then
    say "  ! $label — a real file or directory is already there; skipped"
    return 0
  fi

  if [ "$DRY_RUN" = "yes" ]; then
    say "  · $label -> $target (dry run)"
    return 0
  fi

  ln -snf "$target" "$destination"
  say "  ✓ $label"
}

link_agent() {
  agent="$1"
  skills_dir="$(resolve_skills_dir "$agent")"
  if [ -z "$skills_dir" ]; then
    say "Unknown agent: $agent" >&2
    say "Known: $ALL_AGENTS" >&2
    return 1
  fi

  say "[$agent] $skills_dir"

  if [ "$DRY_RUN" = "no" ]; then
    mkdir -p "$skills_dir"
  fi

  # The router. If the repo was cloned directly into the skills directory,
  # there is nothing to link — it is already where the agent looks.
  if [ "$PACK_DIR" = "$skills_dir/$PACK_NAME" ]; then
    say "  ✓ $PACK_NAME (cloned in place)"
  else
    link_one "$PACK_DIR" "$skills_dir/$PACK_NAME" "$PACK_NAME"
  fi

  for skill in $SUBSKILLS; do
    if [ -f "$PACK_DIR/$skill/SKILL.md" ]; then
      link_one "$PACK_DIR/$skill" "$skills_dir/$PACK_NAME-$skill" "$PACK_NAME-$skill"
    else
      say "  · $PACK_NAME-$skill — not in this version; skipped"
    fi
  done

  say ""
}

# --- flags -------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      { [ $# -ge 2 ] && [ -n "${2:-}" ]; } || die "Missing value for --host"
      HOST="$2"; shift 2 ;;
    --host=*) HOST="${1#--host=}"; shift ;;
    --dry-run) DRY_RUN="yes"; shift ;;
    --verify) exec bash "$SCRIPT_DIR/scripts/verify-integrity.sh" ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
done

# --- run ---------------------------------------------------------------------

[ -f "$PACK_DIR/SKILL.md" ] || die \
  "No SKILL.md at $PACK_DIR — run this from the root of the cabuya-skill repository."

say "Cabuya skill pack"
say "Pack: $PACK_DIR"
[ "$DRY_RUN" = "yes" ] && say "Dry run — nothing will be written."
say ""

if [ -n "$HOST" ] && [ "$HOST" != "auto" ]; then
  if [ "$HOST" = "all" ]; then
    for agent in $ALL_AGENTS; do
      link_agent "$agent"
    done
  else
    link_agent "$HOST"
  fi
else
  found="no"
  while IFS= read -r agent; do
    [ -n "$agent" ] || continue
    found="yes"
    link_agent "$agent"
  done <<EOF
$(detect_agents)
EOF

  if [ "$found" = "no" ]; then
    say "No agent found on this machine."
    say ""
    say "Either name one — bash setup.sh --host claude — or link the pack"
    say "yourself: your agent's skills directory, a symlink to $PACK_DIR."
    say "Run with --host all to link every known agent regardless."
    exit 0
  fi
fi

say "Done."
say ""
say "Ask your agent \"what is Cabuya?\" — the explain sub-skill answers it,"
say "from the vendored specification, with citations and no network."
