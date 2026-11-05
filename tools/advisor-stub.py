#!/usr/bin/env python3
"""Build the paste-ready Claude project stub for an advisor.

An advisor's prompt note in the vault is the source of truth. Its Claude Desktop project
holds only a stub (read the note when the vault is reachable) plus a fallback copy of the
note's body for the phone. This script writes that stub from the note and the advisor's
block in `maps/advisors-map.md`, so every stub has the same shape and a prompt edit needs
one command, not hand-copying.

Usage:
  tools/advisor-stub.py --list
  tools/advisor-stub.py "Chef"            # writes _AI/tmp/chef-project-stub.md
  tools/advisor-stub.py --all
  tools/advisor-stub.py "Chef" --stdout

The note needs a `Version: vX.Y, last updated YYYY-MM-DD` line and a `## Who does what`
heading: the fallback copy is everything from that heading on.
"""
import argparse
import re
import sys
from pathlib import Path

AI = Path(__file__).resolve().parent.parent
VAULT = AI.parent
MAP = AI / "maps" / "advisors-map.md"
OUT = AI / "tmp"
BODY_START = "## Who does what"

FIELD = re.compile(r"^- \*\*(.+?):\*\*\s*(.*)$")


def load_registry():
    if not MAP.exists():
        sys.exit(f"No advisors configured: {MAP} is missing (template: templates/advisors-map.template.md).")
    advisors, current, in_registry = {}, None, False
    for line in MAP.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            in_registry = line.strip() == "## Registry"
            current = None
            continue
        if not in_registry:
            continue
        if line.startswith("### "):
            current = line[4:].strip()
            advisors[current] = {}
        elif current and (m := FIELD.match(line)):
            advisors[current][m.group(1).strip().lower()] = m.group(2).strip()
    return advisors


def strip_ticks(s):
    return s.strip().strip("`")


def build(name, f):
    note_rel = strip_ticks(f.get("prompt note", ""))
    if not note_rel:
        sys.exit(f"{name}: no Prompt note in the map.")
    note = VAULT / note_rel
    if not note.exists():
        sys.exit(f"{name}: {note_rel} not found.")
    text = note.read_text(encoding="utf-8")

    m = re.search(r"^Version:\s*(v[\d.]+),\s*last updated\s*(\d{4}-\d{2}-\d{2})", text, re.M)
    if not m:
        sys.exit(f"{name}: no 'Version: vX.Y, last updated YYYY-MM-DD' line in {note_rel}.")
    version = f"{m.group(1)}, {m.group(2)}"

    i = text.find(BODY_START)
    if i < 0:
        sys.exit(f"{name}: no '{BODY_START}' heading in {note_rel}.")
    body = text[i:].rstrip() + "\n"

    project = f.get("project") or name
    start = f.get("read at start", "")
    if start:
        start = (", " if start.startswith("then") else " ") + start
    phone = f.get("phone docs", "")
    phone_clause = f" and the project docs {phone}" if phone else ""
    source_extra = f" {f['source extra']}" if f.get("source extra") else ""
    files_extra = f" {f['files extra']}" if f.get("files extra") else ""
    footer = f"\n{f['footer']}\n" if f.get("footer") else ""

    return f"""=== Paste into the Claude Project "{project}" → Instructions (replaces everything there) ===

# {name} — project stub

Source of truth: the Obsidian note `{note_rel}`
in `{VAULT}`.{source_extra}

At the start of every chat: if the vault is reachable, read that note{start}, and follow
the note. Where it differs from the fallback below, the note wins. If the vault
isn't reachable (phone/web), use the fallback{phone_clause},
and say once that you are.

Fallback version: {version}. If the note shows a newer version, tell me
the fallback is stale.

Files: everything you know lives in the vault (map: the note's "Knowledge,
files and continuity"). Project docs are phone copies; only their title counts,
with or without a `claude/` prefix. Project memory is only a phone inbox: on the
phone, put what must reach the vault there, marked `phone, not yet in vault`;
the next linked session carries it over and clears it.{files_extra}
{footer}
--- Fallback copy (never edit here; edit the note and paste again) ---

{body}"""


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("advisor", nargs="?")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--stdout", action="store_true")
    a = ap.parse_args()

    reg = load_registry()
    if a.list:
        for n, f in reg.items():
            print(f"{n}\t{strip_ticks(f.get('prompt note', '?'))}")
        return
    if a.all:
        names = list(reg)
    elif a.advisor:
        match = [n for n in reg if n.lower() == a.advisor.lower()]
        if not match:
            sys.exit(f"Unknown advisor '{a.advisor}'. Known: {', '.join(reg)}")
        names = match
    else:
        ap.error("name an advisor, or use --all / --list")

    for n in names:
        stub = build(n, reg[n])
        if a.stdout:
            sys.stdout.write(stub)
            continue
        OUT.mkdir(exist_ok=True)
        path = OUT / f"{slug(n)}-project-stub.md"
        path.write_text(stub, encoding="utf-8")
        print(f"{n}: {path.relative_to(AI)} ({len(stub.split())} words)")


if __name__ == "__main__":
    main()
