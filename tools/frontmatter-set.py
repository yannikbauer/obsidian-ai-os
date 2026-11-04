#!/usr/bin/env python3
"""Set one frontmatter key on a list of vault notes, and touch nothing else.

The bulk-write route for the frontmatter passes (roadmap #11). A shell write is
invisible to the hooks (CLAUDE.md, "route note writes where they can see them"), so
this script enforces their rules itself, and goes further than they can:

  - refuses paths matched by config/readonly-zones.local, and frontmatter holding a
    Templater block
  - snapshots each file to tmp/ before writing
  - proves the write: everything after the frontmatter is byte-identical, and the
    frontmatter differs only by the one key
  - appends one line per changed note to history/file-log.md

An existing different value is left alone unless --replace. Two input modes:

  one key, one value, many notes (vault-relative paths on stdin):
    frontmatter-set.py --key sensitivity --value private --reason "sweep" < paths
  per-note values from propose.py output (rows with "skip" or "flag" are left out):
    frontmatter-set.py --from-jsonl run.jsonl --keys description,language --reason "polish"
"""
import argparse, datetime, fnmatch, json, os, re, shutil, sys

AI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = os.environ.get("AIOS_VAULT_DIR") or os.path.dirname(AI)
FM = re.compile(r"\A---\n(.*?\n)?---\n", re.S)


def zones():
    f = os.path.join(AI, "config", "readonly-zones.local")
    if not os.path.exists(f):
        return ["*/Archive/*", "*/Attachments/*"]
    return [l.strip() for l in open(f) if l.strip() and not l.startswith("#")]


def scalar(v):
    """A YAML scalar for v: plain when that is safe, else double-quoted (JSON is valid YAML)."""
    if re.fullmatch(r"[A-Za-z0-9][\w ,.()/'+-]*", v) and not v.endswith(" "):
        return v
    return json.dumps(v, ensure_ascii=False)


def unscalar(s):
    s = s.strip()
    if s.startswith('"'):
        try:
            return json.loads(s)
        except ValueError:
            pass
    return s.strip("'\"")


def set_key(text, key, value, replace):
    """Return (new_text, status). status: added | replaced | same | kept | refused."""
    line = f"{key}: {scalar(value)}\n"
    m = FM.match(text)
    if not m:
        if text.startswith("---"):  # frontmatter we cannot parse (CRLF, unclosed): hands off
            return text, "refused"
        return f"---\n{line}---\n{text}", "added"
    fm = m.group(1) or ""
    if "<%" in fm:
        return text, "refused"
    cur = re.search(rf"^{re.escape(key)}:[ \t]*(.*)\n", fm, re.M)
    if cur:
        if unscalar(cur.group(1)) == value:
            return text, "same"
        if not replace:
            return text, "kept"
        fm = fm[:cur.start()] + line + fm[cur.end():]
        return f"---\n{fm}---\n" + text[m.end():], "replaced"
    return f"---\n{fm}{line}---\n" + text[m.end():], "added"


def verify(old, new, keys):
    """Everything but the given keys must be unchanged."""
    def split(t):
        m = FM.match(t)
        fm, body = (m.group(1) or "", t[m.end():]) if m else ("", t)
        rest = [l for l in fm.splitlines() if not any(l.startswith(f"{k}:") for k in keys)]
        return rest, body
    return split(old) == split(new)


def jobs(a):
    """Yield (rel, {key: value}) from stdin paths or from a propose.py JSONL file."""
    if a.from_jsonl:
        keys = a.keys.split(",")
        for l in open(a.from_jsonl, encoding="utf-8"):
            r = json.loads(l) if l.strip() else {}
            if r and not (r.get("error") or r.get("flag") or r.get("skip")):
                vals = {k: r[k] for k in keys if r.get(k)}
                if vals:
                    yield r["path"], vals
    else:
        for rel in (l.strip() for l in sys.stdin):
            if rel:
                yield rel, {a.key: a.value}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key")
    ap.add_argument("--value")
    ap.add_argument("--from-jsonl")
    ap.add_argument("--keys", default="description,language")
    ap.add_argument("--reason", required=True)
    ap.add_argument("--replace", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if not a.from_jsonl and not (a.key and a.value):
        sys.exit("give --key and --value, or --from-jsonl")

    stamp = datetime.datetime.now()
    snap = os.path.join(AI, "tmp", f"fm-snapshot-{stamp:%Y-%m-%d-%H%M%S}")
    ro, counts, log = zones(), {}, []
    for rel, vals in jobs(a):
        if any(not re.fullmatch(r"[a-z_]+", k) or "\n" in str(v) for k, v in vals.items()):
            status = "bad-value"
        else:
            p = os.path.normpath(os.path.join(VAULT, rel))
            status = None
            if not p.startswith(VAULT + os.sep) or not p.endswith(".md") or not os.path.isfile(p):
                status = "missing"
            elif any(fnmatch.fnmatch(p, z) for z in ro):
                status = "readonly"
        if status is None:
            old = open(p, encoding="utf-8").read()
            new, done = old, []
            for k, v in vals.items():
                new, s = set_key(new, k, str(v), a.replace)
                if s in ("added", "replaced"):
                    done.append(k)
                elif s == "refused":
                    new, done = old, []
                    status = "refused"
                    break
            status = status or ("added" if done else "same")
            if done:
                if not verify(old, new, done):
                    status = "verify-failed"
                elif not a.dry_run:
                    dst = os.path.join(snap, rel)
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    shutil.copy2(p, dst)
                    tmp = p + ".fmset-tmp"
                    with open(tmp, "w", encoding="utf-8") as o:
                        o.write(new)
                    os.replace(tmp, p)
                    what = ", ".join(done) if a.from_jsonl else f"{a.key}: {a.value}"
                    log.append(f"- {stamp:%Y-%m-%d %H:%M}  [edit]  {rel}  — frontmatter {what} ({a.reason})\n")
        counts[status] = counts.get(status, 0) + 1
        if status not in ("added", "replaced", "same"):
            print(f"{status}\t{rel}")
    if log:
        with open(os.path.join(AI, "history", "file-log.md"), "a", encoding="utf-8") as o:
            o.writelines(log)
        print(f"snapshot: {snap}")
    print(("dry run: " if a.dry_run else "") + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


if __name__ == "__main__":
    main()
