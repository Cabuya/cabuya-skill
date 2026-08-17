# The deny-list, and the one decision you must not make alone

This file drives **Phase 2 of `implement`**, the single mandatory human
decision in the whole flow. Read it before you map anything.

## Why this gate exists, and why it has no override

The protocol excludes person-level data by a **join prohibition, not a field
omission** (§7.1). That distinction is the whole reason this gate cannot be
automated away: there is no set of fields whose absence makes a feed safe.
A column called `contacto` might hold an organization's switchboard or a
volunteer's mobile, and nothing in its name, type or sample values reliably
tells you which.

The failure this prevents is not recoverable. A phone number published in a
feed is fetched, cached and mirrored by every consumer before anybody notices;
deleting the record afterwards deletes your copy and none of theirs. That
asymmetry — cheap to prevent, impossible to undo — is why **the agent presents
and the human decides**, every time, with no flag that skips it.

Three of these leaks were observed in production, in apps built by careful
people:

- ~480 records server-rendered with names and phone numbers into a publicly
  cacheable HTML document, `Allow: /`, no `noindex`.
- An app that Cloudflare-obfuscates emails in its HTML and then serves `tel`,
  `tel_fmt` and `contacto` unauthenticated in the JSON behind the same page —
  the protection on the page defeated by the feed behind it.
- Publisher personal names leaking through a **free-text provenance field**
  in an otherwise careful open API.

None of these were carelessness. They are what happens without a gate.

---

## The deny-list

Match against **column names, JSON keys, ORM field names, and the values of
free-text fields**. Matching is case-insensitive and accent-insensitive
(`cédula` and `cedula` are the same token), and matches on substrings —
`telefono_contacto` matches `telefono`.

### Names

```
name  nombre  nombres  apellido  apellidos  first_name  last_name
full_name  nombre_completo  contacto  responsable  encargado  coordinador
solicitante  beneficiario  reportante  autor  owner  usuario  user_name
```

> `name` is on this list and is **also a required `place` field**. That is not
> a contradiction: `place.name` is the name of a *place*, and a column called
> `name` in the adopter's database may be either. This is precisely the kind
> of ambiguity the gate exists to put in front of a human.

### Phones

```
phone  phones  telefono  telefonos  tel  tel_fmt  celular  movil  whatsapp
wa  contacto_telefono  numero  num_contacto
```

Colombian phone shapes, matched against **values**, not just names:

```
\+?57[ -]?3\d{2}[ -]?\d{3}[ -]?\d{4}     # +57 3xx xxx xxxx
\b3\d{9}\b                                # bare mobile: 3xxxxxxxxx
\b\(?60[0-9]\)?[ -]?\d{3}[ -]?\d{4}\b     # landline, post-2022 numbering
```

### Email

```
email  correo  correo_electronico  e_mail  mail
```

```
[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
```

### Identity documents

```
cedula  cc  documento  documento_identidad  nuip  ti  numero_documento
identificacion  passport  pasaporte
```

### Personal location

```
direccion_casa  direccion_residencia  domicilio  home_address
direccion_personal
```

> Note what is **not** here: `direccion` and `address` alone. A place's
> address is a required field. A *person's* home address is excluded. Same
> word, opposite answer — flag it and ask.

### Media and other person-level signals

```
foto  fotos  photo  photos  imagen_personal  avatar  selfie
firma  signature  huella
fecha_nacimiento  birth_date  edad  genero  gender  etnia
condicion_medica  discapacidad  estado_salud
```

### Free text — the third leak channel

Scan the **values** of every free-text field that will travel:
`description`, `descripcion`, `observaciones`, `notas`, `comentarios`,
`warning_text`, `advertencia`, `title`, `titulo`.

Flag a value when it contains any phone or email pattern above, or a
name-shaped sequence adjacent to a contact word:

```
(?i)(preguntar por|contactar a|llamar a|hablar con|encargad[oa][: ]|responsable[: ])
```

A description reading *"Recibe alimentos. Preguntar por María Ejemplo Pérez,
cel 3000000000."* is the canonical case, and it is
[`examples/invalid/invalid-2-contact-and-personal-data.json`](../examples/invalid/invalid-2-contact-and-personal-data.json).
It passes a schema check. It is not publishable.

---

## Entity-scoped grants

Some apps hold **both** places and person-level data — missing persons,
individual aid requests, volunteer registrations. Several in this ecosystem
do.

The rule is not "be careful with the person tables". It is:

1. **Federate only the non-person entities.** The `place` feed is generated
   from place tables. Nothing else.
2. **Only from surfaces that do not co-serve person data.** Do not add the
   feed endpoint to a route prefix or an auth context that also serves
   person-level records. A shared middleware, a shared session, a shared
   `/api/v1/` prefix with a permissive CORS header — each is a path by which
   the exclusion becomes theoretical.
3. **`Access-Control-Allow-Origin: *` is required on the feed** and must not
   be applied at a level that also covers person-data routes. This is the most
   likely way to get the exclusion wrong while following every other rule
   correctly: one over-broad CORS middleware and the person endpoints are
   browser-readable from anywhere.

If the app's records are *irreducibly* personal — a missing-persons registry,
a case-management tool — then it is **link-out-only by rule §7.1**, not by
choice. Its ceiling is L1, permanently. Say that plainly, explain it is a rule
about the data and not a judgement about the app, and offer the link-out
pattern. Do not look for a way to make it L2.

---

## How to present the gate

Show a table. Not prose, not a summary, and not a recommendation — the human
is deciding, so give them what they need to decide.

```
PII gate — 4 columns need your decision before anything is generated.

  Column              Sample value                    Why flagged
  ─────────────────── ─────────────────────────────── ─────────────────────────
  contacto            "3001234567"                    phone pattern in values
  responsable         "Coordinación Barrio Kennedy"   name-shaped column
  descripcion         "…preguntar por … cel 300…"     contact in free text
  direccion           "Cra 7 # 23-45"                 place OR person address?

  For each: include as-is / exclude / include transformed (say how).

  Reminder: contact values never travel in a feed. A place's contact reaches
  a user through `public_url` and `contact_available: true`, fetched from
  your site under your own consent model.
```

Then **stop**. Do not propose a default. Do not proceed on a partial answer.
Do not interpret silence, a "sounds good", or "do what you think" as consent
for a flagged column — ask again, naming the specific column.

---

## Rules for the agent, stated as rules

1. **Never auto-resolve a match.** Not even an obvious one. "This is clearly
   an organization name" is exactly the reasoning that publishes a volunteer's
   mobile number.
2. **Never widen the deny-list to make an error go away.** If the validator
   reports a PII error in Phase 5, that is a finding, not an obstacle. Stop
   and ask. Editing this file to silence it converts a caught problem into an
   uncaught one.
3. **Never put a contact value in a feed** — including inside a namespaced
   `x_*` extension. Namespacing is for fields the vocabulary lacks, not an
   exemption from §7.2. `x_example_phone` is exactly as non-conforming as
   `phone`.
4. **`confirmed_by` is a role token**, never a person: `team`, `volunteer`,
   `official_source`, `partner:{publisher_id}`.
5. **Ids must be opaque with respect to personal data.** A URL shaped
   `/{set}/{id}-{given-name}/` is both a privacy problem and a durable
   interoperability defect — names are unstable, non-unique and
   locale-dependent.
6. **When unsure, flag it.** A false positive costs one question. A false
   negative is permanent.

The good patterns already exist in this ecosystem and are worth naming when
you present the gate: a required `publishContact` boolean; a
`contacto_publicable` consent flag captured **at write time**; brokered
contact, where the system relays a message and no contact is ever rendered
publicly.
