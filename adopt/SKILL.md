---
name: cabuya-adopt
description: >
  The front door. One sentence — "adopt Cabuya" — and the agent orients,
  explains what implementing the protocol means in this repository, asks who
  should plan the work (the team's own spec-driven methodology, DeepWorkPlan,
  or the agent's own plan mode), and hands off to the right path. Resumes an
  adoption that is already underway without re-asking anything recorded. Use
  when a developer says "adopt Cabuya", "adopta el protocolo", "quiero
  implementar Cabuya desde cero", "get us started", or invokes the pack with
  no more specific intent.
version: "0.1.0"
documentation_url: https://cabuya.org/developers/skill
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# Adopt: one sentence, and the right path

This sub-skill writes no feed, no manifest and no code. It does four things —
orient, ask, choose a path, hand off — and its whole value is doing them in
that order. The procedures live in the other sub-skills; the plan lives in
[`../plan/tasks.json`](../plan/tasks.json); this file decides **who plans**.

The order below is a precedence rule, not a suggestion:

> **Resume what exists → the adopter's own methodology → DeepWorkPlan if
> installed → offer to install it → the agent's own plan mode.**
>
> The adopter's tooling is never displaced by ours. We ask before we propose.

## Step 1 · Orient — before any question

Run both, from the pack root:

```bash
bash shared/context.sh
bash shared/detect-planning.sh
```

Read [`../plan/tasks.json`](../plan/tasks.json), and — if the ledger exists —
`.cabuya/adoption.json` ([`../plan/LEDGER.md`](../plan/LEDGER.md)).

Then say, in one block and in plain language, **what implementing Cabuya
means in this repository**: the stack and framework that were detected, which
files and endpoints the matched stack guide (`implement/stacks/`) says this
will touch, where the manifest will be served from, the one human decision
that is coming (the PII gate), and — from the ledger — the last measured
level (or `unmeasured`) and the next task not yet done.

End the block with two doors:

> Ask me anything about the protocol first, or say **go**.

"Anything about the protocol" is answered from the vendored spec — start at
[`../spec/PROTOCOL_SUMMARY.md`](../spec/PROTOCOL_SUMMARY.md) and cite the
section you answer from. Never answer from memory of what a protocol like
this probably says.

## Step 2 · Resume — never re-ask what is written

If `detect-planning.sh` reported an existing plan or a ledger with recorded
answers, this is a resume, not a start:

- **A plan already at `.dwp/plans/PLAN_cabuya_adoption/`** → point at it and
  continue it. **Never regenerate or overwrite it** — it may contain completed
  work and human decisions.
- **A recorded `methodology`** → that answer stands. Do not ask again.
- **A recorded `pii_decision`** → decided. Do not re-open it unless the
  columns that travel have changed — then it is a new decision about the new
  columns, not a re-ask of the old one.
- **`ledger_newer_major: true`** → the ledger was written by a newer contract
  than this pack knows. **Read it and explain it; never write to it.** Suggest
  updating the pack.
- **The ledger's `publisher_id` differs from the manifest's** → two different
  claims about who publishes here. Stop and ask which is right; never pick.

## Step 3 · The question that outranks our preferences

Asked once, recorded once, in the ledger's `methodology` object:

> **Do you already have a spec-driven development methodology?**

- If `detect-planning.sh` found candidates, ask by the name the registry
  gives them, as a confirmation: "I found *marker* — do you plan work with
  *name*?" The marker is evidence; **the human confirms**. A detected
  methodology the human denies is dropped without argument.
- The known ids and markers live in
  [`../plan/methodologies.json`](../plan/methodologies.json) — data, not
  code, so a methodology this file has never heard of is a normal answer, not
  an error. When the adopter names one that is not listed, ask three short
  questions: **what is it called · what command starts a plan · where do its
  specs live** — record the answers (`source: "declared"`), and say plainly
  that you are following the adopter's instructions, not a built-in
  integration.

**If the answer is yes** — hand the whole context to that methodology and get
out of the way: emit the bundle per [`handover/README.md`](handover/README.md)
(`bin/render-handover.mjs` — the ordered tasks with acceptance criteria,
validation commands and stop conditions, the four non-negotiables that ride
with any plan, and the ledger contract so their plan still writes
`.cabuya/adoption.json` after each task). Then name their entry command and
stop planning.

**If the answer is no** — continue to Step 4.

## Step 4 · DeepWorkPlan, offered — never required

`detect-planning.sh` already answered `dwp_installed`.

- **Installed** → say so, render the adoption as a DeepWorkPlan following
  [`render-dwp.md`](render-dwp.md) (`bin/render-dwp.mjs` — deterministic,
  refuses to overwrite, refuses unfilled placeholders), and hand off naming
  the exact command: `/dwp-execute cabuya_adoption`.
- **Not installed** → one line, one offer, once:

  > The work comes out better with DeepWorkPlan: the plan lands on disk as
  > task files you can review in a pull request, each with its own validation,
  > and it survives across sessions. Shall I install it and run its
  > onboarding?

  If **yes**: install it, run its own `onboard` sub-skill so the repository is
  ready for the plan rather than one the plan has to work around, then render
  and hand off as above.

  If **no**: Step 5, with no second pitch. Record the answer
  (`source: "plan_mode"`); asking again next session is a re-ask, and the
  ledger exists so you never do that.

## Step 5 · The agent's own plan mode

Nobody has to install a planning framework to publish a JSON file. Follow
[`plan-mode.md`](plan-mode.md): enter your own planning mode over the same
task sequence, write nothing while planning, execute one task at a time
recording each in the ledger, and stop at `pii_gate` for the human. It
carries the one honest sentence about the difference, and the upgrade path —
installing DeepWorkPlan later renders the remaining tasks with the completed
ones already marked, because the ledger, not the session, is where the
progress lives.

## Every path ends the same way

Whoever planned it, one command still decides what is true:

```bash
bash bin/run-validator.sh validate <manifest-url> --format json
```

The methodology owns the *how*; the validator owns the *whether*. Record the
measured result in the ledger's `last_measured` (via
[`../bin/check-ledger.mjs`](../bin/check-ledger.mjs) to confirm the write),
and report it in the validator's words.

## What this sub-skill will not do

- Duplicate a procedure. Mapping, the PII gate, serializing, validating and
  publishing live in their own sub-skills, and this file routes to them.
- Record a methodology, a DWP answer or a PII decision the human did not give.
- Regenerate an existing plan, or write to a ledger from a newer contract.
- Plan anything for a team that told it who plans.
