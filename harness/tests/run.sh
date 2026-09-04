#!/bin/sh
# Hook test runner. Each case pipes a fixture into a hook and asserts the exit code.
# Exit codes: 0 = allow, 2 = deny.
#
# The malformed-input cases are not optional. These hooks run on every tool call in
# the vault, and that case decides whether a bad day is a bug or an outage.
HOOKS="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

expect() { # expect <want-exit> <script> <json>
  want=$1; script=$2; json=$3
  printf '%s' "$json" | "$HOOKS/$script" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then
    echo "  ok   $script (exit $got)"
  else
    echo "  FAIL $script — wanted exit $want, got $got" >&2
    echo "       input: $json" >&2
    FAIL=1
  fi
}

# --- guard-vault-write ---
expect 2 hooks/guard-vault-write.sh \
  '{"tool_name":"Write","tool_input":{"file_path":"/v/Archive/old.md","content":"x"}}'
expect 0 hooks/guard-vault-write.sh \
  '{"tool_name":"Write","tool_input":{"file_path":"/v/Notes/ok.md","content":"x"}}'
expect 2 hooks/guard-vault-write.sh \
  '{"tool_name":"Edit","tool_input":{"file_path":"/v/Notes/n.md","old_string":"<%* tR += 1 %>","new_string":"y"}}'
expect 0 hooks/guard-vault-write.sh \
  '{"tool_name":"Edit","tool_input":{"file_path":"/v/Templates/weekly.md","old_string":"<%* tR += 1 %>","new_string":"y"}}'
expect 0 hooks/guard-vault-write.sh 'not json at all'
expect 0 hooks/guard-vault-write.sh ''

# Read-only zones are configurable, so both branches need covering: the built-in
# defaults (no config file) and a config file that replaces them. Run each against
# a temporary _AI root so the result does not depend on this machine's own config.
ZTMP=$(mktemp -d)
mkdir -p "$ZTMP/_AI/harness/hooks"
cp "$HOOKS/hooks/guard-vault-write.sh" "$HOOKS/hooks/lib.sh" "$ZTMP/_AI/harness/hooks/"
ZHOOK="$ZTMP/_AI/harness/hooks/guard-vault-write.sh"

zexpect() { # zexpect <want-exit> <path> <label>
  printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"'"$2"'","content":"x"}}' \
    | "$ZHOOK" >/dev/null 2>&1
  zgot=$?
  if [ "$zgot" -eq "$1" ]; then
    echo "  ok   read-only zones: $3"
  else
    echo "  FAIL read-only zones: $3 — wanted exit $1, got $zgot" >&2; FAIL=1
  fi
}

# No config file: the built-in defaults apply.
zexpect 2 /v/Archive/old.md      "default blocks Archive/"
zexpect 0 /v/Secret/x.md         "default allows an unlisted folder"

# With a config file: it REPLACES the defaults, rather than adding to them.
printf '%s\n' '# comment' '' '*/Secret/*' > "$ZTMP/_AI/readonly-zones.local"
zexpect 2 /v/Secret/x.md         "config blocks a configured folder"
zexpect 0 /v/Archive/old.md      "config replaces the defaults, not extends them"
rm -rf "$ZTMP"

# --- guard-clickup ---
expect 2 hooks/guard-clickup.sh \
  '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"content_edit_mode":"replace","content":"x"}}'
expect 0 hooks/guard-clickup.sh \
  '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"content_edit_mode":"append","content":"x"}}'
expect 0 hooks/guard-clickup.sh 'not json'

# --- guard-mail ---
# Reaching this script at all is the violation: the matcher decides what arrives.
expect 2 hooks/guard-mail.sh '{"tool_name":"mcp__x__send_message","tool_input":{"to":"a@b.c"}}'
expect 0 hooks/guard-mail.sh 'not json'

# --- trace-write ---
# Not an exit-code assertion: this hook is judged by what it writes.
TMPD=$(mktemp -d); export CLAUDE_PROJECT_DIR="$TMPD"
mkdir -p "$TMPD/_AI/tmp"

printf '%s' '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"'"$TMPD"'/Notes/a.md"}}' \
  | "$HOOKS/hooks/trace-write.sh"
if grep -q 'Notes/a.md' "$TMPD/_AI/tmp/writes-s1.log" 2>/dev/null; then
  echo "  ok   trace-write records a vault note"
else
  echo "  FAIL trace-write did not record the write" >&2; FAIL=1
fi

printf '%s' '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"'"$TMPD"'/_AI/x.md"}}' \
  | "$HOOKS/hooks/trace-write.sh"
# Assert the log's actual shape, not just the absence of a string: a bare "does not
# contain" passes vacuously when the hook is missing and writes nothing at all.
lines=$(wc -l < "$TMPD/_AI/tmp/writes-s1.log" 2>/dev/null | tr -d ' ')
if [ "$lines" = "1" ] && ! grep -q '_AI/x.md' "$TMPD/_AI/tmp/writes-s1.log"; then
  echo "  ok   trace-write ignores _AI/ (log has exactly the 1 vault write)"
else
  echo "  FAIL expected exactly 1 logged line and no _AI/ path; got ${lines:-0}" >&2; FAIL=1
fi

printf 'not json' | "$HOOKS/hooks/trace-write.sh"
[ $? -eq 0 ] && echo "  ok   trace-write fails open on bad input" || { echo "  FAIL bad input did not exit 0" >&2; FAIL=1; }

rm -rf "$TMPD"; unset CLAUDE_PROJECT_DIR

# --- check-file-log ---
# Order matters: block, then loop-guard release, then pass-once-logged.
TMPD=$(mktemp -d); export CLAUDE_PROJECT_DIR="$TMPD"
mkdir -p "$TMPD/_AI/tmp" "$TMPD/_AI/history"
printf '# File Modification Log\n' > "$TMPD/_AI/history/file-log.md"
printf '2026-09-04\tWrite\t%s/Notes/unlogged.md\n' "$TMPD" > "$TMPD/_AI/tmp/writes-s9.log"
STOPIN='{"session_id":"s9","hook_event_name":"Stop"}'

printf '%s' "$STOPIN" | "$HOOKS/hooks/check-file-log.sh" >/dev/null 2>&1
[ $? -eq 2 ] && echo "  ok   check-file-log blocks on an unlogged write" \
             || { echo "  FAIL expected exit 2 on an unlogged write" >&2; FAIL=1; }

printf '%s' "$STOPIN" | "$HOOKS/hooks/check-file-log.sh" >/dev/null 2>&1
[ $? -eq 0 ] && echo "  ok   check-file-log loop guard releases on the 2nd Stop" \
             || { echo "  FAIL blocked twice — this can wedge a session" >&2; FAIL=1; }

rm -f "$TMPD/_AI/tmp/.filelog-blocked-s9"
printf -- '- 2026-09-04 12:00  [edit]  Notes/unlogged.md  — reason\n' >> "$TMPD/_AI/history/file-log.md"
printf '%s' "$STOPIN" | "$HOOKS/hooks/check-file-log.sh" >/dev/null 2>&1
[ $? -eq 0 ] && echo "  ok   check-file-log passes once the write is logged" \
             || { echo "  FAIL expected exit 0 once logged" >&2; FAIL=1; }

printf 'not json' | "$HOOKS/hooks/check-file-log.sh" >/dev/null 2>&1
[ $? -eq 0 ] && echo "  ok   check-file-log fails open on bad input" \
             || { echo "  FAIL bad input did not exit 0" >&2; FAIL=1; }

rm -rf "$TMPD"; unset CLAUDE_PROJECT_DIR

exit $FAIL
