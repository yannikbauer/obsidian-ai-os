#!/bin/sh
# Hook test runner. Each case pipes a fixture into a hook and asserts the exit code.
# Exit codes: 0 = allow, 2 = deny.
#
# The malformed-input cases are not optional. These hooks run on every tool call in
# the vault, and that case decides whether a bad day is a bug or an outage.
# tests/ sits beside .claude/, so HOOKS is a sibling hop rather than a parent one.
HOOKS="$(cd "$(dirname "$0")/../.claude" && pwd)"
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
mkdir -p "$ZTMP/_AI/.claude/hooks" "$ZTMP/_AI/config"
cp "$HOOKS/hooks/guard-vault-write.sh" "$HOOKS/hooks/lib.sh" "$ZTMP/_AI/.claude/hooks/"
ZHOOK="$ZTMP/_AI/.claude/hooks/guard-vault-write.sh"

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
printf '%s\n' '# comment' '' '*/Secret/*' > "$ZTMP/_AI/config/readonly-zones.local"
zexpect 2 /v/Secret/x.md         "config blocks a configured folder"
zexpect 0 /v/Archive/old.md      "config replaces the defaults, not extends them"
rm -rf "$ZTMP"

# --- guard-vault-write, MCP route (roadmap #31) ---------------------------
# The MCP vault_* tools carry .tool_input.path (vault-relative), not .file_path.
# Everything below would have passed silently before the matcher was widened,
# which is the entire point of the item: the gate was watching a tool name.
MTMP=$(mktemp -d)
mkdir -p "$MTMP/_AI/.claude/hooks" "$MTMP/_AI/config" "$MTMP/Archive" "$MTMP/Notes"
cp "$HOOKS/hooks/guard-vault-write.sh" "$HOOKS/hooks/lib.sh" "$MTMP/_AI/.claude/hooks/"
printf '%s\n' '*/Archive/*' > "$MTMP/_AI/config/readonly-zones.local"
MHOOK="$MTMP/_AI/.claude/hooks/guard-vault-write.sh"
printf '# Goals\n\n```tasks\nnot done\n```\n' > "$MTMP/Notes/goals.md"
printf '# Plain\n\njust prose\n' > "$MTMP/Notes/plain.md"

mexpect() { # mexpect <want-exit> <json> <label>
  printf '%s' "$2" | env CLAUDE_PROJECT_DIR="$MTMP" "$MHOOK" >/dev/null 2>&1
  mgot=$?
  if [ "$mgot" -eq "$1" ]; then
    echo "  ok   mcp vault route: $3"
  else
    echo "  FAIL mcp vault route: $3 — wanted exit $1, got $mgot" >&2; FAIL=1
  fi
}

mexpect 2 '{"tool_name":"mcp__obs__vault_write","tool_input":{"path":"Archive/old.md","content":"x"}}' \
  "a relative path is resolved against the vault before matching a zone"
mexpect 0 '{"tool_name":"mcp__obs__vault_write","tool_input":{"path":"Notes/plain.md","content":"x"}}' \
  "an ordinary note is allowed"
mexpect 2 '{"tool_name":"mcp__obs__vault_write","tool_input":{"path":"Notes/goals.md","content":"x"}}' \
  "vault_write is a whole-file overwrite, so a live query blocks it"
mexpect 0 '{"tool_name":"mcp__obs__vault_append","tool_input":{"path":"Notes/goals.md","content":"- x"}}' \
  "append does not overwrite, so the same note is fine"
mexpect 2 '{"tool_name":"mcp__obs__vault_patch","tool_input":{"path":"Notes/plain.md","targetType":"heading","target":["A"],"operation":"append","content":"x","createTargetIfMissing":true}}' \
  "createTargetIfMissing is denied (a mis-cased heading silently forks the note)"
mexpect 0 '{"tool_name":"mcp__obs__vault_patch","tool_input":{"path":"Notes/plain.md","targetType":"heading","target":["A"],"operation":"append","content":"x"}}' \
  "the same patch without the flag is allowed"
mexpect 2 '{"tool_name":"mcp__obs__vault_patch","tool_input":{"path":"Notes/goals.md","targetType":"heading","target":["Goals"],"operation":"replace","content":"x"}}' \
  "an unscoped heading replace on a live-query note is denied"
mexpect 0 '{"tool_name":"mcp__obs__vault_patch","tool_input":{"path":"Notes/goals.md","targetType":"heading","target":["Goals"],"within":0,"operation":"replace","content":"x"}}' \
  "the same replace narrowed by 'within' is allowed"
mexpect 0 '{"tool_name":"mcp__obs__vault_patch","tool_input":{"path":"Notes/goals.md","targetType":"frontmatter","target":"tags","operation":"replace","value":["a"]}}' \
  "frontmatter edits are never subtree-destructive"
mexpect 2 '{"tool_name":"mcp__obs__vault_delete","tool_input":{"path":"Notes/plain.md","permanent":true}}' \
  "permanent deletion is refused"
mexpect 0 '{"tool_name":"mcp__obs__vault_delete","tool_input":{"path":"Notes/plain.md"}}' \
  "deleting to trash is allowed"
mexpect 2 '{"tool_name":"mcp__obs__vault_move","tool_input":{"path":"Notes/plain.md","destination":"Archive/plain.md"}}' \
  "the DESTINATION of a move is zone-checked, not just the source"
mexpect 0 '{"tool_name":"mcp__obs__vault_patch","tool_input":{"path":"Notes/plain.md","targetType":"heading","target":["A"],"operation":"replace","scope":"parent","destination":{"parent":null,"place":"last"}}}' \
  "vault_patch's object destination is not mistaken for a path"
mexpect 2 '{"tool_name":"mcp__obs__vault_write","tool_input":{"path":"Notes/new.md","content":"<%* tR += 1 %>"}}' \
  "a Templater block outside Templates/ is denied on this route too"
mexpect 0 'not json at all' "fails open on bad input"
rm -rf "$MTMP"

# --- guard-bash-vault (roadmap #31, con 2) --------------------------------
# ASKS (exit 0 + an "ask" decision), never denies — so the exit code alone proves
# nothing here and the assertion has to read the decision. A negative test that
# checks only for absence passes when the hook does not exist at all (L: negative
# tests must assert shape).
BTMP=$(mktemp -d)
mkdir -p "$BTMP/_AI/.claude/hooks" "$BTMP/_AI/config"
cp "$HOOKS/hooks/guard-bash-vault.sh" "$HOOKS/hooks/lib.sh" "$BTMP/_AI/.claude/hooks/"
printf '%s\n' '*/Archive/*' '*/copilot/*' > "$BTMP/_AI/config/readonly-zones.local"
BHOOK="$BTMP/_AI/.claude/hooks/guard-bash-vault.sh"

bexpect() { # bexpect <ask|quiet> <command> <label>
  out=$(printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(printf '%s' "$2" | /usr/bin/jq -Rs .)}}" \
    | env CLAUDE_PROJECT_DIR="$BTMP" "$BHOOK" 2>/dev/null)
  if [ "$1" = ask ]; then
    case "$out" in
      *'"permissionDecision":"ask"'*) echo "  ok   bash vault gate: $3" ;;
      *) echo "  FAIL bash vault gate: $3 — wanted an ask decision, got: ${out:-<nothing>}" >&2; FAIL=1 ;;
    esac
  else
    case "$out" in
      '') echo "  ok   bash vault gate: $3" ;;
      *) echo "  FAIL bash vault gate: $3 — wanted silence, got: $out" >&2; FAIL=1 ;;
    esac
  fi
}

bexpect ask   'rm "$V/Archive/old.md"'                 "rm naming a zone asks"
bexpect ask   'echo x > "$V/Archive/old.md"'           "a redirect into a zone asks"
bexpect ask   "sed -i '' s/a/b/ Archive/x.md"          "sed -i naming a zone asks"
bexpect ask   'cp a.md copilot/b.md'                   "a second configured zone asks"
bexpect quiet 'cat "$V/Archive/old.md"'                "reading a zone stays silent"
bexpect quiet 'grep -r foo Archive/ 2>&1 | head'       "2>&1 is not a write (session-digest bug)"
bexpect quiet 'rm "$V/Notes/scratch.md"'               "mutating a NON-zone path stays silent"
bexpect quiet 'ls Archive/'                            "a plain listing stays silent"
printf '%s' 'not json at all' | env CLAUDE_PROJECT_DIR="$BTMP" "$BHOOK" >/dev/null 2>&1
if [ $? -eq 0 ]; then echo "  ok   bash vault gate: fails open on bad input"
else echo "  FAIL bash vault gate: bad input did not fail open" >&2; FAIL=1; fi
rm -rf "$BTMP"

# --- setup/leak-check.sh path resolution (roadmap #36) ---------------------
# The harness covers hooks and tools/; setup/ was covered by nothing, and this
# script is the gate between the vault and a public repository. Its failure mode
# is not a false pass on a pattern -- it is failing to FIND its patterns, which
# looks identical to a clean run. Prerequisite for moving the .local knobs.
LTMP=$(mktemp -d)
mkdir -p "$LTMP/_AI/setup" "$LTMP/_AI/config"
cp "$HOOKS/../setup/leak-check.sh" "$LTMP/_AI/setup/"
printf '# framework\n' > "$LTMP/_AI/CLAUDE.md"
printf '%s\n' 'Hieronymus' > "$LTMP/_AI/config/leak-patterns.local"
printf 'a note about Hieronymus\n' > "$LTMP/dirty.md"
printf 'a note about nobody\n'     > "$LTMP/clean.md"
LCHK="$LTMP/_AI/setup/leak-check.sh"

lexpect() { # lexpect <want-exit> <target> <label>
  bash "$LCHK" "$2" >/dev/null 2>&1
  lgot=$?
  if [ "$lgot" -eq "$1" ]; then
    echo "  ok   leak-check: $3"
  else
    echo "  FAIL leak-check: $3 — wanted exit $1, got $lgot" >&2; FAIL=1
  fi
}

lexpect 2 "$LTMP/dirty.md" "a configured pattern is caught"
lexpect 0 "$LTMP/clean.md" "a clean file passes"

# The generic patterns must still work for a fork that has no pattern file --
# absent-but-locatable is legitimate degradation, not a bug.
mv "$LTMP/_AI/config/leak-patterns.local" "$LTMP/_AI/config/leak-patterns.parked"
# Assembled at runtime, never written literally: this file SHIPS, and a literal
# address here matches the very generic pattern the case is testing -- which aborts
# the export. Caught by export.sh doing its job, 2026-09-08.
printf 'mail me at %s%s\n' 'real.person' '@example.org' > "$LTMP/generic.md"
lexpect 0 "$LTMP/clean.md"   "no pattern file: still runs (a fork has none)"
lexpect 2 "$LTMP/generic.md" "no pattern file: the built-in email pattern still fires"
mv "$LTMP/_AI/config/leak-patterns.parked" "$LTMP/_AI/config/leak-patterns.local"

# The case the whole fixture exists for: the script cannot find its own root.
# Before this check it printed a note to STDOUT and exited 0 having scanned for
# generic patterns only -- a disabled gate that reports success.
mkdir -p "$LTMP/stray/setup"
cp "$LCHK" "$LTMP/stray/setup/leak-check.sh"
bash "$LTMP/stray/setup/leak-check.sh" "$LTMP/dirty.md" >/dev/null 2>&1
lgot=$?
if [ "$lgot" -eq 3 ]; then
  echo "  ok   leak-check: an unresolvable _AI root fails loudly (exit 3)"
else
  echo "  FAIL leak-check: an unresolvable _AI root did not fail — got exit $lgot" >&2; FAIL=1
fi
# ...and it must say so on stderr, not stdout: a warning on stdout reads as output.
lerr=$(bash "$LTMP/stray/setup/leak-check.sh" "$LTMP/dirty.md" 2>&1 >/dev/null)
case "$lerr" in
  *"cannot locate the _AI root"*) echo "  ok   leak-check: the refusal names the cause on stderr" ;;
  *) echo "  FAIL leak-check: refusal message missing from stderr — got: ${lerr:-<nothing>}" >&2; FAIL=1 ;;
esac
lexpect 64 "$LTMP/does-not-exist.md" "a missing target is a usage error, not a clean pass"
rm -rf "$LTMP"

# --- trace-write: only VAULT notes are traced ------------------------------
# The Stop hook demands a file-log entry for everything this trace records, so a
# path recorded here that is not a vault note becomes a demand to corrupt the
# audit trail. Excluding _AI/ and treating the rest of the filesystem as "vault"
# did exactly that, twice (a scratchpad file 2026-09-05, two ~/.claude/ memory
# files 2026-09-07) before anyone fixed it rather than working around it.
WTMP=$(mktemp -d)
mkdir -p "$WTMP/_AI/.claude/hooks" "$WTMP/_AI/tmp"
cp "$HOOKS/hooks/trace-write.sh" "$HOOKS/hooks/lib.sh" "$WTMP/_AI/.claude/hooks/"
WHOOK="$WTMP/_AI/.claude/hooks/trace-write.sh"

wtrace() { # wtrace <path> — returns the trace file's line count for that path
  printf '%s' "{\"session_id\":\"S\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":$(printf '%s' "$1" | /usr/bin/jq -Rs .)}}" \
    | env CLAUDE_PROJECT_DIR="$WTMP" "$WHOOK" >/dev/null 2>&1
  # grep -Fc exits 1 on zero matches, so `|| echo 0` would print a SECOND zero.
  c=$(grep -Fc -- "$1" "$WTMP/_AI/tmp/writes-S.log" 2>/dev/null) || c=0
  printf '%s' "${c:-0}"
}

wexpect() { # wexpect <traced 1|0> <path> <label>
  got=$(wtrace "$2")
  if [ "$got" = "$1" ]; then
    echo "  ok   trace-write: $3"
  else
    echo "  FAIL trace-write: $3 — wanted traced=$1, got $got" >&2; FAIL=1
  fi
}

wexpect 1 "$WTMP/Notes/real-note.md"             "a vault note is traced"
wexpect 0 "$WTMP/_AI/docs/roadmap.md"            "_AI/ is not (git is its audit trail)"
wexpect 0 "/tmp/scratchpad/token-days.html"      "a scratchpad file outside the vault is not traced"
wexpect 0 "$HOME/.claude/projects/x/memory/m.md" "a ~/.claude memory file is not traced"
wexpect 0 "/etc/hosts"                           "an unrelated absolute path is not traced"
rm -rf "$WTMP"

# --- guard-clickup ---
# Runs against a TEMP tree with its own allowlist, never the real one. Two reasons: the
# fixture must not depend on this vault's configuration, and hardcoding real page ids into
# a file that SHIPS would put the owner's document tree in the public export. The leak
# check catches that pattern, but a fixture that only passes because another gate stops it
# is a fixture written wrong.
KTMP=$(mktemp -d); mkdir -p "$KTMP/_AI/.claude/hooks" "$KTMP/_AI/config"
cp "$HOOKS/hooks/guard-clickup.sh" "$HOOKS/hooks/lib.sh" "$KTMP/_AI/.claude/hooks/"
printf '# fixture allowlist\nPAGE-ALLOWED\n' > "$KTMP/_AI/config/clickup-replace-allow.local"
kexpect() { # kexpect <want-exit> <json> <label>
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$KTMP" "$KTMP/_AI/.claude/hooks/guard-clickup.sh" >/dev/null 2>&1
  kgot=$?
  if [ "$kgot" -eq "$1" ]; then echo "  ok   guard-clickup: $3"
  else echo "  FAIL guard-clickup: $3 — wanted exit $1, got $kgot" >&2; FAIL=1; fi
}
kexpect 2 '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"page_id":"PAGE-OTHER","content_edit_mode":"replace","content":"x"}}' \
  "denies replace on a page that is not allowlisted"
kexpect 0 '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"page_id":"PAGE-OTHER","content_edit_mode":"append","content":"x"}}' \
  "allows append"
# The tool's schema DEFAULTS content_edit_mode to "replace". A gate that tests only for an
# explicit "replace" misses the likeliest destructive call shape — omitting the field.
kexpect 2 '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"page_id":"PAGE-OTHER","content":"x"}}' \
  "treats an omitted content_edit_mode as replace"
# ...and the ban is conditional, not absolute: integrations/ allowlists one staging page,
# and the old absolute hook denied it while its own message said to use a staging page (L006).
kexpect 0 '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"page_id":"PAGE-ALLOWED","content_edit_mode":"replace","content":"x"}}' \
  "allows replace on the allowlisted page"
kexpect 0 '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"page_id":"PAGE-OTHER","name":"renamed"}}' \
  "a rename with no content is not a rewrite"
# With no allowlist at all — a fresh install — every replace is denied. That is the safe default.
rm -f "$KTMP/_AI/config/clickup-replace-allow.local"
kexpect 2 '{"tool_name":"mcp__x__clickup_update_document_page","tool_input":{"page_id":"PAGE-ALLOWED","content_edit_mode":"replace","content":"x"}}' \
  "denies everything when no allowlist exists"
expect 0 hooks/guard-clickup.sh 'not json'
rm -rf "$KTMP"

# --- guard-mail ---
# Reaching this script at all is the violation: the matcher decides what arrives.
expect 2 hooks/guard-mail.sh '{"tool_name":"mcp__x__send_message","tool_input":{"to":"a@b.c"}}'
expect 0 hooks/guard-mail.sh 'not json'

# --- trace-write ---
# Not an exit-code assertion: this hook is judged by what it writes.
# The hooks run from a COPY inside the sandbox. AIOS_DIR comes from a hook's own
# location, not from CLAUDE_PROJECT_DIR, so a hook invoked from the real tree would
# write its trace into the real tree — which is the point of that resolution order,
# and the reason a test of it has to install itself somewhere first.
TMPD=$(mktemp -d); export CLAUDE_PROJECT_DIR="$TMPD"
mkdir -p "$TMPD/_AI/tmp" "$TMPD/_AI/.claude/hooks"
cp "$HOOKS/hooks/trace-write.sh" "$HOOKS/hooks/lib.sh" "$TMPD/_AI/.claude/hooks/"
TWHOOK="$TMPD/_AI/.claude/hooks/trace-write.sh"

printf '%s' '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"'"$TMPD"'/Notes/a.md"}}' \
  | "$TWHOOK"
if grep -q 'Notes/a.md' "$TMPD/_AI/tmp/writes-s1.log" 2>/dev/null; then
  echo "  ok   trace-write records a vault note"
else
  echo "  FAIL trace-write did not record the write" >&2; FAIL=1
fi

printf '%s' '{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"'"$TMPD"'/_AI/x.md"}}' \
  | "$TWHOOK"
# Assert the log's actual shape, not just the absence of a string: a bare "does not
# contain" passes vacuously when the hook is missing and writes nothing at all.
lines=$(wc -l < "$TMPD/_AI/tmp/writes-s1.log" 2>/dev/null | tr -d ' ')
if [ "$lines" = "1" ] && ! grep -q '_AI/x.md' "$TMPD/_AI/tmp/writes-s1.log"; then
  echo "  ok   trace-write ignores _AI/ (log has exactly the 1 vault write)"
else
  echo "  FAIL expected exactly 1 logged line and no _AI/ path; got ${lines:-0}" >&2; FAIL=1
fi

printf 'not json' | "$TWHOOK"
[ $? -eq 0 ] && echo "  ok   trace-write fails open on bad input" || { echo "  FAIL bad input did not exit 0" >&2; FAIL=1; }

# --- $AIOS_VAULT_DIR outranks $CLAUDE_PROJECT_DIR ---------------------------
# The seam a second vault, or a session started from inside the OS, would use. An
# override nothing exercises is not a seam, it is a comment — so point the two
# variables at DIFFERENT trees and assert which one decides what counts as a note.
OTMP=$(mktemp -d); OTHER=$(mktemp -d)
mkdir -p "$OTMP/_AI/tmp" "$OTMP/_AI/.claude/hooks"
cp "$HOOKS/hooks/trace-write.sh" "$HOOKS/hooks/lib.sh" "$OTMP/_AI/.claude/hooks/"
OHOOK="$OTMP/_AI/.claude/hooks/trace-write.sh"
printf '%s' '{"session_id":"s2","tool_name":"Write","tool_input":{"file_path":"'"$OTHER"'/Notes/b.md"}}' \
  | env CLAUDE_PROJECT_DIR="$OTMP" AIOS_VAULT_DIR="$OTHER" "$OHOOK"
if grep -q 'Notes/b.md' "$OTMP/_AI/tmp/writes-s2.log" 2>/dev/null; then
  echo "  ok   AIOS_VAULT_DIR overrides CLAUDE_PROJECT_DIR for vault membership"
else
  echo "  FAIL AIOS_VAULT_DIR did not override CLAUDE_PROJECT_DIR" >&2; FAIL=1
fi
printf '%s' '{"session_id":"s3","tool_name":"Write","tool_input":{"file_path":"'"$OTMP"'/Notes/c.md"}}' \
  | env CLAUDE_PROJECT_DIR="$OTMP" AIOS_VAULT_DIR="$OTHER" "$OHOOK"
if [ -f "$OTMP/_AI/tmp/writes-s3.log" ]; then
  echo "  FAIL a path outside the overridden vault was traced as a note" >&2; FAIL=1
else
  echo "  ok   a path under CLAUDE_PROJECT_DIR alone is not a note once overridden"
fi
rm -rf "$OTMP" "$OTHER"

rm -rf "$TMPD"; unset CLAUDE_PROJECT_DIR

# --- check-file-log ---
# Order matters: block, then loop-guard release, then pass-once-logged.
TMPD=$(mktemp -d); export CLAUDE_PROJECT_DIR="$TMPD"
mkdir -p "$TMPD/_AI/tmp" "$TMPD/_AI/history" "$TMPD/_AI/.claude/hooks"
cp "$HOOKS/hooks/check-file-log.sh" "$HOOKS/hooks/lib.sh" "$TMPD/_AI/.claude/hooks/"
CFHOOK="$TMPD/_AI/.claude/hooks/check-file-log.sh"
printf '# File Modification Log\n' > "$TMPD/_AI/history/file-log.md"
printf '2026-09-04\tWrite\t%s/Notes/unlogged.md\n' "$TMPD" > "$TMPD/_AI/tmp/writes-s9.log"
STOPIN='{"session_id":"s9","hook_event_name":"Stop"}'

printf '%s' "$STOPIN" | "$CFHOOK" >/dev/null 2>&1
[ $? -eq 2 ] && echo "  ok   check-file-log blocks on an unlogged write" \
             || { echo "  FAIL expected exit 2 on an unlogged write" >&2; FAIL=1; }

printf '%s' "$STOPIN" | "$CFHOOK" >/dev/null 2>&1
[ $? -eq 0 ] && echo "  ok   check-file-log loop guard releases on the 2nd Stop" \
             || { echo "  FAIL blocked twice — this can wedge a session" >&2; FAIL=1; }

rm -f "$TMPD/_AI/tmp/.filelog-blocked-s9"
printf -- '- 2026-09-04 12:00  [edit]  Notes/unlogged.md  — reason\n' >> "$TMPD/_AI/history/file-log.md"
printf '%s' "$STOPIN" | "$CFHOOK" >/dev/null 2>&1
[ $? -eq 0 ] && echo "  ok   check-file-log passes once the write is logged" \
             || { echo "  FAIL expected exit 0 once logged" >&2; FAIL=1; }

printf 'not json' | "$CFHOOK" >/dev/null 2>&1
[ $? -eq 0 ] && echo "  ok   check-file-log fails open on bad input" \
             || { echo "  FAIL bad input did not exit 0" >&2; FAIL=1; }

rm -rf "$TMPD"; unset CLAUDE_PROJECT_DIR

# --- tools/usage.sh ---
# Asserted against a fixture with hand-computed totals, never against the live corpus:
# the arithmetic is what needs pinning, and real numbers drift as sessions accrue.
ROOT="$(cd "$HOOKS/.." && pwd)"
USAGE_JSON=$("$ROOT/tools/usage.sh" --dir "$HOOKS/../tests/fixtures/usage" --json 2>/dev/null)
check() { # check <jq-path> <want>
  got=$(printf '%s' "$USAGE_JSON" | /usr/bin/jq -r "$1" 2>/dev/null)
  if [ "$got" = "$2" ]; then echo "  ok   usage $1 = $2"
  else echo "  FAIL usage $1 — wanted $2, got ${got:-<none>}" >&2; FAIL=1; fi
}
check .sessions 2
check .turns 3
check .input 15
check .cache_creation 300
check .cache_read 1750
check .output 175
check .weighted 1440
check .peak_1h 1160
check .peak_5h 1160
check .peak_24h 1440

FILTERED=$("$ROOT/tools/usage.sh" --dir "$HOOKS/../tests/fixtures/usage" --project proj-b --json 2>/dev/null)
got=$(printf '%s' "$FILTERED" | /usr/bin/jq -r .output 2>/dev/null)
[ "$got" = "25" ] && echo "  ok   usage --project filters to one project" \
                  || { echo "  FAIL --project filter: wanted output 25, got ${got:-<none>}" >&2; FAIL=1; }

# --- suggest-retro (Stop) ---------------------------------------------------
# This hook is advisory, so its failure mode is the opposite of the guards': the
# expensive mistake is a FALSE POSITIVE. A nudge that fires on quiet sessions is a
# nudge the user turns off, and then the learning loop has no trigger at all. Hence
# the below-threshold and loop-guard cases carry as much weight as the firing one.
RTMP=$(mktemp -d)
mkdir -p "$RTMP/_AI/.claude/hooks" "$RTMP/_AI/tools" "$RTMP/_AI/tmp"
cp "$HOOKS/hooks/suggest-retro.sh" "$HOOKS/hooks/lib.sh" "$RTMP/_AI/.claude/hooks/"
cp "$HOOKS/../tools/session-digest.sh" "$RTMP/_AI/tools/"
RHOOK="$RTMP/_AI/.claude/hooks/suggest-retro.sh"

# Synthetic transcripts, not real ones: a fixture that depends on this machine's
# session history is a test that passes until someone prunes ~/.claude.
QUIET="$RTMP/quiet.jsonl"
printf '%s\n' \
  '{"type":"user","promptSource":"typed","message":{"role":"user","content":"do the thing"}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{}}]}}' \
  > "$QUIET"

# Two signals: three corrections (+2) — enough on its own to reach the threshold.
LOUD="$RTMP/loud.jsonl"
printf '%s\n' \
  '{"type":"user","promptSource":"typed","message":{"role":"user","content":"no, that is wrong"}}' \
  '{"type":"user","promptSource":"typed","message":{"role":"user","content":"actually do it the other way"}}' \
  '{"type":"user","promptSource":"typed","message":{"role":"user","content":"revert that please"}}' \
  > "$LOUD"

rexpect() { # rexpect <want-exit> <sid> <transcript> <extra-json> <label>
  printf '{"session_id":"%s","transcript_path":"%s"%s}' "$2" "$3" "$4" \
    | CLAUDE_PROJECT_DIR="$RTMP" "$RHOOK" >/dev/null 2>&1
  rgot=$?
  if [ "$rgot" -eq "$1" ]; then echo "  ok   suggest-retro: $5"
  else echo "  FAIL suggest-retro: $5 — wanted exit $1, got $rgot" >&2; FAIL=1; fi
}

rexpect 0 q1 "$QUIET" ''                        "quiet session stays silent"
rexpect 2 l1 "$LOUD"  ''                        "session with corrections asks"
rexpect 0 l1 "$LOUD"  ''                        "same session does not ask twice"
rexpect 0 l2 "$LOUD"  ',"stop_hook_active":true' "does not block when already blocking"
rexpect 0 l3 "/nonexistent/path.jsonl" ''        "missing transcript is not an error"
printf 'not json' | CLAUDE_PROJECT_DIR="$RTMP" "$RHOOK" >/dev/null 2>&1
[ $? -eq 0 ] && echo "  ok   suggest-retro: malformed input allows" \
             || { echo "  FAIL suggest-retro: malformed input should exit 0" >&2; FAIL=1; }

# A denial alone must be sufficient — it is the strongest evidence a rule was nearly
# broken, and it is the one signal that never appears in the transcript.
printf '%s\t%s\t%s\n' 2026-09-05T00:00:00Z Write "read-only zone" > "$RTMP/_AI/tmp/denies-d1.log"
rexpect 2 d1 "$QUIET" '' "a single hook denial is enough on a quiet session"

# --- deny() leaves the trace suggest-retro depends on ------------------------
# Coupling worth a test: if deny() stops logging, the strongest retro signal goes
# silent and nothing else notices.
DTMP=$(mktemp -d)
mkdir -p "$DTMP/_AI/.claude/hooks"
cp "$HOOKS/hooks/guard-vault-write.sh" "$HOOKS/hooks/lib.sh" "$DTMP/_AI/.claude/hooks/"
printf '%s' '{"session_id":"dsid","tool_name":"Write","tool_input":{"file_path":"/v/Archive/x.md","content":"x"}}' \
  | CLAUDE_PROJECT_DIR="$DTMP" "$DTMP/_AI/.claude/hooks/guard-vault-write.sh" >/dev/null 2>&1
if [ -s "$DTMP/_AI/tmp/denies-dsid.log" ]; then echo "  ok   deny() writes tmp/denies-<sid>.log"
else echo "  FAIL deny() left no trace for suggest-retro to read" >&2; FAIL=1; fi


# --- session-digest: "wrote a framework file" is an act, not a tool ------------
# Regression guard. Counting only Write/Edit reported ZERO framework writes for the
# session that built the digest, because that session edited through Bash heredocs.
DIGEST="$HOOKS/../tools/session-digest.sh"
BTMP=$(mktemp -d)
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"cat > /v/_AI/skills/x/SKILL.md <<EOF"}}]}}' \
  > "$BTMP/bashwrite.jsonl"
bw=$("$DIGEST" --json --transcript "$BTMP/bashwrite.jsonl" 2>/dev/null | /usr/bin/jq -r .framework_writes)
[ "$bw" = "1" ] && echo "  ok   session-digest counts a Bash heredoc write" \
                || { echo "  FAIL session-digest missed a Bash write — wanted 1, got ${bw:-<none>}" >&2; FAIL=1; }

# ...but reading a file is not writing it. Without this the signal fires on every
# session, and a nudge that always fires is a nudge that gets switched off.
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"cat /v/_AI/CLAUDE.md"}}]}}' \
  > "$BTMP/bashread.jsonl"
br=$("$DIGEST" --json --transcript "$BTMP/bashread.jsonl" 2>/dev/null | /usr/bin/jq -r .framework_writes)
[ "$br" = "0" ] && echo "  ok   session-digest does not count a Bash read as a write" \
                || { echo "  FAIL session-digest counted a read as a write — wanted 0, got ${br:-<none>}" >&2; FAIL=1; }

# ...and `2>&1` is not a write either. The mutating-verb clause accepted ANY `>` followed
# by a non-pipe run ending at an _AI/ path, so every stderr-redirecting read of a framework
# file scored as a write. Found 2026-09-07 by printing the matches the Stop hook had just
# counted: both were `ls ... 2>&1 && ... _AI/docs/roadmap.md`. Same shape as L003 — the check
# was watching for a `>` character, not for a file being written.
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"ls -d /v/notes 2>&1 && awk /x/ /v/_AI/docs/roadmap.md"}}]}}' \
  > "$BTMP/bashfd.jsonl"
bf=$("$DIGEST" --json --transcript "$BTMP/bashfd.jsonl" 2>/dev/null | /usr/bin/jq -r .framework_writes)
[ "$bf" = "0" ] && echo "  ok   session-digest does not count 2>&1 as a framework write" \
                || { echo "  FAIL session-digest counted a stderr redirect as a write — wanted 0, got ${bf:-<none>}" >&2; FAIL=1; }

# A skill body injected as a user-role entry is not the human speaking. Counting these
# reported 204 "human turns" for a session with 5.
printf '%s\n' \
  '{"type":"user","promptSource":"typed","message":{"role":"user","content":"the human"}}' \
  '{"type":"user","isMeta":true,"sourceToolUseID":"x","message":{"role":"user","content":"injected skill body"}}' \
  '{"type":"user","toolUseResult":{},"message":{"role":"user","content":[{"type":"tool_result","content":"output"}]}}' \
  > "$BTMP/turns.jsonl"
ut=$("$DIGEST" --json --transcript "$BTMP/turns.jsonl" 2>/dev/null | /usr/bin/jq -r .user_turns)
[ "$ut" = "1" ] && echo "  ok   session-digest counts only human prompts as turns" \
                || { echo "  FAIL session-digest turn count — wanted 1, got ${ut:-<none>}" >&2; FAIL=1; }


# --- guard-blanket-add (L007 mechanised) -------------------------------------
# The prose cases are the important ones. A substring matcher would deny writing the
# very files that document this rule — the skill body saying "never git add -A" was
# authored through a Bash heredoc — which is exactly the L006 failure: a "never" rule
# that fires on legitimate work teaches its owner to switch hooks off.
# CLAUDE_PROJECT_DIR must be set: without it lib.sh falls back to "./_AI", and deny()'s
# trace lands in the repo being tested. Caught by git status — this test created a
# stray _AI/_AI/tmp/ on its first run.
GTMP=$(mktemp -d)
bexpect() { # bexpect <want-exit> <command> <label>
  printf '{"session_id":"bt","tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(printf '%s' "$2" | /usr/bin/jq -Rs .)" \
    | CLAUDE_PROJECT_DIR="$GTMP" "$HOOKS/hooks/guard-blanket-add.sh" >/dev/null 2>&1
  bgot=$?
  if [ "$bgot" -eq "$1" ]; then echo "  ok   guard-blanket-add: $3"
  else echo "  FAIL guard-blanket-add: $3 — wanted exit $1, got $bgot" >&2; FAIL=1; fi
}
bexpect 2 'git add -A'                          "denies git add -A"
bexpect 2 'git add --all'                       "denies git add --all"
bexpect 2 'cd /x && git add .'                  "denies git add . after &&"
bexpect 2 'git commit -am "wip"'                "denies git commit -am"
bexpect 0 'git add CLAUDE.md docs/roadmap.md'   "allows named paths"
bexpect 0 'git commit -q -F -'                  "allows a normal commit"
bexpect 0 'git status --short'                  "allows a status read"
bexpect 0 'grep -n "git add -A" skills/x.md'    "allows grepping for the string"
bexpect 0 'cat > f.md <<EOF
never git add -A, name the paths
EOF'                                            "allows prose that mentions it"
bexpect 0 'not json at all'                     "no command field is not a denial"


# --- session-digest: correction vocabulary is configuration ------------------
# The default is English; the user it watches need not be. A word list hardcoded in a
# file that ships to other people is a bug, so the .local file must actually replace it.
CTMP=$(mktemp -d)
mkdir -p "$CTMP/_AI/tools" "$CTMP/_AI/config"
cp "$HOOKS/../tools/session-digest.sh" "$CTMP/_AI/tools/"
printf '%s\n' \
  '{"type":"user","promptSource":"typed","message":{"role":"user","content":"nein, so nicht"}}' \
  > "$CTMP/de.jsonl"
cn=$(AIOS_DIR="$CTMP/_AI" "$CTMP/_AI/tools/session-digest.sh" --json --transcript "$CTMP/de.jsonl" 2>/dev/null | /usr/bin/jq -r .corrections)
[ "$cn" = "0" ] && echo "  ok   session-digest default vocabulary misses other languages (expected)" \
               || { echo "  FAIL default vocabulary — wanted 0, got ${cn:-<none>}" >&2; FAIL=1; }

printf '%s\n' '# comment' '' '^(nein|nicht so)\b' > "$CTMP/_AI/config/correction-words.local"
cn=$(AIOS_DIR="$CTMP/_AI" "$CTMP/_AI/tools/session-digest.sh" --json --transcript "$CTMP/de.jsonl" 2>/dev/null | /usr/bin/jq -r .corrections)
[ "$cn" = "1" ] && echo "  ok   correction-words.local replaces the default vocabulary" \
               || { echo "  FAIL correction-words.local ignored — wanted 1, got ${cn:-<none>}" >&2; FAIL=1; }

# An all-comments file must not blank the vocabulary — that is how the scaffolded
# default would silently disable every correction signal.
printf '%s\n' '# only comments here' > "$CTMP/_AI/config/correction-words.local"
printf '%s\n' '{"type":"user","promptSource":"typed","message":{"role":"user","content":"no, that is wrong"}}' > "$CTMP/en.jsonl"
cn=$(AIOS_DIR="$CTMP/_AI" "$CTMP/_AI/tools/session-digest.sh" --json --transcript "$CTMP/en.jsonl" 2>/dev/null | /usr/bin/jq -r .corrections)
[ "$cn" = "1" ] && echo "  ok   an all-comments config keeps the built-in vocabulary" \
               || { echo "  FAIL empty config blanked the vocabulary — wanted 1, got ${cn:-<none>}" >&2; FAIL=1; }


# --- enumerations match reality ----------------------------------------------
# export.sh, install.sh and settings.json are allowlists; CLAUDE.md and README make
# claims about them. All of those are right when written and silently wrong after the
# next change. check-coverage.sh is the one place that notices.
if "$HOOKS/../tools/check-coverage.sh" >/dev/null 2>&1; then
  echo "  ok   enumerations match (hooks registered, templates scaffolded, export declared)"
else
  echo "  FAIL check-coverage.sh reports a mismatch:" >&2
  "$HOOKS/../tools/check-coverage.sh" >&2
  FAIL=1
fi


# --- check-coverage detects an ABSENT mention, not just a stale one -----------
# The first version of this check grepped the whole README and stayed green when a
# skill was deleted from the tree, because the word still appeared in prose. A check
# that cannot fail is not a check (L005), so the negative case is the real test.
#
# The scratch copy is deliberately NOT a git repo: check 3 then reports that it had
# nothing to check and skips, which is the behaviour a fresh export relies on. Staging
# a scratch repo would also trip guard-blanket-add.sh — correctly, since that gate
# matches command syntax and can tell neither a temp tree from this one nor a quoted
# command from a real one.
CVTMP=$(mktemp -d)
cp -R "$HOOKS/../tools" "$HOOKS/../setup" "$HOOKS/../.claude" \
      "$HOOKS/../templates" "$HOOKS/../CLAUDE.md" "$HOOKS/../README.md" "$CVTMP/" 2>/dev/null
if ( cd "$CVTMP" && ./tools/check-coverage.sh >/dev/null 2>&1 ); then
  echo "  ok   check-coverage passes on a complete tree"
else
  echo "  FAIL check-coverage should pass on a complete copy" >&2; FAIL=1
  ( cd "$CVTMP" && ./tools/check-coverage.sh ) >&2
fi

# Delete one skill from the README's tree block only — it stays mentioned in prose.
grep -v '├── retro/' "$CVTMP/README.md" > "$CVTMP/README.trimmed" && mv "$CVTMP/README.trimmed" "$CVTMP/README.md"
if ( cd "$CVTMP" && ./tools/check-coverage.sh >/dev/null 2>&1 ); then
  echo "  FAIL check-coverage missed a skill absent from the README tree" >&2; FAIL=1
else
  echo "  ok   check-coverage catches a skill missing from the README tree"
fi

# --- check-coverage: the vault-root glue must be in the README tree ------------
# The glue install.sh writes at the vault root is the part of the layout least likely
# to be documented, because it is the part a fresh clone does not contain. Its own
# scratch copy, so the deletion above cannot mask the result.
CVROOT=$(mktemp -d)
cp -R "$HOOKS/../tools" "$HOOKS/../setup" "$HOOKS/../.claude" \
      "$HOOKS/../templates" "$HOOKS/../CLAUDE.md" "$HOOKS/../README.md" "$CVROOT/" 2>/dev/null
grep -v '\.claudeignore' "$CVROOT/README.md" > "$CVROOT/R2" && mv "$CVROOT/R2" "$CVROOT/README.md"
cvrout=$(cd "$CVROOT" && sh tools/check-coverage.sh 2>&1)
case "$cvrout" in
  *"vault-root file written by install.sh is missing from README tree"*)
    echo "  ok   check-coverage catches vault-root glue missing from the README tree" ;;
  *) echo "  FAIL check-coverage missed an undocumented vault-root file" >&2; FAIL=1 ;;
esac

# --- check-coverage: a skill's name must match its directory -------------------
# A skill is addressed by directory, so a mismatched `name:` does not error — it just
# never gets picked, which is indistinguishable from the model choosing not to use it.
CVSK=$(mktemp -d)
cp -R "$HOOKS/../tools" "$HOOKS/../setup" "$HOOKS/../.claude" \
      "$HOOKS/../templates" "$HOOKS/../CLAUDE.md" "$HOOKS/../README.md" "$CVSK/" 2>/dev/null
sed 's/^name: retro$/name: retrospective/' "$CVSK/.claude/skills/retro/SKILL.md" > "$CVSK/S2" \
  && mv "$CVSK/S2" "$CVSK/.claude/skills/retro/SKILL.md"
cvsout=$(cd "$CVSK" && sh tools/check-coverage.sh 2>&1)
case "$cvsout" in
  *"does not match its directory"*)
    echo "  ok   check-coverage catches a skill whose name and directory disagree" ;;
  *) echo "  FAIL check-coverage missed a skill name/directory mismatch" >&2; FAIL=1 ;;
esac

# ...and an empty description, which silences a skill just as completely.
CVSD=$(mktemp -d)
mkdir -p "$CVSD/.claude/skills/ghost" "$CVSD/tools" "$CVSD/.claude" "$CVSD/setup"
cp "$HOOKS/../tools/check-coverage.sh" "$CVSD/tools/"
: > "$CVSD/.claude/settings.json"; : > "$CVSD/setup/export.sh"; : > "$CVSD/setup/install.sh"
printf -- '---\nname: ghost\ndescription:\n---\n' > "$CVSD/.claude/skills/ghost/SKILL.md"
cvdout=$(cd "$CVSD" && sh tools/check-coverage.sh 2>&1)
case "$cvdout" in
  *"skill description is empty"*)
    echo "  ok   check-coverage catches an empty skill description" ;;
  *) echo "  FAIL check-coverage missed an empty skill description" >&2; FAIL=1 ;;
esac

# --- a registered hook whose file is gone (L019) ------------------------------
# The failure this catches is silent by construction: hooks fail OPEN, so a settings file
# that points at a moved script looks fully wired and enforces nothing. Check 1 only proves
# the hook is NAMED there, which a stale path satisfies perfectly.
CC6=$(mktemp -d)
mkdir -p "$CC6/.claude/hooks" "$CC6/tools" "$CC6/setup"
cp "$HOOKS/../tools/check-coverage.sh" "$CC6/tools/"
: > "$CC6/setup/export.sh"; : > "$CC6/setup/install.sh"
printf '%s\n' '{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"\"${CLAUDE_PROJECT_DIR}/_AI/.claude/hooks/ghost.sh\""}]}]}}' \
  > "$CC6/.claude/settings.json"
case "$(cd "$CC6" && sh tools/check-coverage.sh 2>&1)" in
  *"registers a hook whose file does not exist"*)
    echo "  ok   check-coverage catches a registered hook with no file" ;;
  *) echo "  FAIL check-coverage missed a hook path that resolves to nothing" >&2; FAIL=1 ;;
esac
# ...and goes quiet once the file is there, or it is a check that can only ever be red.
: > "$CC6/.claude/hooks/ghost.sh"
case "$(cd "$CC6" && sh tools/check-coverage.sh 2>&1)" in
  *"registers a hook whose file does not exist"*)
    echo "  FAIL check-coverage still reports a hook whose file now exists" >&2; FAIL=1 ;;
  *) echo "  ok   check-coverage accepts a registered hook that resolves" ;;
esac
rm -rf "$CC6"

# --- .claude/ is a whitelist, and the walk closes its quiet side --------------
# The one directory other programs write into. The ignore rule admits SHAPES, so a new
# hook needs nobody to remember this file exists, and check-coverage walks the directory
# so a new KIND of file cannot go missing instead. Both halves are asserted here,
# against the REAL .gitignore rather than a copy of its intent.
CLTMP=$(mktemp -d)
mkdir -p "$CLTMP/.claude/hooks" "$CLTMP/.claude/sessions" "$CLTMP/tools" "$CLTMP/.claude" "$CLTMP/setup"
cp "$HOOKS/../.claude/.gitignore" "$CLTMP/.claude/.gitignore"
cp "$HOOKS/../tools/check-coverage.sh" "$CLTMP/tools/"
: > "$CLTMP/.claude/settings.json"; : > "$CLTMP/setup/export.sh"; : > "$CLTMP/setup/install.sh"
printf '# R\n\n```\n_AI/\n```\n' > "$CLTMP/README.md"
( cd "$CLTMP" && git init -q >/dev/null 2>&1 \
  && git add .claude/.gitignore .claude/settings.json >/dev/null 2>&1 )
: > "$CLTMP/.claude/settings.local.json"
: > "$CLTMP/.claude/sessions/s.json"
: > "$CLTMP/.claude/hooks/new-gate.sh"

if ( cd "$CLTMP" && git check-ignore -q .claude/settings.local.json ); then
  echo "  ok   .claude: a per-machine settings file is ignored"
else
  echo "  FAIL .claude: settings.local.json would be committed" >&2; FAIL=1
fi
if ( cd "$CLTMP" && git check-ignore -q .claude/sessions/s.json ); then
  echo "  ok   .claude: a plugin's session state is ignored"
else
  echo "  FAIL .claude: sessions/ would be committed" >&2; FAIL=1
fi
if ( cd "$CLTMP" && git check-ignore -q .claude/hooks/new-gate.sh ); then
  echo "  FAIL .claude: a new hook is ignored, so it would never ship" >&2; FAIL=1
else
  echo "  ok   .claude: a new hook is admitted by shape, not by name"
fi

clout=$(cd "$CLTMP" && sh tools/check-coverage.sh 2>&1)
case "$clout" in
  *"neither tracked nor declared LOCAL_ONLY: .claude/hooks/new-gate.sh"*)
    echo "  ok   check-coverage catches an untracked file under .claude/" ;;
  *) echo "  FAIL check-coverage missed an untracked file under .claude/" >&2; FAIL=1 ;;
esac
# The declared droppings must NOT be reported, or the check cries wolf on every session
# and gets switched off — the L006 failure, inside a check written to prevent L008.
case "$clout" in
  *"settings.local.json"*|*"sessions/s.json"*)
    echo "  FAIL check-coverage reports a declared LOCAL_ONLY file" >&2; FAIL=1 ;;
  *) echo "  ok   check-coverage stays quiet about declared LOCAL_ONLY files" ;;
esac
# A foreign skill is the case skills/ being linked as a WHOLE directory makes possible,
# so the walk must name it as a skill rather than as generic bookkeeping.
mkdir -p "$CLTMP/.claude/skills/foreign"
: > "$CLTMP/.claude/skills/foreign/SKILL.md"
case "$(cd "$CLTMP" && sh tools/check-coverage.sh 2>&1)" in
  *"a skill under .claude/skills/ that this repo does not track"*)
    echo "  ok   check-coverage names an untracked skill as a skill" ;;
  *) echo "  FAIL check-coverage did not identify an untracked skill" >&2; FAIL=1 ;;
esac
rm -rf "$CLTMP/.claude/skills"

( cd "$CLTMP" && git add .claude/hooks/new-gate.sh >/dev/null 2>&1 )
clout2=$(cd "$CLTMP" && sh tools/check-coverage.sh 2>&1)
case "$clout2" in
  *"neither tracked nor declared LOCAL_ONLY"*)
    echo "  FAIL check-coverage still complains once the file is tracked" >&2; FAIL=1 ;;
  *) echo "  ok   check-coverage goes quiet once the file is tracked" ;;
esac
rm -rf "$CLTMP"



# --- check-coverage: the two sets that drifted on 2026-09-07 -------------------
# A new integration pack and a new .local knob both reached the README tree late, in the
# same session, and `correction-words.local` had never reached it at all -- found by this
# check on its first run. Enumerated from templates/ (what SHIPS), never from the user's
# own integrations/ or *.local: holding a generic, exported README to a personal file list
# would force it to name the user's tools, which is the leak the architecture prevents (L004).
CC3=$(mktemp -d)
mkdir -p "$CC3/templates/integrations" "$CC3/.claude" "$CC3/tools" "$CC3/setup"
cp "$HOOKS/../tools/check-coverage.sh" "$CC3/tools/"
: > "$CC3/templates/integrations/todoist.template.md"
: > "$CC3/.claude/settings.json"; : > "$CC3/setup/export.sh"; : > "$CC3/setup/install.sh"
printf '# R\n\n```\n_AI/\n├── integrations/\n```\n' > "$CC3/README.md"
cc3out=$(cd "$CC3" && sh tools/check-coverage.sh 2>&1)
case "$cc3out" in
  *"integration pack missing from README tree: todoist.md"*)
    echo "  ok   check-coverage catches an integration pack missing from the README tree" ;;
  *) echo "  FAIL check-coverage missed an unlisted integration pack" >&2; FAIL=1 ;;
esac
# ...and it must go green once the tree names it, or the check is just always-red.
printf '# R\n\n```\n_AI/\n├── integrations/\n│   └── todoist.md\n```\n' > "$CC3/README.md"
cc4out=$(cd "$CC3" && sh tools/check-coverage.sh 2>&1)
case "$cc4out" in
  *"integration pack missing"*) echo "  FAIL check-coverage still complains after the README lists it" >&2; FAIL=1 ;;
  *) echo "  ok   check-coverage passes once the README tree lists the pack" ;;
esac
rm -rf "$CC3"


# --- check-coverage: rules cited by ordinal ----------------------------------
# Inserting one rule into CLAUDE.md on 2026-09-07 broke two cross-references and left a
# duplicate ordinal in the same list; a third was missed by a case-sensitive grep and
# found by this check on its first run. Scope is live prose only — history/ is an
# append-only record and docs/ is dated, so a number there was true when written and
# flagging it would be the rule that fires on legitimate work (L006).
CC5=$(mktemp -d)
mkdir -p "$CC5/.claude" "$CC5/tools" "$CC5/setup"
cp "$HOOKS/../tools/check-coverage.sh" "$CC5/tools/"
: > "$CC5/.claude/settings.json"; : > "$CC5/setup/export.sh"; : > "$CC5/setup/install.sh"
printf '# f\n\nSee rule 5 above.\n' > "$CC5/CLAUDE.md"
case "$(cd "$CC5" && sh tools/check-coverage.sh 2>&1)" in
  *"cites a rule by ordinal"*) echo "  ok   check-coverage catches a rule cited by ordinal" ;;
  *) echo "  FAIL check-coverage missed an ordinal rule reference" >&2; FAIL=1 ;;
esac
# Case-insensitive: the miss that got through was "Rule 7", not "rule 7".
printf '# f\n\nRule 7 depends on noticing.\n' > "$CC5/CLAUDE.md"
case "$(cd "$CC5" && sh tools/check-coverage.sh 2>&1)" in
  *"cites a rule by ordinal"*) echo "  ok   check-coverage catches a capitalised ordinal reference" ;;
  *) echo "  FAIL check-coverage is case-sensitive — the exact miss of 2026-09-07" >&2; FAIL=1 ;;
esac
# ...and naming the rule instead must pass, or the check just bans the word "rule".
printf '# f\n\nSee the *Log file changes* rule above.\n' > "$CC5/CLAUDE.md"
case "$(cd "$CC5" && sh tools/check-coverage.sh 2>&1)" in
  *"cites a rule by ordinal"*) echo "  FAIL check-coverage flags a rule referred to by name" >&2; FAIL=1 ;;
  *) echo "  ok   check-coverage accepts a rule referred to by name" ;;
esac
rm -rf "$CC5"


# --- version.sh: the arithmetic a release depends on ---------------------------
# Split out of publish.sh precisely so it can be run here: the only other way to
# exercise it is to publish, and that path ends in an irreversible push.
V="$HOOKS/../setup/version.sh"

vexpect () { # vexpect <want-stdout> <label> <args...>
  want=$1; label=$2; shift 2
  got=$(bash "$V" "$@" 2>/dev/null)
  if [ "$got" = "$want" ]; then
    echo "  ok   version.sh: $label"
  else
    echo "  FAIL version.sh: $label — wanted '$want', got '$got'" >&2; FAIL=1
  fi
}

vexpect 0.1.1 "patch increments the last field"  bump 0.1.0 patch
vexpect 0.2.0 "minor resets patch"               bump 0.1.9 minor
vexpect 1.0.0 "major resets both"                bump 0.9.4 major
vexpect 0.10.0 "fields are numbers, not digits"  bump 0.9.0 minor

# A malformed VERSION must not become a malformed git tag, so every one of these
# has to be REJECTED rather than coerced into something plausible.
for bad in 1.2 1.2.3.4 "" v1.2.3 1.2.x 1..3 "1.2.3 "; do
  if bash "$V" validate "$bad" 2>/dev/null; then
    echo "  FAIL version.sh accepted a malformed version: '$bad'" >&2; FAIL=1
  else
    echo "  ok   version.sh rejects '$bad'"
  fi
done
vexpect "" "an unknown level exits non-zero" bump 1.0.0 sideways

# `current` reads the file, and reports 0.0.0 rather than empty when it is absent —
# an empty string would flow into `git tag v` and fail somewhere far from the cause.
VT=$(mktemp -d); mkdir -p "$VT/setup"
cp "$V" "$VT/setup/"
vt_current () { ( cd "$VT" && bash setup/version.sh current 2>/dev/null ); }
[ "$(vt_current)" = "0.0.0" ] && echo "  ok   version.sh: absent VERSION reads as 0.0.0" \
  || { echo "  FAIL version.sh: absent VERSION should read 0.0.0, got '$(vt_current)'" >&2; FAIL=1; }
printf '0.4.2\n' > "$VT/VERSION"
[ "$(vt_current)" = "0.4.2" ] && echo "  ok   version.sh: current reads VERSION" \
  || { echo "  FAIL version.sh: current misread VERSION" >&2; FAIL=1; }
printf 'not-a-version\n' > "$VT/VERSION"
if ( cd "$VT" && bash setup/version.sh current >/dev/null 2>&1 ); then
  echo "  FAIL version.sh: a corrupt VERSION passed through as usable" >&2; FAIL=1
else
  echo "  ok   version.sh: a corrupt VERSION fails loudly"
fi
rm -rf "$VT"


# --- version.sh changelog: the prepend that only runs on a SECOND release ------
# This block would otherwise sit unexecuted until the day it mattered. It lives in
# version.sh rather than inside publish.sh exactly so the suite can call the REAL
# code -- a test that re-implements the lines it is checking proves the copy works.
CLT=$(mktemp -d); CLF="$CLT/CHANGELOG.md"
printf -- '- Initial tagged release.\n' | bash "$V" changelog "$CLF" 0.1.0 2026-09-07
printf -- '- Ship versioning\n- Fix the path list\n' | bash "$V" changelog "$CLF" 0.2.0 2026-09-14
printf -- '- Rename a .local knob\n' | bash "$V" changelog "$CLF" 1.0.0 2026-10-01

clcheck () { # clcheck <test> <label>
  if eval "$1"; then echo "  ok   changelog: $2"
  else echo "  FAIL changelog: $2" >&2; FAIL=1; fi
}
clcheck '[ "$(grep -c "^# Changelog$" "$CLF")" -eq 1 ]' "the title is never duplicated"
clcheck '[ "$(head -1 "$CLF")" = "# Changelog" ]'       "the title stays first"
clcheck '[ "$(sed -n 3p "$CLF")" = "## v1.0.0 — 2026-10-01" ]' "newest release on top"
clcheck '[ "$(grep -c "^## v" "$CLF")" -eq 3 ]'         "no release is dropped"
clcheck 'grep -q "^- Initial tagged release.$" "$CLF"'  "the oldest entry survives two prepends"
clcheck 'grep -q "^- Fix the path list$" "$CLF"'        "a multi-line entry keeps every line"

# An empty entry must be refused rather than written: a version heading with nothing
# under it is worse than no changelog, because it reads as "this release changed
# nothing" when what happened is that the range came back empty.
if printf '' | bash "$V" changelog "$CLF" 2.0.0 2026-11-01 2>/dev/null; then
  echo "  FAIL changelog: an empty entry was written" >&2; FAIL=1
else
  echo "  ok   changelog: an empty entry is refused"
fi
# ...and the refusal must not have damaged the file it declined to write.
clcheck '[ "$(grep -c "^## v" "$CLF")" -eq 3 ]' "a refused write leaves the file intact"
rm -rf "$CLT"


# --- publish.sh: a release is never something that just happens ----------------
# These assert on the SCRIPT TEXT rather than by running it, because every path
# through publish.sh ends at a public remote. Coarse, and still worth having: each
# one encodes a decision that is invisible once the line is deleted.
PS="$HOOKS/../setup/publish.sh"

pgrep_ok () { # pgrep_ok <pattern> <label>
  # `--` first: these patterns start with dashes, which grep would read as options.
  if grep -Fq -- "$1" "$PS"; then
    echo "  ok   publish.sh: $2"
  else
    echo "  FAIL publish.sh: $2 — '$1' is gone" >&2; FAIL=1
  fi
}

# --delete would otherwise wipe the changelog on every sync, and it could never
# accumulate more than the entry written that same run.
pgrep_ok "--exclude 'CHANGELOG.md'" "the sync does not delete the public changelog"
# A moved tag rewrites what an existing clone resolves to.
pgrep_ok 'refs/tags/v$RELEASE" >/dev/null 2>&1' "an existing tag is checked before release"
# The tagger is metadata; unpinned it inherits ~/.gitconfig, publicly and permanently.
pgrep_ok 'tag -a "v$RELEASE"' "the tag is annotated, so its identity can be pinned"
# One push for both refs: no window where the commit is public and the tag is not.
pgrep_ok 'git push -q origin HEAD "refs/tags/v$RELEASE"' "commit and tag are pushed together"

# The commit body and the changelog must read the SAME path list. They did not:
# tools/ ships, and was missing from the hand-written copy in the commit-body range.
n=$(grep -c 'EXPORTED_PATHS' "$PS")
[ "$n" -ge 3 ] && echo "  ok   publish.sh: one exported-path list, used by both ranges" \
  || { echo "  FAIL publish.sh: exported paths are enumerated in more than one place" >&2; FAIL=1; }
for pth in tools setup templates VERSION tests .claude; do
  grep -E '^EXPORTED_PATHS=' "$PS" | grep -Fq " $pth" \
    || { echo "  FAIL publish.sh: EXPORTED_PATHS omits '$pth', which ships" >&2; FAIL=1; }
done
echo "  ok   publish.sh: EXPORTED_PATHS covers every shipped path"

# VERSION must actually reach the export, or the file names a version no fork can read.
grep -Fq '$AI_DIR/VERSION' "$HOOKS/../setup/export.sh" \
  && echo "  ok   export.sh ships VERSION" \
  || { echo "  FAIL export.sh does not copy VERSION" >&2; FAIL=1; }

exit $FAIL
