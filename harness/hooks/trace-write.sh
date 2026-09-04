#!/bin/sh
# PostToolUse (Write|Edit): record vault-note writes so the Stop hook can check them
# against history/file-log.md.
#
# Scope is deliberately narrow. This is not a general trace — Claude Code's own
# transcripts already hold every tool call and its token usage. This file exists to
# serve one consumer, and lives in tmp/ (gitignored) because it quotes vault paths.
. "$(dirname "$0")/lib.sh"

path=$(field '.tool_input.file_path')
sid=$(field '.session_id')
[ -n "$path" ] && [ -n "$sid" ] || exit 0

# _AI/ is version-controlled; git is its audit trail, so it needs no log line.
case "$path" in
  */_AI/*) exit 0 ;;
esac

mkdir -p "$AIOS_DIR/tmp" 2>/dev/null || exit 0
printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(field '.tool_name')" "$path" \
  >> "$AIOS_DIR/tmp/writes-$sid.log" 2>/dev/null
exit 0
