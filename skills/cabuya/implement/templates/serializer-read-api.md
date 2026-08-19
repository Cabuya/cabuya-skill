# Read API

For publishers stepping up from a static feed toward L3. The spec's §3.2
equivalence rule is the whole trick: **a static feed is a degenerate read
API** — the feed's `data.places[]` and the API's items MUST be byte-compatible
per record, and conformance tooling tests both with the same schema.

So the floor of a read API is not a new pipeline. It is a route handler that
serves the **same document** your static serializer already produces.

## Start from what you have

Take the output of [`serializer-build-time.md`](serializer-build-time.md) (or
the [`serializer-route-handler.md`](serializer-route-handler.md) you already
run) and serve it from a route. Same envelope, same records, same
`Access-Control-Allow-Origin: *`, same `application/json`. If the static file
and the API answer differ by one byte per record, that is the non-conformance
— not a style issue.

```js
// The floor. The same document the static feed serves, from a route.
app.get('/cabuya/places.json', (req, res) => {
  res
    .set('Access-Control-Allow-Origin', '*')
    .type('application/json')
    .send(serializePlaces(loadRows())); // the SAME serializer the file uses
});
```

## When to step up from static at all

Two honest reasons, and only two:

- **Freshness** the build or cron cadence cannot meet — records that change
  faster than you re-export.
- **Volume**: when one document stops being reasonable, paginate with
  `next_cursor` in the envelope. A consumer follows the cursor until it is
  absent; the concatenation of pages is the feed.

No freshness or volume pressure? Stay static. It is the cheapest thing that
conforms, and it cannot accidentally implement the always-now anti-pattern.

## What L3 measurement checks

- **Byte-compatibility per record** between the feed and the API items —
  check family `API`, e.g. `API001`. Sharing one serializer makes this
  unfailable; maintaining two makes it a matter of time.
- The same schema, the same CORS and content-type requirements as the static
  feed (§3).
- `last_updated` still describes the **data**, never the response — BEH002
  applies to a route handler with more force, because now there is a request
  to regenerate it in. See the rule in
  [`serializer-route-handler.md`](serializer-route-handler.md).

## What this does not change

The manifest still declares whichever URL you serve — file or route, it is
the same feed entry. The crosswalk, the PII gate, and the honesty rules are
identical: `last_confirmed_at` still maps from a real confirmation event or
is `null` — never from `updated_at` (CR-1) — and status stays out of names
(CR-2). This is a transport, not a new pipeline — and the level it earns is
whatever the validator measures, stated by the validator, not by you.
