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
# Runs against a TEMP tree with its own allowlist, never the real one. Two reasons: the
# fixture must not depend on this vault's configuration, and hardcoding real page ids into
# a file that SHIPS would put the owner's document tree in the public export. The leak
# check catches that pattern, but a fixture that only passes because another gate stops it
# is a fixture written wrong.
KTMP=$(mktemp -d); mkdir -p "$KTMP/_AI/harness/hooks"
cp "$HOOKS/hooks/guard-clickup.sh" "$HOOKS/hooks/lib.sh" "$KTMP/_AI/harness/hooks/"
printf '# fixture allowlist\nPAGE-ALLOWED\n' > "$KTMP/_AI/clickup-replace-allow.local"
kexpect() { # kexpect <want-exit> <json> <label>
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$KTMP" "$KTMP/_AI/harness/hooks/guard-clickup.sh" >/dev/null 2>&1
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
rm -f "$KTMP/_AI/clickup-replace-allow.local"
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

# --- tools/usage.sh ---
# Asserted against a fixture with hand-computed totals, never against the live corpus:
# the arithmetic is what needs pinning, and real numbers drift as sessions accrue.
ROOT="$(cd "$HOOKS/.." && pwd)"
USAGE_JSON=$("$ROOT/tools/usage.sh" --dir "$HOOKS/tests/fixtures/usage" --json 2>/dev/null)
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

FILTERED=$("$ROOT/tools/usage.sh" --dir "$HOOKS/tests/fixtures/usage" --project proj-b --json 2>/dev/null)
got=$(printf '%s' "$FILTERED" | /usr/bin/jq -r .output 2>/dev/null)
[ "$got" = "25" ] && echo "  ok   usage --project filters to one project" \
                  || { echo "  FAIL --project filter: wanted output 25, got ${got:-<none>}" >&2; FAIL=1; }

# --- suggest-retro (Stop) ---------------------------------------------------
# This hook is advisory, so its failure mode is the opposite of the guards': the
# expensive mistake is a FALSE POSITIVE. A nudge that fires on quiet sessions is a
# nudge the user turns off, and then the learning loop has no trigger at all. Hence
# the below-threshold and loop-guard cases carry as much weight as the firing one.
RTMP=$(mktemp -d)
mkdir -p "$RTMP/_AI/harness/hooks" "$RTMP/_AI/tools" "$RTMP/_AI/tmp"
cp "$HOOKS/hooks/suggest-retro.sh" "$HOOKS/hooks/lib.sh" "$RTMP/_AI/harness/hooks/"
cp "$HOOKS/../tools/session-digest.sh" "$RTMP/_AI/tools/"
RHOOK="$RTMP/_AI/harness/hooks/suggest-retro.sh"

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
mkdir -p "$DTMP/_AI/harness/hooks"
cp "$HOOKS/hooks/guard-vault-write.sh" "$HOOKS/hooks/lib.sh" "$DTMP/_AI/harness/hooks/"
printf '%s' '{"session_id":"dsid","tool_name":"Write","tool_input":{"file_path":"/v/Archive/x.md","content":"x"}}' \
  | CLAUDE_PROJECT_DIR="$DTMP" "$DTMP/_AI/harness/hooks/guard-vault-write.sh" >/dev/null 2>&1
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
mkdir -p "$CTMP/_AI/tools"
cp "$HOOKS/../tools/session-digest.sh" "$CTMP/_AI/tools/"
printf '%s\n' \
  '{"type":"user","promptSource":"typed","message":{"role":"user","content":"nein, so nicht"}}' \
  > "$CTMP/de.jsonl"
cn=$(AIOS_DIR="$CTMP/_AI" "$CTMP/_AI/tools/session-digest.sh" --json --transcript "$CTMP/de.jsonl" 2>/dev/null | /usr/bin/jq -r .corrections)
[ "$cn" = "0" ] && echo "  ok   session-digest default vocabulary misses other languages (expected)" \
               || { echo "  FAIL default vocabulary — wanted 0, got ${cn:-<none>}" >&2; FAIL=1; }

printf '%s\n' '# comment' '' '^(nein|nicht so)\b' > "$CTMP/_AI/correction-words.local"
cn=$(AIOS_DIR="$CTMP/_AI" "$CTMP/_AI/tools/session-digest.sh" --json --transcript "$CTMP/de.jsonl" 2>/dev/null | /usr/bin/jq -r .corrections)
[ "$cn" = "1" ] && echo "  ok   correction-words.local replaces the default vocabulary" \
               || { echo "  FAIL correction-words.local ignored — wanted 1, got ${cn:-<none>}" >&2; FAIL=1; }

# An all-comments file must not blank the vocabulary — that is how the scaffolded
# default would silently disable every correction signal.
printf '%s\n' '# only comments here' > "$CTMP/_AI/correction-words.local"
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
cp -R "$HOOKS/../tools" "$HOOKS/../skills" "$HOOKS/../setup" "$HOOKS/../harness" \
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



# --- check-coverage: the two sets that drifted on 2026-09-07 -------------------
# A new integration pack and a new .local knob both reached the README tree late, in the
# same session, and `correction-words.local` had never reached it at all -- found by this
# check on its first run. Enumerated from templates/ (what SHIPS), never from the user's
# own integrations/ or *.local: holding a generic, exported README to a personal file list
# would force it to name the user's tools, which is the leak the architecture prevents (L004).
CC3=$(mktemp -d)
mkdir -p "$CC3/templates/integrations" "$CC3/harness" "$CC3/tools" "$CC3/setup"
cp "$HOOKS/../tools/check-coverage.sh" "$CC3/tools/"
: > "$CC3/templates/integrations/todoist.template.md"
: > "$CC3/harness/settings.json"; : > "$CC3/setup/export.sh"; : > "$CC3/setup/install.sh"
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
mkdir -p "$CC5/harness" "$CC5/tools" "$CC5/setup"
cp "$HOOKS/../tools/check-coverage.sh" "$CC5/tools/"
: > "$CC5/harness/settings.json"; : > "$CC5/setup/export.sh"; : > "$CC5/setup/install.sh"
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

exit $FAIL
