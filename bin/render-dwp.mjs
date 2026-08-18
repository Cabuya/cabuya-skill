/**
 * Render the Cabuya adoption as a DeepWorkPlan in the adopter's repository.
 *
 * Input: plan/tasks.json (the methodology-neutral task spec) and the
 * templates in adopt/templates/dwp/. Output: .dwp/plans/PLAN_cabuya_adoption/
 * in DWP's exact anatomy — a README whose task list is checkboxes with links,
 * one N.task_{id}.md per task with the required sections, PROGRESS.md and
 * analysis_results/.
 *
 * A script rather than prose, deliberately: the anatomy is mechanical, and an
 * agent re-typing it per adoption would drift. The parts that need judgement
 * — which stack guide, which publisher id, whether L3 is wanted — arrive as
 * arguments, from the questions the adopt flow already asked. The renderer
 * never invents a framework detail: instructions point into the stack guide;
 * they do not paraphrase it.
 *
 *   node bin/render-dwp.mjs --repo <adopter-root> \
 *     --stack-guide implement/stacks/nextjs-supabase.md \
 *     --publisher-id example-app --target L2 \
 *     --manifest-url https://app.example.invalid/.well-known/cabuya.json \
 *     --feed-path public/cabuya/places.json \
 *     [--include-l3] [--stack node] [--framework nextjs]
 *
 * Refusals, each an exit code:
 *   2  a PLAN_cabuya_adoption already exists — resume it, never overwrite
 *   3  a required argument is missing (every placeholder must fill)
 *   4  the task spec or a template cannot be read
 *   5  a {{placeholder}} survived substitution — a bug here, not user error
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACK_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const TPL = (name) =>
  readFileSync(join(PACK_ROOT, 'adopt', 'templates', 'dwp', name), 'utf8');

// --- arguments ---------------------------------------------------------------

const args = {};
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--include-l3') args.includeL3 = true;
  else if (argv[i].startsWith('--')) args[argv[i].slice(2)] = argv[++i];
}

const REQUIRED = ['repo', 'stack-guide', 'publisher-id', 'target', 'manifest-url', 'feed-path'];
const missing = REQUIRED.filter((k) => !args[k]);
if (missing.length > 0) {
  console.error(
    `missing: ${missing.map((k) => `--${k}`).join(', ')}\n` +
      'Every one of these fills a placeholder in the rendered plan, and a plan\n' +
      'with a hole in it is worse than this error. The adopt flow gathers them\n' +
      'from context.sh and from the questions it already asked.'
  );
  process.exit(3);
}


/*
 * Shape-check the values that land inside rendered shell commands.
 *
 * The validation blocks this script writes are commands an agent will later
 * EXECUTE in the adopter's repository. Every substituted value comes from the
 * adopter's own answers — but a poisoned bundle request (a URL carrying
 * `;`/backticks, a path with `$( )`) would turn a rendered command into an
 * injection an agent runs weeks later. Found in the plan's security review;
 * refuse at render time, where the fix is a better answer, not a shell escape.
 */
const SAFE = {
  'manifest-url': /^https?:\/\/[A-Za-z0-9._~:/?#@!$&'()*+,;=%[\]-]+$/,
  'feed-path': /^[A-Za-z0-9._/-]+$/,
  'publisher-id': /^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$/,
  'stack-guide': /^[A-Za-z0-9._/-]+$/,
};
const SHELL_META = /[;|&`$<>\\\s]/;
for (const [key, pattern] of Object.entries(SAFE)) {
  if (args[key] === undefined) continue;
  if (!pattern.test(args[key]) || SHELL_META.test(args[key])) {
    console.error(
      `--${key} contains characters that cannot travel into a rendered shell command: ${args[key]}\n` +
        'This value is substituted into a validation command an agent will run.'
    );
    process.exit(3);
  }
}

if (!['L1', 'L2', 'L3'].includes(args.target)) {
  console.error(`--target must be L1, L2 or L3, got: ${args.target}`);
  process.exit(3);
}
if (!existsSync(join(PACK_ROOT, args['stack-guide']))) {
  console.error(`--stack-guide does not exist in the pack: ${args['stack-guide']}`);
  process.exit(3);
}

const repoRoot = args.repo;
const planDir = join(repoRoot, '.dwp', 'plans', 'PLAN_cabuya_adoption');

if (existsSync(planDir)) {
  console.error(
    `${planDir} already exists.\n` +
      'This is a resume, not a render: it may hold completed work and human\n' +
      'decisions. Continue it with /dwp-execute cabuya_adoption, or read its\n' +
      'PROGRESS.md to see where it got to. To start truly over, delete the\n' +
      'directory yourself — this script will never do that.'
  );
  process.exit(2);
}

// --- the spec ----------------------------------------------------------------

let spec;
try {
  spec = JSON.parse(readFileSync(join(PACK_ROOT, 'plan', 'tasks.json'), 'utf8'));
} catch (error) {
  console.error(`cannot read plan/tasks.json: ${error.message}`);
  process.exit(4);
}

const tasks = spec.tasks.filter((t) => !t.optional || args.includeL3);
const skipped = spec.tasks.filter((t) => t.optional && !args.includeL3);

/*
 * The ledger is the transfer. A repository that walked part of the adoption in
 * plan mode (or under a foreign methodology) has its completed steps in
 * .cabuya/adoption.json — so a later render arrives with those tasks already
 * checked, instead of asking anyone to redo or hand-tick them. Found by the
 * acceptance run: plan-mode.md promised this and the renderer did not do it.
 */
const ledgerPath = join(repoRootOf(), '.cabuya', 'adoption.json');
function repoRootOf() {
  return args.repo;
}
let completed = new Set();
if (existsSync(ledgerPath)) {
  try {
    const ledger = JSON.parse(readFileSync(ledgerPath, 'utf8'));
    completed = new Set(
      (ledger.steps ?? [])
        .filter((step) => step.status === 'done')
        .map((step) => step.id)
    );
  } catch {
    /* an unreadable ledger marks nothing — never guess at completion */
  }
}

// --- substitution ------------------------------------------------------------

const values = {
  repo: repoRoot.split('/').filter(Boolean).pop() ?? 'this repository',
  stack: args.stack ?? 'unknown',
  framework: args.framework ?? 'unknown',
  stack_guide: args['stack-guide'],
  pack_root: PACK_ROOT,
  manifest_url: args['manifest-url'],
  feed_path: args['feed-path'],
  publisher_id: args['publisher-id'],
  target_level: args.target,
  task_count: String(tasks.length),
  spec_contract: spec.contract,
  /* Deterministic on purpose: the commit that adds the plan carries the real
     date; a wall-clock read here would make renders unreproducible. */
  rendered_at: process.env.CABUYA_RENDERED_AT ?? 'the date of the commit that adds this plan',
};

const fill = (template, extra = {}) => {
  const all = { ...values, ...extra };
  const out = template.replace(/\{\{([a-z_]+)\}\}/g, (match, key) =>
    key in all ? all[key] : match
  );
  const leftover = out.match(/\{\{[a-z_]+\}\}/g);
  if (leftover) {
    console.error(`unfilled placeholder(s): ${[...new Set(leftover)].join(', ')}`);
    process.exit(5);
  }
  return out;
};

/* The spec's validation placeholders, instantiated with the same values. */
const instantiate = (command) =>
  command
    .replaceAll('{stack_guide}', args['stack-guide'])
    .replaceAll('{feed_path}', args['feed-path'])
    .replaceAll('{manifest_url}', args['manifest-url'])
    .replaceAll('{target_level}', args.target)
    .replaceAll('bin/', `${PACK_ROOT}/bin/`);

// --- render ------------------------------------------------------------------

mkdirSync(join(planDir, 'analysis_results'), { recursive: true });
writeFileSync(join(planDir, 'analysis_results', '.gitkeep'), '');

const slug = (t) => `${tasks.indexOf(t) + 1}.task_${t.id}.md`;

const taskList = tasks
  .map((t) => {
    const box = completed.has(t.id) ? '[x]' : '[ ]';
    const done = completed.has(t.id) ? ' — completed before this render (see the ledger)' : '';
    return `- ${box} Task ${tasks.indexOf(t) + 1}: ${t.title}${done}\n      See: [${slug(t)}](./${slug(t)})`;
  })
  .join('\n\n');

const followupNote = skipped.length
  ? `\n> **Follow-up, not in this plan:** ${skipped
      .map((t) => `**${t.title}** (\`${t.id}\`)`)
      .join(', ')} — the L3 path. Re-render with \`--include-l3\`, or run the` +
    ' pack\'s consume flow, when the team wants it.'
  : '';

writeFileSync(
  join(planDir, 'README.md'),
  fill(TPL('README.md'), { task_list: taskList, followup_note: followupNote })
);

for (const t of tasks) {
  const n = tasks.indexOf(t) + 1;
  const reads = t.reads
    .map((r) => {
      const path = r.startsWith('{') ? instantiate(r) : r;
      return `- \`${join(PACK_ROOT, path)}\``;
    })
    .join('\n');

  const instructions = [
    `Follow the procedure in the files above — they carry the guardrails; do`,
    `not work from memory of them. This task's goal, criteria and stops come`,
    `from the pack's task spec (\`${join(PACK_ROOT, 'plan', 'tasks.json')}\`, id \`${t.id}\`).`,
    '',
    ...(t.stop_conditions.length
      ? ['**Stop conditions — end the task honestly here:**', '',
         ...t.stop_conditions.map((s) => `- ${s}`)]
      : []),
    '',
    `Record the step in \`.cabuya/adoption.json\` (fields: ${t.ledger.join(', ')}).`,
  ].join('\n');

  const validation = t.validation.command
    ? '```bash\n' + instantiate(t.validation.command) + '\n```'
    : `**Human check — no command can satisfy this.** ${t.validation.human}` +
      (t.blocks_on_human
        ? '\n\n> **THE PLAN STOPS HERE until a human decides.** Record the answer' +
          '\n> with `decided_by: "human"` — the ledger schema accepts nothing else.'
        : '');

  const prev = tasks[n - 2];
  const context =
    `Task ${n} of ${tasks.length} in the adoption` +
    (prev ? `, after "${prev.title}"` : '') +
    '. The procedure lives in the files under Read Before Starting; this file' +
    " instantiates the pack's task spec for this repository.";

  writeFileSync(
    join(planDir, slug(t)),
    fill(TPL('task.md'), {
      n: String(n),
      title: t.title,
      context,
      reads,
      goal: t.goal,
      instructions,
      acceptance: t.acceptance.map((a) => `- ${a}`).join('\n'),
      validation,
    })
  );
}

writeFileSync(
  join(planDir, 'PROGRESS.md'),
  fill(TPL('PROGRESS.md'), {
    progress_rows:
      '| Task | Status | Summary |\n|---|---|---|\n' +
      tasks
        .map(
          (t) =>
            `| ${tasks.indexOf(t) + 1}. ${t.title} | ${
              completed.has(t.id) ? 'done (from the ledger)' : 'pending'
            } | |`
        )
        .join('\n'),
  })
);

console.log(
  `rendered ${tasks.length} tasks into ${planDir}\n` +
    (completed.size ? `already completed per the ledger: ${[...completed].join(', ')}\n` : '') +
    (skipped.length ? `skipped (follow-up): ${skipped.map((t) => t.id).join(', ')}\n` : '') +
    `next: /dwp-execute cabuya_adoption`
);
