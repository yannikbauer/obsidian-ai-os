#!/usr/bin/env python3
"""Render propose.py output as a markdown review table, one column per model run.

Each row gets a grade cell to fill in: the column letter of the better proposal, `ok`
for both, or `x` for neither. Graded rows are what the apply step takes, and the
counts are the pilot's success number (roadmap #11: "N notes, M needed correction").

  review.py tmp/polish/pilot-gemma3.jsonl tmp/polish/pilot-qwen3.5.jsonl > review.md
"""
import json, os, statistics, sys

runs = []
for f in sys.argv[1:]:
    rows = {}
    for l in open(f, encoding="utf-8"):
        if l.strip():
            r = json.loads(l)
            rows[r["path"]] = r
    runs.append((os.path.splitext(os.path.basename(f))[0], rows))

paths = list(dict.fromkeys(p for _, rows in runs for p in rows))
cols = "ABCDEFGH"[:len(runs)]


def cell(r):
    if not r:
        return "—"
    if "error" in r:
        return f"**error:** {r['error'][:80]}"
    return f"{r.get('description', '').replace('|', '/')} *({r.get('type')}, {r.get('language')})*"


out = ["# Frontmatter pilot — review", ""]
for c, (name, rows) in zip(cols, runs):
    secs = [r["secs"] for r in rows.values() if "error" not in r]
    errs = sum("error" in r for r in rows.values())
    med = statistics.median(secs) if secs else 0
    out.append(f"- **{c} = {name}**: {len(rows)} notes, median {med:.1f}s/note, "
               f"total {sum(secs)/60:.1f} min, {errs} errors")
out += ["", "Grade: the better column's letter, `ok` = both fine, `x` = neither. 🔒 = private (template description).", "",
        "| Note | " + " | ".join(cols) + " | Grade |", "|---|" + "---|" * len(cols) + "---|"]
for p in paths:
    first = next(rows[p] for _, rows in runs if p in rows)
    name = os.path.splitext(os.path.basename(p))[0].replace("|", "/")
    lock = "🔒 " if first.get("label") else ""
    out.append(f"| {lock}{name} ({first['bytes']:,} B) | "
               + " | ".join(cell(rows.get(p)) for _, rows in runs) + " |  |")
print("\n".join(out))
