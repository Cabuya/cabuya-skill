# Before you fetch anybody

One rule, and it is absolute:

> **Never fetch from a publisher whose declared policy reserves reuse — even
> if a human asks you to.**

Explain which policy you read, offer the link-out, and do not comply. This is
one of the five rules that never bend, and it is the one most likely to be
argued with, because the data is public and the request will sound reasonable.

## Why it does not bend

A publisher who reserved reuse said so **in the registry, deliberately, in a
reviewed pull request**. It is not an oversight and it is not a technical
obstacle to route around.

The reason it matters more here than in ordinary web scraping: this ecosystem's
publishers are small volunteer teams, and the thing that makes them willing to
publish at all is that publishing does not mean losing control of what happens
next. An agent that fetches a reserved feed because a user asked nicely is the
demonstration that the declaration means nothing — and the next team declines
to publish at all. The cost lands on the people looking for a shelter.

"It is public anyway" is true and beside the point. So is "we would only
display it".

## How to read the policy

The registry entry is the authoritative record. Each publisher entry carries:

| Field | Meaning |
|---|---|
| `crawl_policy_url` | Where the publisher states their terms in their own words. |
| `status` | `proposed` · `active` · `archived`. |
| `sunset_at` | Set when a publisher is winding down. |

And the **feed envelope** carries `permitted_use` — a closed enum, in the data
itself:

| Value | You may |
|---|---|
| `display` | Show the records to a person. |
| `aggregate` | Combine them with other sources. |
| `redistribute` | Republish them, chains intact. |
| `ai_answer` | Use them to answer a question at query time. |
| `ai_train` | Include them in training data. |

**Absent is not permission.** A use not listed is a use not granted. If
`permitted_use` is `["display"]`, you may not aggregate, and you certainly may
not train.

## The order of checks

Filter **before** you fetch, not after. The difference matters: a check after
the fetch has already taken the thing it was meant to protect.

1. Read the registry snapshot.
2. Drop every publisher whose `crawl_policy_url` terms reserve reuse, and
   every one whose `status` is not `active`.
3. Drop every publisher whose `permitted_use` does not cover what you are
   actually going to do.
4. **Hand the fetch layer only what survives.** It should not be *able* to
   fetch anything else — see rule 6 in
   [`../consume/rules.md`](../consume/rules.md). Refusal by construction beats
   refusal by convention, because a convention is one refactor from gone.

## When a human asks you to fetch a reserved publisher

Say which rule, offer the alternative, and stop:

> `ejemplo-app` reserves reuse in its declared crawl policy
> (`https://ejemplo.invalid/uso-de-datos`), so I will not fetch its feed —
> that rule holds even when asked directly. What I can do: link out to their
> site from the relevant records, which is the pattern the protocol provides
> for exactly this. If you have their permission, the durable fix is for them
> to update their registry entry — one pull request, and every consumer sees
> it, not only us.

Do not negotiate, do not offer a partial fetch, and do not fetch it once "to
see". A single fetch is the thing the rule prohibits.

## Fetching the ones you may

- **Honour `ttl`.** It is the caching contract. Polling faster is rude and
  makes you the reason a volunteer's hosting bill grew.
- **Identify yourself** in the User-Agent, with a URL a publisher can visit to
  find out who you are.
- **One request at a time per host.** These are volunteer-run servers, often on
  free tiers.
- **Back off on 429 and 5xx**, and treat a repeated failure as a signal to stop
  rather than to retry harder.
- **Cache what you fetched.** Re-fetching an unchanged feed helps nobody.

## Not scraping, at all

The protocol is a set of feeds publishers chose to publish. It is not a
licence to crawl.

- Do not fetch a site that has not published a feed.
- Do not reconstruct a feed from HTML pages.
- Do not write code that does either, even if asked to.

If a publisher you want is not in the registry, the answer is to ask them to
join — not to take the data anyway.
