# Templates

Starting points, not drop-ins. Adapt to the app's actual shape — the value
here is the parts that are easy to get wrong, and those are the same in every
stack:

- the envelope's required fields;
- `last_updated` set at **build or publish time**, never per request;
- `Access-Control-Allow-Origin: *` on the feed response, scoped to that route;
- `public_url` derived per record;
- `last_confirmed_at` present on every record, `null` when there is no
  confirmation event.

| File | For |
|---|---|
| [`manifest.json`](manifest.json) | Every stack. Validated against the vendored schema in CI. |
| [`serializer-build-time.md`](serializer-build-time.md) | Static sites, SPAs, anything with no server. The default. |
| [`serializer-route-handler.md`](serializer-route-handler.md) | Next.js, Laravel, Django — an app that already serves requests. |
| [`serializer-cron.md`](serializer-cron.md) | Data that changes faster than deploys, on a host with scheduled jobs. |
| [`CABUYA.md`](CABUYA.md) | What you leave in the adopter's repository. |

## Which one

**Prefer build-time.** It is the cheapest thing that conforms, and it cannot
accidentally implement the always-now anti-pattern — a build runs when it
runs, so `last_updated` is honest by construction.

Reach for a route handler when the data genuinely changes between deploys and
the app already has a server. Reach for cron when it changes faster than
deploys and there is no server.

The choice is not permanent. A publisher that starts with a build-time export
and later needs freshness moves to cron without changing a single field
mapping.

## The manifest template

`manifest.json` is written for `conformance_target: "L2"` with one Core feed.
Change `publisher_id`, `canonical_url`, the feed `url`, the licence and the
municipality code; delete `municipality_code` if the feed is not a
municipality shard; delete `aliases` and `contact` if there are none.

**`contact` is org-level only** — a role address published by the
organization, like `datos@example.org`. Never a person's.

The `publisher_id` is registry-assigned. If the app is not in the registry
yet, use the token it intends to request and note in `CABUYA.md` that
`publish-status` confirms it. Do not invent one that looks official.
