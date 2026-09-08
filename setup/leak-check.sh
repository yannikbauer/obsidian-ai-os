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
# Patterns come from _AI/config/leak-patterns.local. It is NOT copied into the export
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

# --- prove the path resolution before trusting anything it resolves ----------
# This gate stands between the vault and a public repository, and its historical
# failure mode is not a false pass on a pattern -- it is not finding its patterns
# at all. On 2026-09-04 an incomplete list passed deny messages naming the owner
# straight into the shareable tree, and the run still LOOKED clean.
#
# The distinction that matters, because only one of these is a bug:
#   * pattern file absent, root found  -> a fork. Legitimate: fall back to the
#     generic patterns, warn on stderr, keep going.
#   * root NOT found                   -> this script cannot locate the tree it
#     is supposed to be protecting. Everything downstream is meaningless, so it
#     fails loudly instead of degrading into a check that always passes.
#
# CLAUDE.md is the marker because it is the one file that must exist in every
# install, generic and personal alike, and is never renamed.
if [ ! -f "$AI_DIR/CLAUDE.md" ]; then
  echo "! leak-check: cannot locate the _AI root — resolved to '$AI_DIR', which has no CLAUDE.md." >&2
  echo "! Refusing to scan: a wrong path here disables the leak check while still exiting 0." >&2
  exit 3
fi

PATTERNS=()
PATFILE="$AI_DIR/config/leak-patterns.local"
if [ -f "$PATFILE" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    PATTERNS+=("$line")
  done < "$PATFILE"
else
  # stderr, not stdout: this is a degradation notice, and on stdout it reads as
  # part of a successful run's output.
  echo "  (no config/leak-patterns.local found — using built-in generic checks only)" >&2
fi
# Built-in generic patterns (safe against template placeholders like <your email>)
PATTERNS+=("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")   # any real email
PATTERNS+=("@group\.calendar\.google\.com")                    # google calendar ids

# --- deliberate attribution --------------------------------------------------
# Some personal tokens BELONG in a public repo: the copyright holder's name in
# LICENSE, the public repo URL in README. Both match leak-patterns.local, so
# without an exemption the export could never carry a licence or an install URL.
#
# config/leak-allow.local lists those exact literals. They are deleted from a matched
# line before the line is re-tested, so the author's full name in LICENSE passes
# while any OTHER occurrence of their first name in the same file still fails.
# Widening a pattern would have disabled the check globally; this does not.
#
# Fixed-string via awk index(), not regex -- no escaping, and an allow entry can
# never accidentally match more than itself.
ALLOWFILE="$AI_DIR/config/leak-allow.local"
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
