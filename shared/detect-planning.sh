#!/usr/bin/env bash
#
# detect-planning.sh — who could plan this adoption, and what is already here?
#
# The adopt flow starts by asking one question: do you already have a
# spec-driven development methodology? This script gathers the evidence that
# question is asked WITH — an installed DeepWorkPlan, the markers of other
# methodologies, an existing ledger, an existing plan — and emits one line of
# JSON, like shared/context.sh.
#
#   bash shared/detect-planning.sh
#   {"dwp_installed":true,"dwp_path":".agents/skills/deepworkplan",
#    "candidates":["github-spec-kit"],"ledger":"present",
#    "ledger_contract":"1.0","ledger_newer_major":false,
#    "methodology_recorded":"deepworkplan","pii_decided":"true",
#    "plan_present":false,"plan_path":""}
#
# Contract:
#   dwp_installed        deepworkplan found at a repo- or user-level skills path.
#   candidates           methodology ids whose markers exist in this repo, from
#                        plan/methodologies.json — the ONLY place any
#                        methodology is named. Evidence for a question, never a
#                        decision: the human confirms.
#   ledger               present | absent — .cabuya/adoption.json.
#   ledger_contract      its contract string, or "" when unreadable.
#   ledger_newer_major   true when the contract major is newer than this pack
#                        knows: then READ AND EXPLAIN, NEVER WRITE.
#   methodology_recorded the recorded methodology id/name, or "none". A
#                        recorded answer is never re-asked.
#   pii_decided          whether the one human decision is already on record.
#   plan_present         a PLAN_cabuya_adoption already rendered in .dwp/plans/.
#
# Reading the ledger and the registry needs node (the pack requires it
# anyway); without node those fields degrade to "unknown" and the adopt flow
# asks instead of guessing.
#
# Bash 3.2 compatible: no associative arrays, no mapfile, no ${var^^}.

set -euo pipefail

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KNOWN_MAJOR="1"

REPO_ROOT=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || printf '')"
fi
[ -n "$REPO_ROOT" ] || REPO_ROOT="$PWD"

# --- DeepWorkPlan ------------------------------------------------------------

DWP_INSTALLED="false"
DWP_PATH=""
for candidate in \
  "$REPO_ROOT/.agents/skills/deepworkplan" \
  "$REPO_ROOT/.claude/skills/deepworkplan" \
  "$HOME/.agents/skills/deepworkplan" \
  "$HOME/.claude/skills/deepworkplan"; do
  if [ -d "$candidate" ]; then
    DWP_INSTALLED="true"
    DWP_PATH="$candidate"
    break
  fi
done

# --- methodology markers, from the registry ----------------------------------
#
# The registry is data so that adding a methodology is a JSON entry. This
# script therefore reads ids and markers from it rather than knowing any name.

CANDIDATES="[]"
if command -v node >/dev/null 2>&1 && [ -f "$PACK_ROOT/plan/methodologies.json" ]; then
  CANDIDATES="$(node -e '
    const { existsSync } = require("fs");
    const { join } = require("path");
    const root = process.argv[1];
    const registry = require(process.argv[2]);
    const hits = registry.methodologies
      .filter((m) => m.markers.some((marker) => existsSync(join(root, marker))))
      .map((m) => m.id);
    process.stdout.write(JSON.stringify(hits));
  ' "$REPO_ROOT" "$PACK_ROOT/plan/methodologies.json" 2>/dev/null || printf '[]')"
fi

# --- the ledger --------------------------------------------------------------

LEDGER_FILE="$REPO_ROOT/.cabuya/adoption.json"
LEDGER="absent"
LEDGER_CONTRACT=""
LEDGER_NEWER_MAJOR="false"
METHODOLOGY_RECORDED="none"
PII_DECIDED="false"

if [ -f "$LEDGER_FILE" ]; then
  LEDGER="present"
  if command -v node >/dev/null 2>&1; then
    LEDGER_FACTS="$(node -e '
      const ledger = require(process.argv[1]);
      const contract = String(ledger.contract ?? "");
      const major = contract.split(".")[0];
      const facts = [
        contract,
        major && Number(major) > Number(process.argv[2]) ? "true" : "false",
        ledger.methodology ? (ledger.methodology.id ?? ledger.methodology.name) : "none",
        ledger.pii_decision && ledger.pii_decision.decided_by === "human" ? "true" : "false",
      ];
      process.stdout.write(facts.join("\t"));
    ' "$LEDGER_FILE" "$KNOWN_MAJOR" 2>/dev/null || printf 'unknown\tfalse\tunknown\tunknown')"
    LEDGER_CONTRACT="$(printf '%s' "$LEDGER_FACTS" | cut -f1)"
    LEDGER_NEWER_MAJOR="$(printf '%s' "$LEDGER_FACTS" | cut -f2)"
    METHODOLOGY_RECORDED="$(printf '%s' "$LEDGER_FACTS" | cut -f3)"
    PII_DECIDED="$(printf '%s' "$LEDGER_FACTS" | cut -f4)"
  else
    LEDGER_CONTRACT="unknown"
    METHODOLOGY_RECORDED="unknown"
    PII_DECIDED="unknown"
  fi
fi

# --- an already-rendered plan ------------------------------------------------

PLAN_PRESENT="false"
PLAN_PATH=""
if [ -d "$REPO_ROOT/.dwp/plans/PLAN_cabuya_adoption" ]; then
  PLAN_PRESENT="true"
  PLAN_PATH="$REPO_ROOT/.dwp/plans/PLAN_cabuya_adoption"
fi

# --- output ------------------------------------------------------------------

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g'
}

printf '{"dwp_installed":%s,"dwp_path":"%s","candidates":%s,"ledger":"%s","ledger_contract":"%s","ledger_newer_major":%s,"methodology_recorded":"%s","pii_decided":"%s","plan_present":%s,"plan_path":"%s"}\n' \
  "$DWP_INSTALLED" \
  "$(json_escape "$DWP_PATH")" \
  "$CANDIDATES" \
  "$LEDGER" \
  "$(json_escape "$LEDGER_CONTRACT")" \
  "$LEDGER_NEWER_MAJOR" \
  "$(json_escape "$METHODOLOGY_RECORDED")" \
  "$PII_DECIDED" \
  "$PLAN_PRESENT" \
  "$(json_escape "$PLAN_PATH")"
