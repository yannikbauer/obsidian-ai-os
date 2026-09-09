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
# Included: framework CLAUDE.md, .claude/ (settings, hooks, skills), tests/, tools/,
#           templates/, setup/, README, CONTRIBUTING, ignore files.
# Excluded: me.md, maps/, integrations/, history/, tmp/, databases/ (all personal).
# This is an allowlist — a new personal folder is excluded by default, not by rule.
cp    "$AI_DIR/CLAUDE.md"      "$TARGET/CLAUDE.md"
cp    "$AI_DIR/.gitignore"     "$TARGET/.gitignore"
# VERSION names what a fork actually has. It is the one file here whose whole
# purpose is to be read by someone WITHOUT access to this repo -- the private
# history answers "what changed" for you, and answers nothing for them.
cp    "$AI_DIR/VERSION"        "$TARGET/VERSION"
[ -f "$AI_DIR/README.md" ] && cp "$AI_DIR/README.md" "$TARGET/README.md"
[ -f "$AI_DIR/CONTRIBUTING.md" ] && cp "$AI_DIR/CONTRIBUTING.md" "$TARGET/CONTRIBUTING.md"
# A public repo without a licence is all-rights-reserved: nobody may legally reuse
# it. The licence names the copyright holder, which is why the leak check needs
# config/leak-allow.local -- see below.
cp    "$AI_DIR/LICENSE"        "$TARGET/LICENSE"
# NOTICE is not optional decoration: section 4 of Apache-2.0 requires redistributions
# to carry it, so an export without it hands people a licence they cannot comply with.
[ -f "$AI_DIR/NOTICE" ] && cp "$AI_DIR/NOTICE" "$TARGET/NOTICE"

# .github/ as a whole stays private -- the workflows name the private remote and its
# publishing mechanics. FUNDING.yml is the one file in it that is meant for strangers:
# it renders the Sponsor button, and without an exception it can never reach the public
# repo, because publish.sh syncs with --delete and would remove anything added there by
# hand. A NARROW exception, one named file, not the folder: widening it to `.github/*`
# would ship the workflows the next time one is added, silently.
if [ -f "$AI_DIR/.github/FUNDING.yml" ]; then
  mkdir -p "$TARGET/.github"
  cp "$AI_DIR/.github/FUNDING.yml" "$TARGET/.github/FUNDING.yml"
fi

# The public repo's CI. A SEPARATE, generic workflow rather than an exception on verify.yml:
# copying that one out would drag the public-diff rendering and the private remote's name with
# it. This runs the two gates and an install, needs no secret, and is what a contributor's pull
# request should trigger -- CONTRIBUTING.md asks them to run the suite and, until now, nothing
# checked that they had. It is renamed on the way out: `public-ci.yml` says what it is in here,
# `ci.yml` is what it should be called there.
if [ -f "$AI_DIR/.github/workflows/public-ci.yml" ]; then
  mkdir -p "$TARGET/.github/workflows"
  cp "$AI_DIR/.github/workflows/public-ci.yml" "$TARGET/.github/workflows/ci.yml"
fi
# tests/ ships beside the hooks it exercises: a fork that cannot run the suite cannot
# tell a working gate from a dead one.
cp -R "$AI_DIR/tests"         "$TARGET/tests"
# .claude/ ships for its ignore rule above all: it is the directory other programs write
# into, and a fork without that rule commits their droppings on its first push. cp -R
# carries the dotfile; the fresh `git add` below then honours it.
cp -R "$AI_DIR/.claude"       "$TARGET/.claude"
# tools/ ships: skills call these scripts by path, so a shareable skill whose helper
# stays behind is a skill that is broken on arrival. Caught 2026-09-05 — an allowlist
# excludes a new folder by default, which is the safe failure for personal data and
# the silent one for generic code.
[ -d "$AI_DIR/tools" ] && cp -R "$AI_DIR/tools" "$TARGET/tools"
cp -R "$AI_DIR/templates"     "$TARGET/templates"
cp -R "$AI_DIR/setup"         "$TARGET/setup"

# DECLARED EXCLUSIONS. Everything tracked at the top level is either copied above or
# named here — tools/check-coverage.sh enforces that, so a new top-level file or folder
# forces a deliberate decision instead of inheriting the allowlist's silent default.
# (Ledger L008: an allowlist's safe default for personal data is its silent default for
# generic code — that is how tools/ nearly shipped a skill without its helper.)
#
# `config/` is one entry standing for six knobs (2026-09-08, roadmap #36). That trades a
# forced decision per FILE for a forced decision per FOLDER, and a new knob dropped into
# config/ would inherit the exclusion silently -- L008 again, inside the mechanism built
# to prevent it. check-coverage.sh closes it from the other side: every file in config/
# must have a templates/*.template.local, and every such template must appear in the
# README tree. A knob with no template is now the thing that fails, rather than a knob
# with no declaration.
# CHANGELOG.md is not here because it is not in THIS repo at all: publish.sh generates it
# into the public one, where it accretes an entry per release. It still has to be declared,
# because check 3 enumerates what is TRACKED and the public clone tracks it -- and that is
# the representation nobody was running the gates on. Both gates failed on a fresh clone of
# the published repo while passing here and inside a fresh export, because an export has no
# changelog (L003, on the repo that documents L003).
# NOT_EXPORTED: me.md maps integrations history tmp databases docs .github(except FUNDING.yml and the public CI workflow) config CHANGELOG.md

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
# config/publish.local supplies your chosen public identity if you have one; otherwise
# the fallback is deliberately impersonal. ("@localhost" has no dot-TLD, so it
# does not trip the generic email pattern above.)
[ -f "$AI_DIR/config/publish.local" ] && . "$AI_DIR/config/publish.local"
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
