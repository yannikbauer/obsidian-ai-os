#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml==6.0.2", "sqlite-vec==0.1.9", "numpy>=2,<3"]
# [tool.uv]
# python-preference = "only-managed"
# ///
"""Vault health report (roadmap #12): read-only, no model. It never writes a note.

  vault-health.py report [--all]   findings new since the user last saw a report (--all: every finding)
  vault-health.py ack              mark the current findings as seen: run it right after showing a report
  vault-health.py missing          paths of notes without a description, for propose.py
  vault-health.py tmp [--all|--trash]  sort _AI/tmp/ into keep / stale / to classify; --trash moves
                                   the stale ones to the macOS Trash (only on the user's word)

Checks: frontmatter that is not valid YAML, notes missing a `description`, descriptions gone
stale (the body changed a lot since the description was last seen), broken wikilinks, orphan
notes, tag variants that differ only in case or separator, and likely duplicate notes (similar
filenames; near-identical note vectors in the search index, if it exists).

"New" is relative to databases/vault-health.json, which only `ack` updates. The unattended
weekly run never acks, so a skipped review loses nothing: findings stay new, and pile up,
until a report has actually been shown. The same file holds the stale-check
baseline: per note, a hash of the description plus the body's word count and headings. A
note seen for the first time, or whose description changed, gets a fresh baseline.

Paths and link targets only, never note text: the report is safe to show for private notes.
Settings in config/vault-health.local (see templates/vault-health.template.local).
"""
import argparse, collections, datetime, fnmatch, hashlib, json, os, re, sqlite3, sys, urllib.parse
from pathlib import Path

try:
    import yaml
except ImportError:  # run as `python3 vault-health.py`: the shebang's uv environment never started
    sys.exit("vault-health: run it directly (./vault-health.py or its full path), not via python3")

AI = Path(os.environ.get("AIOS_DIR") or Path(__file__).resolve().parent.parent)
VAULT = Path(os.environ.get("AIOS_VAULT_DIR") or AI.parent)
SEARCH_DB = Path(os.environ.get("AIOS_SEARCH_DB") or AI / "databases" / "vault-search.db")
STATE = Path(os.environ.get("AIOS_HEALTH_STATE") or AI / "databases" / "vault-health.json")
CONFIG = AI / "config" / "vault-health.local"

DEFAULTS = {
    "exclude": "_AI/*, .obsidian/*, .trash/*, Archive/*, Attachments/*, copilot/*, Templates/*, Excalidraw/*",
    "skip": "",  # notes that need no description and are not orphans: their filenames route them
    "periodic": r"\d{4}-(?:\d{2}-\d{2}|\d{2}-W\d{2}|W\d{2})",  # a broken link to a date note is expected
    "dup_cosine": "0.92",  # bge-m3: yearly series (2018 Goals, 2019 Goals) sit at 0.88
}
NEVER = ("/.obsidian/", "/.trash/", "/.git/")
FM = re.compile(r"\A---\n(.*?\n)?---\n", re.S)
CAP = 25
COPY = re.compile(r"(?: \d| copy|[ _-]v\d+)$")
SECRETISH = re.compile(r"[A-Z0-9]{16,}")  # key-like ids in attachment names stay out of the report

FIXERS = {
    "yaml": "fix by hand, or tools/frontmatter-set.py once it parses (it quotes values)",
    "nodesc": "`vault-health.py missing | tools/frontmatter-polish/propose.py …`, review, then `frontmatter-set.py --from-jsonl`",
    "stale": "re-propose: `printf '%s\\n' <paths> | propose.py …`, apply with `frontmatter-set.py --from-jsonl … --replace`",
    "broken": "your call per link: fix the target, create the note, or unlink",
    "orphan": "your call: link it from a hub note, or leave it (search still finds it)",
    "tag": "your call: pick one spelling; rename with Obsidian's Tag Wrangler",
    "dup": "your call: merge, and rewrite every link that pointed at the one that goes",
}
TITLES = {"yaml": "Frontmatter that is not valid YAML", "nodesc": "Missing description",
          "stale": "Stale description", "broken": "Broken links", "orphan": "Orphan notes",
          "tag": "Tag variants", "dup": "Likely duplicates"}


def load_config():
    cfg = dict(DEFAULTS)
    if CONFIG.exists():
        for line in CONFIG.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if "=" in line:
                k, v = (s.strip() for s in line.split("=", 1))
                cfg[k] = v
    for k in ("exclude", "skip"):
        cfg[k] = [g.strip() for g in cfg[k].split(",") if g.strip()]
    return cfg


def matches(rel, globs):
    return any(fnmatch.fnmatchcase(rel, g) for g in globs)  # fnmatch's * crosses /, like vault-search


# --- reading the vault -----------------------------------------------------------------------

def strip_code(text):
    text = re.sub(r"^(```|~~~).*?^\1", "", text, flags=re.S | re.M)
    text = re.sub(r"`[^`\n]*`", "", text)
    return re.sub(r"<%[*_-]?.*?%>", "", text, flags=re.S)  # Templater


WIKI = re.compile(r"!?\[\[((?:[^\[\]\n]|\[[^\[\]\n]*\])+?)\]\]")  # a balanced [..] may sit inside: [[Ideas [shared]]]; [[a]]] stays a
MDLINK = re.compile(r"\]\(([^)\s]+)\)")
TAG = re.compile(r"(?<![\w&/])#([^\W\d][\w/-]*)")
HEAD = re.compile(r"^#{1,3}\s+(.+?)\s*#*$", re.M)


def read_note(path):
    text = path.read_text(errors="ignore")
    m = FM.match(text)
    fm, err, body = {}, None, text
    if m:
        body = text[m.end():]
        try:
            fm = yaml.safe_load(m.group(1) or "") or {}
            if not isinstance(fm, dict):
                fm, err = {}, "frontmatter is not a key: value mapping"
        except yaml.YAMLError as e:
            mark = getattr(e, "problem_mark", None)
            err = f"line {mark.line + 2}" if mark else "unparseable"  # +2: the opening --- and 0-based
            err += f": {getattr(e, 'problem', '') or 'invalid YAML'}"
    return text, fm, err, body


def fm_tags(fm):
    t = fm.get("tags") or []
    if isinstance(t, str):
        t = re.split(r"[,\s]+", t)
    return [str(x).lstrip("#") for x in t if x]


class Resolver:
    """Resolve a link target the way Obsidian does: case-insensitive, by name, or by path suffix."""

    def __init__(self, files):
        self.by_name, self.paths = collections.defaultdict(list), []
        for rel in files:
            low = rel.lower()
            self.paths.append(low)
            name = low.rsplit("/", 1)[-1]
            self.by_name[name].append(rel)
            if name.endswith(".md"):
                self.by_name[name[:-3]].append(rel)

    def __call__(self, target):
        t = target.strip().lower().lstrip("/")
        if "/" not in t:
            hits = self.by_name.get(t) or self.by_name.get(t + ".md")
            return hits[0] if hits else None
        for cand in (t, t + ".md"):
            for p in self.paths:
                if p == cand or p.endswith("/" + cand):
                    return p
        return None


def link_targets(text):
    for raw in WIKI.findall(text):
        t = re.split(r"[|#^]", raw, maxsplit=1)[0].strip()
        if t and "://" not in t:
            yield t, True
    for raw in MDLINK.findall(text):
        if "://" in raw or raw.startswith(("#", "mailto:")):
            continue
        t = urllib.parse.unquote(raw.split("#", 1)[0])
        if t:
            yield t, False


# --- the checks ------------------------------------------------------------------------------

def scan(cfg, baseline):
    all_files = [rel for rel in (p.relative_to(VAULT).as_posix() for p in VAULT.rglob("*") if p.is_file())
                 if not any(n in "/" + rel for n in NEVER)]
    resolve = Resolver(all_files)
    periodic = re.compile(cfg["periodic"])
    findings, inbound, tags, new_baseline, sizes = [], collections.Counter(), collections.defaultdict(collections.Counter), {}, {}
    notes = [r for r in all_files if r.endswith(".md")]
    scanned = [r for r in notes if not matches(r, cfg["exclude"])]

    for rel in notes:
        text, fm, err, body = read_note(VAULT / rel)
        own = rel in scanned
        clean = strip_code(text)
        for target, wiki in link_targets(clean):
            hit = resolve(target) if wiki else resolve(os.path.normpath(os.path.join(os.path.dirname(rel), target)))
            if not hit and not wiki:
                hit = resolve(target)
            if hit:
                if hit.lower() != rel.lower():
                    inbound[hit.lower()] += 1
            elif wiki and own:
                findings.append(("broken-periodic" if periodic.search(target) else "broken", rel, target))
        if not own:
            continue
        skip = matches(rel, cfg["skip"])
        sizes[rel] = len(body)
        if err:
            findings.append(("yaml", rel, err))
        for t in fm_tags(fm) + TAG.findall(WIKI.sub("", strip_code(body))):  # [[#Heading]] is an anchor, not a tag
            tags[t.rstrip("/")][rel] += 1
        desc = fm.get("description")
        if not skip and not err and not (isinstance(desc, str) and desc.strip()):
            findings.append(("nodesc", rel, ""))
        if not skip and isinstance(desc, str) and desc.strip():
            words = len(body.split())
            heads = sorted(set(HEAD.findall(strip_code(body))))
            dh = hashlib.sha1(desc.strip().encode()).hexdigest()[:12]
            old = baseline.get(rel)
            if old and old[0] == dh:
                new_baseline[rel] = old
                gone, added = set(old[2]) - set(heads), set(heads) - set(old[2])
                grown = abs(words - old[1]) >= max(50, 0.3 * old[1])
                if grown or len(gone) + len(added) >= 2:
                    why = f"{old[1]}→{words} words" if grown else f"{len(added)} heading(s) added, {len(gone)} removed"
                    findings.append(("stale", rel, why))
            else:
                new_baseline[rel] = [dh, words, heads]

    for rel in scanned:
        if not matches(rel, cfg["skip"]) and not inbound.get(rel.lower()):
            findings.append(("orphan", rel, ""))

    groups = collections.defaultdict(list)
    for t in tags:
        groups[re.sub(r"[-_\s]+", "_", t.lower())].append(t)
    for variants in groups.values():
        if len(variants) > 1:
            ranked = sorted(variants, key=lambda v: -sum(tags[v].values()))
            for v in ranked[1:]:  # the most-used spelling is the reference; the others are findings
                where = sorted(tags[v])[:3]
                findings.append(("tag", "; ".join(where), f"#{v} ({sum(tags[v].values())}×) vs #{ranked[0]} "
                                 f"({sum(tags[ranked[0]].values())}×)"))

    pool = [r for r in scanned if not matches(r, cfg["skip"])]
    findings += duplicates(pool, float(cfg["dup_cosine"]))
    return list(dict.fromkeys(findings)), new_baseline, sizes  # a link twice in one note is one finding


def duplicates(pool, threshold):
    out, seen = [], set()
    stems = collections.defaultdict(list)
    for rel in pool:
        stems[Path(rel).stem.lower()].append(rel)
    for stem, rels in stems.items():  # the same name in two folders, or Obsidian's "Note 1" / "Note_v2" copy
        base = COPY.sub("", stem)
        group = sorted(set(rels + (stems.get(base, []) if base != stem else [])))
        if len(group) > 1:
            pair = tuple(group[:2])
            if pair not in seen:
                seen.add(pair)
                out.append(("dup", pair[0], f"same name as {pair[1]}"))
    if not SEARCH_DB.exists():
        return out
    try:
        import numpy as np, sqlite_vec
        db = sqlite3.connect(f"file:{SEARCH_DB}?mode=ro", uri=True)
        db.enable_load_extension(True)
        sqlite_vec.load(db)
        rows = db.execute("select c.path, v.embedding from chunks c join vec v on v.rowid = c.id "
                          "where c.kind = 'note'").fetchall()
    except Exception as e:  # no vectors (embedder = none) or an older schema: skip, and say so
        print(f"vault-health: duplicate check by meaning skipped ({type(e).__name__})", file=sys.stderr)
        return out
    want = set(pool)
    rows = [(p, e) for p, e in rows if p in want]
    if len(rows) < 2:
        return out
    paths = [p for p, _ in rows]
    m = np.stack([np.frombuffer(e, dtype=np.float32) for _, e in rows])
    m /= np.linalg.norm(m, axis=1, keepdims=True)
    sims = np.triu(m @ m.T, 1)
    for i, j in zip(*np.nonzero(sims >= threshold)):
        pair = tuple(sorted((paths[i], paths[j])))
        if pair not in seen:
            seen.add(pair)
            out.append(("dup", pair[0], f"{sims[i, j]:.2f} similar to {pair[1]}"))
    return out


# --- tmp housekeeping ------------------------------------------------------------------------
# _AI/tmp/ is scratch (its README: "delete freely"), but nothing deleted it, so it grew to
# ~200 entries before the first cleanup (2026-11-05). This sorts it into keep / stale / ask by
# name and age; `tmp --trash` moves the stale ones to the macOS Trash, never `rm`. A tmp/ at the
# vault root is always flagged: something resolved "tmp/" against the vault instead of _AI/.

TMP_DEFAULTS = {
    "tmp_keep": "README.md, .DS_Store, health, touches.log, vault-search-*.log, *.parked, "
                "*-project-stub.md, coach-snapshot.md, polish",
    "tmp_state": "writes-*.log, denies-*.log, collision-acks-*.log, nudged-search-*, .retro-asked-*, .filelog-blocked-*",
    "tmp_scratch": "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]*, *snapshot*, *backup*, *before*, *export*, "
                   "*migration-prompt*, *.bak, *.diff, *.patch, *digest*, *phone-copies*",
    "tmp_sensitive": "*psychotherap*, *therap*, *financ*, *-export-*",
    "tmp_days": "7", "tmp_state_days": "14", "tmp_sensitive_days": "2",
}
TRASH = os.environ.get("AIOS_TRASH") or "/usr/bin/trash"


def _newest(p):  # a folder is as old as its newest file: one still in use is not stale
    try:
        m = p.lstat().st_mtime
        if p.is_dir() and not p.is_symlink():
            for q in p.rglob("*"):
                m = max(m, q.lstat().st_mtime)
        return m
    except OSError:
        return 0


def _size(p):
    try:
        return sum(q.lstat().st_size for q in p.rglob("*")) if p.is_dir() else p.lstat().st_size
    except OSError:
        return 0


def tmp_scan(cfg):
    """[(where, path, kind, reason, days, size)], kind in keep / stale / ask / young."""
    c = {k: cfg.get(k, v) for k, v in TMP_DEFAULTS.items()}
    globs = {k: [g.strip() for g in c[k].split(",") if g.strip()] for k in ("tmp_keep", "tmp_state", "tmp_scratch", "tmp_sensitive")}
    now = datetime.datetime.now().timestamp()
    rows = []
    for where, root in (("_AI/tmp", AI / "tmp"), ("tmp", VAULT / "tmp")):
        if not root.is_dir():
            continue
        for p in sorted(root.iterdir()):
            n, days, size = p.name, int((now - _newest(p)) // 86400), _size(p)
            if where == "tmp":  # nothing belongs at the vault root: all of it is a stray backup
                kind, why, limit = "stale", "vault-root tmp/", int(c["tmp_days"])
            elif any(fnmatch.fnmatchcase(n, g) for g in globs["tmp_keep"]):
                rows.append((where, n, "keep", "on the keep list", days, size)); continue
            elif any(fnmatch.fnmatchcase(n, g) for g in globs["tmp_state"]):
                kind, why, limit = "stale", "hook state", int(c["tmp_state_days"])
            elif any(fnmatch.fnmatchcase(n, g) for g in globs["tmp_sensitive"]):
                kind, why, limit = "stale", "sensitive", int(c["tmp_sensitive_days"])
            elif any(fnmatch.fnmatchcase(n, g) for g in globs["tmp_scratch"]):
                kind, why, limit = "stale", "backup or scratch", int(c["tmp_days"])
            else:
                kind, why, limit = "ask", "unclassified", int(c["tmp_days"])
            rows.append((where, n, kind if days >= limit else "young", why, days, size))
    return rows


def _mb(b):
    return f"{b / 1e6:.1f} MB" if b >= 1e5 else f"{b // 1000} KB"


def tmp_line(rows):
    stale = [r for r in rows if r[2] == "stale"]
    ask = [r for r in rows if r[2] == "ask"]
    root = [r for r in rows if r[0] == "tmp"]
    if not (stale or ask or root):
        return "tmp: clean"
    parts = [f"{len(stale)} stale ({_mb(sum(r[5] for r in stale))})"] if stale else []
    if ask:
        parts.append(f"{len(ask)} to classify")
    if root:
        parts.append(f"vault-root tmp/ present ({len(root)}) ⚠")
    return "tmp: " + " · ".join(parts) + " — `vault-health.py tmp`"


def tmp_report(rows, show_young=False):
    today = datetime.date.today().isoformat()
    out = [f"# tmp housekeeping {today}", "", tmp_line(rows), ""]
    for kind, title, fix in (
            ("stale", "Stale", "`vault-health.py tmp --trash` moves these to the macOS Trash, on the user's word"),
            ("ask", "To classify", "the user's call: trash, or add a pattern to `tmp_keep` / `tmp_scratch`"),
            ("young", "Not old enough yet", None)):
        items = [r for r in rows if r[2] == kind]
        if not items:
            continue
        out += [f"## {title}: {len(items)}"] + ([f"*Fix:* {fix}"] if fix else []) + [""]
        if kind == "young" and not show_young:
            out += [f"{len(items)} item(s) younger than their threshold; `tmp --all` lists them.", ""]
            continue
        groups = collections.defaultdict(list)
        for r in items:
            groups[(r[0], r[3])].append(r)
        for (where, why), rs in sorted(groups.items(), key=lambda g: (g[0][1] != "sensitive", g[0])):
            out.append(f"- **{why}** in `{where}/`: {len(rs)}, {_mb(sum(r[5] for r in rs))}")
            out += [f"  - `{r[1]}` — {r[4]} d" for r in rs[:CAP]]
            if len(rs) > CAP:
                out.append(f"  - … and {len(rs) - CAP} more")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def tmp_trash(rows):
    targets = [(AI / "tmp" if r[0] == "_AI/tmp" else VAULT / "tmp") / r[1] for r in rows if r[2] == "stale"]
    if not targets:
        return "tmp: nothing stale to trash"
    if not os.access(TRASH, os.X_OK):  # never fall back to rm: nothing recovers it
        sys.exit(f"vault-health: {TRASH} not found; trash these by hand, never rm")
    import subprocess
    for i in range(0, len(targets), 100):
        subprocess.run([TRASH, *map(str, targets[i:i + 100])], check=True)
    root = VAULT / "tmp"
    if root.is_dir() and not any(p.name != ".DS_Store" for p in root.iterdir()):
        subprocess.run([TRASH, str(root)], check=True)  # the stray folder itself goes too
    return f"tmp: {len(targets)} item(s) moved to the Trash"


# --- state and report ------------------------------------------------------------------------

def key(f):
    return "\x1f".join(f)


def load_state():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


def report(findings, state, show_all, sizes):
    prev = set(state.get("findings", []))
    first = not state
    by = collections.defaultdict(list)
    for f in findings:
        by[f[0]].append(f)
    new = [f for f in findings if key(f) not in prev and f[0] != "broken-periodic"]
    today = datetime.date.today().isoformat()
    totals = " · ".join(f"{k} {len(by[k])}" for k in TITLES if by[k])
    if not new and not show_all:
        return f"Vault health {today}: nothing new since you last looked ({state.get('saved_at', '?')}) ({totals or 'all clear'}).\n"
    out = [f"# Vault health {today}", ""]
    if first:
        out += ["First run: everything counts as new, and stale descriptions start from today's baseline.", ""]
    else:
        out += [f"{len(new)} new since you last looked ({state.get('saved_at', '?')}). Totals: {totals}.", ""]
    for kind, title in TITLES.items():
        items = by[kind] if show_all else [f for f in new if f[0] == kind]
        if not items:
            continue
        out.append(f"## {title}: {len(items)}{'' if show_all else ' new'} (of {len(by[kind])})")
        out.append(f"*Fix:* {FIXERS[kind]}")
        out.append("")
        if kind == "orphan" and first and not show_all:  # the backlog is a count; only orphans first seen later are listed
            out += [f"Not listed on a first run; `report --all` lists them.", ""]
            continue
        if kind == "orphan" and len(items) > CAP:
            per = collections.Counter(f[1].split("/", 1)[0] if "/" in f[1] else "(root)" for f in items)
            out.append("By folder: " + ", ".join(f"{k} {v}" for k, v in per.most_common()))
            out.append("Largest:")
            items = sorted(items, key=lambda f: -sizes.get(f[1], 0))
        rows = collections.Counter(f"- `{path}`" + (f" — {SECRETISH.sub('…', detail)}" if detail else "")
                                   for _, path, detail in items)  # masked ids can make distinct links read alike
        out += [row + (f" (×{n})" if n > 1 else "") for row, n in list(rows.items())[:CAP]]
        if len(rows) > CAP:
            out.append(f"- … and {len(rows) - CAP} more (`report --all` lists every finding, capped the same way)")
        out.append("")
    periodic = by["broken-periodic"]
    if periodic:
        out.append(f"Not counted: {len(periodic)} link(s) to date notes that were never created (expected).")
    return "\n".join(out).rstrip() + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("report")
    r.add_argument("--all", action="store_true", help="every finding, not only new ones")
    sub.add_parser("ack", help="mark the current findings as seen, and move the stale baseline")
    sub.add_parser("missing")
    t = sub.add_parser("tmp", help="housekeeping of _AI/tmp/ and a stray vault-root tmp/")
    t.add_argument("--all", action="store_true", help="also list items not old enough yet")
    t.add_argument("--trash", action="store_true", help="move the stale items to the macOS Trash")
    a = ap.parse_args()

    cfg = load_config()
    if a.cmd == "tmp":
        rows = tmp_scan(cfg)
        if a.trash:
            print(tmp_trash(rows))
        else:
            print(tmp_report(rows, a.all), end="")
        return
    state = load_state()
    findings, baseline, sizes = scan(cfg, state.get("baseline", {}))
    if a.cmd == "missing":
        print("".join(f[1] + "\n" for f in findings if f[0] == "nodesc"), end="")
        return
    if a.cmd == "report":
        print(report(findings, state, a.all, sizes), end="")
        print(tmp_line(tmp_scan(cfg)))
        return
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"saved_at": datetime.date.today().isoformat(),
                               "findings": sorted(key(f) for f in findings),
                               "baseline": baseline}, ensure_ascii=False))
    tmp.replace(STATE)
    print(f"vault-health: {len(findings)} finding(s) marked as seen")


if __name__ == "__main__":
    main()
