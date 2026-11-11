#!/bin/sh
# SessionStart: if yesterday's daily-log note is missing, tell Claude to offer the check-in.
#
# Why: the daily-log check-in is a local scheduled task, and a local task only runs while
# the app is running. With the laptop off at the scheduled hour it may never fire (first
# seen 2026-11-05: zero runs on its first morning). Opening a session is the next moment the
# user is reachable, so the offer happens there instead.
#
# Off unless the daily-log map exists AND carries a machine-readable path line:
#   <!-- daily-log-note-path: <strftime pattern, vault-relative> -->
# so the hook names no folder and no personal layout. Once per day (marker in tmp/), not
# before 07:00, never more than a context line: it offers, it does not run anything.
. "$(dirname "$0")/lib.sh"

MAP="$AIOS_DIR/maps/daily-log-map.md"
[ -f "$MAP" ] || exit 0
PATTERN=$(sed -n 's/^<!-- daily-log-note-path: \(.*\) -->$/\1/p' "$MAP" | head -1)
[ -n "$PATTERN" ] || exit 0

HOUR=$(date +%H)
[ "${AIOS_NOW_HOUR:-$HOUR}" -ge 7 ] 2>/dev/null || exit 0

TODAY=$(date +%Y-%m-%d)
MARK="$AIOS_DIR/tmp/nudged-daily-$TODAY"
[ -e "$MARK" ] && exit 0

# Yesterday in a given format: BSD date (macOS) first, GNU date (Linux, CI) as fallback.
yesterday() { LC_TIME=C date -v-1d +"$1" 2>/dev/null || LC_TIME=C date -d yesterday +"$1" 2>/dev/null; }

NOTE=$(yesterday "$PATTERN") || exit 0
[ -n "$NOTE" ] || exit 0
[ -e "$VAULT_DIR/$NOTE" ] && exit 0

DAY=$(yesterday %A)
mkdir -p "$AIOS_DIR/tmp" 2>/dev/null && : > "$MARK"

MSG="Daily check-in not done yet: no daily-log note for yesterday ($DAY). If the user is here and this is not an unattended scheduled run, offer it once in one line at the top of your first reply (e.g. \"Daily check-in for $DAY? Say the word.\"), then do what they asked. On a yes, run the daily-log skill. Don't raise it again this session."
/usr/bin/jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$m}}'
exit 0
