# Django

Aid apps in the public sector are disproportionately Django: an admin site
already exists, the data is in Postgres, and the team knows `manage.py`. The
good news is that Django has no SPA catch-all by default; the trap here is
different — the URL order in `urlpatterns`, and an ORM that serializes every
field unless told otherwise.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.** Instructions below cite the Django documentation
(<https://docs.djangoproject.com/en/5.2/>); confirm against the project's own
pinned version.

## 1. Fingerprints

```
manage.py                 ← the strongest signal; nothing else ships one
<project>/settings.py       (or settings/ package)
<project>/urls.py           ROOT_URLCONF — the file that decides discovery
requirements.txt | pyproject.toml with Django pinned
```

`manage.py` alone is decisive. Distinguish from Flask/FastAPI (no
`manage.py`, no `urls.py`) before reading anything else.

## 2. Where the data lives

In order of reliability:

1. **Migrations** — `*/migrations/*.py`. Authoritative for what columns exist.
2. **`models.py`** — authoritative for names, types, and the `verbose_name`
   hints that reveal what a column means in Spanish.
3. **Query call sites** — `grep -rn "objects\." --include="*.py"` shows which
   models the views actually serve.
4. A response from `python manage.py shell`, if the team runs one for you.

```bash
find . -name models.py -not -path "*/venv/*"
grep -rn "class .*models.Model" --include="models.py" .
```

**Never infer the model from the admin UI** — `list_display` is a subset.

## 3. The mapping worksheet

Against an invented `Albergue` model — the real app's fields will not match,
and that is the point of the worksheet:

```
Mapping: albergues.Albergue → place (Core profile)

  place field           ← model field          notes
  ───────────────────── ────────────────────── ─────────────────────────────
  id                    ← pk
  publisher_id          ← (constant)           the registry token
  name                  ← nombre
  place_kind            ← tipo                 see mapping/place-kind.md
  municipality_code     ← (constant or FK)     see mapping/divipola.md
  address_text          ← direccion
  lifecycle_status      ← estado               model choices → the enum
  last_confirmed_at     ← verificado_en, or null
  source                ← (constant)           {source_id, source_kind}
  public_url            ← (derived)            get_absolute_url() if defined
```

`last_confirmed_at` maps to a real confirmation event or to `null` — never to
`auto_now` fields. Django's `auto_now=True` is an edit timestamp by
definition: it updates on every `save()`, which is exactly the manufactured
freshness CR-1 forbids. If the model has no confirmation concept, `null` is
the correct value, present on every record.

## 4. The PII gate here

Where person-level data hides in a Django project:

- **`django.contrib.auth`** — `User` is always there. Any FK from a place
  model to `User` (`responsable`, `creado_por`) is a join to person data;
  the *name behind the FK* must never travel, and neither must the FK value.
- **The admin's phone habit** — public-sector Django apps grow `telefono`,
  `celular`, `contacto` columns on every model because the admin form made
  it easy. Run the deny-list over every field name and every `CharField`'s
  sample values.
- **Free text** — `TextField`s named `observaciones`, `descripcion`, `notas`
  hold phone numbers typed by operators. This is the third leak channel;
  check values, not just names.

## 5. The serializer

A management command, not a view, is the honest default: Django's docs call
this the supported way to run repository code on a schedule
(<https://docs.djangoproject.com/en/5.2/howto/custom-management-commands/>),
and a file written at export time cannot implement the always-now
anti-pattern.

```python
# albergues/management/commands/export_cabuya.py
import json
from pathlib import Path
from django.core.management.base import BaseCommand
from albergues.models import Albergue

class Command(BaseCommand):
    help = "Write the Cabuya place feed to static/cabuya/places.json"

    def handle(self, *args, **options):
        rows = Albergue.objects.values(          # explicit list, never all fields
            "pk", "nombre", "tipo", "direccion", "estado", "verificado_en",
        ).order_by("pk")

        records = [self.to_place(r) for r in rows]
        # High-water mark: the data's own newest change, at export time —
        # never a clock read inside a request.
        last_updated = max(
            (r["verificado_en"] for r in rows if r["verificado_en"]),
            default=None,
        )
        feed = {
            "version": "0.1.0",
            "publisher_id": "example-app",
            "license": "CC-BY-4.0",
            "last_updated": last_updated.isoformat() if last_updated else None,
            "ttl": 86400,
            "data": {"places": records},
        }
        out = Path("static/cabuya/places.json")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(feed, ensure_ascii=False, indent=2))
        self.stdout.write(f"wrote {len(records)} places")

    def to_place(self, r):
        return {
            "id": str(r["pk"]),
            "publisher_id": "example-app",
            "name": r["nombre"],
            "place_kind": self.kind(r["tipo"]),      # mapping/place-kind.md
            "municipality_code": "66001",            # verify: mapping/divipola.md
            "address_text": r["direccion"],
            "lifecycle_status": self.status(r["estado"]),
            "last_confirmed_at": (
                r["verificado_en"].isoformat() if r["verificado_en"] else None
            ),
            "source": {"source_id": "example-app", "source_kind": "first_party"},
            "public_url": f"https://app.example.invalid/albergues/{r['pk']}",
        }
```

Schedule it with the deployment's own scheduler (cron, systemd timer, or the
PaaS equivalent) after each data-changing deploy. `Albergue.objects.values()`
with an explicit field list is the ORM shape that cannot widen silently — a
bare `.values()` or a full queryset serializes every column, including the
one somebody adds next month.

## 6. The manifest and the catch-all

From [`../../spec/SPA_EXCLUSIONS.md`](../../spec/SPA_EXCLUSIONS.md):

> Add a static route for `/.well-known/` before the catch-all urlpattern.
> Order in `urlpatterns` is the entire mechanism.

Concretely, in `urls.py`, **before** any catch-all or i18n fallback —
Django resolves in list order
(<https://docs.djangoproject.com/en/5.2/topics/http/urls/>):

```python
from django.views.static import serve

urlpatterns = [
    path(".well-known/cabuya.json", serve, {
        "path": "cabuya.json",
        "document_root": BASE_DIR / "static" / ".well-known",
    }),
    # ... the rest, catch-alls last
]
```

In production, serving `static/` through the web server (nginx `location` or
WhiteNoise) is better; the rule is the same — the manifest path resolves
before any pattern that returns HTML. Both files must return
`Content-Type: application/json`, and the feed route needs
`Access-Control-Allow-Origin: *` **on that route** (nginx recipe in
[`../../spec/CORS.md`](../../spec/CORS.md)) — never via
`django-cors-headers` with `CORS_ALLOW_ALL_ORIGINS = True`, which would widen
every endpoint, including any that serve person data.

Check `robots.txt` returns 200 with `text/plain` — a Django app that routes
everything through views often has none.

## 7. The validator loop

The findings this stack characteristically produces:

- **DSC001 (manifest not found)** — the urlpattern order, or `DEBUG=False`
  turning off `django.views.static.serve`. The fix is routing, not the JSON.
- **BEH002 (always-now)** — somebody rewrote the export as a view with
  `timezone.now()` in it. Move `last_updated` back to the export's
  high-water mark.
- **PII findings on free text** — `observaciones` made it into
  `description`. Halt, show the human, never edit the deny-list.

## 8. Hand-off

Left behind: the management command, the manifest, the urlpattern (or web
server block), and [`../templates/CABUYA.md`](../templates/CABUYA.md) filled
in. Next step: `publish-status` to set `conformance_target` and open the
registry entry — with the human's yes.
