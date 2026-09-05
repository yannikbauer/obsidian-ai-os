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
# Fail loudly if any known-personal token slipped into the export. The scan lives
# in leak-check.sh so publish.sh can run the identical check over things that are
# not files in the tree -- generated commit messages, specifically.
echo "Running leak check..."
if ! bash "$SCRIPT_DIR/leak-check.sh" "$TARGET"; then
  echo >&2
  echo "! Personal data detected in export. Aborting; NOT initializing git." >&2
  echo "! Remove the offending content and re-run." >&2
  exit 2
fi

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
