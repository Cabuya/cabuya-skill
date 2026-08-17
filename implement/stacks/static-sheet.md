# A spreadsheet, and no backend

For a team with no developer and no application — a coordination group running
on a shared sheet. This is the largest group of potential publishers in the
ecosystem and the one every other guide leaves out.

The premise is that **even an afternoon of agent-assisted work is too much**
mid-emergency. Adding one row of hashtags to a spreadsheet is not.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.** The tag dictionary below is fixed; what each column in a
particular sheet actually *means* is not, and that is the part that decides
whether the feed is honest.

## 1. Fingerprints

There is no repository to fingerprint. You are here when the answer to "where
does your data live?" is a Google Sheet, an Excel file, an Airtable, or a CSV
somebody mails around.

Signals that this is the right guide: no `package.json` anywhere; the "site" is
a Linktree, a Facebook page, or nothing; the data is maintained by people who
are not developers and who are, right now, busy.

## 2. What HXL is, and why it is the on-ramp

[HXL](https://hxlstandard.org) is a tagging convention for spreadsheets: **one
extra row, directly under the headers**, carrying machine-readable hashtags.
Humans keep reading the sheet exactly as before; a converter can now read it
too.

```
| Nombre del punto | Dirección       | Municipio | Cupos | Ocupados |
| #loc+name        | #loc+address    | #adm2     | #cap  | #reached |   ← HXL row
| Coliseo Mayor    | Av. 30 de Agosto| Pereira   | 200   | 150      |
| Acopio Kennedy   | Parque principal| Pereira   |       |          |
```

That row is the entire integration. No export, no migration, no new tool for
the people maintaining the data — which is the point, because they are not
going to adopt one this week.

An HXL-tagged sheet at a stable URL is an accepted **generator input**. It does
not add a second canonical format: the converter produces the JSON feed, and
**conformance is measured on the produced feed**, never on the sheet.

## 3. The tag dictionary

| HXL tag | `place` field | Notes |
|---|---|---|
| `#loc+name` | `name` | Required. Must not encode status (CR-2) — `"Coliseo (LLENO)"` is a finding. |
| `#loc+address` | `address_text` | The locator, unless coordinates are present. |
| `#geo+lat` / `#geo+lon` | `lat` / `lon` | Both or neither. |
| `#adm2` | `municipality_code` | Municipality **name** in most sheets — the converter resolves it to DIVIPOLA and reports what it could not. |
| `#adm2+code` | `municipality_code` | Already a code. Preferred. |
| `#loc+type` / `#sector` | `place_kind` + `origin_category` | Through the crosswalk; the raw value is always kept. |
| `#status` | `lifecycle_status` | Mapped conservatively — see below. |
| `#date+updated` | `updated_at` | The row's edit date. **Not** a confirmation. |
| `#date+checked` | `last_confirmed_at` | Only if it genuinely records somebody checking. |
| `#cap` | `capacity_total` | Extended profile. |
| `#reached` | `capacity_used` | Extended profile. |
| `#meta+url` | `public_url` | Required — see below when there is no site. |
| `#description` | `description` | Free text. **Screened**, always. |
| **`#contact+phone`** | — | **Dropped.** |
| **`#contact+email`** | — | **Dropped.** |
| **`#contact+name`** | — | **Dropped.** |

### The converter drops contact columns

`#contact+phone` appears in HXL's own canonical examples, so a sheet that
follows the standard well will have one. It still does not travel: contact is
`public_url` plus link-out, fetched on demand from the origin under the
origin's own consent model.

**Drop these columns rather than failing on them.** That is deliberate — a
hard failure would strand exactly the teams this on-ramp exists for, and the
sheet is their working tool, not a publication artefact. Report what was
dropped, every run, by column name.

The one exception is a **declared institutional** contact: an organization's
switchboard or role address, published by that organization, declared as such
by a human before the conversion is written. Never a person's number, however senior, and never a
volunteer's mobile. If the sheet mixes both in one column — and it usually
does — the column is dropped and that is the right outcome.

## 4. The mapping worksheet, and the two hard questions

The tags do most of the mapping. Two things still need a human.

**`public_url` is required, and a sheet-only publisher has no per-record
page.** Real options, in order of preference:

1. A page per record on any site the team controls, even a simple one.
2. A single public page describing the operation, used for every record. Honest
   and conforming: it is where a person goes for more, which is what the field
   is for.
3. The published view of the sheet itself, if the team is content for it to be
   public — check what else is on it first, including hidden columns and other
   tabs.

**`last_confirmed_at`.** Most sheets have a "last updated" column and no
confirmation concept. Then it is `null`, on every row, present. A sheet where
somebody physically visits and ticks a column *does* have a confirmation
event, and that is `#date+checked`.

Do not accept "the sheet is kept up to date" as a confirmation event. Ask what
the column means when it changes: if the answer is "somebody edited the row",
it is `updated_at`.

## 5. Converting

**The agent does this conversion.** The blueprint names two converters — this
skill and the validator's `convert` mode — and **`convert` is not in the
shipped CLI yet**. Do not tell a team to run it; `npx cabuya-validator --help`
lists `validate`, `explain`, `checks` and `init`, and nothing else.

So write the converter. It is about forty lines, it lives in the team's
repository, and it is the artefact that keeps working after you leave.

```js
// scripts/sheet-to-cabuya.mjs
//
// Reads the HXL-tagged sheet and writes the Cabuya feed.
// The hashtag row is the mapping; this script is the machinery.

import { writeFile, mkdir } from 'node:fs/promises';

// Use a real CSV parser — `csv-parse/sync`, or the team's existing one. A
// split on commas breaks on the first address containing one, and addresses
// in this dataset contain commas constantly ("Mz 7 y 8, Villa Consota").
import { parse as parseCsv } from 'csv-parse/sync';

const SHEET_CSV = process.env.SHEET_CSV_URL;
const PUBLISHER_ID = 'example-app';
const SITE = 'https://example.invalid';
const MUNICIPALITY = { pereira: '66001' }; // verify — mapping/divipola.md

// Tags that must never reach the feed. Contact is public_url plus link-out,
// fetched from the origin under the origin's own consent model — a hashtag
// does not change that. Dropped rather than fatal: a hard failure would
// strand exactly the teams this on-ramp exists for.
const DROP = new Set(['#contact+phone', '#contact+email', '#contact+name']);

const FIELD = {
  '#loc+name': 'name',
  '#loc+address': 'address_text',
  '#geo+lat': 'lat',
  '#geo+lon': 'lon',
  '#adm2+code': 'municipality_code',
  '#date+checked': 'last_confirmed_at',
  '#meta+url': 'public_url',
  '#description': 'description',
};

const rows = parseCsv(await (await fetch(SHEET_CSV)).text(), { relax_column_count: true });
const [headers, tags, ...data] = rows;

const dropped = tags.filter((tag) => DROP.has(tag));
for (const tag of dropped) {
  console.warn(`dropped: ${tag} (column "${headers[tags.indexOf(tag)]}")`);
}

const places = data.map((row, index) => {
  const place = {
    id: String(index + 1),
    publisher_id: PUBLISHER_ID,
    lifecycle_status: 'active',
    source: { source_id: PUBLISHER_ID, source_kind: 'first_party' },

    // No #date+checked column means no confirmation event. Present and null —
    // never filled from a "last updated" column, which records an edit.
    last_confirmed_at: null,
  };

  tags.forEach((tag, column) => {
    if (DROP.has(tag) || !FIELD[tag]) return;
    const value = row[column]?.trim();
    if (value) place[FIELD[tag]] = value;
  });

  return place;
});

await mkdir('cabuya', { recursive: true });
await writeFile(
  'cabuya/places.json',
  JSON.stringify(
    {
      last_updated: new Date().toISOString(), // the run IS the publication
      ttl: 21600,
      version: '0.1.0',
      publisher_id: PUBLISHER_ID,
      license: 'CC-BY-4.0',
      permitted_use: ['display', 'aggregate'],
      data: { places },
    },
    null,
    2
  )
);

console.log(`Wrote ${places.length} places; dropped ${dropped.length} columns.`);
```

Then validate what it produced — that part *does* exist:

```bash
npx cabuya-validator validate cabuya/places.json --no-network
```

**Report every drop and every unresolved value to the team, by column name:**

```
Read 42 rows, 11 tagged columns.
  dropped: #contact+phone (column "Teléfono")   — §7.2, contact never travels
  dropped: #contact+name  (column "Encargado")  — §7.1, person-level
  resolved: #adm2 "Pereira" → 66001 (39 rows)
  UNRESOLVED: #adm2 "Pereria" → ? (3 rows)      — typo? fix in the sheet
  last_confirmed_at: null on all rows (no #date+checked column)
```

**The unresolved municipalities are the human's decision, not yours.** Do not
guess at a typo: "Pereria" could be a misspelling of Pereira or a real place in
another department, and picking wrong files a record in the wrong municipality
— findable by nobody who needs it.

### The stable URL

The sheet must be published at a URL that does not change, and it must be
readable without a login. For Google Sheets that is File → Share → Publish to
web, then the CSV export link.

**Look at the whole sheet before publishing it**, including other tabs and
hidden columns. "Publish to web" publishes what you point it at, and a second
tab named `voluntarios` is a person-level dataset one click from public.

## 6. Hosting the produced feed

The script outputs a file. It still has to be served, and the requirements
are the ordinary ones.

**GitHub Pages** is the usual answer for a team with no host: free, serves
dot-directories, sends `Access-Control-Allow-Origin: *` on everything by
default.

```
your-repo/
├── .well-known/cabuya.json
├── cabuya/places.json
└── robots.txt
```

Add a scheduled action so the feed follows the sheet:

```yaml
# .github/workflows/cabuya.yml
name: Cabuya feed
on:
  schedule: [{ cron: '0 */6 * * *' }]
  workflow_dispatch: {}
permissions:
  contents: write
jobs:
  convert:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '24' }
      - run: node scripts/sheet-to-cabuya.mjs
        env:
          SHEET_CSV_URL: ${{ vars.SHEET_CSV_URL }}
      - run: npx cabuya-validator validate cabuya/places.json --no-network
      - run: |
          # Only commit when the data changed. Otherwise `last_updated` becomes
          # a heartbeat every six hours rather than a data signal, which is the
          # always-now anti-pattern with extra steps.
          if git diff --quiet -- cabuya/places.json; then
            echo "No change."; exit 0
          fi
          git config user.name "cabuya-feed[bot]"
          git config user.email "cabuya-feed@users.noreply.github.com"
          git commit -am "chore(cabuya): regenerate feed from the sheet"
          git push
```

**Set `ttl` to the schedule.** Six-hourly conversion with `ttl: 900` tells
consumers to re-poll every fifteen minutes for data that cannot change more
than four times a day.

## 7. Honest limits

**The behavioural probes still apply to the produced feed's hosting.** The
converter can make the JSON right; it cannot make the host serve it correctly.
Soft-404, CORS and always-now are measured where the file is served, so the
discovery checks in every other guide apply here unchanged.

**A conversion is not a conformance measurement.** The script reports what it
read and what it dropped. `validate` reports conformance, and only against the
deployed URL. Do not tell a team they are L2 because the file converted.

**The sheet keeps its own risks.** The script reads a snapshot. If somebody
adds a `Teléfono` column next week, the next run drops it and reports the drop
— and if somebody puts a phone number into the `Dirección` column, the free-text
screen is what catches it, imperfectly. Say this out loud to the team: **the
column that leaks is usually the one nobody planned to use that way.**

## 8. Hand-off

Left behind: the tagged sheet, a repository with the workflow, the manifest,
the feed, a `robots.txt`, and a `CABUYA.md` written for a **non-developer
audience** — this is the one stack where the person maintaining it may never
open a terminal.

Say plainly, in that file: what the hashtag row does, that deleting it breaks
the feed, which columns are dropped and why, and who to ask. Then run
`publish-status`.
