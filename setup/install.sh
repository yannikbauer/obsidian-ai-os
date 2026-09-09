#!/usr/bin/env bash
#
# install.sh — set up the AI OS in an Obsidian vault.
#
# Idempotent. Run from anywhere; it locates itself. It:
#   1. Creates the vault-root CLAUDE.md stub (imports the _AI framework)
#   2. Creates the vault-root .claudeignore
#   3. Creates (or repoints) the .claude/ symlinks into _AI/.claude/
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
! @_AI/CLAUDE.md, and .claude/skills symlinks to ../_AI/.claude/skills. Installing from
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

# --- 1b. root AGENTS.md stub -------------------------------------------------
# The same pointer, in the runtime-neutral file Codex, Cursor, Gemini CLI and others
# look for. A POINTER, never a copy: two files describing one framework is two
# frameworks, and only one of them gets edited.
if [ -e "$VAULT_DIR/AGENTS.md" ]; then
  echo "• AGENTS.md exists — leaving as is"
else
  cp "$TPL/AGENTS.root.template.md" "$VAULT_DIR/AGENTS.md"
  echo "• created AGENTS.md (root stub, runtime-neutral)"
fi

# --- 2. root .claudeignore ---------------------------------------------------
if [ -e "$VAULT_DIR/.claudeignore" ]; then
  echo "• .claudeignore exists — leaving as is"
else
  cp "$TPL/claudeignore.template" "$VAULT_DIR/.claudeignore"
  echo "• created .claudeignore"
fi

# --- 3. the two symlinks into the repo ---------------------------------------
# Both point at _AI/.claude/, so the skills Claude discovers and the settings it runs
# on are the ones under version control.
#
# RETARGETING IS THE POINT, not an afterthought. Until 2026-09-09 these lived at
# _AI/skills and _AI/harness/settings.json. An upgrade that found an existing symlink
# and said "leaving as is" would leave a fork pointing at directories that no longer
# exist -- a dangling link resolves to nothing, and hooks that cannot be found fail
# OPEN, so the gates would simply stop enforcing without a word. So a symlink whose
# target has moved is repointed; only a real file or directory is left for a human.
mkdir -p "$VAULT_DIR/.claude"

link_into_repo () {  # $1 = path under .claude/, $2 = relative target, $3 = label
  _l="$VAULT_DIR/.claude/$1"
  if [ -L "$_l" ]; then
    _cur=$(readlink "$_l")
    if [ "$_cur" = "$2" ]; then
      echo "• .claude/$1 symlink is current — leaving as is"
    else
      ln -sfn "$2" "$_l"
      echo "• repointed .claude/$1: $_cur -> $2"
    fi
  elif [ -e "$_l" ]; then
    echo "! .claude/$1 exists and is NOT a symlink — skipping (resolve manually)"
  else
    # relative link keeps it portable if the vault moves
    ln -s "$2" "$_l"
    echo "• linked .claude/$1 -> $2  ($3)"
  fi
}

link_into_repo skills        "../_AI/.claude/skills"        "native skill discovery"
link_into_repo settings.json "../_AI/.claude/settings.json" "model pin + hooks"

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
scaffold "templates/workflow-map.template.md"           "maps/workflow-map.md"
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
scaffold "templates/working-notes-readme.template.md"     "docs/working-notes/README.md"

# The .local files. None of these ship, so without scaffolding a fresh install has
# no sign they exist — and the leak-patterns one is a safety gap, not a convenience:
# absent, export.sh silently falls back to two generic checks and publishes anyway.
scaffold "templates/leak-patterns.template.local"        "config/leak-patterns.local"
scaffold "templates/readonly-zones.template.local"       "config/readonly-zones.local"
scaffold "templates/leak-allow.template.local"           "config/leak-allow.local"
scaffold "templates/publish.template.local"              "config/publish.local"
# all-comments by default, so the built-in English vocabulary stays in force until
# someone actually edits it — but the file exists, which is the only way anyone learns
# the knob is there
scaffold "templates/correction-words.template.local"      "config/correction-words.local"
scaffold "templates/clickup-replace-allow.template.local" "config/clickup-replace-allow.local"

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
  echo "  ok   settings symlink resolves"
else
  echo "  FAIL settings symlink does not resolve: $VAULT_DIR/.claude/settings.json" >&2
  FAILED=1
fi

# Hooks fail open by design, so a missing jq is silent: the gates simply stop
# enforcing. Say so at install time rather than letting it be discovered later.
# A missing AGENTS.md is silent in exactly the situation it exists for: another runtime
# opens the vault, finds no entry point, and improvises against a system it cannot see.
if [ -f "$VAULT_DIR/AGENTS.md" ]; then
  echo "  ok   AGENTS.md present (entry point for non-Claude runtimes)"
else
  echo "  FAIL AGENTS.md missing: $VAULT_DIR/AGENTS.md" >&2
  FAILED=1
fi

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
