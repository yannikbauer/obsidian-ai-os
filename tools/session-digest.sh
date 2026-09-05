#!/bin/sh
# session-digest.sh — reduce one Claude Code transcript to the parts a retro needs.
#
# Read-only. Touches nothing but the transcript file.
#
# WHY A REDUCER AND NOT A READ: a working session's JSONL runs to megabytes, but the
# human's own turns are ~0.3% of it (measured: 3.0 MB -> 8.6 KB). Corrections live in
# that 0.3%, and everything else is the model re-reading its own output. So the whole
# job is: keep the human's words, the tool-call shape, and the failures; drop the rest.
#
# WHY NOT session-log.md: that log is what the model believed it did. This is what
# happened. A learning loop that trains on its own summary learns its own blind spots.
#
# Output is a tmp/ artifact by convention — it quotes vault content verbatim (diary,
# health, finances), so it is never committed. See docs/work/2026-09-05-retro.md D6.
set -u

DIR="$HOME/.claude/projects"
PROJECT=""
SESSION=""
TRANSCRIPT=""
MODE="digest"
MAX_TURN_CHARS=600

# Correction vocabulary. Deliberately conservative: a false positive costs one wasted
# question, a false negative costs a lesson.
#
# The default is English because the rest of the OS is, but the user it watches need
# not be, and plenty of people think in one language and work in another. So it is
# CONFIGURATION, not code: _AI/correction-words.local holds one extended-regex alternative per line
# and REPLACES the default when present, the same contract readonly-zones.local uses.
# A word list is the wrong thing to hardcode in a file that ships to other people.
CORRECTION_RE='^(no|nope|not quite|wrong)\b|\b(actually|instead|revert|undo|misread|incorrect|not what i|rather than|you (missed|forgot|misunderstood)|that.s (wrong|not)|don.t |do not )'
CORRECTION_FILE="${AIOS_DIR:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}/correction-words.local"
if [ -f "$CORRECTION_FILE" ]; then
  _re=$(grep -v '^[[:space:]]*#' "$CORRECTION_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' \
        | tr '\n' '|' | sed 's/|$//')
  [ -n "$_re" ] && CORRECTION_RE="$_re"
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)        DIR="$2"; shift 2 ;;
    --project)    PROJECT="$2"; shift 2 ;;
    --session)    SESSION="$2"; shift 2 ;;
    --transcript) TRANSCRIPT="$2"; shift 2 ;;
    --signals)    MODE="signals"; shift ;;
    --json)       MODE="json"; shift ;;
    -h|--help)
      echo "session-digest.sh [--session ID] [--transcript FILE] [--dir DIR] [--project NAME] [--signals|--json]"
      echo "  --session     session id or unique prefix (default: most recent transcript)"
      echo "  --transcript  explicit transcript path, bypassing the search"
      echo "  --signals     just the teaching-signal score, no content (for the Stop hook)"
      echo "  --json        machine-readable digest"
      exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

[ -x /usr/bin/jq ] || { echo "jq not found at /usr/bin/jq" >&2; exit 1; }

# --- locate the transcript ---------------------------------------------------
if [ -z "$TRANSCRIPT" ]; then
  [ -d "$DIR" ] || { echo "no transcript directory at $DIR" >&2; exit 1; }
  search="$DIR"
  [ -n "$PROJECT" ] && search="$DIR/$PROJECT"
  if [ -n "$SESSION" ]; then
    TRANSCRIPT=$(find "$search" -name "${SESSION}*.jsonl" -type f 2>/dev/null | head -1)
  else
    # Most recently modified. `ls -t` over find's output is portable enough here and
    # avoids depending on GNU find's -printf.
    TRANSCRIPT=$(find "$search" -name '*.jsonl' -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
  fi
fi
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || { echo "no transcript found" >&2; exit 1; }

# The transcript filename IS the session id in Claude Code today, but relying on that
# couples this script to a naming convention it does not own — and the denies log is
# keyed by the real session id. Prefer what the caller told us.
SID="${SESSION:-$(basename "$TRANSCRIPT" .jsonl)}"

# --- extraction ---------------------------------------------------------------
# User turns, both content shapes (string and content-array) — clients differ, and a
# reducer that handles one silently returns almost nothing on the other.
# ONE TURN PER LINE, and only turns the human actually typed.
#
# Both halves of that were bugs on the first pass. A user-role entry in a transcript is
# not the same thing as a human speaking: tool results and injected skill bodies arrive
# in the same role, and counting them reported 204 "human turns" for a session with 5.
# The discriminator (verified across CLI and desktop-app transcripts, 2026-09-05):
#   real prompt    -> has .promptSource ("typed" | "sdk")
#   tool result    -> has .toolUseResult
#   injected skill -> .isMeta true / has .sourceToolUseID
# The fallback clause keeps older transcripts that predate .promptSource working, and
# leans toward including: a missed correction costs a lesson, a false one costs a line.
#
# Newlines become a visible marker so one turn stays one line — every count below is
# line-based, and a multi-line paste would otherwise read as a dozen separate turns.
user_turns() {
  /usr/bin/jq -r '
    select(.type=="user")
    | select(.promptSource
             or ((has("toolUseResult")|not) and (.isMeta|not) and (has("sourceToolUseID")|not)))
    | (if (.message.content|type)=="string" then .message.content
       else ([.message.content[]? | select(.type=="text") | .text] | join(" ")) end)
    | select(. != null and . != "")
    | gsub("\\s*\n\\s*"; " / ")' "$TRANSCRIPT" 2>/dev/null \
  | grep -v '^[[:space:]]*$' \
  | grep -v '^<' \
  | grep -v '^\[Request interrupted'
}

tool_calls() {
  /usr/bin/jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' \
    "$TRANSCRIPT" 2>/dev/null
}

# "Wrote a framework file" is an ACT, not a tool. Counting Write/Edit alone reported
# zero for the session that built this script, because that session did every edit
# through Bash heredocs — the signal was watching one representation of the act and
# missing another. So: Write/Edit file paths, plus Bash commands that redirect into or
# rewrite an _AI/ path. The Bash clause requires a mutating verb, so reading a file
# with cat does not count as writing it.
framework_writes() {
  /usr/bin/jq -r 'select(.type=="assistant") | .message.content[]?
    | select(.type=="tool_use")
    | if (.name=="Write" or .name=="Edit") then (.input.file_path // empty)
      elif .name=="Bash" then
        ((.input.command // "")
         | select(test("_AI/|AIOS_DIR|\\$AI_DIR"))
         | select(test(">>?[[:space:]]*[\"'"'"']?[^|]*_AI/|sed -i|tee |^\\s*(cp|mv)\\b|python3?[[:space:]]|write_text"))
         | "Bash: " + (.[0:80]))
      else empty end' "$TRANSCRIPT" 2>/dev/null | grep -E '/_AI/|^Bash: '
}

error_results() {
  /usr/bin/jq -r 'select(.type=="user") | .message.content[]?
    | select(.type=="tool_result" and .is_error==true)
    | (.content | if type=="array" then (.[0].text // "") else (. // "") end)
    | gsub("\\s*\n\\s*"; " / ")' \
    "$TRANSCRIPT" 2>/dev/null | cut -c1-120
}

TURNS=$(user_turns)
CORRECTIONS=$(printf '%s\n' "$TURNS" | grep -iE "$CORRECTION_RE" || true)

n_turns=$(printf '%s\n' "$TURNS" | grep -c . || true)
n_corr=$(printf '%s\n' "$CORRECTIONS" | grep -c . || true)
n_err=$(error_results | grep -c . || true)
n_fw=$(framework_writes | grep -c . || true)
n_tools=$(tool_calls | grep -c . || true)

# Deny gates leave no trace in the transcript — verified 2026-09-05, "permissionDecision"
# appears nowhere in it. lib.sh's deny() writes tmp/denies-<sid>.log instead, and that
# file is the only evidence a rule was nearly broken.
AIOS_DIR="${AIOS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
denies="$AIOS_DIR/tmp/denies-$SID.log"
n_deny=0
[ -f "$denies" ] && n_deny=$(grep -c . "$denies" 2>/dev/null || echo 0)

# A deny is on its own sufficient: it means a rule was about to be broken.
score=$(( n_deny * 2 ))
[ "$n_corr" -ge 1 ] && score=$((score + 1))
[ "$n_corr" -ge 3 ] && score=$((score + 1))
[ "$n_err"  -ge 2 ] && score=$((score + 1))
[ "$n_fw"   -ge 1 ] && score=$((score + 1))

case "$MODE" in
  signals)
    echo "score=$score denies=$n_deny corrections=$n_corr errors=$n_err framework_writes=$n_fw"
    exit 0 ;;
  json)
    /usr/bin/jq -n --arg sid "$SID" --arg path "$TRANSCRIPT" \
      --argjson score "$score" --argjson denies "$n_deny" \
      --argjson corrections "$n_corr" --argjson errors "$n_err" \
      --argjson framework_writes "$n_fw" --argjson turns "$n_turns" \
      --argjson tools "$n_tools" \
      '{session:$sid, transcript:$path, score:$score, denies:$denies,
        corrections:$corrections, errors:$errors,
        framework_writes:$framework_writes, user_turns:$turns, tool_calls:$tools}'
    exit 0 ;;
esac

# --- the digest ----------------------------------------------------------------
echo "# Session digest — $SID"
echo
echo "Teaching signals: score $score (denies $n_deny · corrections $n_corr · errors $n_err · framework writes $n_fw)"
echo "$n_turns human turns · $n_tools tool calls"
echo
echo "## What the human said"
echo
printf '%s\n' "$TURNS" | cut -c1-$MAX_TURN_CHARS | sed 's/^/- /'
echo
if [ "$n_corr" -gt 0 ]; then
  echo "## Turns that read as corrections"
  echo
  printf '%s\n' "$CORRECTIONS" | cut -c1-$MAX_TURN_CHARS | sed 's/^/- /'
  echo
fi
if [ "$n_deny" -gt 0 ]; then
  echo "## Hook denials — a rule was nearly broken"
  echo
  sed 's/^/- /' "$denies"
  echo
fi
if [ "$n_err" -gt 0 ]; then
  echo "## Failed tool calls"
  echo
  error_results | sed 's/^/- /'
  echo
fi
if [ "$n_fw" -gt 0 ]; then
  echo "## Framework files written"
  echo
  framework_writes | sort -u | sed 's/^/- /'
  echo
fi
echo "## Tool calls"
echo
tool_calls | sort | uniq -c | sort -rn | sed 's/^ */- /'
