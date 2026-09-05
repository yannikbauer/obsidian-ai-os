#!/bin/sh
# Stop: if the session shows signs of having taught something, ask about a retro.
#
# IT ASKS; IT NEVER RUNS. Roadmap #3 rejected a Stop hook because firing a retro at
# every session end would pay a full extraction pass to usually hear "no lessons".
# That objection is against auto-RUNNING. Auto-ASKING is one injected sentence, and it
# removes the single thing the whole learning loop otherwise depends on: the user
# remembering to invoke it. Deciding stays with the human.
#
# THE SIGNALS ARE MECHANICAL ON PURPOSE. A hook cannot judge whether a session was
# interesting, so it does not try — it counts denials, corrections, errored calls and
# framework writes, and defers. A purely conceptual lesson will not trip it, which is
# a known and accepted gap: this is a nudge, not a net.
. "$(dirname "$0")/lib.sh"

THRESHOLD=2

# stop_hook_active means we already blocked once and the model is continuing. Blocking
# again from here is how a Stop hook wedges a session.
[ "$(field '.stop_hook_active')" = "true" ] && exit 0

sid=$(field '.session_id')
transcript=$(field '.transcript_path')
[ -n "$sid" ] && [ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# Ask at most once per session, whatever the answer was. A hook that re-asks every turn
# is a hook the user turns off.
marker="$AIOS_DIR/tmp/.retro-asked-$sid"
[ -f "$marker" ] && exit 0

digest="$AIOS_DIR/tools/session-digest.sh"
[ -x "$digest" ] || exit 0
signals=$(AIOS_DIR="$AIOS_DIR" "$digest" --signals --transcript "$transcript" --session "$sid" 2>/dev/null) || exit 0

score=${signals#score=}
score=${score%% *}
case "$score" in ''|*[!0-9]*) exit 0 ;; esac
[ "$score" -ge "$THRESHOLD" ] || exit 0

mkdir -p "$AIOS_DIR/tmp" 2>/dev/null && : > "$marker"

printf 'This session shows teaching signals (%s).\n\nAsk the user — once, in one line — whether to run /retro before finishing. Do not run it unasked, and do not re-raise it if they decline.\n' \
  "$signals" >&2
exit 2
