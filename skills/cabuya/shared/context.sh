#!/usr/bin/env bash
#
# context.sh — what repository am I in, and what is it built with?
#
# Every sub-skill starts here. It emits one line of JSON so an agent can read
# it without parsing prose, and so a human can read it without running an
# agent.
#
#   bash shared/context.sh
#   {"repo":"aqui-ayuda","repo_root":"/w/aqui","branch":"main",
#    "agent_tool":"claude-code","stack":"node","framework":"nextjs",
#    "manifest_path":"/w/aqui/public/.well-known/cabuya.json","spec_version":"0.1"}
#
# Contract:
#   repo          repo name from `git remote get-url origin`, else the
#                 basename of repo_root.
#   repo_root     git toplevel if there is one, else $PWD.
#   branch        current branch, or "unknown" outside a work tree.
#   agent_tool    the coding agent in use, from vendor env vars.
#                 CABUYA_AGENT_TOOL overrides.
#   stack         node | python | php | ruby | go | rust | static | unknown
#   framework     a best guess, or "unknown". Deliberately shallow — the real
#                 detection heuristics live in shared/stack-detection.md, and
#                 this value is a hint for the first question, never a decision.
#   manifest_path where /.well-known/cabuya.json would be served from, given
#                 the framework. A path, not a promise that it exists.
#   spec_version  the protocol MINOR this pack implements.
#
# Overrides, all honoured before detection: CABUYA_AGENT_TOOL, CABUYA_STACK,
# CABUYA_FRAMEWORK, CABUYA_MANIFEST_PATH.
#
# If this script will not run at all, nothing is lost — every field is
# something you can answer yourself, and a sub-skill will ask you rather than
# refuse to continue.
#
# Bash 3.2 compatible (macOS default): no associative arrays, no `mapfile`,
# no `${var^^}`.

set -euo pipefail

SPEC_VERSION="0.1"

# --- repository --------------------------------------------------------------

REPO_ROOT=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || printf '')"
fi
[ -n "$REPO_ROOT" ] || REPO_ROOT="$PWD"

REPO=""
REMOTE="$(git remote get-url origin 2>/dev/null || printf '')"
if [ -n "$REMOTE" ]; then
  REPO="${REMOTE##*/}"
  REPO="${REPO%.git}"
fi
[ -n "$REPO" ] || REPO="$(basename "$REPO_ROOT")"

BRANCH="$(git branch --show-current 2>/dev/null || printf '')"
[ -n "$BRANCH" ] || BRANCH="unknown"

# --- agent -------------------------------------------------------------------

AGENT_TOOL="unknown"
if [ -n "${CABUYA_AGENT_TOOL:-}" ]; then
  AGENT_TOOL="$CABUYA_AGENT_TOOL"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}${CLAUDECODE:-}" ]; then
  AGENT_TOOL="claude-code"
elif [ -n "${CODEX_SESSION_ID:-}${CODEX_HOME:-}" ]; then
  AGENT_TOOL="codex-cli"
elif [ -n "${CURSOR_SESSION_ID:-}${CURSOR_TRACE_ID:-}" ]; then
  AGENT_TOOL="cursor"
elif [ -n "${OPENCLAW_SESSION:-}" ]; then
  AGENT_TOOL="openclaw"
elif [ -n "${GEMINI_SESSION_ID:-}" ]; then
  AGENT_TOOL="gemini-cli"
elif [ -n "${WINDSURF_SESSION_ID:-}" ]; then
  AGENT_TOOL="windsurf"
fi

# --- stack and framework -----------------------------------------------------
#
# Shallow on purpose. A wrong guess that looks confident is worse than
# "unknown", so this checks for files that mean one thing and stops there.

exists() { [ -e "$REPO_ROOT/$1" ]; }

STACK="unknown"
FRAMEWORK="unknown"

if exists package.json; then
  STACK="node"
  if exists next.config.js || exists next.config.mjs || exists next.config.ts; then
    FRAMEWORK="nextjs"
  elif exists astro.config.mjs || exists astro.config.ts; then
    FRAMEWORK="astro"
  elif exists nuxt.config.ts || exists nuxt.config.js; then
    FRAMEWORK="nuxt"
  elif exists remix.config.js; then
    FRAMEWORK="remix"
  elif exists svelte.config.js; then
    FRAMEWORK="sveltekit"
  elif exists vite.config.ts || exists vite.config.js; then
    FRAMEWORK="vite"
  elif exists firebase.json; then
    FRAMEWORK="firebase"
  elif grep -q '"express"' "$REPO_ROOT/package.json" 2>/dev/null; then
    FRAMEWORK="express"
  fi
elif exists manage.py; then
  STACK="python"; FRAMEWORK="django"
elif exists pyproject.toml || exists requirements.txt; then
  STACK="python"
elif exists artisan; then
  STACK="php"; FRAMEWORK="laravel"
elif exists composer.json; then
  STACK="php"
elif exists Gemfile; then
  STACK="ruby"
  exists config/application.rb && FRAMEWORK="rails"
elif exists go.mod; then
  STACK="go"
elif exists Cargo.toml; then
  STACK="rust"
elif exists index.html; then
  STACK="static"
fi

[ -n "${CABUYA_STACK:-}" ] && STACK="$CABUYA_STACK"
[ -n "${CABUYA_FRAMEWORK:-}" ] && FRAMEWORK="$CABUYA_FRAMEWORK"

# --- where the manifest is served from ---------------------------------------
#
# The protocol requires /.well-known/cabuya.json at the site root. Which
# directory produces that URL depends on the framework, and getting it wrong
# is the single most common reason a first feed 404s.

case "$FRAMEWORK" in
  nextjs|astro|nuxt|sveltekit|vite|remix|firebase|express)
    MANIFEST_PATH="$REPO_ROOT/public/.well-known/cabuya.json" ;;
  django)
    MANIFEST_PATH="$REPO_ROOT/static/.well-known/cabuya.json" ;;
  laravel)
    MANIFEST_PATH="$REPO_ROOT/public/.well-known/cabuya.json" ;;
  rails)
    MANIFEST_PATH="$REPO_ROOT/public/.well-known/cabuya.json" ;;
  *)
    MANIFEST_PATH="$REPO_ROOT/.well-known/cabuya.json" ;;
esac

[ -n "${CABUYA_MANIFEST_PATH:-}" ] && MANIFEST_PATH="$CABUYA_MANIFEST_PATH"

# --- output ------------------------------------------------------------------
#
# Escaped properly rather than assumed safe. A checkout under a directory with
# an apostrophe in it, or a branch named with a backslash, would otherwise emit
# JSON that does not parse — and the consumer of this line is a program.

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g'
}

printf '{"repo":"%s","repo_root":"%s","branch":"%s","agent_tool":"%s","stack":"%s","framework":"%s","manifest_path":"%s","spec_version":"%s"}\n' \
  "$(json_escape "$REPO")" \
  "$(json_escape "$REPO_ROOT")" \
  "$(json_escape "$BRANCH")" \
  "$(json_escape "$AGENT_TOOL")" \
  "$(json_escape "$STACK")" \
  "$(json_escape "$FRAMEWORK")" \
  "$(json_escape "$MANIFEST_PATH")" \
  "$SPEC_VERSION"
