#!/usr/bin/env bash
#
# Shared helpers for the prose contract tests.
#
# In this pack the prose IS the implementation — an agent reads it at runtime —
# so the tests assert on sentences. Three separate false-failure modes showed
# up while writing them, each of which would have pushed an author to make the
# documentation worse:
#
#   1. Line wraps. A sentence that matters straddles two lines, and grep is
#      line-based. Fixing that by reflowing the paragraph is exactly backwards.
#   2. Inline emphasis. "a target *below* the measured level is allowed" does
#      not stop meaning what it means because one word is italic.
#   3. Blockquote markers. The strongest rules are written as blockquotes.
#
# So: search the text as a reader sees it.

# The file's prose with wraps collapsed and Markdown decoration removed.
flowed() {
  tr '\n' ' ' < "$1" \
    | tr -s ' \t' ' ' \
    | sed -e 's/^> //g' -e 's/ > / /g' -e 's/\*\*//g' -e 's/\*//g' -e 's/`//g'
}

# Does this file say this, in prose? Case-insensitive.
says() {
  flowed "$1" | grep -qi -- "$2"
}

# Only what is inside fenced code blocks — for checks about code, so that a
# guide *describing* an anti-pattern is not mistaken for one committing it.
code_only() {
  awk '/^```/ { fenced = !fenced; next } fenced { print }' "$1"
}
