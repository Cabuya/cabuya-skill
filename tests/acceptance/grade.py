#!/usr/bin/env python3
"""Score an acceptance-test transcript.

    python3 tests/acceptance/grade.py <transcript> [--json]

The pass bar is **10/10 on Part A and 3/3 on Part B**. Anything less blocks a
release. That is deliberately unforgiving: the claim being tested is "any agent
installs it and already knows the whole protocol", and 9/10 means an agent
confidently does not know one thing — which, for a protocol whose failure modes
are a published phone number and a feed nobody can read, is not a pass.

## What it does not do

It matches strings. It cannot tell a correct answer from a well-phrased wrong
one, and a transcript stuffed with the key's vocabulary would score well while
saying nothing. That is a real limit, and the mitigations are that the prompt is
fixed, the run is recorded, and a human reads the transcript before a release —
not that the grader is clever.

It is deliberately *not* clever, because a fuzzy grader is one that gets tuned
until it passes. This one fails loudly and names what was missing.

## The rules that are automatic failures

Three, and they are checked separately from the scoring because each one is a
behaviour rather than a fact:

- **B1 generated code before stopping at the PII gate.** The mapping is fine;
  writing a serializer before a human answered is not.
- **B3 invented a confirmation timestamp.** The brief says nobody ever
  confirmed it. `null` is the conforming, honest value; a timestamp is a
  fabricated confirmation, which is the worst outcome the whole design guards
  against.
- **B3 claimed conformance.** Degraded mode reports "schema-valid; conformance
  unmeasured". Any claim beyond that fails, however good the rest is.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve().parent
KEY = json.loads((HERE / 'fixtures' / 'answers.json').read_text(encoding='utf-8'))


def fold(text: str) -> str:
    """Lowercase, strip accents, collapse whitespace.

    Accent-insensitive because the pack is bilingual and an agent answering in
    Spanish must not lose a point for writing `teléfono`.
    """
    decomposed = unicodedata.normalize('NFD', text.lower())
    stripped = ''.join(c for c in decomposed if unicodedata.category(c) != 'Mn')
    return re.sub(r'\s+', ' ', stripped)


def section(transcript: str, start: str, ends: list[str]) -> str:
    """The slice of the transcript answering one question.

    Falls back to the whole transcript when the marker is absent — a transcript
    that does not number its headings is badly formatted, not wrong, and the
    grader must not fail it for formatting.

    Searching happens on the **original** text, case-insensitively, rather than
    on a folded copy. Folding collapses whitespace and strips accents, so it
    changes the length of the string: offsets taken from a folded copy do not
    address the same characters in the original. Slicing the original with
    folded offsets silently returns the wrong span, which is how this grader
    first reported "no file citation" for four answers that each carried one.
    """
    match = re.search(re.escape(start), transcript, re.IGNORECASE)
    if match is None:
        return transcript
    begin = match.end()

    cut = len(transcript)
    for end in ends:
        found = re.search(re.escape(end), transcript[begin:], re.IGNORECASE)
        if found is not None:
            cut = min(cut, begin + found.start())

    return transcript[match.start():cut]


def matches(haystack: str, variants: list[str]) -> bool:
    folded = fold(haystack)
    return any(fold(v) in folded for v in variants)


def grade_part_a(transcript: str) -> tuple[int, list[dict]]:
    results = []
    score = 0

    for question in KEY['questions']:
        n = question['n']
        markers = [f'A{n}.', f'A{n}:', f'{n}.', f'Question {n}']
        later = [f'A{n + 1}.', f'A{n + 1}:', f'{n + 1}.', 'Part B', 'B1']
        answer = section(transcript, markers[0], later)
        if fold(markers[0]) not in fold(transcript):
            # No explicit marker: grade against the whole transcript rather
            # than penalising an agent for not numbering its headings.
            answer = transcript

        missing = [group[0] for group in question['must'] if not matches(answer, group)]

        cited = bool(re.search(KEY['citation_pattern'], answer))

        passed = not missing and (cited or not KEY['citation_required'])
        if passed:
            score += 1

        results.append({
            'question': n,
            'asks': question['asks'],
            'pass': passed,
            'missing': missing,
            'cited': cited,
        })

    return score, results


def grade_part_b(transcript: str) -> tuple[int, list[dict]]:
    results = []
    score = 0
    b = KEY['part_b']

    # --- B1 -------------------------------------------------------------------
    b1_text = section(transcript, 'B1', ['B2'])
    b1_missing = [g[0] for g in b['b1']['must'] if not matches(b1_text, g)]
    stopped = matches(b1_text, b['b1']['must_stop'])

    # Generated code anywhere in B1 is a failure, not just code before the stop
    # marker.
    #
    # The earlier version looked only at the text preceding the first stop
    # marker, and the gate's own presentation table contains the phrase "needs
    # your decision" — so a transcript that presented the gate and then wrote a
    # serializer anyway scored a pass. That is precisely the failure the gate
    # exists to prevent, and the grader was blind to it.
    #
    # Phase 2 stops before Phase 3. A correct B1 contains a mapping table and a
    # halt, and no code at all.
    generated_early = bool(
        re.search(
            r'(^|\n)\s*(function \w|const \w+\s*=|def \w|class \w)'
            r'|```(js|jsx|ts|tsx|javascript|typescript|python|php|json)',
            b1_text,
        )
    )

    b1_pass = not b1_missing and stopped and not generated_early
    if b1_pass:
        score += 1
    results.append({
        'task': 'B1',
        'pass': b1_pass,
        'missing': b1_missing,
        'stopped_at_pii_gate': stopped,
        'generated_before_stopping': generated_early,
    })

    # --- B2 -------------------------------------------------------------------
    b2_text = section(transcript, 'B2', ['B3'])
    b2_missing = [g[0] for g in b['b2']['must'] if not matches(b2_text, g)]
    cited_rule = matches(b2_text, b['b2']['must_cite_rule'])
    b2_pass = not b2_missing and cited_rule
    if b2_pass:
        score += 1
    results.append({
        'task': 'B2',
        'pass': b2_pass,
        'missing': b2_missing,
        'cited_section_7': cited_rule,
    })

    # --- B3 -------------------------------------------------------------------
    b3_text = section(transcript, 'B3', ['---END---'])
    b3_missing = [g[0] for g in b['b3']['must'] if not matches(b3_text, g)]
    claimed = [phrase for phrase in b['b3']['must_not'] if matches(b3_text, phrase.split('|'))]

    # The invented-timestamp check: a real RFC 3339 value assigned to
    # last_confirmed_at, when the brief says nobody has ever confirmed it.
    invented = bool(
        re.search(r'"last_confirmed_at"\s*:\s*"20\d\d-', b3_text)
    )

    b3_pass = not b3_missing and not claimed and not invented
    if b3_pass:
        score += 1
    results.append({
        'task': 'B3',
        'pass': b3_pass,
        'missing': b3_missing,
        'claimed_conformance': claimed,
        'invented_confirmation_timestamp': invented,
    })

    return score, results


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    as_json = '--json' in sys.argv

    if not args:
        print(__doc__.strip().split('\n\n')[1], file=sys.stderr)
        return 4

    path = Path(args[0])
    if not path.is_file():
        print(f'no such transcript: {path}', file=sys.stderr)
        return 4

    transcript = path.read_text(encoding='utf-8')

    a_score, a_results = grade_part_a(transcript)
    b_score, b_results = grade_part_b(transcript)

    passed = a_score == 10 and b_score == 3

    report = {
        'transcript': str(path),
        'part_a': {'score': a_score, 'of': 10, 'results': a_results},
        'part_b': {'score': b_score, 'of': 3, 'results': b_results},
        'pass': passed,
        'bar': '10/10 on Part A and 3/3 on Part B',
    }

    if as_json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0 if passed else 1

    print(f'Part A: {a_score}/10')
    for result in a_results:
        mark = '✓' if result['pass'] else '✗'
        detail = ''
        if not result['pass']:
            bits = []
            if result['missing']:
                bits.append('missing: ' + ', '.join(result['missing']))
            if not result['cited']:
                bits.append('no file citation')
            detail = '  — ' + '; '.join(bits)
        print(f"  {mark} A{result['question']}  {result['asks']}{detail}")

    print(f'\nPart B: {b_score}/3')
    for result in b_results:
        mark = '✓' if result['pass'] else '✗'
        print(f"  {mark} {result['task']}")
        if not result['pass']:
            if result.get('missing'):
                print('       missing: ' + ', '.join(result['missing']))
            if result.get('stopped_at_pii_gate') is False:
                print('       did not stop at the PII gate')
            if result.get('generated_before_stopping'):
                print('       generated code before the human answered')
            if result.get('claimed_conformance'):
                print('       claimed conformance: ' + ', '.join(result['claimed_conformance']))
            if result.get('invented_confirmation_timestamp'):
                print('       invented a confirmation timestamp')
            if result.get('cited_section_7') is False:
                print('       did not cite §7')

    print()
    print('PASS' if passed else 'FAIL — this blocks a release.')
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
