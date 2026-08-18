/**
 * Emit the context bundle that briefs a foreign methodology.
 *
 * When the adopter already has a spec-driven methodology — theirs, not ours —
 * the pack does not plan. It emits this bundle and gets out of the way: the
 * ordered tasks from plan/tasks.json with their acceptance criteria,
 * validation commands and stop conditions, the four non-negotiables that ride
 * with any plan, and the ledger contract so a foreign plan still leaves the
 * trail the pack reads on resume.
 *
 * Plain Markdown with one fenced JSON block, because that is what every
 * planner can read. No format of ours to learn.
 *
 *   node bin/render-handover.mjs \
 *     --stack-guide implement/stacks/nextjs-supabase.md \
 *     --publisher-id example-app --target L2 \
 *     --manifest-url https://app.example.invalid/.well-known/cabuya.json \
 *     --feed-path public/cabuya/places.json \
 *     [--stack node] [--framework nextjs] [--measured unmeasured] \
 *     [--include-l3] [--out <path>]
 *
 * Writes to stdout unless --out is given. Exit 3 on a missing argument —
 * a bundle with a hole briefs a methodology into inventing the answer.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACK_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

/**
 * The four rules that ride with the bundle, verbatim — the handover tests
 * grep for these exact sentences, so a rewording here fails the suite
 * rather than quietly weakening what travels.
 */
export const NON_NEGOTIABLES = [
  'The PII decision is made by a human. The ledger accepts decided_by: "human" and nothing else, and there is no flag that skips the gate.',
  'No conformance level is claimed that the validator did not measure, and an offline run is never "conforming" — it is schema-valid at best.',
  'The word "certified" (certificado) is never used, in any language, about anything.',
  'No person-level data — no personal name, phone, email, document or photo — enters the feed, the fixtures, the examples or the ledger. Contact reaches users through public_url.',
];

const args = { measured: 'unmeasured' };
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--include-l3') args.includeL3 = true;
  else if (argv[i].startsWith('--')) args[argv[i].slice(2)] = argv[++i];
}

const REQUIRED = ['stack-guide', 'publisher-id', 'target', 'manifest-url', 'feed-path'];
const missing = REQUIRED.filter((k) => !args[k]);
if (missing.length > 0) {
  console.error(
    `missing: ${missing.map((k) => `--${k}`).join(', ')}\n` +
      'A bundle with a hole briefs a methodology into inventing the answer.'
  );
  process.exit(3);
}
if (!existsSync(join(PACK_ROOT, args['stack-guide']))) {
  console.error(`--stack-guide does not exist in the pack: ${args['stack-guide']}`);
  process.exit(3);
}

const spec = JSON.parse(readFileSync(join(PACK_ROOT, 'plan', 'tasks.json'), 'utf8'));
const tasks = spec.tasks.filter((t) => !t.optional || args.includeL3);
const skipped = spec.tasks.filter((t) => t.optional && !args.includeL3);

const instantiate = (s) =>
  s
    .replaceAll('{stack_guide}', args['stack-guide'])
    .replaceAll('{feed_path}', args['feed-path'])
    .replaceAll('{manifest_url}', args['manifest-url'])
    .replaceAll('{target_level}', args.target)
    .replaceAll('bin/', `${PACK_ROOT}/bin/`);

const taskSection = (t, n) =>
  [
    `### ${n}. \`${t.id}\` — ${t.title}`,
    '',
    `**Goal.** ${t.goal}`,
    t.blocks_on_human
      ? '\n**This task blocks on a human.** Your plan stops here until a human decides; no agent may record the answer on its own authority.'
      : '',
    '',
    '**Acceptance:**',
    ...t.acceptance.map((a) => `- ${a}`),
    '',
    '**Validation:**',
    t.validation.command
      ? '```bash\n' + instantiate(t.validation.command) + '\n```'
      : `A named human check: ${t.validation.human}`,
    t.stop_conditions.length
      ? ['', '**Stops honestly when:**', ...t.stop_conditions.map((s) => `- ${s}`)].join('\n')
      : '',
    '',
    `**Governing files** (read them; do not paraphrase from memory): ${t.reads
      .map((r) => `\`${join(PACK_ROOT, r.startsWith('{') ? instantiate(r) : r)}\``)
      .join(' · ')}`,
    '',
    `**After this task**, record in \`.cabuya/adoption.json\`: ${t.ledger.join(', ')}.`,
  ]
    .filter((line) => line !== '')
    .join('\n');

const machineBlock = {
  contract: spec.contract,
  name: spec.name,
  target_level: args.target,
  tasks: tasks.map((t) => ({
    id: t.id,
    title: t.title,
    blocks_on_human: t.blocks_on_human,
    validation: t.validation.command ? instantiate(t.validation.command) : 'human',
    ledger: t.ledger,
  })),
};

const bundle = `# Cabuya adoption — context for your planning methodology

You are a planning tool (or the agent driving one). This bundle is everything
you need to plan and execute the adoption of the Cabuya Protocol in this
repository. It was generated by the Cabuya pack, which will not plan anything
itself: **the methodology owns the how; the validator owns the whether.**

## What Cabuya is

Cabuya is an open interoperability standard that lets emergency-aid
applications publish and read the same data: one \`place\` schema, four
equivalent transports (a static feed, a read API, a write API, and MCP).
Conformance is **measured by a published validator, never self-declared** —
which is why this bundle can name a target level and cannot award one.

The protocol excludes person-level data by a join prohibition, not a field
omission: no set of published fields makes a feed of people safe, so records
describe places and services, and contact reaches a user through each
record's \`public_url\`. The full specification is vendored, offline, at
\`${join(PACK_ROOT, 'spec')}\` — start with \`PROTOCOL_SUMMARY.md\`.

## This repository

| Fact | Value |
|---|---|
| Stack | ${args.stack ?? 'unknown'} (${args.framework ?? 'unknown'}) |
| Stack guide | \`${join(PACK_ROOT, args['stack-guide'])}\` |
| Manifest URL | \`${args['manifest-url']}\` |
| Feed file | \`${args['feed-path']}\` |
| Publisher id | \`${args['publisher-id']}\` |
| Target level | ${args.target} (an aim — the validator decides what is reached) |
| Last measured | ${args.measured} |

## Four constraints on any plan you produce

These are not preferences. They ride with this bundle, restated from the
pack's own rules, and the ledger schema enforces the first structurally:

${NON_NEGOTIABLES.map((r, i) => `${i + 1}. ${r}`).join('\n')}

## The tasks, in order

${tasks.map((t, i) => taskSection(t, i + 1)).join('\n\n')}
${
  skipped.length
    ? `\n> Not included (the adopter did not ask for L3): ${skipped
        .map((t) => `\`${t.id}\``)
        .join(', ')}. Add it later by re-emitting this bundle with --include-l3.\n`
    : ''
}
## The ledger: how your plan reports progress

After each task, append the step to \`.cabuya/adoption.json\` (schema:
\`${join(PACK_ROOT, 'plan', 'adoption.schema.json')}\`, explained in
\`${join(PACK_ROOT, 'plan', 'LEDGER.md')}\`) and verify the write:

\`\`\`bash
node ${join(PACK_ROOT, 'bin', 'check-ledger.mjs')} .cabuya/adoption.json
\`\`\`

This is what lets any tool — including a different one next month — resume
the adoption without re-asking a decision a human already made.

## When your plan finishes

One command decides what is true, regardless of how the work was planned:

\`\`\`bash
bash ${join(PACK_ROOT, 'bin', 'run-validator.sh')} validate ${args['manifest-url']} --format json
\`\`\`

Record \`measured_level\` — in the validator's words — in the ledger's
\`last_measured\`, with the report digest. That number, and nothing else, is
what this repository may say about its conformance.

## Machine-readable summary

\`\`\`json
${JSON.stringify(machineBlock, null, 2)}
\`\`\`
`;

if (args.out) {
  writeFileSync(args.out, bundle);
  console.log(`wrote ${args.out}`);
} else {
  process.stdout.write(bundle);
}
