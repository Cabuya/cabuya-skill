# Scheduled job

For data that changes faster than deploys, on a host with no application
server — or where you want the feed generated off the request path entirely.

Same code as [`serializer-build-time.md`](serializer-build-time.md). The only
difference is what runs it and where the output lands.

`last_updated` is the job's run time, which is honest: the feed genuinely was
regenerated then. This is the one shape where a "now" timestamp is correct,
because the job *is* the publication event.

## GitHub Actions → committed file

The simplest thing that works, and it comes with an audit trail: every
regeneration is a commit, so a broken pipeline is visible in the history
rather than inferred from a stale timestamp.

```yaml
# .github/workflows/cabuya-feed.yml
name: Cabuya feed

on:
  schedule:
    - cron: '*/15 * * * *'
  workflow_dispatch: {}

permissions:
  contents: write

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
      - run: npm ci
      - run: node scripts/build-cabuya-feed.mjs
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}

      - name: Commit only when the data changed
        run: |
          # `git diff --quiet` exits non-zero when there is a change. Without
          # this guard the job commits every 15 minutes forever, and
          # `last_updated` becomes a heartbeat rather than a data signal —
          # which is the always-now anti-pattern with extra steps.
          if git diff --quiet -- public/cabuya/places.json; then
            echo "No change."
            exit 0
          fi
          git config user.name "cabuya-feed[bot]"
          git config user.email "cabuya-feed@users.noreply.github.com"
          git add public/cabuya/places.json
          git commit -m "chore(cabuya): regenerate place feed"
          git push
```

> **The `git diff --quiet` guard is the point of this file.** Regenerating
> `last_updated` on a schedule when nothing changed is the same lie as
> regenerating it per request, just slower. Only publish a new timestamp when
> the data behind it actually moved.

## Supabase Edge Function on a schedule

```ts
// supabase/functions/cabuya-feed/index.ts
//
// Writes the feed to Supabase Storage, served from a public bucket.
// Schedule with pg_cron:
//   select cron.schedule('cabuya-feed', '*/15 * * * *',
//     $$ select net.http_post('https://<project>.functions.supabase.co/cabuya-feed') $$);

import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data: rows, error } = await supabase
    .from('albergues')
    .select('id, nombre, tipo, direccion, activo, updated_at');

  if (error) {
    // Do not write a partial or empty feed on failure. The previous one is
    // stale; an empty one is wrong, and consumers cannot tell the difference.
    return new Response(`query failed: ${error.message}`, { status: 500 });
  }

  const feed = {
    last_updated: new Date().toISOString(),
    ttl: 900,
    version: '0.1.0',
    publisher_id: 'example-app',
    license: 'CC-BY-4.0',
    permitted_use: ['display', 'aggregate'],
    // toPlace() is the mapping function from serializer-build-time.md —
    // identical here, because the mapping never depends on what triggers it.
    // The three things it must get right are the same in every stack:
    //   last_confirmed_at: present on every record, null when there is no
    //                      confirmation event (never mapped from updated_at)
    //   public_url:        derived per record, the link-out that makes the
    //                      no-contact rule workable
    //   origin_category:   the publisher's own value, verbatim
    data: { places: rows.map(toPlace) },
  };

  await supabase.storage
    .from('public')
    .upload('cabuya/places.json', JSON.stringify(feed, null, 2), {
      contentType: 'application/json',
      upsert: true,
      cacheControl: '900',
    });

  return new Response(`ok: ${feed.data.places.length} places`);
});
```

Storage buckets set CORS at the bucket level — confirm the public bucket
returns `Access-Control-Allow-Origin: *` before declaring L2, and make sure
the bucket does not also hold anything person-level.

## Choosing the interval

The interval and the feed's `ttl` are the same promise stated twice. A `ttl`
of 900 with a job that runs hourly tells consumers to re-poll four times more
often than the data can possibly change.

Set `ttl` to the job interval, and be honest about how often the underlying
data really moves. A feed regenerated every 15 minutes from a table edited
twice a day should say `ttl: 900` only if you want the freshness *checked*
that often — not to look busy.

## Failure is a first-class case

If the job fails, **the old feed stays up and gets old**. That is the correct
behaviour: consumers can see `last_updated` receding and act on it, which is
exactly what the field is for.

What must not happen is a job that fails and writes an empty feed anyway. An
empty `places[]` is a claim that there are no shelters. Fail loudly, write
nothing, and let the timestamp tell the truth.
