#!/bin/sh
# The weekly unattended run of the vault health check (roadmap #12). Writes only into
# tmp/health/, never into a note: applying a proposal is the user's "apply" in the review.
# It never acks either: findings stay new until a report has been shown (`vault-health.py ack`).
#
#   tmp/health/YYYY-MM-DD.md              the report: everything not yet seen (one line if nothing)
#   tmp/health/proposals.jsonl            every description ever proposed, cumulative
#   tmp/health/YYYY-MM-DD-proposals.jsonl this week's rows: notes still missing one
#   tmp/health/YYYY-MM-DD-review.md       the same rows as a review sheet
#   tmp/health/YYYY-MM-DD-tmp.md          tmp housekeeping: what is stale in tmp/ (trashing it is
#                                         the user's word, `vault-health.py tmp --trash`)
#
# The cumulative file is what makes a failed week cheap: propose.py skips notes it already
# answered and retries rows that failed (a private note while Ollama was down).
# Proposing can take minutes on the local model, so start this detached (ledger L035):
#   nohup tools/vault-health-weekly.sh >/dev/null 2>&1 &
set -u
AI=$(cd "$(dirname "$0")/.." && pwd)
OUT="${AIOS_HEALTH_OUT:-$AI/tmp/health}"
D=$(date +%F)
mkdir -p "$OUT"
"$AI/tools/vault-health.py" missing > "$OUT/$D-missing.txt" || exit 1
# Frontmatter `status: open`; whoever applies the fixes sets it to applied (vault-maintenance skill)
{ printf -- '---\nstatus: open\n---\n\n'; "$AI/tools/vault-health.py" report; } > "$OUT/$D.md" || exit 1
"$AI/tools/vault-health.py" tmp > "$OUT/$D-tmp.md"
[ -s "$OUT/$D-missing.txt" ] || exit 0
"$AI/tools/frontmatter-polish/propose.py" --backend "${HEALTH_BACKEND:-claude}" --model "${HEALTH_MODEL:-haiku}" \
  --out "$OUT/proposals.jsonl" < "$OUT/$D-missing.txt" 2> "$OUT/$D-propose.log"
python3 - "$OUT/proposals.jsonl" "$OUT/$D-missing.txt" > "$OUT/$D-proposals.jsonl" <<'PY'
import json, sys
want = set(open(sys.argv[2]).read().split("\n")) - {""}
rows = {}
for line in open(sys.argv[1]):
    r = json.loads(line)
    if r["path"] in want:
        rows[r["path"]] = r  # the last row per note wins: a retry replaces the failure
print("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows.values()), end="")
PY
"$AI/tools/frontmatter-polish/review.py" "$OUT/$D-proposals.jsonl" > "$OUT/$D-review.md"
