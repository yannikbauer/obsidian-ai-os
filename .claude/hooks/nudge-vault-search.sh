#!/bin/sh
# PreToolUse (Grep, Bash): reminds the model, once per session, that the vault has a
# search index, when it reaches for a content grep over the notes. Never blocks: grep is
# still right for exact strings and for regexes, and a nudge that denied would teach the
# model to route around it (roadmap #10).
#
# Why a hook and not only the line in CLAUDE.md: "search before grep" is a habit, and
# habits are what a prose rule loses mid-session. The nudge only makes the choice visible.
#
# Two routes, because the Grep tool does not exist everywhere: Claude Desktop sessions
# have none and grep through Bash (live check, 2026-11-03). For Bash the test is dumb on
# purpose, like guard-bash-vault.sh: the command runs grep/rg, and nothing marks it as
# aimed at the OS's own code. A false nudge costs one line of context, once.
#
# Silent when there is no index yet, when the grep targets the OS directory (code, not
# notes), and after the first nudge in a session.
. "$(dirname "$0")/lib.sh"

DB="${AIOS_SEARCH_DB:-$AIOS_DIR/databases/vault-search.db}"
[ -f "$DB" ] || exit 0

VAULT="${VAULT_DIR%/}"
cwd=$(field '.cwd')
case "$(field '.tool_name')" in
  Grep)
    p=$(field '.tool_input.path')
    [ -n "$p" ] || p=$cwd
    [ -n "$p" ] || exit 0
    case "$p" in
      "$AIOS_DIR"|"$AIOS_DIR"/*) exit 0 ;;
      "$VAULT"|"$VAULT"/*) ;;
      /*) exit 0 ;;                   # outside the vault
    esac ;;
  Bash)
    cmd=$(field '.tool_input.command')
    printf '%s' "$cmd" | grep -Eq '(^|[|;&(`[:space:]])(grep|egrep|rg)([[:space:]]|$)' || exit 0
    # Searching the OS itself (by its directory name or path) is code work.
    case "$cmd" in *"$(basename "$AIOS_DIR")/"*|*"$AIOS_DIR"*) exit 0 ;; esac
    # From inside the OS directory, a relative grep stays there unless it climbs out.
    case "$cwd" in
      "$AIOS_DIR"|"$AIOS_DIR"/*)
        case "$cmd" in *../*|*"$VAULT"*) ;; *) exit 0 ;; esac ;;
      "$VAULT"|"$VAULT"/*) ;;
      *) case "$cmd" in *"$VAULT"*) ;; *) exit 0 ;; esac ;;
    esac ;;
  *) exit 0 ;;
esac

sid=$(field '.session_id')
if [ -n "$sid" ] && mkdir -p "$AIOS_DIR/tmp" 2>/dev/null; then
  mark="$AIOS_DIR/tmp/nudged-search-$sid"
  [ -f "$mark" ] && exit 0
  : > "$mark" 2>/dev/null
fi

msg='This vault has a semantic search index. To find notes by topic or meaning (paraphrase, German/English, "which note was about…"), run: _AI/tools/vault-search.py search "<question>" (directly, not via python3). It ranks notes and returns pointers for private ones. Grep is still right for an exact string or regex. (Shown once per session.)'
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":%s}}\n' \
  "$(printf '%s' "$msg" | /usr/bin/jq -Rs .)"
exit 0
