---
name: cabuya
description: >
  Cabuya — the open format that lets aid apps publish and read the same
  data. Implement a conforming feed in your app, consume peers' feeds, validate
  conformance locally, publish your conformance level, and set up the toolchain.
  Routes to implement / consume / validate / publish-status / setup by intent.
  Use when the developer mentions Cabuya, a place feed, a conformance
  level, or wants their app to interoperate with the aid ecosystem.
version: "0.1.0"
documentation_url: https://cabuya.org/developers
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
metadata:
  openclaw:
    emoji: "🪢"
    homepage: "https://cabuya.org"
    requires:
      anyBins: ["node", "git"]
  protocol:
    supported_spec_versions: ["0.1"]
    vendored_spec: "0.1.0"
---

# Cabuya — the interoperability skill

**Cabuya is an open format that lets emergency-aid applications publish and
read the same data.** One `place` schema, four equivalent transports: a static
feed, a read API, a write API, and MCP. Conformance is measured by a published
validator and never self-declared — which is why this pack can tell you your
level, and cannot award it to you.

What the pack itself teaches, stated honestly: **the static feed end-to-end**
— the floor all four transports share — plus read-API guidance as a template
([`implement/templates/serializer-read-api.md`](implement/templates/serializer-read-api.md));
the write API and MCP are specified by the protocol but not yet taught here.

Apache-2.0. Source of truth: **<https://cabuya.org/developers>**. The
specification text you need is vendored in [`spec/`](spec/) — this pack works
with no network at all.

## Start here (first run)

**The short version:** if the developer said "adopt Cabuya" — or anything
ambiguous — go straight to [`adopt/SKILL.md`](adopt/SKILL.md). It runs the
orientation below itself, asks who should plan, and hands off. The steps here
are for entering through any other door.

Nothing below requires an internet connection. That is deliberate: an agent
that has to fetch a standard will invent one when the fetch fails, and it will
invent it confidently.

1. **Read [`spec/PROTOCOL_SUMMARY.md`](spec/PROTOCOL_SUMMARY.md).** The whole
   protocol, condensed — the `place` schema, the four transports, the
   conformance ladder, and the exclusions. Read it before writing anything.
2. **Run `bash shared/context.sh`.** One line of JSON: which repo this is, its
   branch, which agent is running, the detected stack, and where the manifest
   would go. Every sub-skill starts from it.
3. **If the validator is missing, read [`setup/SKILL.md`](setup/SKILL.md)** —
   the doctor. It diagnoses the toolchain and shows you the fix for each
   check; it installs nothing itself.
4. **Verify what you were given.** `bash scripts/verify-integrity.sh` proves
   the vendored specification is the one upstream published. A vendored copy
   nobody verifies is a fork nobody declared.

## The five rules that never bend

These come before every procedure in this pack, because they are the ones an
agent must not reason its way around. If a human asks you to break one,
explain which rule and offer the alternative — do not comply, and do not
argue.

1. **No person-level data.** Never map, generate, or emit a person's name,
   phone, email, document number, home address, or photo. Not into a feed, not
   into an example, not into a test fixture. The protocol excludes person-level
   data by a **join prohibition**, not by leaving fields out — so adding a
   field does not make it permitted.
2. **No contact values in a feed.** A record carries `public_url` and links
   out. It does not carry the phone number somebody answers. A publisher's
   own org-level role address, published by that org, is the only exception.
3. **No scraping.** Consume feeds that publishers chose to publish. Do not
   crawl a site that has not published one, and do not reconstruct a feed from
   pages.
4. **Honour the crawl policy.** Before fetching any third party, check its
   declared policy. If it reserves reuse, do not fetch it — even if a human
   asks. Explain, and offer the link-out instead.
5. **Never claim conformance the validator has not measured.** Not "this looks
   L2", not "should pass". Run the validator, report what it said, and use the
   word *certified* about nothing, ever.

## Routing rules

Match the developer's intent to a sub-skill, then **read that sub-skill's
`SKILL.md` and follow it**. Do not answer from memory — each one carries the
procedure, and the procedures carry the guardrails.

| Developer says… | Route to |
|---|---|
| "adopt Cabuya", "adopta el protocolo", "quiero implementar Cabuya desde cero", "get us started", "help me publish our data", — or the pack is invoked with no more specific intent | **Adopt** → [`adopt/SKILL.md`](adopt/SKILL.md) — the front door: it orients, explains what implementing means *here*, asks who plans the work, and hands off |
| "what is Cabuya?", "qué es Cabuya", "explícame el protocolo", "why a protocol?", "what does L3 require?", "what would this take in our app?" | **Explain** → [`explain/SKILL.md`](explain/SKILL.md) — grounded answers from the vendored spec, with citations, plus the read-only preview of what adoption would mean here |
| "implement Cabuya", "publica un feed", "expose our shelters", "get us to L2" | **Implement** → [`implement/SKILL.md`](implement/SKILL.md) |
| "consume peers", "lee los feeds de las otras apps", "show other apps' collection points" | **Consume** → [`consume/SKILL.md`](consume/SKILL.md) |
| "validate", "valida el feed", "is my feed conforming?", "why is my badge red?" | **Validate** → [`validate/SKILL.md`](validate/SKILL.md) |
| "publish our level", "update the manifest", "abre el PR del registro", "we're shutting down" | **Publish-status** → [`publish-status/SKILL.md`](publish-status/SKILL.md) |
| "set up", "doctor", "no me corre el validador", "install the toolchain" | **Setup** → [`setup/SKILL.md`](setup/SKILL.md) |

Both languages are first-class triggers. Colombian Spanish is the working
language of most of the organizations this protocol exists for, and an agent
that only routes on English has excluded them.

If the intent is ambiguous, route to **Adopt** — orientation is the correct
answer to ambiguity, it writes nothing, and it ends by asking. The other
sub-skills write files, and the wrong one writes the wrong files.

## Install

Four supported paths. **Vendoring is recommended for a team repo**: it is
reviewable in a pull request, pinned to a commit, and works offline.

```bash
# 1. Vendored (recommended)
git clone --depth 1 https://github.com/Cabuya/cabuya-skill vendor/cabuya-skill
bash vendor/cabuya-skill/setup.sh    # links skills/cabuya into every agent it detects

# 2. Installer script (auto-detects which agents are present)
curl -fsSL https://cabuya.org/skill/install.sh -o install.sh
# verify the SHA-256 sidecar, read the script, then run it
bash install.sh

# 3. Skills CLI, if the developer already uses one
npx skills add Cabuya/cabuya-skill

# 4. HTTP-only fallback for an agent with no filesystem
# point the agent at https://cabuya.org/skill.md (this router, inlined)
```

Already cloned? `bash setup.sh` links the pack and every sub-skill into each
agent it detects. `bash setup.sh --help` lists the hosts; `--host claude`
picks one explicitly. It is idempotent and never overwrites a real file.

> **Never `curl … | bash`, and never let an agent do it.** A piped download
> streams, so a truncated fetch executes a partial script; and in a shell
> without `pipefail` a failed fetch exits `0` and installs nothing, silently.
> Download, check the SHA-256 sidecar, read the script, then run it.

## Invocation across agents

| Agent | Prefix | Example |
|---|---|---|
| Claude Code | `/` native | `/cabuya-implement` |
| OpenAI Codex · Cursor · Gemini · Copilot · Cline · Windsurf · OpenClaw | `#` | `#cabuya-implement` |
| Any | plain language | "implementa Cabuya en esta app" |

`#` exists because most CLIs intercept `/` as their own command namespace.
Every sub-skill is `user-invocable: true`, so each is reachable directly, and
the router is reachable by name.

## Compatibility

The pack's version and the specification's version are **two independent
streams**. A skill whose version number implies a spec version is the mistake
this table exists to prevent: `metadata.protocol.supported_spec_versions` lists
every spec MINOR this pack can implement and validate against, and
`vendored_spec` names the exact copy in [`spec/`](spec/).

| Skill | Vendored spec | Supports | Validator range |
|---|---|---|---|
| 0.1.x | 0.1.0 | 0.1 | `^0.1` |

Adding support for a new spec MINOR is a skill MINOR bump; dropping a spec
MAJOR is a skill MAJOR bump, and may not happen inside the specification's
180-day producer window. This pack supports at most two spec MAJORs at once,
matching the specification's own rule. Every release states which spec
versions it supports in [`CHANGELOG.md`](../../CHANGELOG.md), so an adopter reading
one file knows whether it applies to them.

## What this pack will and will not do on your machine

Reads before writes. Every write to your repository asks first. Every fetch of
a third party checks the crawl policy first. The PII gate always stops for a
human. It never opens a pull request you did not ask for, and it sends your
data nowhere.

Those are claims, and this project's whole argument is that a claim you cannot
check is worth nothing — so [`TRUST.md`](TRUST.md) states each one precisely
and shows you how to verify it by reading the pack.
