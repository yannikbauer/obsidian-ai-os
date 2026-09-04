#!/usr/bin/env bash
#
# publish.sh — push the shareable export to the public repo, preserving history.
#
# export.sh is a one-shot: it refuses an existing target and inits FRESH git
# history, so using it to update a published repo would orphan every previous
# commit. This script keeps the public history intact:
#
#   1. run export.sh into a temp dir  (leak check runs there — an abort stops us)
#   2. clone the public repo
#   3. rsync export -> clone, --delete so removals propagate
#   4. show the diff, confirm, commit, push
#
# The leak check is the ONLY barrier between this repo and a public one, and a
# push cannot be taken back. That is why step 4 confirms by default; --yes skips
# it and is meant for CI, where a human reviewed the change before it merged.
#
# Usage:
#   ./publish.sh                    export, diff, confirm, push to the default branch
#   ./publish.sh --dry-run          export and diff only — never pushes
#   ./publish.sh --yes              no confirmation prompt (CI)
#   ./publish.sh --branch sync/main push to a branch instead, for review via PR
#
# Environment overrides:
#   AIOS_PUBLIC_REMOTE      destination repo
#   AIOS_PUBLIC_GIT_NAME    author name on public commits
#   AIOS_PUBLIC_GIT_EMAIL   author email on public commits

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$(dirname "$SCRIPT_DIR")"

# Your destination and identity are PERSONAL, so they are not baked in here --
# this script ships in the export and must be generic for whoever forks it.
# Settings resolve in order: environment, then _AI/publish.local (never exported,
# same convention as leak-patterns.local), then nothing.
[ -f "$AI_DIR/publish.local" ] && . "$AI_DIR/publish.local"

PUBLIC_REMOTE="${AIOS_PUBLIC_REMOTE:-}"
if [ -z "$PUBLIC_REMOTE" ]; then
  cat >&2 <<'MSG'
! No destination configured. Create _AI/publish.local:
!
!     AIOS_PUBLIC_REMOTE=https://github.com/<you>/<repo>.git
!     AIOS_PUBLIC_GIT_NAME="Your Name"
!     AIOS_PUBLIC_GIT_EMAIL=<you>@users.noreply.github.com
!
! or set AIOS_PUBLIC_REMOTE in the environment.
MSG
  exit 64
fi

# Commit METADATA is not file content, so the leak check cannot see it: a plain
# `git commit` would stamp the name and address from ~/.gitconfig onto every
# public commit, permanently. Pin an explicit identity instead. A GitHub noreply
# address still links commits to your account without publishing a mailbox.
PUBLIC_GIT_NAME="${AIOS_PUBLIC_GIT_NAME:-AI OS publish}"
PUBLIC_GIT_EMAIL="${AIOS_PUBLIC_GIT_EMAIL:-}"
if [ -z "$PUBLIC_GIT_EMAIL" ]; then
  echo "! AIOS_PUBLIC_GIT_EMAIL is unset — refusing to publish with your ~/.gitconfig" >&2
  echo "! identity, which would put your real address in public commit metadata." >&2
  echo "! Set it in _AI/publish.local (a <user>@users.noreply.github.com address works)." >&2
  exit 64
fi

DRY_RUN=0
ASSUME_YES=0
BRANCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    --branch)
      shift
      [ $# -gt 0 ] || { echo "! --branch needs a name" >&2; exit 64; }
      BRANCH="$1"
      ;;
    --branch=*) BRANCH="${1#--branch=}" ;;
    *) echo "! unknown argument: $1" >&2; exit 64 ;;
  esac
  shift
done

command -v rsync >/dev/null || { echo "! rsync not found" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Publishing AI OS"
echo "  from   : $AI_DIR"
echo "  to     : $PUBLIC_REMOTE"
[ "$DRY_RUN" -eq 1 ] && echo "  mode   : DRY RUN (nothing will be pushed)"
echo

# --- 1. export (this is where the leak check runs) ---------------------------
# export.sh exits 2 on a leak; set -e turns that into an abort here, before the
# public repo is touched at all.
bash "$SCRIPT_DIR/export.sh" "$WORK/export"
echo

# --- 2. clone the public repo ------------------------------------------------
echo "Cloning public repo..."
if ! git clone --quiet "$PUBLIC_REMOTE" "$WORK/public" 2>"$WORK/clone.err"; then
  cat "$WORK/clone.err" >&2
  echo "! Could not clone $PUBLIC_REMOTE" >&2
  echo "! If the repo does not exist yet, create it first (--add-readme gives it a" >&2
  echo "! default branch, which a review PR needs as its base):" >&2
  echo "!     gh repo create <repo> --public --add-readme" >&2
  exit 1
fi

# A brand-new empty repo clones with no commits; make sure we are on a branch.
cd "$WORK/public"
if ! git rev-parse --verify -q HEAD >/dev/null; then
  git checkout -q -b main 2>/dev/null || true
  echo "  (public repo is empty — this will be its first commit)"
fi

# --- 3. sync ------------------------------------------------------------------
# --delete makes the public repo mirror the export exactly: a file removed from
# the allowlist disappears publicly instead of lingering. --exclude .git keeps
# the public history (that is the whole point of this script).
rsync -a --delete --exclude '.git' "$WORK/export/" "$WORK/public/"

# Tell a GitHub Actions caller whether anything actually changed, so it can skip
# opening an empty PR. Harmless and invisible outside CI ($GITHUB_OUTPUT is unset).
signal_changed () { [ -n "${GITHUB_OUTPUT:-}" ] && echo "changed=$1" >> "$GITHUB_OUTPUT"; return 0; }

git add -A
if git diff --cached --quiet; then
  signal_changed false
  echo
  echo "No changes — public repo is already up to date."
  exit 0
fi
signal_changed true

echo
echo "Changes to publish:"
git diff --cached --stat
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run — stopping here. Nothing was pushed."
  exit 0
fi

# --- 4. confirm, commit, push -------------------------------------------------
if [ "$ASSUME_YES" -ne 1 ]; then
  printf 'Push these changes to %s? [y/N] ' "$PUBLIC_REMOTE"
  read -r reply </dev/tty
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted. Nothing was pushed."; exit 0 ;;
  esac
fi

# Record which private commit this public state came from. The SHA is
# meaningless without access to the private repo, so it leaks nothing, but it
# answers "which version is this?" when the two drift.
SRC_SHA="$(cd "$AI_DIR" && git rev-parse --short HEAD 2>/dev/null || echo unknown)"
git -c "user.name=$PUBLIC_GIT_NAME" -c "user.email=$PUBLIC_GIT_EMAIL" \
    commit -q -m "Sync AI OS framework (source $SRC_SHA)"

if [ -n "$BRANCH" ]; then
  # Force is correct here and only here: the sync branch is a machine-owned
  # mirror of the current export, rebuilt from scratch each run. It is never the
  # default branch, so no human work can be sitting on it to lose.
  git push -q --force origin "HEAD:refs/heads/$BRANCH"
  echo
  echo "Pushed to branch '$BRANCH' on $PUBLIC_REMOTE."
  echo "Open a PR from it to review the public diff before it lands."
else
  git push -q origin HEAD
  echo
  echo "Published. $PUBLIC_REMOTE is now at $(git rev-parse --short HEAD)."
fi
