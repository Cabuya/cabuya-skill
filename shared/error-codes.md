# Reading a check id

Every finding carries a stable id. The three-letter prefix tells you **which
layer is wrong**, which is usually enough to know who fixes it and where —
before you read the message.

| Prefix | Family | What is wrong | Where the fix lives |
|---|---|---|---|
| `DSC` | discovery | The manifest cannot be found, or is not really there. | Hosting and routing. |
| `ENV` | envelope | The feed's wrapper — required fields, `ttl`, licence, `permitted_use`. | The serializer's envelope. |
| `SCH` | envelope | The document does not match the schema at all. | Usually a shape mistake — an array where an object belongs. |
| `REC` | record | A `place` record is wrong. | The mapping. |
| `PII` | pii | Person-level or contact data is present. | **Stop. A human decides.** |
| `BEH` | behavior | The feed *behaves* wrongly — measured, not read. | Deployment or the timestamp strategy. |
| `API` | api | The read API disagrees with the feed, or is missing at L3. | The API layer. |
| `WRT` | write | The write surface is wrong at L4. | The write endpoint. |
| `LIC` | license | The licence or reuse terms are missing or incoherent. | The envelope, and a human decision about terms. |

Offline detail for any id:

```bash
bash bin/run-validator.sh explain REC001
```

Full documentation: `https://cabuya.org/developers/validator/checks#<ID>`,
which is also on every finding as `docs`.

## The four families that behave differently in a fix loop

Most findings are ordinary: read the message, apply the fix, re-run. These four
are not.

### `PII*` — the loop stops

**Halt. Ask a human. Do not iterate.**

A PII finding is not an obstacle between you and a green run; it is the check
working. Never "fix" one by widening
[`pii-deny-list.md`](pii-deny-list.md), by renaming the field, or by moving
the value into a namespaced `x_*` extension — a namespaced field is exactly as
non-conforming as a plain one, and the second and third of those are worse
than the first because they leave the data published and the check silent.

The three you will actually see:

- **`PII001`** — a contact value in the feed. The fix is `contact_available:
  true` plus `public_url`, and the value stays at the origin.
- **`PII002`** — `confirmed_by` carries a name. It takes a role token:
  `team`, `volunteer`, `official_source`, `partner:{publisher_id}`.
- **`PII003`** — free text contains personal data. Somebody has to edit the
  source record; there is no mapping change that fixes it.

### `BEH*` — the data is fine and the deployment is not

Behavioural findings are **measured, not read**. The document can be perfect
and still fail them.

- **`BEH002` (always-now)** — `last_updated` advanced between two fetches of
  identical content. The feed always reads fresh, so a stalled pipeline looks
  identical to a healthy one. The fix is a code change: generate the timestamp
  at build or publish time. It needs `--probe-twice` to detect.

Do not respond to a `BEH` finding by editing the mapping. Nothing about the
records is wrong.

### `DSC*` — nothing is wrong with your JSON

The most common shape here is the **soft-404**: the manifest returns HTTP 200
with `text/html`, because a catch-all served the SPA shell. The file may be
perfect and even present.

The fix is in
[`../spec/SPA_EXCLUSIONS.md`](../spec/SPA_EXCLUSIONS.md), and it is hosting
configuration every time. If a `DSC` finding sends you to the serializer, you
have misread it.

### `REC001` — the one with a designed parenthetical

> `required property 'last_confirmed_at' is missing (did you mean to publish
> last_confirmed_at: null?)`

That parenthetical is the whole design of the message set in one line. **Do
not fix this by inventing a timestamp.** A fabricated confirmation is worse
than a missing key: it tells every consumer downstream that somebody went and
checked, and they will render it as freshness.

If the app has no confirmation event, the answer is `null` — present,
explicit, conforming.

## How findings are written, and why it matters to you

The message set follows seven rules, and two of them change how you should
read a finding:

- **One violation per message.** Two findings on the same field are two
  problems. Fixing one does not resolve the other, and a half-fix that clears
  one message is the failure this rule prevents.
- **The fix is named imperatively** — "move it to `service_status`", not
  "this is invalid". If a message tells you what to do and you do something
  else, you will meet it again on the next iteration.

And one that matters to what *you* write: findings never blame, never
moralize, and never say *certified*. When you relay a finding to a human,
relay it in the same register. A team that feels judged by a validator stops
running it, and then nothing is measured at all.
