---
name: cabuya-setup
description: >
  The doctor. Checks the toolchain this pack needs — Node, the validator,
  the vendored specification's integrity, network reachability, git identity,
  gh — and reports each with its fix. Use when something will not run, when
  setting up a machine for the first time, or when a developer says "no me
  corre el validador", "set up", "doctor" or "install the toolchain".
version: "0.1.0"
documentation_url: https://cabuya.org/developers/skill
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Setup: the doctor

Diagnoses. Does not install. Every check ends in a command **you show the
developer**, and they run it — this pack does not modify a machine on its own
initiative, and the `allowed-tools` above are the enforcement, not the
promise.

Idempotent and safe to re-run. Run it whenever something behaves oddly; it is
faster than reasoning about it.

## The checks, in order

Order matters: each check's failure explains the next one's. A missing Node
makes every later check fail in a way that looks like a different problem.

### 1. Node

```bash
node --version
```

**Needs ≥ 24.** The validator targets it, and `npx` needs it.

Missing or old → point at nodejs.org or the developer's version manager
(`nvm install 24`, `fnm install 24`, `brew install node`). **Do not install a
runtime for somebody.** It is a machine-wide change with consequences for
every other project on it.

### 2. The validator resolves

```bash
bash bin/run-validator.sh --which
```

Prints which of the four orders would fire, and nothing runs. Read it back
verbatim — "order 3, npx `@cabuya/validator@^0.1.0`" is more useful than "the
validator is available".

| Result | What it means |
|---|---|
| `1 env` | Pinned via `$CABUYA_VALIDATOR_BIN`. Deliberate; leave it. |
| `2 local` | Installed in this repo. The fastest, and version-pinned by the lockfile. |
| `3 npx` | The default. Needs network on first use, then it is cached. |
| `4 degraded` | **No validator and no network.** Works, partially — see below. |
| `error` | `$CABUYA_VALIDATOR_BIN` is set and not executable. Fix the path or unset it. |

That last one does not fall through on purpose: somebody pinned that binary,
and silently running a different one would answer a question they did not ask.

### 3. The vendored specification is intact

```bash
bash scripts/verify-integrity.sh
```

Every vendored file matches `spec/CHECKSUMS.txt`.

Fails → **do not regenerate the checksums to make it stop.** That converts a
detected problem into an undetected one. Either somebody hand-edited a
normative document — find out who and why — or a re-vendoring landed without
its checksums, which is the same commit's job. See
[`../shared/spec-paths.md`](../shared/spec-paths.md).

### 4. Network — and what still works without it

```bash
curl -sI https://cabuya.org/registry/index.json | head -1
```

**Offline is a supported state, not a failure.** Say so, and say precisely
what changes:

| Works offline | Needs network |
|---|---|
| Reading the specification, the schemas, the exclusions | Fetching a peer's feed |
| Mapping a data model, generating a serializer | The registry snapshot's freshness |
| The whole PII gate | `npx` on first use |
| Schema + PII validation, degraded | **soft-404, CORS, always-now** |

That last row is the one to say out loud. Those three probes are what catch a
publisher who believes they have published and has not, and no amount of
offline work substitutes for them.

### 5. Git identity

```bash
git config user.name && git config user.email
```

Needed for the registry pull request in `publish-status`. Unset → show
`git config --global user.name "…"`, and let them run it.

### 6. `gh`, only if a pull request is wanted

```bash
gh --version && gh auth status
```

**Optional.** The registry entry can be opened through the web interface just
as well. Do not present this as a blocker; a developer who does not want
GitHub's CLI on their machine is not blocked from publishing.

### 7. The pack is where the agent looks

```bash
bash setup.sh --dry-run
```

Shows what would be linked, and changes nothing. If the agent is not finding
`/cabuya-implement`, this is why.

For Claude Code the pack lives in `.agents/skills/` with `.claude` symlinked to
it, or in `~/.claude/skills/`. Other agents use their own directory —
`setup.sh --help` lists them.

## The status table

End with one screen. Nothing else.

```
Cabuya toolchain

  ✓ node               v24.18.1
  ✓ validator          order 3 — npx @cabuya/validator@^0.1.0
  ✓ vendored spec      14 files match CHECKSUMS.txt
  ✓ network            registry reachable
  ✓ git identity       configured
  · gh                 not installed — optional, only for the registry PR
  ✓ pack linked        claude, cursor

  Ready. Next: /cabuya-implement to map your data onto the schema.
```

Use `✓` for pass, `✗` for a real failure, and `·` for "absent and that is
fine". Do not mark an optional tool `✗` — it trains people to ignore the
column.

If anything failed, repeat its fix **under** the table rather than only in the
row. The row is the summary; the fix is what they need.

## Rules

- **Diagnose, do not install.** Show the command; they run it. Installing a
  runtime, a package manager or a CLI on somebody's machine is a change with
  consequences beyond this project.
- **Say what still works.** A failing check almost never blocks everything,
  and "the validator is not installed" without "mapping and the PII gate work
  fine" reads as a dead end.
- **Never report degraded mode as fine.** It is a supported state and a
  reduced one; say both.
- Re-run freely. Nothing here has side effects.
