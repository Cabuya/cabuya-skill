# Where the protocol lives in this pack

Read this before quoting the specification at anybody. The distinction that
matters is **vendored** versus **authored**: one is a copy whose value comes
entirely from being unmodified, the other is a summary written here.

## The map

| Path | What it is | Quote it for |
|---|---|---|
| `spec/PROTOCOL_SUMMARY.md` | **Authored here.** The protocol distilled for an offline agent. | Explaining the protocol, answering "what is Cabuya?", finding which rule applies |
| `spec/EXCLUSIONS.md` | **Vendored.** §7, byte-verbatim. | Any refusal. When you tell somebody no, quote this — never a paraphrase |
| `spec/schemas/*.schema.json` | **Vendored.** What the validator enforces. | Field names, types, required-ness. The schema is the answer, not your memory of it |
| `spec/vocab/` | **Vendored.** The equivalence dictionary and the place-kind crosswalk. | Mapping somebody's categories onto `place_kind` |
| `examples/valid/` | **Vendored.** Two worked feeds. | Showing what conforming looks like; `valid-minimal-core.json` is the L2 floor |
| `examples/invalid/` | **Vendored.** Three teaching failures. | Explaining a violation. Each carries a `$comment` naming every violation and its rule |
| `spec/VERSION` | The spec MINOR vendored here. | Checking you are answering about the right version |
| `spec/SOURCE` | Repo, ref and commit this copy came from. | Proving provenance; reporting a suspected drift |
| `spec/CHECKSUMS.txt` | SHA-256 of every vendored file. | Nothing — it is for `verify-integrity.sh` |

The full normative text — all nine sections, not just §7 — lives at
<https://cabuya.org/developers/spec/0.1>. It is deliberately **not** vendored:
the summary plus the exclusions plus the schemas cover what an agent needs to
act, and vendoring the whole corpus would trade a large maintenance surface for
prose an agent rarely needs to quote exactly.

## Never hand-edit anything vendored

`scripts/sync-spec.sh` is the only writer. This is rule **V6**, and it has a
mechanical consequence: `scripts/verify-integrity.sh` recomputes every checksum
in CI, so a hand-edited vendored file **fails the build**.

That is not bureaucracy. The vendored copy is what an offline agent will teach
people, so the difference between "a copy of the standard" and "a fork nobody
declared" is exactly whether every byte traces to an upstream commit.

**To change the standard:** open an RFC in `Cabuya/cabuya.org`. Nothing about
the protocol changes in this repository.

**To take a new upstream version:**

```bash
bash scripts/sync-spec.sh --from https://github.com/Cabuya/cabuya.org --ref v0.2.0
bash scripts/verify-integrity.sh
```

Commit the vendored files and the regenerated `CHECKSUMS.txt` **in the same
commit** — a checksum update in a separate commit is a window in which the
check passes and the tree is wrong.

**If `verify-integrity.sh` fails,** do not run `generate-checksums.sh` to make
it stop. That converts a detected problem into an undetected one. Either
somebody edited a vendored file — find out who and why — or a sync landed
without its checksums, which is the same commit's job.

## The two version streams

The pack's version and the protocol's version are independent. A skill whose
version number implies a spec version is the mistake these rules exist to
prevent.

| Rule | Statement |
|---|---|
| **V1** | The pack's `version` is its own. It never mirrors the spec version. |
| **V2** | `metadata.protocol.supported_spec_versions` lists every spec MINOR the pack can implement and validate against; `vendored_spec` names the exact copy in `spec/`. |
| **V3** | Adding support for a new spec MINOR is a pack **MINOR** bump. |
| **V4** | Dropping support for a spec MAJOR is a pack **MAJOR** bump — and may not happen inside the specification's 180-day producer window. |
| **V5** | The pack supports at most **two spec MAJORs** at once, matching the specification's own rule. |
| **V6** | `scripts/sync-spec.sh` is the only writer of `spec/`; CI verifies `CHECKSUMS.txt` on every pull request. |
| **V7** | `CHANGELOG.md` states, for every release, which spec versions it supports — so an adopter reading one file knows whether it applies to them. |

## Resolution order

When two sources disagree about what the protocol says:

1. **The vendored schemas** — for anything about fields, types or required-ness.
   They are what the validator actually runs.
2. **`EXCLUSIONS.md`** — for anything about what must not travel. Verbatim, so
   it cannot have drifted.
3. **`PROTOCOL_SUMMARY.md`** — for everything else here.
4. **<https://cabuya.org/developers/spec/0.1>** — the normative text, which
   wins over all of the above if you can reach it.
5. **Your own recollection** — never. If none of the above answers the
   question, say the pack does not answer it. An agent that fills the gap
   confidently is the failure mode this whole vendoring scheme was built to
   prevent.
