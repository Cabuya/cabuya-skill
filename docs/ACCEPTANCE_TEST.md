# The acceptance test

The pack's central claim is that **any agent installs it and already knows the
whole protocol** — offline, with no other context.

A claim that cannot fail is marketing. This is the procedure that can fail it.

## The setup

Non-negotiable, because each condition removes a way of passing without the
pack doing the work:

| Condition | Why |
|---|---|
| **A fresh agent session** | No prior conversation to have learned from. |
| **Network disabled** | Really disabled. An agent that can fetch cabuya.org is not testing the pack. |
| **An empty repository** | No code to infer conventions from. |
| **The pack at `.agents/skills/cabuya/`** | As an adopter receives it. |
| **No other context** | No other skills, no README, no prompt engineering. |
| **The agent may read only pack files** | The claim is about the pack. |

## The prompt

[`../tests/acceptance/prompt.md`](../tests/acceptance/prompt.md), verbatim, in
one message.

**It is fixed and versioned.** Editing a question so a run passes invalidates
every previous result — and it is the most tempting thing to do at 11pm before
a release. If a question is genuinely wrong, change it in a pull request with
the reason, and mark the earlier runs historical.

Every answer must **cite the pack file it came from**. An uncited answer scores
zero even when it is correct, because the thing being tested is that the answer
is *in the pack* rather than in the model's training data.

## The bar

**10/10 on Part A and 3/3 on Part B.** Anything less blocks the release.

That is unforgiving on purpose. 9/10 means an agent confidently does not know
one thing about a protocol whose failure modes are a published phone number
and a feed nobody can read.

### Part A — ten questions

The ladder · manifest location and fallback · why a soft-404 is treated as
absent · the record id format · what never travels · CR-1 · omitted versus
`null` · the two anti-patterns · the six consumption MUSTs · the required
envelope fields and the non-obvious one.

Graded by matching against
[`../tests/acceptance/fixtures/answers.json`](../tests/acceptance/fixtures/answers.json).

### Part B — three tasks

| Task | Passes when |
|---|---|
| **B1** | The mapping is complete, **both** PII columns are flagged, and the agent **stops** — with no generated code anywhere in the answer. |
| **B2** | All three violations in `invalid-2`, each with its §7 rule. Two of three is a fail: the message design is one violation per message. |
| **B3** | The manifest and feed are schema-valid, `last_confirmed_at` is `null` and present, and the result is reported as **"schema-valid; conformance unmeasured"** — never "conforming". |

Three automatic failures, checked separately because each is a behaviour
rather than a fact:

- **B1 generated code before the human answered.** The mapping is fine;
  writing a serializer before the gate is answered is not.
- **B3 invented a confirmation timestamp.** The brief says nobody ever
  confirmed the shelter. A fabricated confirmation is the worst outcome the
  design guards against — worse than a missing key, because it tells every
  consumer downstream that somebody went and checked.
- **B3 claimed conformance.** Degraded mode measures nothing about behaviour.

## Running it

```bash
bash tests/acceptance/run-acceptance.sh --prepare      # builds the sandbox
# …run the agent in it, offline, and save the reply…
bash tests/acceptance/run-acceptance.sh --grade reply.md
bash tests/acceptance/run-acceptance.sh --check        # release gate
```

`--prepare` copies the pack into a temp repository rather than symlinking it: a
symlink out of the sandbox is a path to everything else on the machine, and the
agent is supposed to see only what an adopter receives.

## Two harnesses

**A MINOR release requires two passing runs, on two different agent
harnesses.** The pack claims to work across agents, and that claim is only true
if it has been observed twice.

Recorded runs live in `tests/acceptance/runs/`, one file per run, named
`YYYY-MM-DD-harness.md`, each naming the pack version it tested.

## What CI does, and what it does not

Driving a real agent needs a harness and an API key, which a fork's CI does not
have. So:

- **CI never reports this test green when it did not run.** There is no
  simulated pass, no cached result presented as fresh. The job that has no
  harness is **skipped, visibly**.
- **CI does check the grader**, on committed fixtures — one that must pass and
  five that must fail. A grader that cannot fail is worth nothing, and that is
  checkable without an agent.
- **The release gate checks the artifact**: `--check` requires a recorded run
  that names the current version and still passes when re-graded.

So the honest summary: the test is a **required manual gate with automated
scoring**. The grading is mechanical and verified; the running is human.

## What the grader cannot do

It matches strings. It cannot distinguish a correct answer from a
well-phrased wrong one, and a transcript stuffed with the key's vocabulary
would score well while saying nothing.

That is a real limit. The mitigations are that the prompt is fixed, the run is
recorded in full, and **a human reads the transcript before a release** — not
that the grader is clever. A fuzzy grader is one that gets tuned until it
passes; this one fails loudly and names what was missing.

## Honesty note on the first recorded run

`runs/2026-08-18-claude-code.md` scores 10/10 + 3/3 and was performed by the
session that **wrote the pack**.

It therefore verifies something narrower than the headline claim: that every
required answer is present in the pack, findable, and citable to a specific
file. It does **not** verify that an agent with no memory of writing it would
find them.

Recorded here rather than quietly counted, because a project whose argument is
that unverified claims are worth nothing does not get to launder one. **The
first genuinely independent run — a fresh session, a different harness, ideally
a different operator — is a release blocker for 0.1.0**, and it is what turns
this from a self-check into evidence.
