#!/usr/bin/env bash
#
# export.sh — produce a clean, shareable copy of the AI OS.
#
# Copies the generic framework + templates + setup into a fresh directory,
# OMITS all personal files, runs a leak check, and inits fresh git history.
#
# Usage:  ./export.sh [TARGET_DIR]        (default: ~/aios-export)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$(dirname "$SCRIPT_DIR")"
TARGET="${1:-$HOME/aios-export}"

echo "Exporting shareable AI OS"
echo "  from : $AI_DIR"
echo "  to   : $TARGET"
echo

if [ -e "$TARGET" ]; then
  echo "! $TARGET already exists. Remove it or pass a different path." >&2
  exit 1
fi
mkdir -p "$TARGET"

# --- copy the SHAREABLE set (everything generic) ----------------------------
# Included: framework CLAUDE.md, skills/, templates/, setup/, README, ignore files.
# Excluded: me.md, maps/, integrations/, history/, tmp/, databases/ (all personal).
# This is an allowlist — a new personal folder is excluded by default, not by rule.
cp    "$AI_DIR/CLAUDE.md"      "$TARGET/CLAUDE.md"
cp    "$AI_DIR/.gitignore"     "$TARGET/.gitignore"
[ -f "$AI_DIR/README.md" ] && cp "$AI_DIR/README.md" "$TARGET/README.md"
# A public repo without a licence is all-rights-reserved: nobody may legally reuse
# it. The licence names the copyright holder, which is why the leak check needs
# leak-allow.local -- see below.
cp    "$AI_DIR/LICENSE"        "$TARGET/LICENSE"
cp -R "$AI_DIR/skills"        "$TARGET/skills"
cp -R "$AI_DIR/harness"       "$TARGET/harness"
cp -R "$AI_DIR/templates"     "$TARGET/templates"
cp -R "$AI_DIR/setup"         "$TARGET/setup"

# strip any stray junk
find "$TARGET" -name '.DS_Store' -delete

# --- leak check --------------------------------------------------------------
# Fail loudly if any known-personal token slipped into the export.
# Patterns come from _AI/leak-patterns.local. It is NOT copied into the export
# (the copy list above is an allowlist), but it IS tracked in this repo, on
# purpose: a fresh clone then gets a working leak check instead of silently
# degrading to the generic patterns below. That is safe only because this
# remote is private and already holds me.md and integrations/ -- the file adds
# no exposure those do not. If this repo is ever made public, that stops being
# true for every one of those files, not just this one.
# plus a couple of built-in generic patterns. Edit that file as your IDs change.
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
# line before the line is re-tested, so "Yannik Bauer" in LICENSE passes while
# any OTHER occurrence of [Yy]annik in the same file still fails. Widening a
# pattern would have disabled the check globally; this does not.
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

echo "Running leak check..."
if [ -f "$ALLOWFILE" ]; then
  echo "  (attribution allowlist: $(grep -cvE '^[[:space:]]*(#|$)' "$ALLOWFILE") literal(s))"
fi
LEAKED=0
for p in "${PATTERNS[@]}"; do
  # grep from INSIDE $TARGET so output paths are relative: an absolute path can
  # itself contain a personal token (e.g. /Users/<name>/...) and would otherwise
  # trip the re-test on every single line.
  hits="$(cd "$TARGET" && grep -rEIn --binary-files=without-match -- "$p" . 2>/dev/null \
            | strip_allowed \
            | grep -E -- "$p" || true)"
  if [ -n "$hits" ]; then
    echo "  LEAK: pattern '$p' matched in export:" >&2
    printf '%s\n' "$hits" >&2
    LEAKED=1
  fi
done
if [ "$LEAKED" -ne 0 ]; then
  echo >&2
  echo "! Personal data detected in export. Aborting; NOT initializing git." >&2
  echo "! Remove the offending content and re-run." >&2
  exit 2
fi
echo "  clean — no personal tokens found."

# --- fresh git history -------------------------------------------------------
# Pin the commit identity rather than inheriting ~/.gitconfig. Two reasons, and
# the second is the one that bites:
#
#   1. A CI runner has no git identity at all, so `git commit` aborts.
#   2. This export is meant to be pushed to a PUBLIC remote. Commit metadata is
#      not file content, so the leak check above cannot see it -- inheriting the
#      ambient identity would put your real address in the first public commit,
#      permanently and unscrubbably.
#
# publish.local supplies your chosen public identity if you have one; otherwise
# the fallback is deliberately impersonal. ("@localhost" has no dot-TLD, so it
# does not trip the generic email pattern above.)
[ -f "$AI_DIR/publish.local" ] && . "$AI_DIR/publish.local"
EXPORT_GIT_NAME="${AIOS_PUBLIC_GIT_NAME:-AI OS export}"
EXPORT_GIT_EMAIL="${AIOS_PUBLIC_GIT_EMAIL:-ai-os@localhost}"
(
  cd "$TARGET" && git init -q && git add -A && \
  git -c "user.name=$EXPORT_GIT_NAME" -c "user.email=$EXPORT_GIT_EMAIL" \
      commit -q -m "AI OS framework (shareable export)"
)
echo
echo "Export ready at: $TARGET"
echo "Fresh git history, no personal data. Push it to a public remote when ready."
