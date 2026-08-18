# Rendering the adoption as a DeepWorkPlan

The mechanical half of the DWP path lives in a script; this file is the
judgement half — where each argument comes from, and what to do before and
after running it.

## Why a script

The DWP anatomy is exact — a README with checkbox links, one
`N.task_{id}.md` per task with its required sections, `PROGRESS.md`,
`analysis_results/` — and an agent re-typing that per adoption would drift.
`bin/render-dwp.mjs` produces it deterministically from
[`../plan/tasks.json`](../plan/tasks.json) and the templates in
[`templates/dwp/`](templates/dwp/), and refuses to ship an unfilled
placeholder. What it cannot know, you pass in — and every argument is an
answer you already have by the time you are here.

## The arguments, and where each comes from

| Argument | Source |
|---|---|
| `--repo` | `repo_root` from `shared/context.sh` |
| `--stack`, `--framework` | same |
| `--stack-guide` | the guide `implement/SKILL.md` Phase 0 matched — confirm it against `shared/stack-detection.md`, do not pass a guess |
| `--publisher-id` | the adopter's registry token; ask if none exists yet |
| `--target` | the level the adopter is aiming at (an aim, never a claim) |
| `--manifest-url` | the deployed URL where `/.well-known/cabuya.json` will live — ask; the production origin is known even before anything is deployed |
| `--feed-path` | where the feed file will live, from the stack guide |
| `--include-l3` | only when the adopter said they want to consume peers; otherwise the plan lists it as a follow-up |

## Run it

```bash
node bin/render-dwp.mjs --repo <repo_root> \
  --stack-guide implement/stacks/<guide>.md \
  --publisher-id <id> --target L2 \
  --manifest-url https://<origin>/.well-known/cabuya.json \
  --feed-path <path> [--include-l3]
```

Exit 2 means a `PLAN_cabuya_adoption` already exists — that is a **resume**,
never a re-render; the script will not overwrite it and neither will you.
Exit 3 is a missing argument: go get the answer, do not invent one.

## After rendering

1. Show the adopter the plan's README — it is short, and it is theirs now.
2. Write the render into the ledger: `methodology: {id: "deepworkplan",
   source: "dwp"}` if it was not already recorded, and verify with
   `node bin/check-ledger.mjs .cabuya/adoption.json`.
3. Hand off with the exact command: **`/dwp-execute cabuya_adoption`**.

The plan is now the adopter's artifact, reviewable in a pull request like any
other file. The pack's job resumes when a task routes back into a sub-skill —
and at the PII gate, where the plan stops for a human no matter who rendered
it.
