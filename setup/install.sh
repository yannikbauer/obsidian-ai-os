#!/usr/bin/env bash
#
# install.sh — set up the AI OS in an Obsidian vault.
#
# Idempotent. Run from anywhere; it locates itself. It:
#   1. Creates the vault-root CLAUDE.md stub (imports the _AI framework)
#   2. Creates the vault-root .claudeignore
#   3. Creates the .claude/skills -> _AI/skills symlink (native skill discovery)
#   4. Scaffolds missing personal files from templates/ (never overwrites):
#      me.md, maps/, history/, docs/, tmp/, and the .local config files
#      (leak-patterns, leak-allow, readonly-zones, publish), plus an empty
#      integrations/ for the setup skill to fill
#   5. Initializes the _AI/ git repo if needed
#   6. Verifies its own output and fails loudly if the install is broken
#
# Safe to re-run: existing files are left untouched.
#
# This script infers the vault from its own location: it must live at
# <vault>/_AI/setup/install.sh. Running it from a clone that is not named
# _AI, or not inside a vault, is refused rather than half-completed.

set -euo pipefail

# --- locate paths -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # _AI/setup
AI_DIR="$(dirname "$SCRIPT_DIR")"                            # _AI
VAULT_DIR="$(dirname "$AI_DIR")"                             # vault root
TPL="$AI_DIR/templates"

# --- 0. preflight: refuse to install into the wrong place --------------------
# The root stub's @-imports and the skills symlink both hardcode the name _AI.
# If this directory is called anything else, every path written below is wrong,
# so abort before touching the filesystem rather than leaving broken links.
if [ "$(basename "$AI_DIR")" != "_AI" ]; then
  cat >&2 <<MSG
! This directory is named '$(basename "$AI_DIR")', but the AI OS must live at
!   <your-obsidian-vault>/_AI
!
! The framework hardcodes that name: the vault-root CLAUDE.md stub imports
! @_AI/CLAUDE.md, and .claude/skills symlinks to ../_AI/skills. Installing from
! a differently-named directory produces a broken symlink and a stub pointing at
! files that do not exist.
!
! Fix: move (or clone) this directory into your vault under the name _AI, then
! re-run:
!     mv "$AI_DIR" "/path/to/your/vault/_AI"
!     bash "/path/to/your/vault/_AI/setup/install.sh"
MSG
  exit 1
fi

# Guard against installing into HOME or / — the usual result of running the
# script from wherever a clone happened to land.
if [ "$VAULT_DIR" = "$HOME" ] || [ "$VAULT_DIR" = "/" ]; then
  echo "! Refusing to install: the parent of _AI is '$VAULT_DIR'." >&2
  echo "! That is your home (or root), not an Obsidian vault. Move _AI into a vault first." >&2
  exit 1
fi

echo "AI OS install"
echo "  vault : $VAULT_DIR"
echo "  _AI   : $AI_DIR"
if [ ! -d "$VAULT_DIR/.obsidian" ]; then
  echo "  note  : no .obsidian/ here — proceeding, but check this is really your vault"
fi
echo

# --- 1. root CLAUDE.md stub --------------------------------------------------
if [ -e "$VAULT_DIR/CLAUDE.md" ]; then
  echo "• CLAUDE.md exists — leaving as is"
else
  cp "$TPL/CLAUDE.root.template.md" "$VAULT_DIR/CLAUDE.md"
  echo "• created CLAUDE.md (root stub)"
fi

# --- 2. root .claudeignore ---------------------------------------------------
if [ -e "$VAULT_DIR/.claudeignore" ]; then
  echo "• .claudeignore exists — leaving as is"
else
  cp "$TPL/claudeignore.template" "$VAULT_DIR/.claudeignore"
  echo "• created .claudeignore"
fi

# --- 3. skills symlink -------------------------------------------------------
mkdir -p "$VAULT_DIR/.claude"
LINK="$VAULT_DIR/.claude/skills"
if [ -L "$LINK" ]; then
  echo "• .claude/skills symlink exists — leaving as is"
elif [ -e "$LINK" ]; then
  echo "! .claude/skills exists and is NOT a symlink — skipping (resolve manually)"
else
  # relative link keeps it portable if the vault moves
  ln -s "../_AI/skills" "$LINK"
  echo "• linked .claude/skills -> _AI/skills"
fi

# The harness's own config, same pattern: the real file is tracked in _AI/, the
# vault root only points at it. Without this the OS is version-controlled but the
# settings it runs on are not.
SLINK="$VAULT_DIR/.claude/settings.json"
if [ -L "$SLINK" ]; then
  echo "• .claude/settings.json symlink exists — leaving as is"
elif [ -e "$SLINK" ]; then
  echo "! .claude/settings.json exists and is NOT a symlink — skipping (resolve manually)"
else
  ln -s "../_AI/harness/settings.json" "$SLINK"
  echo "• linked .claude/settings.json -> _AI/harness/settings.json"
fi

# --- 4. scaffold missing personal files from templates -----------------------
scaffold () {  # $1 = template path (relative to _AI), $2 = target (relative to _AI)
  local src="$AI_DIR/$1" dst="$AI_DIR/$2"
  if [ -e "$dst" ]; then
    echo "• $2 exists — leaving as is"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "• scaffolded $2 (fill it in)"
  fi
}
scaffold "templates/me.template.md"                      "me.md"
scaffold "templates/vault-map.template.md"               "maps/vault-map.md"
# history/ must exist before the first logged change, or rule 5 fails on first use
scaffold "templates/file-log.template.md"                "history/file-log.md"
scaffold "templates/session-log.template.md"             "history/session-log.md"
# the learning ledger (framework rule 7) — the retro skill has nowhere to write without it
scaffold "templates/lessons-log.template.md"             "history/lessons.md"
# tmp/ is gitignored, so a fresh clone has no folder — scaffold its README to create it
scaffold "templates/tmp-readme.template.md"              "tmp/README.md"
# docs/ is never exported, so a fresh clone has no folder and no hint that it is a
# place to write. The README is the hint.
scaffold "templates/docs-readme.template.md"             "docs/README.md"

# The .local files. None of these ship, so without scaffolding a fresh install has
# no sign they exist — and the leak-patterns one is a safety gap, not a convenience:
# absent, export.sh silently falls back to two generic checks and publishes anyway.
scaffold "templates/leak-patterns.template.local"        "leak-patterns.local"
scaffold "templates/readonly-zones.template.local"       "readonly-zones.local"
scaffold "templates/leak-allow.template.local"           "leak-allow.local"
scaffold "templates/publish.template.local"              "publish.local"
# all-comments by default, so the built-in English vocabulary stays in force until
# someone actually edits it — but the file exists, which is the only way anyone learns
# the knob is there
scaffold "templates/correction-words.template.local"      "correction-words.local"

# integrations/ stays EMPTY on purpose: in this framework a file's existence is the
# on-switch, so a placeholder .md here would read as a half-configured tool. The
# `setup` skill writes the real files. Create the directory so it is discoverable.
mkdir -p "$AI_DIR/integrations"
echo "• integrations/ ready (empty — the setup skill fills it)"

# --- 5. git init for _AI ------------------------------------------------------
if [ -d "$AI_DIR/.git" ]; then
  echo "• _AI git repo already initialized"
else
  ( cd "$AI_DIR" && git init -q && echo "• git init in _AI/" )
fi

# --- 6. verify the install actually works ------------------------------------
# Case A of the 2026-08-28 install test produced a fully broken tree while
# printing a success line for every step. An install with no success criterion
# is not an install, so check the two things that silently go wrong.
echo
echo "Verifying..."
FAILED=0

if [ -e "$VAULT_DIR/.claude/skills" ]; then
  echo "  ok   skills symlink resolves"
else
  echo "  FAIL skills symlink does not resolve: $VAULT_DIR/.claude/skills" >&2
  FAILED=1
fi

if [ -e "$VAULT_DIR/.claude/settings.json" ]; then
  echo "  ok   harness settings symlink resolves"
else
  echo "  FAIL harness settings symlink does not resolve: $VAULT_DIR/.claude/settings.json" >&2
  FAILED=1
fi

# Hooks fail open by design, so a missing jq is silent: the gates simply stop
# enforcing. Say so at install time rather than letting it be discovered later.
if [ -x /usr/bin/jq ]; then
  echo "  ok   jq present at /usr/bin/jq"
else
  echo "  FAIL /usr/bin/jq missing — hooks fail open, so the safety gates will not enforce" >&2
  FAILED=1
fi

while IFS= read -r imp; do
  target="${imp#@}"
  if [ -e "$VAULT_DIR/$target" ]; then
    echo "  ok   root stub import: $target"
  else
    echo "  FAIL root stub imports a missing file: $target" >&2
    FAILED=1
  fi
done < <(grep '^@' "$VAULT_DIR/CLAUDE.md" || true)

if [ "$FAILED" -ne 0 ]; then
  echo >&2
  echo "! Install is INCOMPLETE — see the FAIL lines above." >&2
  echo "! Nothing was deleted; fix the cause and re-run this script." >&2
  exit 3
fi
echo "  all checks passed."

echo
echo "Done. Next:"
echo "  - fill in _AI/me.md, _AI/maps/vault-map.md if freshly scaffolded"
echo "  - start a session and run the 'setup' skill to configure your tools (writes _AI/integrations/)"
echo "  - cd \"$VAULT_DIR\" && claude   # start a session"
