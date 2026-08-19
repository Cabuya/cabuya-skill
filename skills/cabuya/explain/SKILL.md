---
name: cabuya-explain
description: >
  Answer what the Cabuya Protocol is, how it works and why it exists — from
  the vendored specification, with citations, in English or Spanish — and
  preview what adopting it would mean in the current repository without
  writing anything. Use when someone asks "what is Cabuya", "qué es Cabuya",
  "explícame el protocolo", "why a protocol", "cómo funciona Cabuya", "what
  would this take in our app", or any question about the protocol rather
  than a request to implement it.
version: "0.1.0"
documentation_url: https://cabuya.org/developers
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Explain: grounded answers, or a pointer — never a guess

The pack vendors the entire specification, checksummed. So there are exactly
two honest moves here: answer **from the vendored spec, citing the section**,
or say the question is outside it and point at <https://cabuya.org>. There is
no third move. An agent that explains a protocol from training data explains
a protocol that does not exist.

Note the `allowed-tools`: no `Edit`, no `Write`. Explaining changes nothing —
that is what makes it safe to ask anything.

## How to answer

1. **Find the question in [`QUESTIONS.md`](QUESTIONS.md)** — the map of what
   newcomers ask, in both languages, each with its sources. A question that
   is not there is answered the same way: from the vendored files, cited, or
   not at all.
2. **Short first.** Three or four sentences, then offer depth: "want the
   section itself?" The reader who wanted one paragraph got it; the reader
   who wanted §7.1 verbatim is one yes away.
3. **Cite as you go** — the vendored path and section, e.g.
   `spec/EXCLUSIONS.md §7.1`. When a rule matters, quote it rather than
   paraphrase: the exclusions are vendored verbatim precisely so refusals
   cite text nobody rewrote.
4. **Answer in the language of the question.** Both are first-class.
5. **End with the one next step**, when one exists: `/cabuya` to start, the
   sub-skill that does the thing just explained, or the website page that
   owns the claim.

## «¿Y aquí qué significaría?» — the read-only preview

When the question is about *this* repository — "what would adopting this
take for us?" — ground the answer in the repo, still writing nothing:

```bash
bash shared/context.sh
```

Match the stack guide per [`../shared/stack-detection.md`](../shared/stack-detection.md),
then describe: which files would be created (from the guide), where the
manifest would be served, roughly the effort (§1 of the summary: L2 is one
afternoon for a small app), and the one human decision that will come — the
PII gate. **This preview writes nothing** — not a file, not a scaffold, not
a sample. It is a description of work, and the moment it starts doing the
work it has become `implement` without the guardrails.

## The lines that hold even here

- **No invented figures.** The spec's numbers (7×ttl, 180 days, one
  afternoon) come with their sections; a number you cannot cite is a number
  you do not say.
- **Stability gets the status sentence**: the specification is 0.1, normative
  — early, but published — say so whenever stability, maturity or "can we
  depend on this" is asked, and never claim more maturity than the version
  number carries.
- **The registry question gets the listing sentence**: inclusion is not
  endorsement — a directory lists, a registry measures.
- **Levels are measured.** There is no *certified* and never will be; an
  agent may report what the validator measured and must not award a level,
  including to its own work (§8).
- **Out of scope is out of scope.** A publisher's status, a figure the spec
  does not carry, a claim the website owns: say so, link out, stop.

## Where this hands off

| The question turns into… | Go to |
|---|---|
| "ok, let's do it" | [`../adopt/SKILL.md`](../adopt/SKILL.md) — the front door |
| "is our feed conforming?" | [`../validate/SKILL.md`](../validate/SKILL.md) |
| "show me other apps' data" | [`../consume/SKILL.md`](../consume/SKILL.md) |
| "update our level" | [`../publish-status/SKILL.md`](../publish-status/SKILL.md) |
