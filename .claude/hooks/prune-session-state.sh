#!/bin/sh
# SessionStart: moves other sessions' old hook markers in tmp/ to the macOS Trash.
#
# The hooks leave one small file per session (writes-, denies-, collision-acks-,
# nudged-search-, .retro-asked-, .filelog-blocked-). They must outlive a turn, and a resumed
# session needs them again, so nothing can delete them when a session "ends": Stop fires
# every turn, and SessionEnd also fires on an exit that a resume later undoes. Age is the
# safe signal: a marker untouched for 14 days belongs to a session nobody is coming back to.
# Before this hook they piled up to ~110 files (first cleanup, 2026-11-05).
#
# The Trash, never rm (the vault rule against permanent deletion). No trash command: leave
# them; `vault-health.py tmp` still lists them. Silent, and quick: usually nothing matches.
. "$(dirname "$0")/lib.sh"

TRASH="${AIOS_TRASH:-/usr/bin/trash}"
DAYS="${AIOS_STATE_DAYS:-14}"
[ -x "$TRASH" ] || exit 0
[ -d "$AIOS_DIR/tmp" ] || exit 0

find "$AIOS_DIR/tmp" -maxdepth 1 -type f -mtime +"$DAYS" \( \
    -name 'writes-*.log' -o -name 'denies-*.log' -o -name 'collision-acks-*.log' \
    -o -name 'nudged-search-*' -o -name '.retro-asked-*' -o -name '.filelog-blocked-*' \) \
    -exec "$TRASH" {} + >/dev/null 2>&1 </dev/null
exit 0
