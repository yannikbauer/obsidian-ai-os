#!/usr/bin/env bash
#
# leak-check.sh — scan a file or directory for personal identifiers.
#
#   leak-check.sh <path>        exit 0 = clean, exit 2 = leak found (details on stderr)
#
# Extracted from export.sh so that publish.sh can scan things that are not files
# in the export. That distinction is the whole point: the export check sees file
# CONTENTS, and metadata -- commit identities, commit messages, repo topics --
# is a class of leak it structurally cannot reach. Generated commit messages are
# built from private commit subjects, so they need the same scan the tree gets.
#
# Patterns come from _AI/leak-patterns.local. It is NOT copied into the export
# (that copy list is an allowlist), but it IS tracked in this repo, on purpose:
# a fresh clone then gets a working leak check instead of silently degrading to
# the generic patterns below. That is safe only because this remote is private
# and already holds me.md and integrations/ -- the file adds no exposure those
# do not. If this repo is ever made public, that stops being true for every one
# of those files, not just this one.

set -euo pipefail

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: leak-check.sh <file-or-directory>" >&2; exit 64; }
[ -e "$TARGET" ] || { echo "! leak-check: no such path: $TARGET" >&2; exit 64; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$(dirname "$SCRIPT_DIR")"

PATTERNS=()
PATFILE="$AI_DIR/leak-patterns.local"
if [ -f "$PATFILE" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    PATTERNS+=("$line")
  done < "$PATFILE"
else
  echo "  (no leak-patterns.local found — using built-in generic checks only)"
fi
# Built-in generic patterns (safe against template placeholders like <your email>)
PATTERNS+=("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")   # any real email
PATTERNS+=("@group\.calendar\.google\.com")                    # google calendar ids

# --- deliberate attribution --------------------------------------------------
# Some personal tokens BELONG in a public repo: the copyright holder's name in
# LICENSE, the public repo URL in README. Both match leak-patterns.local, so
# without an exemption the export could never carry a licence or an install URL.
#
# leak-allow.local lists those exact literals. They are deleted from a matched
# line before the line is re-tested, so the author's full name in LICENSE passes
# while any OTHER occurrence of their first name in the same file still fails.
# Widening a pattern would have disabled the check globally; this does not.
#
# Fixed-string via awk index(), not regex -- no escaping, and an allow entry can
# never accidentally match more than itself.
ALLOWFILE="$AI_DIR/leak-allow.local"
strip_allowed () {
  awk -v allowfile="$ALLOWFILE" '
    BEGIN {
      n = 0
      while ((getline line < allowfile) > 0) {
        if (line ~ /^[ \t]*$/ || line ~ /^#/) continue
        L[++n] = line
      }
      close(allowfile)
    }
    {
      for (i = 1; i <= n; i++)
        while ((p = index($0, L[i])) > 0)
          $0 = substr($0, 1, p - 1) substr($0, p + length(L[i]))
      print
    }
  '
}

if [ -f "$ALLOWFILE" ]; then
  echo "  (attribution allowlist: $(grep -cvE '^[[:space:]]*(#|$)' "$ALLOWFILE") literal(s))"
fi

# Directories are scanned from the inside so grep prints RELATIVE paths: an
# absolute path can itself contain a personal token (/Users/<name>/...) and would
# otherwise trip the re-test on every single line.
if [ -d "$TARGET" ]; then
  scan () { ( cd "$TARGET" && grep -rEIn --binary-files=without-match -- "$1" . 2>/dev/null ) || true; }
else
  scan () { grep -EIn --binary-files=without-match -- "$1" "$TARGET" 2>/dev/null || true; }
fi

LEAKED=0
for p in "${PATTERNS[@]}"; do
  hits="$(scan "$p" | strip_allowed | grep -E -- "$p" || true)"
  if [ -n "$hits" ]; then
    echo "  LEAK: pattern '$p' matched:" >&2
    printf '%s\n' "$hits" >&2
    LEAKED=1
  fi
done

if [ "$LEAKED" -ne 0 ]; then
  exit 2
fi
echo "  clean — no personal tokens found."
