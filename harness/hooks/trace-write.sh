#!/bin/sh
# PostToolUse: record vault-note writes so the Stop hook can check them
# against history/file-log.md.
#
# Scope is deliberately narrow. This is not a general trace — Claude Code's own
# transcripts already hold every tool call and its token usage. This file exists to
# serve one consumer, and lives in tmp/ (gitignored) because it quotes vault paths.
#
# Matches both write routes, for the reason in guard-vault-write.sh: Write|Edit
# carry an absolute .tool_input.file_path, the MCP vault_* tools a vault-relative
# .tool_input.path. Tracing only the first meant a whole session of Bash-and-API
# edits left this log empty and the Stop hook with nothing to check.
. "$(dirname "$0")/lib.sh"

path=$(field '.tool_input.file_path')
[ -n "$path" ] || path=$(field '.tool_input.path')
sid=$(field '.session_id')
[ -n "$path" ] && [ -n "$sid" ] || exit 0

# CLAUDE_PROJECT_DIR is the authority on where the project root is; the script's own
# location (<vault>/_AI/harness/hooks/) is only the fallback for when it is unset.
# Deriving from the location FIRST looks more robust and is wrong: it ignores the one
# signal the harness actually provides, and pins the hook to the tree it was copied from.
VAULT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$VAULT" ] || VAULT="$(cd "$(dirname "$0")/../../.." 2>/dev/null && pwd)"
[ -n "$VAULT" ] || exit 0

case "$path" in
  /*) : ;;
  *)  path="$VAULT/$path" ;;
esac

# MEMBERSHIP IS TESTED POSITIVELY. Excluding _AI/ and calling everything else a vault
# note was wrong in the one direction that matters: Claude writes outside the vault all
# the time -- scratchpad files, ~/.claude/ memory, anything under /tmp -- and every one
# of those was traced as a note, then demanded of file-log.md by the Stop hook. Seen
# 2026-09-05 (a scratchpad .html) and again 2026-09-07 (two memory files); both times the
# session correctly refused to write a false entry, and both times the hook survived to
# do it again. Logging a non-note would be worse than the false alarm: file-log.md means
# "vault notes outside _AI/", and an entry that is not one corrupts the audit trail.
case "$path" in
  "$VAULT"/*) : ;;
  *) exit 0 ;;
esac

# _AI/ is version-controlled; git is its audit trail, so it needs no log line.
case "$path" in
  */_AI/*) exit 0 ;;
esac

mkdir -p "$AIOS_DIR/tmp" 2>/dev/null || exit 0
printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(field '.tool_name')" "$path" \
  >> "$AIOS_DIR/tmp/writes-$sid.log" 2>/dev/null
exit 0
