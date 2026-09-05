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
#   AIOS_PUBLIC_TOPICS      space-separated GitHub topics, applied after a push
#   AIOS_PUBLIC_DESCRIPTION the repo's one-line description

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

sync_metadata () {
  # Topics and description are repo METADATA -- they live in GitHub's database,
  # not in any file, so nothing in the export can carry them and they drift
  # silently. Declaring them in publish.local makes them versioned like the rest.
  [ -n "${AIOS_PUBLIC_TOPICS:-}${AIOS_PUBLIC_DESCRIPTION:-}" ] || return 0

  if ! command -v gh >/dev/null; then
    echo "  (skipping topics/description: gh CLI not found)"
    return 0
  fi

  # owner/repo from the remote, https or ssh form
  slug="${PUBLIC_REMOTE%.git}"
  slug="${slug##*github.com/}"
  slug="${slug##*github.com:}"

  if [ -n "${AIOS_PUBLIC_TOPICS:-}" ]; then
    # PUT replaces the whole set, which is the point: publish.local is the single
    # source of truth, so removing a topic there removes it on GitHub too.
    want="$(printf '%s\n' $AIOS_PUBLIC_TOPICS | sort | tr '\n' ' ')"
    have="$(gh api "repos/$slug/topics" --jq '.names[]' 2>/dev/null | sort | tr '\n' ' ')"
    if [ "$want" = "$have" ]; then
      echo "  topics already match publish.local"
    else
      set -- --method PUT "repos/$slug/topics"
      for t in $AIOS_PUBLIC_TOPICS; do set -- "$@" -f "names[]=$t"; done
      # A fine-grained token scoped to Contents cannot write metadata, so this
      # fails in CI by design. That must not fail the publish -- the content is
      # already pushed, and metadata is cosmetic.
      if gh api "$@" >/dev/null 2>&1; then
        echo "  topics updated: $want"
      else
        echo "  (could not set topics -- the token likely lacks Administration:"
        echo "   write. Harmless; set them once from a machine with your gh login.)"
      fi
    fi
  fi

  if [ -n "${AIOS_PUBLIC_DESCRIPTION:-}" ]; then
    have_d="$(gh api "repos/$slug" --jq '.description // ""' 2>/dev/null)"
    if [ "$have_d" = "$AIOS_PUBLIC_DESCRIPTION" ]; then
      echo "  description already matches publish.local"
    elif gh api --method PATCH "repos/$slug" -f "description=$AIOS_PUBLIC_DESCRIPTION" >/dev/null 2>&1; then
      echo "  description updated"
    else
      echo "  (could not set description -- same permission caveat as topics)"
    fi
  fi
}

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
  # Metadata still gets a pass: topics and description live in GitHub's database,
  # not in the tree, so they can drift from publish.local while every file matches.
  # Exiting here would make a topics-only edit impossible to apply.
  if [ "$DRY_RUN" -ne 1 ] && [ -z "$BRANCH" ]; then sync_metadata; fi
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

# Build the public commit message from the private commit subjects since the last
# publish, so the public history says what changed instead of repeating one line.
#
# Three constraints make this less trivial than it looks:
#   1. Only commits touching EXPORTED paths belong here. A roadmap or session-log
#      commit changed nothing publicly, and its subject is private.
#   2. A commit subject is metadata, so the export's leak check never saw it.
#      Scan the generated text before it becomes a permanent public commit --
#      this is exactly the class of leak that has bitten this pipeline before.
#   3. Subjects reference private roadmap items by number. On a public repo "#29"
#      auto-links to an issue that does not exist, so the marker is neutralised
#      to plain words rather than left to render as a broken link.
BODY=""
SUBJECT="Sync AI OS framework"

# Where the next publish learns what it last published from. Read the whole
# message, not just the subject: the marker moved into a trailer when the subject
# became the change itself. The second pattern reads the older in-subject form,
# so the chain survives commits made before this change.
LAST_SRC="$(git log -1 --format=%B 2>/dev/null \
            | sed -n 's/^Source-commit: \([0-9a-f]\{7,\}\).*/\1/p' | head -1)"
[ -n "$LAST_SRC" ] || LAST_SRC="$(git log -1 --format=%s 2>/dev/null \
            | sed -n 's/.*(source \([0-9a-f]\{7,\}\))$/\1/p')"

if [ -n "$LAST_SRC" ] && (cd "$AI_DIR" && git cat-file -e "${LAST_SRC}^{commit}" 2>/dev/null); then
  CAND="$(cd "$AI_DIR" && git log --reverse --format='%s' "${LAST_SRC}..HEAD" -- \
            CLAUDE.md README.md LICENSE .gitignore skills harness templates setup 2>/dev/null \
          | sed -E 's/#([0-9]+)/item \1/g')"
  if [ -n "$CAND" ]; then
    printf '%s\n' "$CAND" > "$WORK/msg.txt"
    if bash "$SCRIPT_DIR/leak-check.sh" "$WORK/msg.txt" >/dev/null 2>&1; then
      N="$(printf '%s\n' "$CAND" | grep -c . || true)"
      if [ "$N" -eq 1 ]; then
        # One change: let it BE the subject, so `git log --oneline` is readable.
        SUBJECT="$CAND"
      else
        SUBJECT="Sync AI OS framework ($N changes)"
        BODY="$(printf '%s\n' "$CAND" | sed 's/^/- /')"
      fi
    else
      echo "  (commit subjects held a personal token — using the plain message;"
      echo "   the published FILES are unaffected, only this message)"
    fi
  fi
fi

# Source-commit is a trailer, not part of the subject, so the subject is free to
# carry the change. publish.sh reads it back on the next run.
if [ -n "$BODY" ]; then
  git -c "user.name=$PUBLIC_GIT_NAME" -c "user.email=$PUBLIC_GIT_EMAIL" \
      commit -q -m "$SUBJECT" -m "$BODY" -m "Source-commit: $SRC_SHA"
else
  git -c "user.name=$PUBLIC_GIT_NAME" -c "user.email=$PUBLIC_GIT_EMAIL" \
      commit -q -m "$SUBJECT" -m "Source-commit: $SRC_SHA"
fi

if [ -n "$BRANCH" ]; then
  # Force is correct here and only here: the sync branch is a machine-owned
  # mirror of the current export, rebuilt from scratch each run. It is never the
  # default branch, so no human work can be sitting on it to lose.
  git push -q --force origin "HEAD:refs/heads/$BRANCH"
  echo
  echo "Pushed to branch '$BRANCH' on $PUBLIC_REMOTE."
  echo "Open a PR from it to review the public diff before it lands."
  # Deliberately no metadata sync here: the branch is a proposal, and topics
  # would take effect on the live repo before anyone approved it.
else
  git push -q origin HEAD
  echo
  echo "Published. $PUBLIC_REMOTE is now at $(git rev-parse --short HEAD)."
  sync_metadata
fi
