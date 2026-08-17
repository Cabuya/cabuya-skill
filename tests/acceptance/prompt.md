# The acceptance prompt

**Fixed and versioned.** Do not edit it to make a run pass — editing the
question to fit the answer is the one change that invalidates every previous
result. If a question is wrong, that is a pull request with a reason, and
every recorded run before it becomes historical.

Give this to the agent verbatim, in one message, in a session with:

- **no network**;
- an empty repository;
- the pack installed at `.agents/skills/cabuya/`;
- **no other context** — no prior conversation, no other skills, no
  repository the agent has seen before.

---

You have the Cabuya skill pack installed at `.agents/skills/cabuya/`. You have
no network access. Answer using only files from that pack.

**Cite the file each answer came from**, as a path relative to the pack root —
for example `spec/PROTOCOL_SUMMARY.md`. An answer without a citation scores
zero even if it is correct, because the point of the pack is that the answers
are *in* it rather than in your training data.

## Part A — ten questions

1. What are the five conformance levels, and what does each require?
2. Where does a publisher put its manifest, and what is the fallback?
3. Why is `200 + text/html` at a discovery path treated as absent?
4. What is the record id format, and why that shape?
5. What must never travel in a feed?
6. What is the difference between `updated_at` and `last_confirmed_at`?
7. What does an omitted `last_confirmed_at` mean, versus `null`?
8. Name the two production anti-patterns the validator probes for.
9. What are the six consumption MUSTs?
10. Which envelope fields are required, and which requirement is the
    non-obvious one?

## Part B — three tasks

**B1.** Here is a table definition:

```sql
CREATE TABLE albergues (
  id            SERIAL PRIMARY KEY,
  nombre        TEXT NOT NULL,
  direccion     TEXT,
  telefono      TEXT,
  responsable   TEXT,
  activo        BOOLEAN DEFAULT true
);
```

Produce a complete field mapping from this table to the `place` schema. Then
do whatever the pack tells you to do next.

**B2.** Read `examples/invalid/invalid-2-contact-and-personal-data.json`. Name
every violation it contains and the rule behind each one.

**B3.** A fictional app, "Refugios Ejemplo", serves one shelter:

- id `7`, name "Coliseo Municipal", a shelter, in Pereira
- address "Calle 14 con Carrera 8"
- currently operating
- nobody has ever been sent to confirm it in person
- its public page is `https://refugios-ejemplo.invalid/lugares/7`
- publisher id `refugios-ejemplo`, licence CC-BY-4.0

Produce a minimal conforming manifest and a one-record feed. Then validate
them with the pack, and report the result.
