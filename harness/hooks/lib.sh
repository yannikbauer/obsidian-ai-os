#!/bin/sh
# Shared helpers for AIOS hooks. Sourced by each hook, never executed directly.
#
# FAIL-OPEN POSTURE: every early exit here is `exit 0` — allow the call. A hook that
# cannot parse its input must never block work. A missed gate leaves a prose rule doing
# what it already does; a false deny makes the OS unusable and teaches its owner to turn
# hooks off.
#
# `exit` from a sourced file exits the hook that sourced it. That is deliberate.

[ -x /usr/bin/jq ] || exit 0

# ${CLAUDE_PROJECT_DIR} is the vault root, not _AI/.
AIOS_DIR="${CLAUDE_PROJECT_DIR:-.}/_AI"
export AIOS_DIR

INPUT=$(cat)
[ -n "$INPUT" ] || exit 0
printf '%s' "$INPUT" | /usr/bin/jq -e . >/dev/null 2>&1 || exit 0

field() { # field <jq-path> — prints the value, or nothing
  printf '%s' "$INPUT" | /usr/bin/jq -r "$1 // empty" 2>/dev/null
}

deny() { # deny <reason> — emits the PreToolUse denial and stops the tool call
  # Leave a trace first. A denial is the strongest evidence that a session had something
  # to teach, and it appears NOWHERE in Claude Code's transcript — verified 2026-09-05.
  # Best-effort by design: nothing here may prevent or delay the denial itself.
  _sid=$(field '.session_id')
  if [ -n "$_sid" ] && mkdir -p "$AIOS_DIR/tmp" 2>/dev/null; then
    printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(field '.tool_name')" \
      "$(printf '%s' "$1" | tr '\n' ' ' | cut -c1-200)" \
      >> "$AIOS_DIR/tmp/denies-$_sid.log" 2>/dev/null
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$1" | /usr/bin/jq -Rs .)"
  exit 2
}
