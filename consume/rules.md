# The six rules, and how the code proves it follows them

A consuming app (L3+) MUST do all six. They are not style guidance: each one
exists because its absence was observed doing damage, and each one is
checkable in the code you generate.

**Every rule below has a self-test.** Generate the test with the code. A rule
that lives only in a comment is a rule that survives exactly one refactor.

---

## 1. Attribute

**Display the origin publisher for every foreign record.**

*Why:* a record that reaches a person with no origin is a record nobody can
correct, dispute, or follow up. And attribution is the consideration a
publisher gets in exchange for opening their data — the licence terms in the
envelope are a real obligation, not a courtesy.

**The code must:** render `source.source_id` (resolved to the publisher's
display name via the registry) on every foreign record, in the same view as
the record itself. Not on a details page, not behind a tooltip. When
`attribution_required` is true, the display is mandatory rather than
preferred.

**Self-test:** an assertion in the rendering component's test that the
publisher name appears in the rendered output for a foreign fixture. Written
so a grep for `source_id` in the component finds it.

```ts
it('names the origin publisher on every foreign record', () => {
  render(<PlaceCard place={foreignFixture} />);
  expect(screen.getByText(/pereira-ayuda/i)).toBeInTheDocument();
});
```

---

## 2. Show age

**Render `last_confirmed_at` age — or "sin confirmar" for `null` — wherever a
foreign record can direct a person somewhere.**

*Why:* this is the rule with the starkest evidence. On one live map, 31 of 36
points read `viejo` by the app's *own* measure — 86 % — and another publisher
serves 226 place records across 57 municipalities with no recency signal at
all. Without age, a consumer laundering that data into a clean UI makes it
look current.

**The code must:**

- render the age of `last_confirmed_at` on every foreign record;
- render **"sin confirmar"** for `null` — not "hoy", not blank, not hidden;
- **visually distinguish** a record when the age exceeds **7 days** OR
  `contradictions_active > 0`;
- **not silently hide it.** Absence of data is not evidence of closure, and a
  hidden record is one a person cannot decide about.

**Self-test:** a unit test with three fixtures — fresh, stale (> 7 days), and
`null` — asserting the three different renderings.

```ts
it.each([
  ['fresh',  { last_confirmed_at: hoursAgo(2) },  /hace 2 horas/],
  ['stale',  { last_confirmed_at: daysAgo(9) },   /hace 9 días/],
  ['never',  { last_confirmed_at: null },         /sin confirmar/],
])('renders %s freshness', (_, patch, expected) => {
  render(<PlaceCard place={{ ...base, ...patch }} />);
  expect(screen.getByText(expected)).toBeInTheDocument();
});

it('distinguishes a stale record visually', () => {
  const { container } = render(<PlaceCard place={{ ...base, last_confirmed_at: daysAgo(9) }} />);
  expect(container.querySelector('[data-stale="true"]')).toBeTruthy();
});
```

---

## 3. Do not mutate

**Never alter a foreign record's content.**

*Why:* an edited copy that keeps the original's id and attribution puts your
words in somebody else's mouth, and the origin cannot correct what they did
not write. Enrichments belong in your own records, linked with `same_as`.

**The code must:** store foreign records read-only. Enrichments live in the
consumer's own records, carrying a `same_as` claim pointing at the foreign
id.

**Self-test:** make it a type-level guarantee, so the test is the compiler.

```ts
/** A record from another publisher. Read-only by construction. */
export type ForeignPlace = Readonly<{
  id: string;
  publisher_id: string;
  name: string;
  // …every field readonly
}>;

// And a runtime guard for the boundary the types cannot reach:
export function freezeForeign(place: ForeignPlace): ForeignPlace {
  return Object.freeze(place);
}
```

---

## 4. Preserve chains

**An aggregator republishing MUST keep the original `source{}` intact.** Its
own identity goes in the envelope's `publisher_id`, never in the record's
provenance.

*Why:* an aggregator that rewrites `source` to itself becomes the apparent
origin of everything it touched, and the real origin disappears one hop back.
Two hops later, nobody can find who to ask.

**The code must:** copy `source{}` through unchanged when republishing. Set
your own `publisher_id` in the envelope only.

**Self-test:** a round-trip fixture test.

```ts
it('keeps the original source through a republish', () => {
  const republished = republish([foreignFixture]);
  expect(republished.data.places[0].source).toEqual(foreignFixture.source);
  expect(republished.publisher_id).toBe(OUR_PUBLISHER_ID);
  expect(republished.data.places[0].source.source_id).not.toBe(OUR_PUBLISHER_ID);
});
```

---

## 5. Dedupe by claim, not by authority

**Cluster via `same_as` (one-hop, non-transitive) plus accent-folded
address/DIVIPOLA matching — never raw display strings. Publish clusters only
as your own records.**

*Why:* exact-name matching failed on **100 %** of ~20 observed duplicate
cases, while address matching succeeded on 100 % of those same cases. And
"Coliseo Mayor" exists in more than one municipality, which is why the
DIVIPOLA code is part of the key rather than a filter applied afterwards.

**The code must:**

- match on `municipality_code` + accent-folded, normalised `address_text` —
  never on `name`;
- treat `same_as` as a **claim**: one hop, not transitive. A says it is B, B
  says it is C — that does **not** make A and C the same place;
- publish the cluster as **your own record** with `same_as` claims, never as
  an authoritative merge of somebody else's records.

**Self-test:** the constraint is documented in the generated module's header
*and* tested for non-transitivity.

```ts
it('does not follow same_as transitively', () => {
  const clusters = cluster([aClaimsB, bClaimsC]);
  expect(sameCluster(clusters, 'a', 'b')).toBe(true);
  expect(sameCluster(clusters, 'a', 'c')).toBe(false);
});

it('never matches on display name alone', () => {
  const clusters = cluster([coliseoPereira, coliseoManizales]);
  expect(clusters).toHaveLength(2); // 50 km apart, same name
});
```

---

## 6. Respect exclusions

**Never join place data with person-level sources. Never fetch from a
publisher whose declared policy reserves reuse.**

*Why:* the protocol excludes person-level data by a **join prohibition, not a
field omission** — so the exclusion lives in the consuming code, not only in
the feed. And a publisher who reserved reuse said so; fetching anyway is
taking something that was not offered.

**The code must:** refuse both **by construction**, not by convention.

- The fetch layer takes hosts from the filtered registry and cannot be handed
  an arbitrary URL. A publisher whose policy reserves reuse is filtered out
  before the fetch layer sees it — so there is no code path that fetches it,
  rather than a check somebody can skip.
- Foreign place records and any person-level table live in separate stores
  with no join key between them, and no query touches both.

**Self-test:** the fetch layer refuses an unlisted host, and there is no query
joining the two.

```ts
it('cannot fetch a host that is not in the filtered registry', async () => {
  await expect(fetchFeed('https://not-in-registry.invalid/f.json'))
    .rejects.toThrow(/not in the permitted set/);
});

it('excludes a publisher whose policy reserves reuse', () => {
  const permitted = permittedPublishers(registryFixture);
  expect(permitted.map(p => p.publisher_id)).not.toContain('reserves-reuse-app');
});
```

See [`../shared/crawl-policy.md`](../shared/crawl-policy.md) — that rule holds
**even if a human asks**.

---

## One more thing, which is not a MUST but matters

**No moderation verdicts travel.** A suppressed record is omitted from a feed,
never labelled. So if you are building a moderation queue over foreign data,
your verdicts stay yours: do not republish them, and do not attach them to the
foreign record. A "flagged as false" travelling through an aggregator is a
defamation-shaped risk carried by whoever displays it.
