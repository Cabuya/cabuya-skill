---
name: cabuya-validate
description: >
  Run the Cabuya validator against a feed or manifest, parse the JSON report,
  and present the findings grouped by what to do next — blockers for the
  target level first. Use when a developer asks whether their feed conforms,
  why a registry badge is red, wants to check a feed before deploying it, or
  says "valida el feed" / "is my feed conforming?".
version: "0.1.0"
documentation_url: https://cabuya.org/developers/validator
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Validate

Thin by design. This skill resolves a validator, runs it, and reads the
report — it decides nothing about conformance itself, because the whole
protocol rests on conformance being measured rather than declared.

Note the `allowed-tools`: no `Edit`, no `Write`. **Measuring does not change
anything.** Fixing is `implement`'s job, and keeping the two apart is what
makes it safe to run this whenever you want.

## 1. Run it

```bash
bash bin/run-validator.sh validate <target> --format json
```

`<target>` is a manifest URL, a feed URL, or a local file. Add
`--no-network` for a local file, and `--probe-twice` when you need BEH002
(always-now) measured.

[`../shared/validator.md`](../shared/validator.md) has the resolution order and
the flags. Two things from it that decide what you do next:

- **Branch on the exit code before parsing anything.** Exit **3** is a
  transport failure — unreachable, TLS, timeout, non-JSON body. **The data is
  not wrong.** Say so and stop; do not open the serializer.
- **Parse the JSON, never the text.** The human-readable output is written for
  a person and it will change. A skill that greps it breaks silently, in the
  direction that looks like "no findings".

## 2. Read the report

In this order:

1. **`measured_level`** — the only level anybody may state. Not
   `requested_level`. Not your reading of the findings.
2. **`blockers_for_next_level`** — the findings that stand between the app and
   the level it is aiming at.
3. **`summary`** — counts.
4. **`findings`** — each with `pointer`, `message`, `rule`, `fix`, and often a
   `suggested_patch`.
5. **`probes`** — `cors`, `soft_404`, `always_now`. A missing probe result is
   not a pass.

## 3. Present it: grouped by what to do next

Not by severity, and not in the order the validator emitted them. The
difference between a tool that measures and a tool that teaches is whether
somebody knows what to do when it finishes.

```
Measured: L1. Target: L2.

  Fix these 2 and you are L2
  ──────────────────────────────────────────────────────────────
  REC001  /data/places/0/last_confirmed_at
          required property 'last_confirmed_at' is missing
          (did you mean to publish last_confirmed_at: null?)
          → Add "last_confirmed_at": null, or a real confirmation time.

  ENV007  /license
          the envelope has no licence
          → An unlicensed feed does not conform: it blocks every
            consumer's legal review before it starts.

  Worth fixing, not blocking
  ──────────────────────────────────────────────────────────────
  REC014  /data/places/3   no locator (no address_text, no lat/lon)
          → This record is not usable by a consumer.

  For L3, later
  ──────────────────────────────────────────────────────────────
  API001  a read API or live-refreshed feeds with sync signals
  API004  at least one peer feed consumed under the six rules
```

Three findings you must not present as ordinary — see
[`../shared/error-codes.md`](../shared/error-codes.md):

- **`PII*` — stop the loop.** Halt, name the rule, ask a human. Never resolve
  one by editing the deny-list, renaming the field, or moving the value into
  an `x_*` extension. A namespaced field is exactly as non-conforming.
- **`BEH*` — the data is fine.** The fix is deployment or the timestamp
  strategy. Do not send anybody to the mapping.
- **`DSC*` — the JSON is probably perfect.** The manifest is being swallowed by
  a catch-all, and the fix is hosting configuration.

## 4. Say what was measured, and only that

**Report `measured_level` in the validator's words.** Never infer a level from
a clean run, never round up, and never use the word *certified* — there is no
certification, only a published validator and whatever it measured last.

When the report has `"degraded": true`:

> Schema-valid; conformance unmeasured. The behavioural probes — soft-404,
> CORS and always-now — did not run, because there is no validator installed
> and no network. Those three are what catch a manifest that returns your SPA
> shell with a 200.

**Never shorten that to "it validates".** Degraded mode also skips record and
envelope semantics beyond the schema: one of the vendored teaching examples is
genuinely non-conformant and passes degraded mode cleanly. The run prints its
own list of what it did not check — relay it.

## 5. Working before deployment

`--no-network` runs the content passes over a local file, which is how you
check a feed while it is still being written. It is honest about the limit:
the behavioural probes need a deployed URL, so a clean `--no-network` run is
**not** an L2 measurement.

Tell people that plainly. "It passes locally" is the sentence that precedes
discovering the catch-all.

## 6. When the loop is not converging

If `implement` is looping, eight iterations is the ceiling, and it exists
because a loop that has not converged by then has hit something structural —
a mapping decision, a hosting problem, or a question for a human. The ninth
attempt is not the one that finds it.

Stop, summarize what remains, and name what each remaining finding would take.

## What this skill will not do

- Change a file. It has no `Edit` or `Write`.
- State a level the report does not state.
- Report "conforming" from degraded mode.
- Continue past a `PII` finding.
- Retry after exit 5. That is a validator bug; report it.
