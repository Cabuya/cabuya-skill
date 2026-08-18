# Plan mode: the adoption without DeepWorkPlan

You — the agent — are reading this because the adopter has no spec-driven
methodology and declined DeepWorkPlan. Both were their call to make. Say the
one honest sentence about what that means — **the decisions will survive in
the ledger; the task detail lives in this session** — once, at the start, and
then do not mention it again. This path is lighter, not improvised: you are
being handed a plan to adopt, not asked to invent one.

## The protocol

1. **Enter your planning mode.** In Claude Code that is plan mode; in other
   hosts, whatever holds a plan for approval before execution. If your host
   has none, write the plan as a message and ask for an explicit yes.
   **Write nothing to the repository while planning.**
2. **Build the plan from [`../plan/tasks.json`](../plan/tasks.json)** — the
   ordered tasks below, each with its goal, acceptance criteria, validation
   command and stop conditions, instantiated for this stack from the guide
   that `implement/SKILL.md` Phase 0 matched. Resolve the spec's placeholders
   (`{stack_guide}`, `{feed_path}`, `{manifest_url}`, `{target_level}`) from
   `shared/context.sh` and the adopter's answers before presenting anything.
3. **Present it for approval** the way your host does. Then execute **one
   task at a time**: do the work by the sub-skill the task's `reads` points
   at, run the task's validation, record the step in `.cabuya/adoption.json`
   (verify with `node bin/check-ledger.mjs .cabuya/adoption.json`), move on.
4. **Stop at `pii_gate` and ask the human.** Present the deny-list table and
   wait for an explicit yes naming the specific columns. The ledger accepts
   only `decided_by: "human"` — there is nothing an agent could honestly
   write there, and that is the point.
5. **On any validator PII finding, halt** and ask. Never resolve one by
   editing the deny-list, renaming a field, or moving the value into an
   `x_*` extension.

## The sequence

The ids below are `plan/tasks.json` in order — the test suite fails this file
if they drift. Read each task's full entry there; this list is what plan mode
needs to know about the shape:

1. `read_and_detect` — write nothing; two stop conditions can end the
   adoption honestly right here.
2. `map` — the crosswalk goes in front of the human before any code.
3. `pii_gate` — **the hard stop.** The one decision that is never yours.
4. `serialize` — envelope first; never invent data.
5. `serve` — the manifest, the catch-all, the soft-404 trap.
6. `validate_loop` — at most 8 iterations; parse the JSON, never the text.
7. `publish_status` — the target never exceeds the measured level.
8. `registry_pr` — only with the human's yes.
9. `consume_peers` — optional; only when the adopter wants L3.
10. `handoff` — `CABUYA.md` in the repo; the level in the validator's words.
11. `pii_audit` — the deny patterns over everything this adoption created.
12. `report` — every claim traces to the ledger or the validator report.

## Resume

Re-entering this path reads `.cabuya/adoption.json` first: report what is
done, then rebuild the plan **from the first step that is not**. A recorded
`methodology`, DWP answer or `pii_decision` is never re-asked — if the ledger
holds it, it happened.

## The upgrade stays open

Choosing this path is not a dead end. If the adopter installs DeepWorkPlan at
any point, render the remaining work with
[`render-dwp.md`](render-dwp.md) — the renderer reads the same spec, and the
ledger's `steps` say which tasks are already done, so the rendered plan
arrives with the completed ones marked. **The ledger is the transfer**: no
session memory is needed, because nothing that matters lives only in a
session.
