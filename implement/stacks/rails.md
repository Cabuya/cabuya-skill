# Ruby on Rails

Rails apps in this ecosystem are usually a few years old, server-rendered,
and already have the data modelled well — Rails' conventions mean the schema
is readable from one file. The trap is the same shape as Django's but in
different clothes: route order, and an ORM whose default serialization emits
every attribute.

Read [`README.md`](README.md) first if you have not: **reason, do not
copy-paste.** Instructions cite the Rails Guides
(<https://guides.rubyonrails.org/>); confirm against the app's pinned major.

## 1. Fingerprints

```
config/application.rb     ← the strongest signal
Gemfile with rails pinned
config/routes.rb            the file that decides discovery
db/schema.rb                the data model, in one authoritative file
```

Distinguish from a plain Rack/Sinatra service: those have a `config.ru` but
no `config/application.rb`.

## 2. Where the data lives

In order of reliability:

1. **`db/schema.rb`** (or `structure.sql`) — Rails regenerates it from
   migrations; it is the whole schema in one file. Start here.
2. **Models** — `app/models/*.rb` for enums, scopes and the validation hints
   that reveal meaning.
3. **Query call sites** — `grep -rn "\.where(\|\.find" app/` for what the
   controllers actually serve.
4. A `rails runner` one-liner, if the team runs it for you.

## 3. The mapping worksheet

Against an invented `refugios` table — the real app's columns will not match:

```
Mapping: refugios → place (Core profile)

  place field           ← column               notes
  ───────────────────── ────────────────────── ─────────────────────────────
  id                    ← id
  publisher_id          ← (constant)           the registry token
  name                  ← nombre
  place_kind            ← categoria            see mapping/place-kind.md
  municipality_code     ← codigo_municipio     verify: mapping/divipola.md
  address_text          ← direccion
  lifecycle_status      ← estado               enum → the protocol's enum
  last_confirmed_at     ← confirmado_en, or null
  source                ← (constant)
  public_url            ← (derived)            url_helpers, the show route
```

Rails timestamps are the CR-1 trap with a convention behind it: every table
has `updated_at`, touched by every `save`. It is an edit timestamp, not a
confirmation event — `last_confirmed_at` maps to a column a human sets when
they verify the place still operates, or to `null`, present on every record.

## 4. The PII gate here

- **Devise/`users`** — almost every Rails app has it. Any `belongs_to :user`
  from a place model is a join to person data; neither the FK nor anything
  reached through it travels.
- **`has_many :contacts` and phone columns** — Rails makes association
  tables cheap, so contact data ends up in `contactos`/`encargados` tables
  one join away. The deny-list runs over every column the serializer can
  reach, not only the base table.
- **Serialized columns** — `store :metadata` and `jsonb` columns hold
  whatever the form put in them. Sample the values.

## 5. The serializer

A rake task writing to `public/`, scheduled after data changes — not a
controller action. Rake is Rails' own answer for scripted repository work
(<https://guides.rubyonrails.org/command_line.html#custom-rake-tasks>), and
a file written at export time cannot lie about freshness per request.

```ruby
# lib/tasks/cabuya.rake
namespace :cabuya do
  desc "Write the Cabuya place feed to public/cabuya/places.json"
  task export: :environment do
    rows = Refugio.select(:id, :nombre, :categoria, :direccion,
                          :codigo_municipio, :estado, :confirmado_en)
                  .order(:id)

    records = rows.map { |r| to_place(r) }
    # High-water mark: the newest real change in the data, at export time.
    last_updated = rows.filter_map(&:confirmado_en).max

    feed = {
      protocol: { name: "cabuya", spec_version: "0.1.0" },
      publisher_id: "example-app",
      last_updated: last_updated&.iso8601,
      ttl: 86_400,
      data: { places: records },
    }

    path = Rails.root.join("public/cabuya/places.json")
    FileUtils.mkdir_p(path.dirname)
    path.write(JSON.pretty_generate(feed))
    puts "wrote #{records.size} places"
  end

  def to_place(r)
    {
      id: r.id.to_s,
      publisher_id: "example-app",
      name: r.nombre,
      place_kind: kind_for(r.categoria),          # mapping/place-kind.md
      municipality_code: r.codigo_municipio,
      address_text: r.direccion,
      lifecycle_status: status_for(r.estado),
      last_confirmed_at: r.confirmado_en&.iso8601, # nil serializes as null
      source: { source_id: "example-app", source_kind: "first_party" },
      public_url: "https://app.example.invalid/refugios/#{r.id}",
    }
  end
end
```

The explicit `select` list is the rule: `as_json` on a bare model emits
every attribute — including the `telefono` column somebody adds next month —
which is the widening-by-default this guide exists to prevent.

## 6. The manifest and the catch-all

`public/.well-known/cabuya.json`. Rails serves `public/` before routing when
`config.public_file_server.enabled` is true (the default; behind a reverse
proxy the web server usually serves it —
<https://guides.rubyonrails.org/asset_pipeline.html>), so placement is most
of the fix. Two verifications, because both fail silently:

1. If `routes.rb` ends in a catch-all (`match "*path" ...` for an SPA or a
   custom 404), request the manifest and check the `Content-Type`: a 200
   with `text/html` is an *absent* manifest.
2. Some proxy configs skip `public/` for dot-directories — fetch
   `/.well-known/cabuya.json` on the deployed origin, not localhost.

The feed route needs `Access-Control-Allow-Origin: *` **on that route** —
set it in the web server per [`../../spec/CORS.md`](../../spec/CORS.md)
(nginx/Apache recipes) rather than `rack-cors` with a global wildcard, which
would also cover any endpoint serving person data. `robots.txt`: Rails ships
a real one in `public/` by default; verify it still returns 200
`text/plain`.

## 7. The validator loop

- **DSC001** — the SPA catch-all in `routes.rb`, or the proxy hiding
  `.well-known`. Routing, not JSON.
- **BEH002** — the export moved into a controller with `Time.current`.
  Return it to the rake task's high-water mark.
- **REC001 (`last_confirmed_at` missing)** — the serializer skipped the key
  when the value was nil. The key is required; `null` is the honest value.

## 8. Hand-off

Left behind: the rake task, the manifest in `public/.well-known/`, the
scheduler entry, and [`../templates/CABUYA.md`](../templates/CABUYA.md)
filled in. Next step: `publish-status` — with the human's yes on the
registry PR.
