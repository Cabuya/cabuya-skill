# Trust and guarantees — the Cabuya skill

This file ships **inside** the pack so you can read what it will and will not
do on your machine before you let it run. It is not a promise page. Every
claim below names the file that enforces it, and the last section is a
procedure for checking each one yourself in about ten minutes.

That framing is the protocol's own: Cabuya's central argument is that a
conformance claim nobody measured is worth nothing. A pack built on that
argument does not get to ask for trust on its word.

Source of truth: <https://github.com/Cabuya/cabuya-skill>. Apache-2.0. The
security policy is [`SECURITY.md`](../../SECURITY.md); this is its install-time
companion.

## What this pack is

**Markdown, one Python script, and a handful of Bash.** The "code" is the
`SKILL.md` files an agent reads at runtime. There is no daemon, no background
process, no build step, and no runtime dependency to install. `spec/` is a
verbatim copy of the normative protocol documents, and
[`scripts/verify-integrity.sh`](scripts/verify-integrity.sh) proves it is the
copy upstream published.

Unlike an integration pack, this one has **no service behind it**. There is no
Cabuya account, no API key, and nothing to log into. The only network access it
ever performs is fetching feeds and validators you explicitly point it at.

## Permissions it requests

`allowed-tools: Bash, Read, Grep, Glob, Edit, Write`

- **Read, Grep, Glob** — read this pack's own files, read your schema or model
  definitions to map them onto the `place` schema, and search your repository
  for the columns and free-text fields that need a PII screen.
- **Edit, Write** — generate the feed endpoint, the manifest, and the
  serializer. This pack writes code into your repository; that is its job.
  Which is exactly why the next section exists.
- **Bash** — run the validator, run `shared/context.sh`, and run `git` to see
  which branch you are on. It does not run your build or your tests unless you
  ask.

## What it does to your repository

**Reads before writes, always.** Every sub-skill's first step is reading your
existing structure. None of them writes anything before it has told you what
it found.

**Every write asks first**, and asks with specifics: which file, what it will
contain, and what it will not touch. "I'll add the feed endpoint" is not a
confirmation prompt; "I'll create `app/api/cabuya/route.ts` and add one line
to `app/api/index.ts`, changing nothing else" is.

**It never opens a pull request you did not ask for.** `publish-status` opens
a registry PR only when you asked it to publish your status, and it shows you
the diff first. The word *never* here means the sub-skills contain no
unprompted `gh pr create` path — see the self-audit.

**It writes exactly two files of its own, and you can delete both.**

1. `.cabuya/adoption.json` — the adoption ledger: the detected stack, who
   plans the work, which steps are done, the one human PII decision, and the
   last measured level with the digest of the report that measured it. Its
   schema ([`plan/adoption.schema.json`](plan/adoption.schema.json)) is
   closed: columns are recorded by *name* only, free text is capped, and
   there is no field that could hold a personal name, phone, email or
   document. Remove it: `rm -r .cabuya/` — nothing else references it.
2. A plan under `.dwp/plans/PLAN_cabuya_adoption/` — **only with your
   consent**, on the DeepWorkPlan path, and never regenerated over an
   existing one. Remove it by deleting the directory.

Neither file ever contains a contact value, a person's data, or a
conformance level the validator did not measure — the ledger schema makes
the last two unrepresentable, and `bin/check-ledger.mjs` proves it offline.

Two guards you can check by reading the code: `setup.sh` verifies the
vendored specification against its checksums **before** creating any
symlink, and refuses a pack that does not match; and the two renderers
refuse any value that would put shell metacharacters into a rendered
validation command — the commands a generated plan carries are commands an
agent will later run, so a poisoned value dies at render time instead.

**It never sends your data anywhere.** Not to Cabuya, not to a telemetry
endpoint, not to an LLM provider beyond the agent session you are already in.
There is nothing in this pack that posts your schema, your rows, or your repo
contents to any host. The registry PR contains the URL of a feed you chose to
publish, and nothing else.

## The three refusals

These are not preferences the agent balances against your request. They are
places the pack stops.

### 1. The PII gate always stops for a human

When mapping your data model, the pack screens column names, JSON keys and
free-text fields against [`shared/pii-deny-list.md`](shared/pii-deny-list.md)
— name, nombre, apellido, phone, teléfono, celular, whatsapp, email, correo,
cédula, documento, dirección, foto, contacto, responsable, plus patterns for
Colombian phone shapes and email addresses.

**Matches are surfaced, never auto-resolved.** The pack will not decide that a
column called `contacto` is safe because it looks like an organization name.
It shows you the match and waits. This is the one gate that has no override
flag, because the failure it prevents — a person's phone number in a public
feed, mirrored by every consumer before anyone notices — cannot be undone by
deleting the record.

Free text is screened too. A `description` containing a name and a phone
number is the third leak channel, and the pack refuses to publish until it is
stripped.

### 2. It will not fetch a publisher who reserved reuse

Before any third-party fetch, the pack consults the target's declared crawl
policy. If the policy reserves reuse, **it does not fetch — even if you ask.**
It explains which policy it read and offers a link-out instead.

It does not scrape at all. It consumes feeds that publishers chose to publish.
It will not reconstruct a feed by crawling pages, and it will not write you
code that does.

### 3. It will not claim a conformance level

The pack can run the validator and report exactly what the validator said. It
cannot award a level, and it will not write "L2-conformant" into your README,
your manifest, or your marketing copy on the strength of its own reading.

It never uses the word *certified*. There is no certification. There is a
published validator, and whatever it measured last time it ran.

## Degraded mode: what it says when it cannot do something

A pack that quietly does less than it claims is worse than one that fails.
When something is unavailable, the rule is to **name the limit rather than
work around it silently**:

- **No network.** It says so, and continues — the specification is vendored,
  so implementation and mapping work fully offline. What it cannot do offline
  is fetch a peer's feed or check a live validator, and it says which.
- **No validator installed.** It reports that conformance is **unmeasured**,
  not that it is fine. It offers [`setup/SKILL.md`](setup/SKILL.md).
- **A fetch failed.** It reports the failure. It does not fall back to a
  cached, remembered, or invented version of the document it could not fetch —
  the failure mode this whole pack exists to prevent is an agent inventing a
  standard, confidently, when the fetch fails.
- **An integrity check failed.** It stops. A `spec/` file whose checksum does
  not match is not "probably fine"; it is a document nobody signed, and the
  pack will not teach you a protocol from it.

## Self-audit — check every claim above

Ten minutes, no trust required. Run these from the pack's root.

```bash
# 1. The vendored specification is upstream's, byte for byte.
bash scripts/verify-integrity.sh
bash scripts/verify-integrity.sh --list    # what is vendored

# 2. Nothing phones home. No POSTs, no telemetry, no analytics hosts.
grep -rn 'curl -X POST\|fetch(.*POST\|https\?://' --include='*.md' \
     --include='*.sh' --include='*.py' . | grep -v 'cabuya.org\|github.com'

# 3. No unprompted pull request. Every `gh pr` occurrence should sit inside a
#    step that shows you a diff and waits.
grep -rn 'gh pr create\|git push' --include='*.md' .

# 4. The PII gate has no override. Search for one; there is nothing to find.
grep -rni 'skip.*pii\|--force\|ignore.*deny.list' --include='*.md' .

# 5. Read what the pack is actually instructed to do. It is Markdown — the
#    prompts are the implementation, and they are all readable.
wc -l */SKILL.md SKILL.md
```

If any of those turns up something this file did not tell you about, that is a
security issue and [`SECURITY.md`](../../SECURITY.md) says how to report it
privately. A gap between what this file claims and what the pack does is the
most serious kind of bug this project can have.

## What this pack cannot protect you from

Honest limits, since the rest of this file is a list of guarantees:

- **Your agent's own permissions.** This pack declares `allowed-tools`, but
  the host enforces them. An agent running with unrestricted shell access can
  do anything; the declaration narrows intent, not capability.
- **Your judgement about your own data.** The deny-list catches the field
  names people actually use. It cannot know that your `notes` column contains
  the coordinator's mobile number, and it will ask you rather than guess.
- **What a consumer does with a published feed.** Once you publish, the data
  is public. The protocol's exclusions exist so that publishing is safe; they
  cannot un-publish something you chose to include.
- **A modified copy of this pack.** Everything above describes the pack as
  published. Verify the copy you have.
