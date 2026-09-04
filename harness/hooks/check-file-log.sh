#!/bin/sh
# Stop: refuse to end a session with vault writes missing from history/file-log.md.
#
# Exit 2 on Stop prevents stopping and continues the conversation, so this is
# enforcing rather than advisory. That is the whole reason this beats a hook that
# writes log entries itself: the rule becomes mechanical while the log keeps a
# human-meaningful reason column that only the model can fill in.
. "$(dirname "$0")/lib.sh"

sid=$(field '.session_id')
[ -n "$sid" ] || exit 0
trace="$AIOS_DIR/tmp/writes-$sid.log"
[ -f "$trace" ] || exit 0

log="$AIOS_DIR/history/file-log.md"
missing=""
TAB=$(printf '\t')
while IFS="$TAB" read -r _ts _tool path; do
  [ -n "$path" ] || continue
  # Match on the vault-relative path, not the basename: two notes can share a
  # filename in different folders, and basename matching would pass one off as
  # the other's log entry — a false pass in a safety check.
  rel=${path#"${CLAUDE_PROJECT_DIR:-}/"}
  grep -Fq "$rel" "$log" 2>/dev/null || missing="$missing  $rel
"
done < "$trace"

[ -n "$missing" ] || exit 0

# LOOP GUARD: block at most once per session. A check the model cannot satisfy must
# never be able to wedge a session — that turns a safety feature into an outage.
marker="$AIOS_DIR/tmp/.filelog-blocked-$sid"
if [ -f "$marker" ]; then
  printf 'file-log still incomplete (already blocked once this session; not blocking again):\n%s' "$missing" >&2
  exit 0
fi
: > "$marker"
printf 'These vault notes were changed but have no entry in history/file-log.md:\n%s\nAppend one line per change — the format is at the top of that file — then finish.\n' "$missing" >&2
exit 2
