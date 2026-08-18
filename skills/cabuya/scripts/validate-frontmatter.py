#!/usr/bin/env python3
"""Validate the YAML frontmatter on every SKILL.md in this pack.

    python3 scripts/validate-frontmatter.py

The frontmatter is not decoration. An agent host reads it to decide whether a
skill is invocable, what it may be invoked as, and which tools it is permitted
to use — so a missing `allowed-tools` is not a lint warning, it is a pack that
either does not load or loads with permissions nobody declared.

Rules, and why each one is here:

  name                 kebab-case, starts with "cabuya". The prefix is how a
                       host disambiguates this pack's sub-skills from every
                       other pack's; snake_case is rejected explicitly because
                       it is the mistake people actually make.
  description          non-empty. It is what the router matches intent against.
  version              a *quoted* SemVer string. Unquoted `1.0` parses as a
                       float and reaches the host as "1", which is a different
                       version.
  documentation_url    where a human goes when the skill is wrong.
  user-invocable       a real boolean. `"true"` is a string and is truthy in
                       every language, which is how a skill nobody meant to
                       expose becomes directly callable.
  allowed-tools        present. An absent list is not "no restrictions" to a
                       reviewer, but it is to a host.

And one addition this pack makes over the reference packs:

  metadata.protocol.supported_spec_versions
                       on the router only. An agent that knows the protocol has
                       to know *which version* it knows, because a pack
                       vendoring 0.1 must not be trusted to implement 0.2. The
                       website's skill page renders this list, and a
                       consistency check compares the two.

Tolerant of absence by design: it validates the files that exist. The pack is
built over several tasks, and a validator that failed because a sub-skill has
not been written yet would be a validator somebody disables on day one.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover — exercised on machines without pyyaml
    yaml = None

SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+(?:-[\w.-]+)?(?:\+[\w.-]+)?$")
KEBAB_RE = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
SPEC_VERSION_RE = re.compile(r"^\d+\.\d+$")

REPO_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_KEYS = (
    "name",
    "description",
    "version",
    "documentation_url",
    "user-invocable",
    "allowed-tools",
)


def find_skill_files() -> list[Path]:
    """Every SKILL.md, router first so its errors are reported first."""
    router = REPO_ROOT / "SKILL.md"
    subskills = sorted(
        path
        for path in REPO_ROOT.glob("*/SKILL.md")
        if path.is_file()
    )
    return ([router] if router.is_file() else []) + subskills


def parse_minimal_yaml(text: str) -> dict:
    """A deliberately small reader for the shape this pack's frontmatter uses.

    Used only when PyYAML is absent, so the check runs on a machine with no
    Python packaging set up — which is most contributors' first five minutes.

    It understands exactly what the frontmatter contains: top-level scalars,
    two levels of nested mapping (`metadata.protocol.*`), inline or block lists
    of strings, and block scalars (`>`, `|`, and their `-`/`+` chomping forms)
    because every skill in every reference pack writes its description as a
    folded scalar. Anything else raises, because a reader that guesses at a
    construct it does not know would accept frontmatter CI would then reject —
    the one outcome worse than requiring the dependency.
    """

    def coerce(raw: str) -> object:
        value = raw.strip()
        if value.startswith(("'", '"')) and value[-1:] == value[:1]:
            return value[1:-1]
        if value in ("true", "false"):
            return value == "true"
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            if not inner:
                return []
            return [coerce(item) for item in inner.split(",")]
        if re.fullmatch(r"-?\d+", value):
            return int(value)
        if re.fullmatch(r"-?\d+\.\d+", value):
            return float(value)
        return value

    def read_block_scalar(
        lines: list[str], start: int, parent_indent: int
    ) -> tuple[list[str], int]:
        """Consume the indented body of a `>` or `|` scalar.

        Returns the body lines and the index of the first line that is not part
        of it. Folded (`>`) joins on spaces, literal (`|`) on newlines. The
        chomping indicator is honoured exactly — clip (bare) keeps one trailing
        newline, strip (`-`) keeps none, keep (`+`) keeps them all — because
        this reader's whole justification is that it never disagrees with
        PyYAML about a file that parses, and a trailing newline is a
        disagreement.
        """
        body: list[str] = []
        index = start
        while index < len(lines):
            candidate = lines[index]
            if not candidate.strip():
                body.append("")
                index += 1
                continue
            if len(candidate) - len(candidate.lstrip()) <= parent_indent:
                break
            body.append(candidate.strip())
            index += 1
        return body, index

    root: dict = {}
    # (indent, container) — the mapping each indentation level writes into.
    stack: list[tuple[int, dict]] = [(-1, root)]
    pending_list: list | None = None

    lines = text.splitlines()
    cursor = 0
    while cursor < len(lines):
        line = lines[cursor]
        number = cursor + 1
        cursor += 1

        if not line.strip() or line.lstrip().startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())
        stripped = line.strip()

        if stripped.startswith("- "):
            if pending_list is None:
                raise ValueError(f"line {number}: list item outside a key")
            pending_list.append(coerce(stripped[2:]))
            continue

        pending_list = None
        if ":" not in stripped:
            raise ValueError(f"line {number}: not a key/value pair: {stripped!r}")

        key, _, raw = stripped.partition(":")
        key = key.strip()

        while stack and indent <= stack[-1][0]:
            stack.pop()
        if not stack:
            raise ValueError(f"line {number}: indentation does not nest")
        container = stack[-1][1]

        marker = raw.strip()
        if marker and marker[0] in "|>" and set(marker[1:]) <= {"-", "+"}:
            body, cursor = read_block_scalar(lines, cursor, indent)
            joiner = "\n" if marker[0] == "|" else " "
            while body and not body[-1]:
                body.pop()
            value = joiner.join(body)
            if "+" in marker:
                # keep: every trailing blank line survives. Reconstructing the
                # exact count is out of scope for a fallback, and the pack's
                # frontmatter does not use it — so say so rather than be wrong.
                raise ValueError(
                    f"line {number}: `{marker}` (keep chomping) is not "
                    "supported by the fallback reader — install pyyaml"
                )
            container[key] = value if "-" in marker else value + "\n"
            continue

        if raw.strip() == "":
            # Either a nested mapping or a block list; the next line decides.
            child: dict = {}
            container[key] = child
            stack.append((indent, child))
            pending_list = []
            container[key] = child
            # A block list replaces the mapping if items follow.
            _BLOCK_LIST_OWNERS.append((container, key, child, pending_list))
        elif raw.strip().startswith("{"):
            raise ValueError(
                f"line {number}: inline mappings are not supported by the "
                "fallback reader — install pyyaml, or use block style"
            )
        else:
            container[key] = coerce(raw)

    # Resolve the block-list ambiguity: a key whose child mapping stayed empty
    # while its list collected items was a list all along.
    for container, key, child, items in _BLOCK_LIST_OWNERS:
        if items and not child:
            container[key] = items
    _BLOCK_LIST_OWNERS.clear()

    return root


_BLOCK_LIST_OWNERS: list[tuple[dict, str, dict, list]] = []


def parse_frontmatter(path: Path) -> tuple[dict | None, str | None]:
    """Return (data, error). Never both non-None."""
    text = path.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(text)
    if not match:
        return None, "no frontmatter block delimited by --- markers"

    block = match.group(1)
    try:
        if yaml is not None:
            data = yaml.safe_load(block)
        else:
            data = parse_minimal_yaml(block)
    except Exception as error:  # noqa: BLE001 — any parse failure is the same answer
        return None, f"frontmatter is not valid YAML: {error}"

    if not isinstance(data, dict):
        return None, "frontmatter is not a mapping"

    # Two readers, one answer — checked, not asserted.
    #
    # The fallback exists so this validator runs before a contributor has pip
    # working. That is only worth anything if it agrees with PyYAML, and the
    # way to know it agrees is to run both wherever both exist. CI installs
    # PyYAML, so this comparison runs on every push: a frontmatter construct
    # the fallback reads differently fails here rather than on somebody's
    # laptop, months later, as a mystery.
    if yaml is not None:
        try:
            shadow = parse_minimal_yaml(block)
        except Exception as error:  # noqa: BLE001
            return None, (
                f"frontmatter parses under PyYAML but not under the fallback "
                f"reader ({error}) — contributors without pyyaml cannot run "
                "this check. Simplify the frontmatter, or teach the fallback."
            )
        if shadow != data:
            return None, (
                "the two frontmatter readers disagree about this file. "
                f"PyYAML: {data!r}. Fallback: {shadow!r}."
            )

    return data, None


def check_version_is_quoted(path: Path) -> str | None:
    """`version: 1.0` parses as a float; the host receives "1"."""
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("version:"):
            value = line.split(":", 1)[1].strip()
            if not (value.startswith('"') or value.startswith("'")):
                return (
                    f'version must be quoted — write version: "{value}", '
                    "or YAML reads it as a number"
                )
            break
    return None


def validate(path: Path, is_router: bool) -> list[str]:
    relative = path.relative_to(REPO_ROOT)
    data, error = parse_frontmatter(path)
    if error:
        return [f"{relative}: {error}"]
    assert data is not None

    problems: list[str] = []

    for key in REQUIRED_KEYS:
        if key not in data:
            problems.append(f"{relative}: missing `{key}`")

    name = data.get("name")
    if isinstance(name, str):
        if "_" in name:
            problems.append(
                f"{relative}: name `{name}` uses snake_case — "
                "hosts expect kebab-case (cabuya-implement, not cabuya_implement)"
            )
        elif not KEBAB_RE.match(name):
            problems.append(f"{relative}: name `{name}` is not kebab-case")
        elif not name.startswith("cabuya"):
            problems.append(
                f"{relative}: name `{name}` must start with `cabuya` so a host "
                "can tell this pack's skills from another pack's"
            )

    description = data.get("description")
    if isinstance(description, str) and not description.strip():
        problems.append(f"{relative}: description is empty")

    version = data.get("version")
    if version is not None:
        if not isinstance(version, str):
            problems.append(
                f"{relative}: version must be a string, got {type(version).__name__}"
            )
        elif not SEMVER_RE.match(version):
            problems.append(f"{relative}: version `{version}` is not SemVer")
    quoted = check_version_is_quoted(path)
    if quoted:
        problems.append(f"{relative}: {quoted}")

    if "homepage" in data:
        problems.append(
            f"{relative}: `homepage` is the legacy key — use `documentation_url`"
        )

    invocable = data.get("user-invocable")
    if invocable is not None and not isinstance(invocable, bool):
        problems.append(
            f"{relative}: user-invocable must be a boolean, not "
            f"{type(invocable).__name__} — a quoted \"false\" is truthy"
        )

    tools = data.get("allowed-tools")
    if tools is not None and not isinstance(tools, (list, str)):
        problems.append(f"{relative}: allowed-tools must be a list or a string")

    if is_router:
        problems.extend(validate_protocol_metadata(relative, data))

    return problems


def validate_protocol_metadata(relative: Path, data: dict) -> list[str]:
    """The router declares which spec versions this pack actually knows."""
    problems: list[str] = []
    metadata = data.get("metadata")
    if not isinstance(metadata, dict):
        return [f"{relative}: router needs a `metadata` mapping"]

    protocol = metadata.get("protocol")
    if not isinstance(protocol, dict):
        return [
            f"{relative}: router needs `metadata.protocol` — an agent that "
            "knows the protocol must know which version it knows"
        ]

    supported = protocol.get("supported_spec_versions")
    if not isinstance(supported, list) or not supported:
        problems.append(
            f"{relative}: metadata.protocol.supported_spec_versions must be a "
            "non-empty list"
        )
    else:
        for entry in supported:
            if not isinstance(entry, str) or not SPEC_VERSION_RE.match(entry):
                problems.append(
                    f"{relative}: supported_spec_versions entry `{entry}` is "
                    'not a MAJOR.MINOR string like "0.1"'
                )

    vendored = protocol.get("vendored_spec")
    if not isinstance(vendored, str) or not SEMVER_RE.match(vendored):
        problems.append(
            f"{relative}: metadata.protocol.vendored_spec must be the SemVer "
            'of the vendored copy, like "0.1.0"'
        )

    return problems


def main() -> int:
    files = find_skill_files()

    if not files:
        # Honest rather than green: the pack is built over several tasks, and
        # "0 files checked" is information, not success.
        print("No SKILL.md found yet — nothing to validate.")
        return 0

    problems: list[str] = []
    for path in files:
        problems.extend(validate(path, is_router=path.parent == REPO_ROOT))

    if problems:
        print(f"\n{len(problems)} frontmatter problem(s):\n", file=sys.stderr)
        for problem in problems:
            print(f"  ✗ {problem}", file=sys.stderr)
        return 1

    print(f"✅ frontmatter valid in {len(files)} SKILL.md file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
