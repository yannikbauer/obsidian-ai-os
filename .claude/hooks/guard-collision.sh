#!/bin/sh
# Cross-session collision guard. One script, three call sites (see .claude/settings.json):
#
#   PostToolUse  on note/file writes → RECORD  <epoch> <session> <path> in tmp/touches.log
#   PreToolUse   on note/file writes → ASK if another session wrote that path recently
#   PreToolUse   on Bash git add/commit → ASK if a file being staged was written by
#                another session recently
#
# WHY. The user runs several sessions against one vault and one _AI/ working tree.
# Claude Code already refuses a Write/Edit to a file that changed since it was read, so
# bytes are rarely lost. What goes wrong is intent. Two sessions reshape the same skill
# in different directions, or one commits the other's half-finished file. Git cannot
# see vault notes at all. So this hook tracks writes itself, per session, across both.
#
# ASK, NEVER DENY. Two sessions touching one file is often fine (the user may be steering
# both). The hook cannot tell, so it surfaces the overlap and the human decides. It asks
# once per (path, other session) per session, since an overlap you approved stays approved.
#
# "Recently" = AIOS_COLLISION_WINDOW seconds (default 1800). There is no liveness signal
# for a session, so recency stands in for "still running".
#
# EXEMPT: _AI/tmp/ (scratch, never recorded) and _AI/history/ (append-only logs that
# every session writes to by design; the stale-read check covers their bytes).
. "$(dirname "$0")/lib.sh"

sid=$(field '.session_id')
[ -n "$sid" ] || exit 0
event=$(field '.hook_event_name')
tool=$(field '.tool_name')
WINDOW="${AIOS_COLLISION_WINDOW:-1800}"
LOG="$AIOS_DIR/tmp/touches.log"
ACKS="$AIOS_DIR/tmp/collision-acks-$sid.log"
now=$(date +%s)

abs() { # abs <path> — vault-relative paths (the MCP route) become absolute
  case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$VAULT_DIR" "$1" ;; esac
}

exempt() {
  case "$1" in "$AIOS_DIR"/tmp/*|"$AIOS_DIR"/history/*) return 0 ;; esac
  return 1
}

other_writer() { # other_writer <abs-path> — prints "<session> <epoch>" of the latest other-session write in the window
  [ -f "$LOG" ] || return 0
  /usr/bin/awk -F'\t' -v p="$1" -v s="$sid" -v cut=$((now - WINDOW)) \
    '$3 == p && $2 != s && $1 >= cut { w = $2 " " $1 } END { if (w) print w }' "$LOG"
}

already_asked() { # already_asked <path> <other-session>
  [ -f "$ACKS" ] && /usr/bin/grep -qxF "$2	$1" "$ACKS"
}

describe() { # describe <abs-path> — one line per collision, or nothing
  exempt "$1" && return 0
  w=$(other_writer "$1")
  [ -n "$w" ] || return 0
  osid=${w%% *}; oat=${w#* }
  already_asked "$1" "$osid" && return 0
  mkdir -p "$AIOS_DIR/tmp" 2>/dev/null && printf '%s\t%s\n' "$osid" "$1" >> "$ACKS"
  printf -- '- %s (session %s, %s min ago)\n' "${1#"$VAULT_DIR"/}" \
    "$(printf '%s' "$osid" | cut -c1-8)" $(( (now - oat) / 60 ))
}

# --- record -----------------------------------------------------------------------
if [ "$event" = "PostToolUse" ]; then
  mkdir -p "$AIOS_DIR/tmp" 2>/dev/null || exit 0
  for p in "$(field '.tool_input.file_path')" "$(field '.tool_input.path')" \
           "$(field '.tool_input.destination')"; do
    [ -n "$p" ] || continue
    p=$(abs "$p")
    case "$p" in "$VAULT_DIR"/*|"$AIOS_DIR"/*) : ;; *) continue ;; esac
    exempt "$p" && continue
    printf '%s\t%s\t%s\n' "$now" "$sid" "$p" >> "$LOG"
  done
  # Keep the log small: past the window it carries no information.
  if [ "$(/usr/bin/wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 2000 ]; then
    /usr/bin/awk -F'\t' -v cut=$((now - WINDOW)) '$1 >= cut' "$LOG" > "$LOG.$$" \
      && mv "$LOG.$$" "$LOG"
  fi
  exit 0
fi

[ "$event" = "PreToolUse" ] || exit 0
[ -f "$LOG" ] || exit 0

# --- git staging ------------------------------------------------------------------
if [ "$tool" = "Bash" ]; then
  cmd=$(field '.tool_input.command')
  printf '%s' "$cmd" | /usr/bin/grep -qE '(^|[;&|]|&&|\|\|)[[:space:]]*(cd[^;&|]*&&[[:space:]]*)?git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+|-C[[:space:]]+"[^"]*"[[:space:]]+)?(add|commit)([[:space:]]|$)' || exit 0
  git -C "$AIOS_DIR" rev-parse --git-dir >/dev/null 2>&1 || exit 0
  # Candidates: what is already staged, plus changed files the command names.
  cands=$( {
    git -C "$AIOS_DIR" diff --cached --name-only 2>/dev/null
    git -C "$AIOS_DIR" status --porcelain 2>/dev/null | cut -c4- | sed 's/.* -> //; s/^"//; s/"$//' |
      while IFS= read -r f; do
        printf '%s' "$cmd" | /usr/bin/grep -qF -- "$f" && printf '%s\n' "$f"
      done
  } | sort -u )
  [ -n "$cands" ] || exit 0
  out=$(printf '%s\n' "$cands" | while IFS= read -r f; do describe "$AIOS_DIR/$f"; done)
  [ -n "$out" ] || exit 0
  ask "Another session wrote these files in the last $((WINDOW / 60)) min, and this command would stage or commit them:
$out
Check that the changes in them are this session's. If the other session is still working, leave its files out of this commit."
fi

# --- file writes ------------------------------------------------------------------
out=$(for p in "$(field '.tool_input.file_path')" "$(field '.tool_input.path')" \
               "$(field '.tool_input.destination')"; do
  [ -n "$p" ] && describe "$(abs "$p")"
done)
[ -n "$out" ] || exit 0
ask "Another session wrote this file in the last $((WINDOW / 60)) min:
$out
Two sessions may be changing it in different directions. Re-read it before writing, and continue only if this edit should win."
