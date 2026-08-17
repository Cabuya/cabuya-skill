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

**The converter drops these columns rather than failing on them.** That is
deliberate — a hard failure would strand exactly the teams this on-ramp exists
for, and the sheet is their working tool, not a publication artefact. It
reports what it dropped, every run, by column name.

The one exception is a **declared institutional** contact: an organization's
switchboard or role address, published by that organization, declared as such
in the conversion config. Never a person's number, however senior, and never a
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

```bash
npx cabuya-validator convert \
  --input "https://docs.google.com/spreadsheets/d/…/export?format=csv" \
  --publisher-id example-app \
  --municipality 66001 \
  --site https://example.invalid \
  --output places.json
```

It reports what it did, including what it dropped:

```
Read 42 rows, 11 tagged columns.
  dropped: #contact+phone (column "Teléfono")   — §7.2, contact never travels
  dropped: #contact+name  (column "Encargado")  — §7.1, person-level
  resolved: #adm2 "Pereira" → 66001 (39 rows)
  UNRESOLVED: #adm2 "Pereria" → ? (3 rows)      — typo? fix in the sheet
  last_confirmed_at: null on all rows (no #date+checked column)
Wrote places.json — 42 places, profile core.
```

**The unresolved municipalities are the human's decision, not the converter's.**
It does not guess at a typo, because "Pereria" could be a misspelling of
Pereira or a real place in another department, and picking wrong files a record
in the wrong municipality — findable by nobody who needs it.

### The stable URL

The sheet must be published at a URL that does not change, and it must be
readable without a login. For Google Sheets that is File → Share → Publish to
web, then the CSV export link.

**Look at the whole sheet before publishing it**, including other tabs and
hidden columns. "Publish to web" publishes what you point it at, and a second
tab named `voluntarios` is a person-level dataset one click from public.

## 6. Hosting the produced feed

The converter outputs a file. It still has to be served, and the requirements
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
      - run: |
          npx cabuya-validator convert \
            --input "${{ vars.SHEET_CSV_URL }}" \
            --publisher-id example-app \
            --municipality 66001 \
            --site https://example.invalid \
            --output cabuya/places.json
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

**A conversion is not a conformance measurement.** The converter reports
schema validity. `validate` reports conformance, and only against the deployed
URL. Do not tell a team they are L2 because the file converted.

**The sheet keeps its own risks.** The converter reads a snapshot. If somebody
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
