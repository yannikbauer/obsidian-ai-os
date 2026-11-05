#!/usr/bin/env python3
"""Numbers for the daily log, computed the same way every time.

Read-only. Reads the frontmatter of every daily-log note (type: daily_log) and prints
markdown. The schema lives in maps/daily-log-map.md, and so do the field lists this script
needs: its "Stats settings" section names the sensitive, pre-registered and skipped fields
(`- **Sensitive:** a, b, c`). Without that section every list is empty and the script says so.

  daily-log-stats.py week [--week 2026-W46]        one line: outcome averages, days logged
  daily-log-stats.py summary [--since D] [--until D] [--top 10] [--no-sensitive]
  daily-log-stats.py table [--since D] [--until D]  all notes as one table (for checking)

The summary compares outcome means between groups of days: bool true vs false, numbers
above vs at-or-below their median, list values by membership, text values one vs the rest.
Same day and lag-1 (factor on day D, outcome on day D+1). Every number comes with its n;
a group under --min-n days prints "too few days". A shuffle test gives a chance check per
row; with many rows, some will look strong by chance, and the header says how many rows ran.
"""
import argparse
import datetime as dt
import random
import re
import statistics as st
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("needs pyyaml: pip install pyyaml")

VAULT = Path(__file__).resolve().parents[2]
OUTCOMES = ["mood", "energy", "anxiety"]
MAP = Path(__file__).resolve().parents[1] / "maps" / "daily-log-map.md"


def stats_settings(path=MAP):
    """Field lists from the map's "## Stats settings" section: {key: set of field names}."""
    out = {"sensitive": set(), "pre-registered": set(), "skip": set()}
    if not path.exists():
        return out, f"no {path.name}"
    inside = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            inside = line.strip() == "## Stats settings"
            continue
        m = re.match(r"^- \*\*(.+?):\*\*\s*(.*)$", line) if inside else None
        if m and m.group(1).strip().lower() in out:
            out[m.group(1).strip().lower()] = {x.strip().strip("`") for x in m.group(2).split(",") if x.strip()}
    found = any(out.values())
    return out, None if found else f"no 'Stats settings' section in {path.name}"


_SETTINGS, SETTINGS_NOTE = stats_settings()
SENSITIVE = _SETTINGS["sensitive"]
SKIP = {"type", "schema", "date", "logged", "week", "sensitivity", "tags"} | _SETTINGS["skip"]
PREREG = _SETTINGS["pre-registered"]
SHUFFLES = 2000


def load(vault, since=None, until=None):
    notes = []
    for p in sorted(vault.glob("Periodic notes/*/*/Daily_note_*.md")):
        text = p.read_text(encoding="utf-8")
        if not text.startswith("---"):
            continue
        try:
            fm = yaml.safe_load(text.split("---", 2)[1]) or {}
        except yaml.YAMLError as e:
            print(f"> skipped {p.name}: frontmatter does not parse ({e.__class__.__name__})")
            continue
        if fm.get("type") != "daily_log" or not fm.get("date"):
            continue
        d = fm["date"] if isinstance(fm["date"], dt.date) else dt.date.fromisoformat(str(fm["date"]))
        if (since and d < since) or (until and d > until):
            continue
        fm["date"] = d
        notes.append(fm)
    notes.sort(key=lambda n: n["date"])
    return notes


def num(v):
    if isinstance(v, bool) or v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def mean(xs):
    return f"{st.mean(xs):.1f}" if xs else "–"


def week_line(notes, week):
    if week:
        y, w = week.upper().split("-W")
        start = dt.date.fromisocalendar(int(y), int(w), 1)
    else:  # last full week
        today = dt.date.today()
        start = today - dt.timedelta(days=today.weekday() + 7)
    end = start + dt.timedelta(days=6)
    days = [n for n in notes if start <= n["date"] <= end]
    parts = []
    for o in OUTCOMES:
        xs = [num(n.get(o)) for n in days if num(n.get(o)) is not None]
        parts.append(f"{o} {mean(xs)}")
    iso = start.isocalendar()
    print(f"{iso[0]}-W{iso[1]:02d}: " + " · ".join(parts) + f" · {len(days)}/7 logged")


def groupings(notes, no_sensitive):
    """Yield (factor, label, predicate) for every grouping of days worth testing."""
    keys = sorted({k for n in notes for k in n} - SKIP - set(OUTCOMES))
    for k in keys:
        if no_sensitive and k in SENSITIVE:
            continue
        vals = [n.get(k) for n in notes if n.get(k) not in (None, "", [])]
        if not vals:
            continue
        if all(isinstance(v, bool) for v in vals):
            yield k, "yes vs no", (lambda n, k=k: None if not isinstance(n.get(k), bool) else n[k])
        elif all(num(v) is not None for v in vals):
            med = st.median(num(v) for v in vals)
            if all(num(v) == med for v in vals):
                continue
            yield k, f"> {med:g} vs ≤ {med:g}", (
                lambda n, k=k, med=med: None if num(n.get(k)) is None else num(n[k]) > med)
        elif all(isinstance(v, list) for v in vals):
            for item in sorted({i for v in vals for i in v}):
                yield f"{k}:{item}", "yes vs no", (
                    lambda n, k=k, item=item: None if not isinstance(n.get(k), list) else item in n[k])
        else:
            for item in sorted({str(v) for v in vals}):
                yield f"{k}={item}", "this vs rest", (
                    lambda n, k=k, item=item: None if n.get(k) in (None, "") else str(n[k]) == item)


def shuffle_p(a, b):
    obs = abs(st.mean(a) - st.mean(b))
    pool, na, hits = a + b, len(a), 0
    rng = random.Random(1)
    for _ in range(SHUFFLES):
        rng.shuffle(pool)
        if abs(st.mean(pool[:na]) - st.mean(pool[na:])) >= obs - 1e-12:
            hits += 1
    return hits / SHUFFLES


def compare(notes, pred, outcome, lag, min_n):
    by_date = {n["date"]: n for n in notes}
    a, b = [], []
    for n in notes:
        g = pred(n)
        if g is None:
            continue
        target = by_date.get(n["date"] + dt.timedelta(days=lag)) if lag else n
        y = num(target.get(outcome)) if target else None
        if y is None:
            continue
        (a if g else b).append(y)
    if len(a) < min_n or len(b) < min_n:
        return None, len(a), len(b)
    return st.mean(a) - st.mean(b), a, b


def summary(notes, top, min_n, no_sensitive):
    if not notes:
        print("No daily-log notes in range.")
        return
    first, last = notes[0]["date"], notes[-1]["date"]
    span = (last - first).days + 1
    print(f"## Daily log summary · {first} – {last}\n")
    print(f"{len(notes)} days logged of {span}. Groups under {min_n} days: \"too few days\".")
    if len(notes) < 14:
        print(f"\n> **Under 14 logged days.** Differences below are descriptive only; the map "
              f"allows effect sizes from 14 days.")
    places = {}
    for n in notes:
        places.setdefault(str(n.get("place") or "?"), []).append(n)
    print("\n### Outcomes by place\n\n| place | days | " + " | ".join(OUTCOMES) + " |")
    print("|---|---|" + "---|" * len(OUTCOMES))
    for p, ns in sorted(places.items(), key=lambda x: -len(x[1])):
        cells = [mean([num(n.get(o)) for n in ns if num(n.get(o)) is not None]) for o in OUTCOMES]
        print(f"| {p} | {len(ns)} | " + " | ".join(cells) + " |")
    if len(places) > 1:
        print("\n> Place moves many factors at once (people, stimulants, structure, light). "
              "A place difference is a bundle, not a finding.")

    rows, ran, small = [], 0, 0
    groups = list(groupings(notes, no_sensitive))
    for factor, label, pred in groups:
        for outcome in OUTCOMES:
            for lag in (0, 1):
                ran += 1
                diff, a, b = compare(notes, pred, outcome, lag, min_n)
                if diff is None:
                    small += 1
                    continue
                rows.append((abs(diff), factor, label, outcome, lag, diff, a, b))
    rows.sort(key=lambda r: -r[0])
    print(f"\n### Top differences\n\n{ran} comparisons tried, {small} with too few days. "
          f"With this many, a few strong-looking rows are expected by chance alone; "
          f"prereg = pre-registered question.\n")
    if not rows:
        print("Nothing to compare yet: every group has too few days.")
    else:
        print("| factor | groups | outcome | lag | diff | mean (n) | mean (n) | chance | prereg |")
        print("|---|---|---|---|---|---|---|---|---|")
        for _, factor, label, outcome, lag, diff, a, b in rows[:top]:
            base = factor.split(":")[0].split("=")[0]
            print(f"| {factor} | {label} | {outcome} | {'D+1' if lag else 'same'} | {diff:+.1f} "
                  f"| {st.mean(a):.1f} ({len(a)}) | {st.mean(b):.1f} ({len(b)}) "
                  f"| {shuffle_p(a, b):.2f} | {'yes' if base in PREREG else ''} |")
        print("\n`chance` = share of 2000 random reshuffles of the same days that gave a "
              "difference at least this big. Not a p-value to hunt with; a large one means "
              "\"could easily be noise\".")

    # Factors that travel together: their effects can't be told apart.
    binar = []
    for factor, _, pred in groups:
        vec = [pred(n) for n in notes]
        if sum(v is True for v in vec) >= min_n and sum(v is False for v in vec) >= min_n:
            binar.append((factor, vec))
    pairs = []
    for i in range(len(binar)):
        for j in range(i + 1, len(binar)):
            (f1, v1), (f2, v2) = binar[i], binar[j]
            if f1.split(":")[0].split("=")[0] == f2.split(":")[0].split("=")[0]:
                continue
            both = [(x, y) for x, y in zip(v1, v2) if x is not None and y is not None]
            if len(both) < 2 * min_n:
                continue
            agree = sum(x == y for x, y in both) / len(both)
            if agree >= 0.85 or agree <= 0.15:
                pairs.append((f1, f2, agree, len(both)))
    if pairs:
        print("\n### Travel together (confounds)\n")
        for f1, f2, agree, n in pairs:
            how = "same" if agree >= 0.5 else "opposite"
            print(f"- {f1} and {f2}: {how} on {max(agree, 1 - agree):.0%} of {n} days")

    themes = {}
    for n in notes:
        for t in n.get("themes") or []:
            themes[t] = themes.get(t, 0) + 1
    ripe = [f"{t} ({c})" for t, c in sorted(themes.items(), key=lambda x: -x[1]) if c >= 5]
    if ripe:
        print("\n### Themes on 5+ days (candidates for a field of their own)\n\n- " + "\n- ".join(ripe))
    running = sorted({str(n["experiment"]) for n in notes if n.get("experiment")})
    if running:
        print("\n### Experiments tagged\n")
        for e in running:
            print(f"- {e}: {sum(str(n.get('experiment')) == e for n in notes)} days")


def table(notes):
    keys = ["date", "place"] + OUTCOMES + ["sleep_h", "move_min", "people_n", "outside_min", "work_h"]
    print("| " + " | ".join(keys) + " |\n|" + "---|" * len(keys))
    for n in notes:
        print("| " + " | ".join("" if n.get(k) is None else str(n.get(k)) for k in keys) + " |")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["week", "summary", "table"])
    ap.add_argument("--vault", type=Path, default=VAULT)
    ap.add_argument("--week", help="ISO week, e.g. 2026-W46 (default: last full week)")
    ap.add_argument("--since", type=dt.date.fromisoformat)
    ap.add_argument("--until", type=dt.date.fromisoformat)
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--min-n", type=int, default=4)
    ap.add_argument("--no-sensitive", action="store_true",
                    help="leave out substance and relationship fields")
    a = ap.parse_args()
    if a.no_sensitive and not SENSITIVE:
        # Fail closed: an empty list would print the very fields the flag exists to hide.
        sys.exit(f"--no-sensitive needs a 'Sensitive' list ({SETTINGS_NOTE or 'it is empty'}).")
    if a.mode == "summary" and SETTINGS_NOTE:
        print(f"> note: {SETTINGS_NOTE}; no fields are marked sensitive or pre-registered.", file=sys.stderr)
    notes = load(a.vault, a.since, a.until)
    if a.mode == "week":
        week_line(notes, a.week)
    elif a.mode == "summary":
        summary(notes, a.top, a.min_n, a.no_sensitive)
    else:
        table(notes)


if __name__ == "__main__":
    main()
