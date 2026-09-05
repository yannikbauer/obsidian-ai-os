#!/bin/sh
# usage.sh — what this account actually spends, read from Claude Code's own transcripts.
#
# Read-only. Touches nothing but ~/.claude/projects/**/*.jsonl.
#
# WHY RATE, NOT TOTALS: session limits are about how much is used inside a rolling
# window, so lifetime totals say nothing about whether you will hit one. Block 1 is
# the one that answers that question.
#
# ACCOUNT-WIDE BY DEFAULT: limits apply to the account, not a project. This vault is
# only about half of this machine's Claude Code usage, so scanning it alone understates
# consumption roughly twofold. Use --project to narrow deliberately.
set -u

# Published list ratios relative to base input price, NOT measured here. On a flat
# subscription they indicate effort, not money — a weighted total is a workload
# figure, not a bill. Change them here if the published ratios change.
W_IN=1; W_CACHE_CREATE=1.25; W_CACHE_READ=0.1; W_OUT=5

DIR="$HOME/.claude/projects"
PROJECT=""
MODE="report"

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)     DIR="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --json)    MODE="json"; shift ;;
    -h|--help)
      echo "usage.sh [--dir DIR] [--project NAME] [--json]"
      echo "  --dir      transcript root (default ~/.claude/projects)"
      echo "  --project  restrict to one project directory"
      echo "  --json     machine-readable totals instead of the report"
      exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

[ -d "$DIR" ] || { echo "no transcript directory at $DIR" >&2; exit 1; }
[ -x /usr/bin/jq ] || { echo "jq not found at /usr/bin/jq" >&2; exit 1; }

# Project dirs are the project path with "/" replaced by "-", so the home prefix is
# derivable and must not be hardcoded: this file ships in the export as of 2026-09-05,
# and a hardcoded username is exactly what the leak check exists to stop.
HOME_PREFIX="$(printf '%s' "$HOME" | tr '/' '-')-"

# One compact record per assistant turn, with the project name injected.
collect() {
  for pdir in "$DIR"/*/; do
    [ -d "$pdir" ] || continue
    proj=$(basename "$pdir")
    if [ -n "$PROJECT" ] && [ "$proj" != "$PROJECT" ]; then continue; fi
    for f in "$pdir"*.jsonl; do
      [ -f "$f" ] || continue
      /usr/bin/jq -c --arg proj "$proj" \
        --argjson wi "$W_IN" --argjson wc "$W_CACHE_CREATE" \
        --argjson wr "$W_CACHE_READ" --argjson wo "$W_OUT" '
        select(.type=="assistant")
        | (.message.usage // empty) as $u
        | { proj: $proj,
            sess: (.sessionId // "unknown"),
            t: ((.timestamp // "1970-01-01T00:00:00Z")
                 | sub("\\.[0-9]+Z$";"Z") | (fromdateiso8601? // 0)),
            i:  ($u.input_tokens // 0),
            cc: ($u.cache_creation_input_tokens // 0),
            cr: ($u.cache_read_input_tokens // 0),
            o:  ($u.output_tokens // 0) }
        | .w = (.i*$wi + .cc*$wc + .cr*$wr + .o*$wo)' "$f" 2>/dev/null
    done
  done
}

# Peak rolling window. Sorted times + prefix sums + a two-pointer that only moves
# forward, so this is O(n) rather than the O(n^2) pairwise scan it replaces — that
# version took two minutes on 4.5k turns, which is too slow to run habitually.
AGG='
def peak($win):
  if length == 0 then 0 else
    (sort_by(.t)) as $r | ($r | map(.t)) as $t | ($r | length) as $n
    | (reduce range(0;$n) as $k ([0]; . + [ .[-1] + $r[$k].w ])) as $pre
    | (reduce range(0;$n) as $i ({j:0, best:0};
         .j = (.j | until(. >= $n or $t[.] >= ($t[$i] + $win); . + 1))
         | .best = ([.best, ($pre[.j] - $pre[$i])] | max)) | .best)
  end;
{ sessions:       ([.[].sess] | unique | length),
  turns:          length,
  input:          ([.[].i]  | add // 0),
  cache_creation: ([.[].cc] | add // 0),
  cache_read:     ([.[].cr] | add // 0),
  output:         ([.[].o]  | add // 0),
  weighted:       (([.[].w] | add // 0) | round),
  peak_1h:        (peak(3600)  | round),
  peak_5h:        (peak(18000) | round),
  peak_24h:       (peak(86400) | round) }'

ROWS=$(collect)

if [ "$MODE" = "json" ]; then
  printf '%s\n' "$ROWS" | /usr/bin/jq -s "$AGG"
  exit 0
fi

TOTALS=$(printf '%s\n' "$ROWS" | /usr/bin/jq -s "$AGG")
get() { printf '%s' "$TOTALS" | /usr/bin/jq -r ".$1"; }

echo "═══ 1. RATE — the block that speaks to session limits ═══"
echo
printf '  peak 1h  : %s weighted tokens\n'  "$(get peak_1h)"
printf '  peak 5h  : %s weighted tokens\n'  "$(get peak_5h)"
printf '  peak 24h : %s weighted tokens\n'  "$(get peak_24h)"
echo
echo "  Busiest windows (when the peaks happened):"
printf '%s\n' "$ROWS" | /usr/bin/jq -sr '
  def peakat($win):
    (sort_by(.t)) as $r | ($r | map(.t)) as $t | ($r | length) as $n
    | (reduce range(0;$n) as $k ([0]; . + [ .[-1] + $r[$k].w ])) as $pre
    | (reduce range(0;$n) as $i ({j:0, best:0, at:0};
         .j = (.j | until(. >= $n or $t[.] >= ($t[$i] + $win); . + 1))
         | (($pre[.j] - $pre[$i]) as $sum
            | if $sum > .best then .best = $sum | .at = $t[$i] else . end)));
  (peakat(18000)) | "    5h peak began \(.at | todate)  (\(.best | round) weighted)"' 2>/dev/null

echo
echo "═══ 2. PER SESSION — where the spend actually goes ═══"
echo
printf '  %-26s %-8s %6s %10s %10s %12s\n' PROJECT DATE TURNS OUTPUT CACHE_CR WEIGHTED
printf '%s\n' "$ROWS" | /usr/bin/jq -sr --arg hp "$HOME_PREFIX" '
  group_by(.sess) | map({
    proj: (.[0].proj | ltrimstr($hp) | .[0:26]),
    date: (.[0].t | strftime("%Y-%m-%d")),
    turns: length,
    o: ([.[].o] | add), cc: ([.[].cc] | add), w: ([.[].w] | add | round)})
  | sort_by(-.w) | .[:12][]
  | "  \(.proj | tostring | (. + "                          ")[0:26]) \(.date) \(.turns|tostring|(("      ")+.)[-6:]) \(.o|tostring|(("          ")+.)[-10:]) \(.cc|tostring|(("          ")+.)[-10:]) \(.w|tostring|(("            ")+.)[-12:])"' 2>/dev/null

echo
echo "═══ 3. TOTALS ═══"
echo
printf '  sessions %s over %s assistant turns\n' "$(get sessions)" "$(get turns)"
printf '  true input     %14s  ×%s\n'  "$(get input)"          "$W_IN"
printf '  cache creation %14s  ×%s\n'  "$(get cache_creation)" "$W_CACHE_CREATE"
printf '  cache read     %14s  ×%s\n'  "$(get cache_read)"     "$W_CACHE_READ"
printf '  output         %14s  ×%s\n'  "$(get output)"         "$W_OUT"
printf '  ─────────────────────────────\n'
printf '  weighted total %14s\n' "$(get weighted)"
echo
echo "  Multipliers are published list ratios, not measured. On a flat subscription"
echo "  the weighted total is a workload figure, not a bill."
echo
echo "  Per project:"
printf '%s\n' "$ROWS" | /usr/bin/jq -sr --arg hp "$HOME_PREFIX" '
  group_by(.proj) | map({p: (.[0].proj | ltrimstr($hp)),
                         w: ([.[].w] | add | round)})
  | sort_by(-.w) | (map(.w) | add) as $tot | .[]
  | "    \(.p | (. + "                                        ")[0:40]) \(.w) (\((.w * 100 / $tot) | round)%)"' 2>/dev/null
