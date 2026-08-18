# Handing the adoption to the methodology the team already uses

A team that practises spec-driven development has tooling they trust and
reviewers who read its artifacts. The second-worst thing this pack could do
is ask them to adopt our methodology to adopt our protocol; the worst is
planning next to theirs, so the repository ends up with two plans. So when
the adopter answers the methodology question with *yes* — a registry entry
they confirmed, or one they declared in three answers — the pack stops being
a planner and becomes a **briefing**.

## Emit the bundle

```bash
node bin/render-handover.mjs \
  --stack-guide implement/stacks/<guide>.md \
  --publisher-id <id> --target <L1|L2|L3> \
  --manifest-url https://<origin>/.well-known/cabuya.json \
  --feed-path <path> [--include-l3] [--out CABUYA_CONTEXT.md]
```

Arguments come from the same places as the DWP renderer's
([`../render-dwp.md`](../render-dwp.md) has the table). The bundle contains
the ordered tasks with acceptance criteria, validation commands and stop
conditions; the four non-negotiables that ride with any plan; the ledger
contract; and a fenced JSON block for tooling. Plain Markdown — no format of
theirs to learn, none of ours to teach.

## Then hand it over, and stop planning

Name the methodology's own entry command — from
[`../../plan/methodologies.json`](../../plan/methodologies.json) for a known
one, or the command the adopter gave you for one the registry has never
heard of. For an unknown methodology, say plainly that you are following the
adopter's instructions, not a built-in integration.

Give the bundle to that command as its input (most methodologies take a spec
document; this is one). From here the methodology owns the plan, its
artifacts and its review flow.

## What the pack still does

Two things, and only these:

1. **Reads the trail.** The bundle asks the foreign plan to record each task
   in `.cabuya/adoption.json` — that is how `/cabuya` resumes, reports, and
   never re-asks, whatever tool did the work.
2. **Measures the result.** When their plan finishes, `/cabuya validate`
   against the live URL is still the only thing that decides the level, and
   `last_measured` records it with the report digest.

The methodology owns the *how*; the validator owns the *whether*.
