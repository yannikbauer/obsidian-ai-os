#!/bin/sh
# PreToolUse (Read, vault_read): asks before a note marked
# private or secret is opened. Asks, never denies: the label exists so private text
# does not reach a cloud model *unwatched* (batch jobs, digests, a search for something
# else), not to keep the owner out of their own notes (roadmap #8, #11).
#
# A note's label comes from two places, and the stricter wins:
#   1. its frontmatter: `sensitivity: private|secret`
#   2. config/sensitivity.local: `<glob> = private|secret`, vault-relative globs
# The frontmatter is read by this hook, never by the model: the whole point is that
# nothing of the note reaches the context before the human says yes.
#
# AIOS_INCLUDE_PRIVATE=1 in the session's environment skips the question. It is an
# env var on purpose: the model cannot set it for itself from inside the session.
#
# Known gap: Grep, and Bash cat/sed, read file content without passing through here.
# This closes the routine route, not every route.
. "$(dirname "$0")/lib.sh"

[ "${AIOS_INCLUDE_PRIVATE:-}" = 1 ] && exit 0

p=$(field '.tool_input.file_path')
[ -n "$p" ] || p=$(field '.tool_input.path')
[ -n "$p" ] || exit 0
# A frontmatter-only vault_read returns properties, not the note: let it through.
[ "$(field '.tool_input.targetType')" = frontmatter ] && exit 0

VAULT="${VAULT_DIR%/}"
case "$p" in
  "$VAULT"/*) rel=${p#"$VAULT"/} ;;
  /*) exit 0 ;;                       # outside the vault: not a note
  *) rel=$p ;;                        # MCP route: already vault-relative
esac
case "$rel" in *.md) ;; *) exit 0 ;; esac
abs="$VAULT/$rel"

rank() { case "$1" in secret) echo 2 ;; private) echo 1 ;; *) echo 0 ;; esac; }
label=""

RULES="$AIOS_DIR/config/sensitivity.local"
if [ -f "$RULES" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    pat=$(printf '%s' "${line%%=*}" | sed 's/[[:space:]]*$//; s/\*\*/*/g')
    lab=$(printf '%s' "${line#*=}" | tr -d '[:space:]')
    # $pat is deliberately unquoted: in `case`, that makes it a glob.
    case "$rel" in $pat) [ "$(rank "$lab")" -gt "$(rank "$label")" ] && label=$lab ;; esac
  done < "$RULES"
fi

if [ -f "$abs" ]; then
  # Frontmatter only: the first block between --- lines, at most 80 lines in.
  fm=$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1 {print} NR>80 {exit}' "$abs" 2>/dev/null \
    | sed -n 's/^sensitivity:[[:space:]]*["'\'']*\([a-z]*\).*/\1/p' | head -1)
  [ "$(rank "$fm")" -gt "$(rank "$label")" ] && label=$fm
fi

case "$label" in
  secret)  ask "Sensitive note ($label): $rel holds credentials or account numbers. Opening it sends its content to the model. Approve only if you mean to read it now; set AIOS_INCLUDE_PRIVATE=1 for a session that should read private notes without asking." ;;
  private) ask "Sensitive note ($label): $rel is marked private. Opening it sends its content to the model. Approve to read it; set AIOS_INCLUDE_PRIVATE=1 for a session that should read private notes without asking." ;;
esac
exit 0
