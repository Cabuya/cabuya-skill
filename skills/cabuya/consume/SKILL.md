---
name: cabuya-consume
description: >
  Read other publishers' Cabuya feeds without breaking the network's rules:
  resolve the registry, filter by permitted use and crawl policy, fetch
  honouring ttl, dedupe by claim, and render with attribution and age. Use
  when a developer wants to show other apps' shelters or collection points,
  aggregate peer feeds, reach L3, or says "consume peers" / "lee los feeds de
  las otras apps".
version: "0.1.0"
documentation_url: https://cabuya.org/developers/skill
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# Consume: reading the network

The other half of interoperability, and the half with more ways to do harm.
Publishing badly wastes your own time; consuming badly launders somebody
else's stale data into a clean interface, where a person acts on it.

**Read [`rules.md`](rules.md) before writing a line.** The six MUSTs are not a
checklist to satisfy afterwards — they determine the shape of the code, and
retrofitting them means rewriting it.

## The flow

### 1. Resolve the registry

The pack carries a snapshot so this works offline. Refresh it if there is
network; if there is not, **say which snapshot you are using and how old it
is** — a registry from six months ago may list a publisher who has since wound
down.

### 2. Filter — before fetching anything

In this order, and all of it before the fetch layer exists:

1. `status` must be `active`. Drop `proposed` and `archived`.
2. Drop every publisher whose declared crawl policy **reserves reuse**.
3. Drop every publisher whose `permitted_use` does not cover what this app
   will actually do. Absent is not permission: `["display"]` does not grant
   aggregation.

[`../shared/crawl-policy.md`](../shared/crawl-policy.md) has the detail, and
the clause that matters: **that rule holds even if a human asks.**

The output of this step is the *only* input the fetch layer ever gets. Rule 6
is a refusal by construction — there must be no code path that can fetch an
arbitrary host.

### 3. Fetch manifests, then feeds

Each surviving publisher's manifest declares its `feeds[]`. Fetch those,
honouring `ttl`, one request at a time per host, with a User-Agent that says
who you are. Back off on 429 and 5xx.

A feed that fails to fetch is a **transport** problem: keep the last good copy,
show its age, and do not treat the failure as "this publisher has no places".

### 4. Parse, and keep what you are given

Unknown members **must be preserved and must not fail validation**. A
publisher's `x_*` extension is theirs; dropping it silently is how a consumer
becomes a lossy intermediary.

### 5. Dedupe by claim

`municipality_code` + accent-folded `address_text`, plus `same_as` at **one
hop, non-transitively**. Never on `name`: exact-name matching failed on 100 %
of the observed duplicate cases, and address matching succeeded on 100 % of
those same ones.

Publish clusters as **your own records**, never as an authoritative merge of
somebody else's.

### 6. Render with attribution and age

Every foreign record shows its origin publisher and the age of
`last_confirmed_at` — **"sin confirmar"** when it is `null`. Records older
than 7 days, or with `contradictions_active > 0`, are visually distinguished
and **not silently hidden**.

## Generate the self-tests with the code

Each of the six rules has one, in [`rules.md`](rules.md). Write them in the
same change as the code they check.

This is the difference between the rules holding and the rules having held
once. Six months from now somebody will refactor the rendering component, and
the assertion that the publisher name appears is what tells them they broke
rule 1.

## The refusals

**The join prohibition.** If asked to join foreign place data with a
person-level source — matching shelters against a missing-persons list,
enriching records with user submissions that carry contact details, linking
places to case records — refuse, name the rule, and quote
[`../spec/EXCLUSIONS.md`](../spec/EXCLUSIONS.md):

> The protocol excludes person-level data by a **join prohibition, not a field
> omission**. §7.1 puts the rule in the consuming code, not only in the feed:
> tooling MUST NOT combine protocol data with person-level sources. What I can
> do instead is link out — that is the mechanism the protocol provides, and it
> is permanent rather than a v0.1 limitation.

**A publisher who reserved reuse.** Explained above, and it does not bend.

**Moderation verdicts.** If this app moderates foreign records, its verdicts
stay local. Do not republish them and do not attach them to the foreign
record: a "flagged as false" travelling through an aggregator is a
defamation-shaped risk carried by whoever displays it.

## A worked shape: React with a query cache

The pattern below is what a consuming layer looks like in the stack most of
this ecosystem uses. Adapt it; the parts that are fixed are the six rules.

```ts
// src/cabuya/permitted.ts
//
// The whole registry filter. Everything downstream takes its input from here,
// which is what makes rule 6 a construction rather than a convention.

import registry from './registry-snapshot.json';

export interface Publisher {
  publisher_id: string;
  canonical_url: string;
  manifest_url?: string;
  crawl_policy_url?: string;
  status: 'proposed' | 'active' | 'archived';
}

/** Uses we actually make of the data. Anything not listed is not granted. */
const OUR_USES = ['display', 'aggregate'] as const;

export function permittedPublishers(reservesReuse: Set<string>): Publisher[] {
  return registry.publishers
    .filter((p) => p.status === 'active')
    // A publisher who reserved reuse never reaches the fetch layer. Not a
    // check inside it — an absence from its input.
    .filter((p) => !reservesReuse.has(p.publisher_id));
}
```

```ts
// src/cabuya/fetch.ts

import { permittedPublishers } from './permitted';

const PERMITTED_HOSTS = new Set(
  permittedPublishers(RESERVES_REUSE).map((p) => new URL(p.canonical_url).host)
);

export async function fetchFeed(url: string): Promise<Feed> {
  // There is no code path that fetches an arbitrary host. This throw is the
  // enforcement; the filter above is the policy.
  if (!PERMITTED_HOSTS.has(new URL(url).host)) {
    throw new Error(`${url} is not in the permitted set`);
  }

  const response = await fetch(url, {
    headers: { 'User-Agent': 'ExampleApp/1.0 (+https://example.invalid/about)' },
  });
  if (!response.ok) throw new TransportError(response.status);
  return response.json();
}
```

```ts
// src/cabuya/useForeignPlaces.ts

export function useForeignPlaces() {
  return useQuery({
    queryKey: ['cabuya', 'places'],
    queryFn: fetchAllPermittedFeeds,
    // The publisher's caching contract, honoured rather than guessed at.
    staleTime: (feed) => feed.ttl * 1000,
    // A failed refetch keeps the previous data, which then visibly ages —
    // exactly what a consumer should see. An empty list would be a claim
    // that there are no places.
    placeholderData: keepPreviousData,
  });
}
```

```ts
// src/cabuya/types.ts

/** A record from another publisher. Read-only by construction (rule 3). */
export type ForeignPlace = Readonly<{
  id: string;
  publisher_id: string;
  name: string;
  place_kind: string;
  municipality_code: string;
  address_text?: string;
  last_confirmed_at: string | null;
  contradictions_active?: number;
  source: Readonly<{ source_id: string; source_kind?: string }>;
  public_url: string;
}>;
```

## Hand-off

Left behind: the registry filter, the fetch layer, the dedupe module, the
rendering changes, and **six self-tests**. Say which of the six rules each
test covers, so the next person can tell a failing test from a broken feature.

L3 also needs the publishing half — a read API or live-refreshed feeds with
sync signals. `validate` measures whether you got there; do not state the
level yourself.
