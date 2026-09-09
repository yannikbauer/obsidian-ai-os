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

# --- where things are --------------------------------------------------------
# Two paths every hook needs, resolved ONCE, here. Until 2026-09-09 each hook worked
# them out for itself, with three different fallbacks ('.', '', and the script's own
# location), and every one of them ASSUMED the vault root is the directory the session
# started in. That assumption holds only by convention — it is true because sessions
# start at the vault, not because anything makes it true. One seam is easier to move
# than four assumptions, which is what a second vault, or a session started from inside
# the OS, would have to move.
#
# AIOS_DIR is derived from this file's own location, always <AI>/.claude/hooks/. That
# removes the last place the directory name `_AI` was written into a hook.
AIOS_DIR="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
[ -n "$AIOS_DIR" ] || exit 0

# VAULT_DIR is the vault this install serves, in order of authority:
#   1. $AIOS_VAULT_DIR       explicit override — the seam a second vault would use
#   2. $CLAUDE_PROJECT_DIR   the harness's own signal; correct for as long as sessions
#                            start at the vault root
#   3. the parent of AIOS_DIR — the layout itself, and a far better guess than the '.'
#                            the hooks used to fall back to
# The location is deliberately LAST: deriving from it first pins a hook to whatever tree
# it was copied into, and ignores the one signal the harness actually provides.
VAULT_DIR="${AIOS_VAULT_DIR:-${CLAUDE_PROJECT_DIR:-$(dirname "$AIOS_DIR")}}"
export AIOS_DIR VAULT_DIR

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

ask() { # ask <reason> — surfaces the call for a human decision instead of blocking it
  # Deliberately NOT deny. Used where the hook cannot tell a real violation from a
  # false positive (see guard-bash-vault.sh), and where a wrong deny would be worse
  # than a prompt. Not traced: an ask is not evidence of a violation, and logging
  # every one would drown the deny log that suggest-retro.sh reads.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$1" | /usr/bin/jq -Rs .)"
  exit 0
}
