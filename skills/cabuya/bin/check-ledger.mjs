/**
 * Validate an adoption ledger against plan/adoption.schema.json.
 *
 * The ledger is the file that lets a second session trust the first one, so
 * checking it must work everywhere the pack works: offline, with no installed
 * dependencies. This implements exactly the JSON Schema subset the adoption
 * schema uses, and — like bin/degraded-check.mjs, whose pattern it follows —
 * refuses to run against a schema using a keyword it does not implement
 * (exit 5). Silently ignoring an unknown keyword is how a partial validator
 * becomes a wrong one.
 *
 * Deliberately self-contained rather than sharing a module with
 * degraded-check.mjs: the test harness copies these tools into sandboxes one
 * file at a time, and a tool that needs a sibling to run is a tool that
 * breaks when copied. Two small validators that each state their subset beat
 * one shared one that neither can carry.
 *
 *   node bin/check-ledger.mjs <path-to-adoption.json>
 *
 * Exit 0: valid. Exit 1: invalid, with one line per finding. Exit 4: cannot
 * read the file. Exit 5: the schema outgrew this checker.
 */

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACK_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SCHEMA_PATH = join(PACK_ROOT, 'plan', 'adoption.schema.json');

/** Keywords this implements. Anything else is a refusal, not a shrug. */
const SUPPORTED = new Set([
  '$schema', '$id', 'title', 'description',
  'type', 'required', 'enum', 'const', 'properties', 'items',
  'additionalProperties', 'if', 'then', 'pattern', 'format',
  'maxLength', 'maxItems',
]);

const FORMATS = {
  'date-time': (v) =>
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/.test(v),
};

function typeOf(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (Number.isInteger(value)) return 'integer';
  return typeof value;
}

function unsupportedKeywords(schema, found = new Set()) {
  if (Array.isArray(schema)) {
    schema.forEach((item) => unsupportedKeywords(item, found));
    return found;
  }
  if (!schema || typeof schema !== 'object') return found;
  for (const [key, value] of Object.entries(schema)) {
    if (!SUPPORTED.has(key)) found.add(key);
    if (key === 'properties') {
      Object.values(value ?? {}).forEach((sub) => unsupportedKeywords(sub, found));
    } else if (key !== 'required' && key !== 'enum') {
      unsupportedKeywords(value, found);
    }
  }
  return found;
}

function validate(value, schema, pointer, errors) {
  if (schema === true || schema === undefined) return;
  if (schema === false) {
    errors.push(`${pointer}: no value is allowed here`);
    return;
  }

  if (schema.type && typeOf(value) !== schema.type) {
    errors.push(`${pointer}: expected ${schema.type}, got ${typeOf(value)}`);
    return; // further checks would be noise
  }

  if (schema.enum && !schema.enum.includes(value)) {
    errors.push(
      `${pointer}: must be one of ${schema.enum.map((o) => JSON.stringify(o)).join(' | ')}`
    );
  }

  if (schema.const !== undefined && value !== schema.const) {
    errors.push(`${pointer}: must be ${JSON.stringify(schema.const)}`);
  }

  if (typeof value === 'string') {
    if (schema.pattern && !new RegExp(schema.pattern, 'u').test(value)) {
      errors.push(`${pointer}: does not match ${schema.pattern}`);
    }
    if (schema.maxLength != null && value.length > schema.maxLength) {
      errors.push(`${pointer}: longer than ${schema.maxLength}`);
    }
    if (schema.format && FORMATS[schema.format] && !FORMATS[schema.format](value)) {
      errors.push(`${pointer}: is not a valid ${schema.format}`);
    }
  }

  if (Array.isArray(value)) {
    if (schema.maxItems != null && value.length > schema.maxItems) {
      errors.push(`${pointer}: more than ${schema.maxItems} items`);
    }
    if (schema.items) {
      value.forEach((item, index) =>
        validate(item, schema.items, `${pointer}/${index}`, errors)
      );
    }
  }

  if (value && typeOf(value) === 'object') {
    for (const key of schema.required ?? []) {
      if (!(key in value)) {
        errors.push(`${pointer}: required property '${key}' is missing`);
      }
    }
    for (const [key, subschema] of Object.entries(schema.properties ?? {})) {
      if (key in value) {
        validate(value[key], subschema, `${pointer}/${key}`, errors);
      }
    }
    if (schema.additionalProperties === false) {
      const known = Object.keys(schema.properties ?? {});
      for (const key of Object.keys(value)) {
        if (!known.includes(key)) {
          errors.push(`${pointer}/${key}: is not allowed here`);
        }
      }
    }
    if (schema.if) {
      const scratch = [];
      validate(value, schema.if, pointer, scratch);
      if (scratch.length === 0 && schema.then) {
        validate(value, schema.then, pointer, errors);
      }
    }
  }
}

// --- main --------------------------------------------------------------------

const target = process.argv[2];
if (!target) {
  console.error('usage: node bin/check-ledger.mjs <path-to-adoption.json>');
  process.exit(4);
}
if (!existsSync(target)) {
  console.error(`cannot read ${target}: no such file`);
  process.exit(4);
}

const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));

const unknown = unsupportedKeywords(schema);
if (unknown.size > 0) {
  console.error(
    `the adoption schema uses keywords this checker does not implement: ` +
      `${[...unknown].join(', ')}.\n` +
      'Extend bin/check-ledger.mjs rather than letting it half-check a ledger.'
  );
  process.exit(5);
}

let ledger;
try {
  ledger = JSON.parse(readFileSync(target, 'utf8'));
} catch (error) {
  console.error(`${target} is not JSON: ${error.message}`);
  process.exit(1);
}

const errors = [];
validate(ledger, schema, '', errors);

if (errors.length > 0) {
  for (const line of errors) console.error(`  ✗ ${line || '/'}`);
  console.error(`\n${errors.length} finding(s) — this ledger does not conform to contract 1.x`);
  process.exit(1);
}

console.log('✓ ledger conforms to the adoption contract');
