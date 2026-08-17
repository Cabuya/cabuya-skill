/**
 * Degraded offline validation — the honest partial answer.
 *
 * Runs when no validator is available and there is no network. It checks the
 * two things that can be checked from a file alone:
 *
 *   1. structure, against the vendored JSON Schemas;
 *   2. PII deny patterns, over keys and free-text values.
 *
 * It cannot check the three that need a deployed URL — soft-404, CORS,
 * always-now — and those are precisely the ones that catch a publisher who
 * believes they have published and has not.
 *
 * So this never reports "conforming". It reports **"schema-valid; conformance
 * unmeasured"**, names the probes that did not run, and exits 1 on any error.
 * A pack that blurred that line would undermine the one thing the protocol
 * rests on: that conformance is measured rather than declared.
 *
 * ## Reduced fidelity, stated plainly
 *
 * The pack has no runtime dependencies — that is a promise in TRUST.md — and
 * degraded mode by definition cannot install one. So this implements the JSON
 * Schema subset the vendored schemas actually use (type, required, enum,
 * pattern, format, properties, items, $ref/$defs, allOf/anyOf/oneOf, if/then,
 * min/max, minItems, minLength, additionalProperties) rather than pulling Ajv.
 *
 * That subset is checked at startup: if a vendored schema ever uses a keyword
 * this does not implement, it says so and exits 5 rather than passing a
 * document it did not fully check. Silently ignoring an unknown keyword is how
 * a partial validator becomes a wrong one.
 *
 * The PII pass is likewise reduced: it carries the pattern families from
 * shared/pii-deny-list.md, not the validator's full corpus.
 */

import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACK_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SCHEMA_DIR = join(PACK_ROOT, 'spec', 'schemas');

/** Exactly the phrase every surface must use for this outcome. */
const UNMEASURED = 'schema-valid; conformance unmeasured';

const PROBES_NOT_RUN = ['soft_404', 'cors', 'always_now'];

/**
 * What "schema-valid" does not mean.
 *
 * The schema says a `name` is a string. It cannot say that
 * "Coliseo Mayor (CERRADO)" encodes operational state in a display string
 * (CR-2 / REC010), and it cannot say that `last_updated` advances with the
 * probe clock (BEH002). Both are real non-conformance, both are invisible
 * here, and one of them is checkable from a file — this mode simply does not
 * implement it.
 *
 * Naming that is the difference between a partial answer and a misleading
 * one: without this list, a clean run on an invalid feed reads as approval.
 */
const CHECKS_NOT_RUN = [
  'record semantics beyond the schema (CR-2 status-in-name, locator rule, id shape)',
  'envelope semantics beyond the schema (ttl coherence, permitted_use vs licence)',
  'the full PII corpus — this carries the pattern families, not every rule',
];

/** Keywords this implements. Anything else is a refusal, not a shrug. */
const SUPPORTED = new Set([
  '$schema', '$id', '$defs', '$ref', '$comment', 'title', 'description',
  'default', 'examples', 'deprecated',
  'type', 'required', 'enum', 'const', 'properties', 'items',
  'additionalProperties', 'allOf', 'anyOf', 'oneOf', 'if', 'then', 'else',
  'not', 'pattern', 'format', 'minimum', 'maximum', 'minItems', 'maxItems',
  'minLength', 'maxLength', 'uniqueItems', 'patternProperties',
]);

// --- the tiny validator ------------------------------------------------------

function resolveRef(ref, root) {
  if (!ref.startsWith('#/')) throw new Error(`unsupported $ref: ${ref}`);
  return ref
    .slice(2)
    .split('/')
    .reduce((node, part) => node?.[decodeURIComponent(part)], root);
}

function typeOf(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (Number.isInteger(value)) return 'integer';
  return typeof value;
}

function typeMatches(value, expected) {
  const actual = typeOf(value);
  const wanted = Array.isArray(expected) ? expected : [expected];
  return wanted.some(
    (type) => type === actual || (type === 'number' && actual === 'integer')
  );
}

const FORMATS = {
  'date-time': (v) => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/.test(v),
  uri: (v) => /^[a-z][a-z0-9+.-]*:/i.test(v),
  email: () => true, // not our business; contact values do not travel anyway
};

function validate(value, schema, root, pointer, errors) {
  if (schema === true || schema === undefined) return;
  if (schema === false) {
    errors.push({ pointer, message: 'no value is allowed here' });
    return;
  }

  if (schema.$ref) {
    validate(value, resolveRef(schema.$ref, root), root, pointer, errors);
    return;
  }

  if (schema.type && !typeMatches(value, schema.type)) {
    errors.push({
      pointer,
      message: `expected ${[].concat(schema.type).join(' or ')}, got ${typeOf(value)}`,
    });
    return; // further checks would be noise
  }

  if (schema.enum && !schema.enum.some((option) => option === value)) {
    errors.push({
      pointer,
      message: `must be one of ${schema.enum.map((o) => JSON.stringify(o)).join(' | ')}`,
    });
  }

  if (schema.const !== undefined && value !== schema.const) {
    errors.push({ pointer, message: `must be ${JSON.stringify(schema.const)}` });
  }

  if (typeof value === 'string') {
    if (schema.pattern && !new RegExp(schema.pattern, 'u').test(value)) {
      errors.push({ pointer, message: `does not match ${schema.pattern}` });
    }
    if (schema.minLength != null && value.length < schema.minLength) {
      errors.push({ pointer, message: `shorter than ${schema.minLength}` });
    }
    if (schema.format && FORMATS[schema.format] && !FORMATS[schema.format](value)) {
      errors.push({ pointer, message: `is not a valid ${schema.format}` });
    }
  }

  if (typeof value === 'number') {
    if (schema.minimum != null && value < schema.minimum) {
      errors.push({ pointer, message: `below minimum ${schema.minimum}` });
    }
    if (schema.maximum != null && value > schema.maximum) {
      errors.push({ pointer, message: `above maximum ${schema.maximum}` });
    }
  }

  if (Array.isArray(value)) {
    if (schema.minItems != null && value.length < schema.minItems) {
      errors.push({ pointer, message: `needs at least ${schema.minItems} items` });
    }
    if (schema.items) {
      value.forEach((item, index) =>
        validate(item, schema.items, root, `${pointer}/${index}`, errors)
      );
    }
  }

  if (value && typeof value === 'object' && !Array.isArray(value)) {
    for (const key of schema.required ?? []) {
      if (!(key in value)) {
        // The message the blueprint designed: it names the honest
        // alternative, so an agent cannot "fix" this by inventing a
        // confirmation timestamp.
        const hint =
          key === 'last_confirmed_at'
            ? " (did you mean to publish last_confirmed_at: null?)"
            : '';
        errors.push({
          pointer,
          message: `required property '${key}' is missing${hint}`,
        });
      }
    }
    for (const [key, subschema] of Object.entries(schema.properties ?? {})) {
      if (key in value) {
        validate(value[key], subschema, root, `${pointer}/${key}`, errors);
      }
    }
    if (schema.additionalProperties === false) {
      const known = Object.keys(schema.properties ?? {});
      for (const key of Object.keys(value)) {
        if (!known.includes(key)) {
          errors.push({ pointer: `${pointer}/${key}`, message: 'is not allowed here' });
        }
      }
    }
  }

  for (const subschema of schema.allOf ?? []) {
    validate(value, subschema, root, pointer, errors);
  }

  for (const key of ['anyOf', 'oneOf']) {
    if (!schema[key]) continue;
    const passing = schema[key].filter((option) => {
      const scratch = [];
      validate(value, option, root, pointer, scratch);
      return scratch.length === 0;
    }).length;
    const ok = key === 'anyOf' ? passing >= 1 : passing === 1;
    if (!ok) {
      errors.push({
        pointer,
        message:
          key === 'anyOf'
            ? 'does not match any allowed shape'
            : `must match exactly one allowed shape (matched ${passing})`,
      });
    }
  }

  if (schema.if) {
    const scratch = [];
    validate(value, schema.if, root, pointer, scratch);
    const branch = scratch.length === 0 ? schema.then : schema.else;
    if (branch) validate(value, branch, root, pointer, errors);
  }
}

/** Refuse to run against a schema using a keyword we do not implement. */
function unsupportedKeywords(schema, found = new Set()) {
  if (Array.isArray(schema)) {
    schema.forEach((item) => unsupportedKeywords(item, found));
    return found;
  }
  if (!schema || typeof schema !== 'object') return found;
  for (const [key, value] of Object.entries(schema)) {
    if (!SUPPORTED.has(key) && !key.startsWith('x-')) found.add(key);
    if (key === 'properties' || key === '$defs' || key === 'patternProperties') {
      Object.values(value ?? {}).forEach((sub) => unsupportedKeywords(sub, found));
    } else {
      unsupportedKeywords(value, found);
    }
  }
  return found;
}

// --- the PII pass ------------------------------------------------------------

const DENY_KEYS = [
  'nombre', 'apellido', 'first_name', 'last_name', 'full_name',
  'telefono', 'phone', 'celular', 'movil', 'whatsapp', 'tel', 'tel_fmt',
  'email', 'correo', 'mail',
  'cedula', 'documento', 'nuip', 'identificacion', 'pasaporte', 'passport',
  'direccion_casa', 'direccion_residencia', 'domicilio',
  'foto', 'photo', 'avatar', 'selfie',
  'contacto', 'responsable', 'encargado', 'coordinador', 'solicitante',
];

const DENY_VALUE_PATTERNS = [
  { id: 'PII003', re: /\+?57[ -]?3\d{2}[ -]?\d{3}[ -]?\d{4}/, what: 'a Colombian phone number' },
  { id: 'PII003', re: /\b3\d{9}\b/, what: 'a bare mobile number' },
  { id: 'PII003', re: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/, what: 'an email address' },
  { id: 'PII003', re: /(preguntar por|contactar a|llamar a|hablar con)/i, what: 'a contact instruction in free text' },
];

const ROLE_TOKENS = /^(team|volunteer|official_source|partner:[a-z0-9-]+)$/;

function normalize(key) {
  return key
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
}

function piiFindings(node, pointer, findings) {
  if (Array.isArray(node)) {
    node.forEach((item, index) => piiFindings(item, `${pointer}/${index}`, findings));
    return;
  }
  if (!node || typeof node !== 'object') return;

  for (const [key, value] of Object.entries(node)) {
    const here = `${pointer}/${key}`;
    const flat = normalize(key);

    if (DENY_KEYS.some((deny) => flat.includes(deny))) {
      findings.push({
        id: 'PII001',
        pointer: here,
        message: `contact or person-level values MUST NOT travel in feeds (use contact_available + public_url)`,
        rule: '§7.2 — contact is fetched on demand from the origin, never replicated.',
        fix: `Remove ${key}. Set contact_available: true and rely on public_url.`,
      });
    }

    if (flat === 'confirmed_by' && typeof value === 'string' && !ROLE_TOKENS.test(value)) {
      findings.push({
        id: 'PII002',
        pointer: here,
        message:
          'must be a role token (team|volunteer|official_source|partner:{id}), never a personal name',
        rule: '§6.1 — the verification block carries roles, not people.',
        fix: 'Replace with the role that confirmed it, e.g. "team".',
      });
    }

    // One violation per message (M5). A key that already tripped the
    // deny-list does not also need "and the value looks like a phone number":
    // it is one problem, and two messages invite a half-fix.
    const alreadyFlagged = findings.some(
      (finding) => finding.pointer === here && finding.id === 'PII001'
    );

    if (typeof value === 'string' && !alreadyFlagged) {
      for (const pattern of DENY_VALUE_PATTERNS) {
        if (pattern.re.test(value)) {
          findings.push({
            id: pattern.id,
            pointer: here,
            // The value itself is never echoed — reporting it would copy the
            // thing we are objecting to into a log.
            message: `possible personal data detected (${pattern.what}) — strip before publishing`,
            rule: '§7.1 — free text is the third leak channel.',
            fix: 'Remove the personal data from this field.',
          });
          break;
        }
      }
    }

    piiFindings(value, here, findings);
  }
}

// --- main --------------------------------------------------------------------

const args = process.argv.slice(2).filter((a) => !a.startsWith('-'));
// `validate`, `feed`, `manifest` are command words, not paths.
const target = args.find((a) => !['validate', 'feed', 'manifest', 'probe'].includes(a));

if (!target) {
  console.error('degraded mode needs a local file — it cannot fetch a URL.');
  process.exit(4);
}
if (/^https?:/.test(target)) {
  console.error(
    `degraded mode cannot fetch ${target}.\n` +
      'There is no network and no validator. Point it at a local file, or\n' +
      'install the validator: npx @cabuya/validator'
  );
  process.exit(3);
}
if (!existsSync(target)) {
  console.error(`cannot read ${basename(target)}: no such file`);
  process.exit(4);
}

let document;
try {
  document = JSON.parse(readFileSync(target, 'utf-8'));
} catch (error) {
  console.error(`${basename(target)} is not valid JSON: ${error.message}`);
  process.exit(1);
}

// Pick the schema by shape: a manifest declares `protocol`, a feed has `data`.
const schemaFile = document?.protocol ? 'manifest.schema.json' : 'place-feed.schema.json';
const schemaPath = join(SCHEMA_DIR, schemaFile);
if (!existsSync(schemaPath)) {
  console.error(`vendored schema missing: ${schemaFile}`);
  process.exit(5);
}
const schema = JSON.parse(readFileSync(schemaPath, 'utf-8'));

const unknown = unsupportedKeywords(schema);
if (unknown.size > 0) {
  console.error(
    `This reduced validator does not implement: ${[...unknown].join(', ')}.\n` +
      'Refusing to report a result it did not fully check.\n' +
      'Install the real validator: npx @cabuya/validator'
  );
  process.exit(5);
}

const structural = [];
validate(document, schema, schema, '', structural);

const pii = [];
piiFindings(document, '', pii);

const findings = [
  ...structural.map((error) => ({
    id: 'REC001',
    severity: 'error',
    pointer: error.pointer || '/',
    message: error.message,
    rule: 'Structural requirement from the vendored schema.',
    fix: 'Correct the field named in the pointer.',
  })),
  ...pii.map((finding) => ({ ...finding, severity: 'error' })),
];

const report = {
  validator: 'degraded (cabuya-skill)',
  spec_version: existsSync(join(PACK_ROOT, 'spec/VERSION'))
    ? readFileSync(join(PACK_ROOT, 'spec/VERSION'), 'utf-8').trim()
    : 'unknown',
  target,
  degraded: true,
  measured_level: null,
  summary: {
    errors: findings.filter((f) => f.severity === 'error').length,
    warnings: 0,
    infos: 0,
    // The one phrase. Not "conforming", not "passes", not "looks good".
    outcome: findings.length === 0 ? UNMEASURED : 'schema errors found; conformance unmeasured',
  },
  probes_not_run: PROBES_NOT_RUN,
  checks_not_run: CHECKS_NOT_RUN,
  findings,
};

const wantsJson = process.argv.includes('--format=json') || process.argv.includes('json');

if (wantsJson) {
  process.stdout.write(JSON.stringify(report, null, 2) + '\n');
} else {
  for (const finding of findings) {
    process.stdout.write(`${finding.severity}  ${finding.id}  ${finding.pointer || '/'}\n`);
    process.stdout.write(`       ${finding.message}\n`);
    if (finding.fix) process.stdout.write(`       fix: ${finding.fix}\n`);
    process.stdout.write('\n');
  }
  process.stdout.write(`${report.summary.outcome}\n\n`);
  process.stdout.write(
    `Probes not run (they need a deployed URL): ${PROBES_NOT_RUN.join(', ')}\n`
  );
  process.stdout.write('Checks not implemented in degraded mode:\n');
  for (const check of CHECKS_NOT_RUN) {
    process.stdout.write(`  · ${check}\n`);
  }
  process.stdout.write(
    '\nA clean run here means well-formed, not conforming.\n'
  );
}

process.exit(report.summary.errors > 0 ? 1 : 0);
