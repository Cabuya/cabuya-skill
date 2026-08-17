# The validator, as every sub-skill sees it

One entry point — [`bin/run-validator.sh`](../bin/run-validator.sh) — so that
every sub-skill resolves, invokes and parses the same way. Read this before
writing anything that measures conformance.

## Resolution order

```bash
bash bin/run-validator.sh --which   # what would run, without running it
```

| # | Source | When it fires |
|---|---|---|
| 1 | `$CABUYA_VALIDATOR_BIN` | Air-gapped or pinned environments. |
| 2 | `./node_modules/.bin/cabuya-validator` | The adopter installed it as a dev dependency. |
| 3 | `npx --yes @cabuya/validator@^X.Y` | The default. The range comes from `spec/VERSION`. |
| 4 | **Degraded offline mode** | No validator, no network. Schema + PII only. |

**Order 1 does not fall through.** If `CABUYA_VALIDATOR_BIN` is set and not
executable, the runner exits 4 rather than quietly using order 2 or 3. Somebody
pinned that binary on purpose; running a different one answers a question they
did not ask.

**The version range is derived, never hardcoded.** A pack vendoring spec 0.1
resolves `@cabuya/validator@^0.1.0`. This matters because a 0.2 validator
disagrees with a 0.1 pack about what conforms, and the pack would report that
disagreement to the adopter as their bug.

## Exit codes

Branch on these **before parsing anything**. The distinction that earns its
keep is 1 versus 3: *the feed is wrong* versus *the network is wrong*.
Conflating them is how a fix loop burns eight iterations rewriting correct
code.

| Code | Meaning | What the loop should do |
|---|---|---|
| `0` | Conformant at the requested level (warnings may exist) | Proceed. |
| `1` | **Non-conformant** — errors in the content | Read `findings`, fix, re-run. |
| `2` | Conformant, warnings exist, `--strict` was passed | Decide whether they matter. **Do not rewrite the mapping.** |
| `3` | **Transport failure** — unreachable, TLS, timeout, non-JSON body | Fix deployment, DNS or routing. **Not the data.** |
| `4` | Usage error — bad flags, unreadable file, unknown profile | Fix the invocation. |
| `5` | Internal validator error | Report it. **Do not retry in a loop.** |

Exit 3 in particular: an unreachable feed is not an invalid feed. Editing the
serializer because the DNS is wrong is the most expensive mistake a fix loop
makes, and the exit code exists to prevent it.

## The report

`--format json` emits the shape every harness produces and every consumer
parses. The fields a sub-skill may rely on:

```jsonc
{
  "validator_version": "0.1.4",
  "spec_version": "0.1.0",
  "target": "https://example.invalid/.well-known/cabuya.json",
  "measured_level": "L1",
  "requested_level": "L2",
  "summary": { "errors": 2, "warnings": 3, "infos": 1 },
  "blockers_for_next_level": ["REC001", "ENV007"],
  "findings": [
    {
      "id": "REC001",
      "severity": "error",
      "level": "L2",
      "pointer": "/data/places/0/last_confirmed_at",
      "message": "required property 'last_confirmed_at' is missing (did you mean to publish last_confirmed_at: null?)",
      "rule": "The confirmation key is REQUIRED; null is the honest 'never confirmed'.",
      "fix": "Add \"last_confirmed_at\": null, or the timestamp of the last real confirmation.",
      "suggested_patch": { "op": "add", "path": "/data/places/0/last_confirmed_at", "value": null },
      "docs": "https://cabuya.org/developers/validator/checks#REC001"
    }
  ],
  "probes": { "cors": "missing", "soft_404": "pass", "always_now": "pass" }
}
```

**Parse the JSON. Never the text.** The human-readable output is written for a
person reading a terminal and it will change; the JSON is a contract. A
sub-skill that greps the text output breaks on the next release, silently, in
a direction that looks like "no findings".

**`blockers_for_next_level` is the field to read first.** It converts "here are
six problems" into "fix these two and you are L2", which is the difference
between a tool that measures and a tool that teaches. Present those first,
always.

**`measured_level` is the only level anyone may state.** Not `requested_level`,
not your reading of the findings.

## Flags worth knowing

| Flag | Effect |
|---|---|
| `--no-network` | Schema and content passes over a local file. How you work on a feed before it is deployed. |
| `--format json` | The report above. Always use this from a sub-skill. |
| `--level L2` | Measure against a specific target level. |
| `--strict` | Warnings become exit 2. |
| `--probe-twice` | Fetches twice to detect always-now. Needed for BEH002. |
| `--lang es` | Findings in Spanish. |

Commands: `validate` · `explain <id>` · `checks` · `init`. **There is no
`convert` command** — the HXL on-ramp is converted by the agent, per
[`../implement/stacks/static-sheet.md`](../implement/stacks/static-sheet.md).
Do not tell anybody to run a command that does not exist.

## Degraded mode — the contract

When nothing else resolves, the runner performs the two checks that a file
alone allows: **structure** against the vendored schemas, and the **PII
pattern families**. It emits the same report shape with `"degraded": true`.

Its summary phrase is exactly:

> **schema-valid; conformance unmeasured**

It never emits "conforming", "passes" or "looks good", because the whole
protocol rests on conformance being something somebody measured, and a pack
that blurred that line would undermine the thing it exists to spread.

It also names what it did not do:

- **Probes not run** — `soft_404`, `cors`, `always_now`. All three need a
  deployed URL, and all three catch a publisher who believes they have
  published and has not.
- **Checks not implemented** — record and envelope semantics beyond the
  schema, and the full PII corpus. `invalid-3` in the vendored examples passes
  degraded mode while being genuinely non-conformant, which is exactly why
  this list is printed on every run.

Degraded mode is deliberately **reduced fidelity**, and it refuses rather than
guesses: the pack has no runtime dependencies, so it implements the JSON Schema
subset the vendored schemas use rather than pulling in a library — and if a
vendored schema ever uses a keyword it does not implement, it **exits 5 instead
of reporting a result it did not fully check**. Silently ignoring an unknown
keyword is how a partial validator becomes a wrong one.

## Reporting a degraded result

Say the limit in the same breath as the outcome:

> Schema-valid; conformance unmeasured. The behavioural probes — soft-404,
> CORS and always-now — did not run, because there is no validator installed
> and no network. Those three are what catch a manifest that returns your SPA
> shell with a 200. Run `npx @cabuya/validator` against the deployed URL when
> you can.

Never shorten that to "it validates".
