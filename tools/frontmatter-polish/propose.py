#!/usr/bin/env python3
"""Propose frontmatter for vault notes: description, type, language (roadmap #11).

Reads notes, asks a model, and writes one JSON line per note. It never writes a note:
applying is a separate, reviewed step. Resumable: notes already in --out are skipped.

Backends:
  ollama  (default) local model, e.g. qwen3.5:9b-32k; nothing leaves the machine
  claude  the `claude` CLI in print mode, e.g. haiku; faster, but it is a cloud model

The privacy rule is enforced here, not left to the caller: a note labelled private or
secret (frontmatter or config/sensitivity.local) always goes to the local model, even
with --backend claude, unless --allow-private is given.

  propose.py --model qwen3.5:9b-32k --out tmp/polish/qwen.jsonl < paths
"""
import argparse, fnmatch, json, os, re, subprocess, sys, time, urllib.request

AI = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VAULT = os.environ.get("AIOS_VAULT_DIR") or os.path.dirname(AI)
OLLAMA = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
LOCAL_FALLBACK = os.environ.get("POLISH_LOCAL_MODEL", "qwen3.5:9b-32k")
FM = re.compile(r"\A---\n(.*?\n)?---\n", re.S)
TYPES = ["reference", "howto", "project", "meeting", "person", "log", "reflection",
         "plan", "idea", "moc", "other"]
MAX_CHARS = 6000


def prefixes():
    """Filename-prefix glossary from the vault map, so an employer prefix is not read
    as, say, a country code."""
    path = os.path.join(AI, "maps", "vault-map.md")
    if not os.path.exists(path):
        return ""
    text = open(path, encoding="utf-8").read()
    lines = re.findall(r"^\s*- `([^`]+)`\s+—\s+(.+)$", text, re.M)
    return "".join(f"- {p}: {d.strip()}\n" for p, d in lines)


GLOSSARY = prefixes()

SCHEMA = {
    "type": "object",
    "properties": {
        "description": {"type": "string"},
        "type": {"type": "string", "enum": TYPES},
        "language": {"type": "string", "enum": ["en", "de", "mixed"]},
    },
    "required": ["description", "type", "language"],
}

PROMPT = """You write frontmatter for one note in a personal Obsidian knowledge base.

Return JSON with:
- description (unless told otherwise below): ONE sentence in plain English (even if the note is German), 15-30 words, no links or markdown. Say what the note is FOR and what kind of information it holds, so a search system can decide whether to open it. Do not summarise its content in detail. Start with the kind of note ("Notes on...", "Checklist for...", "Log of...", "Reference for..."), not with "This note".
- type: one of {types}. log = dated entries over time; reference = facts to look up; howto = steps or advice; meeting = notes from one conversation or call; person = about one person; moc = mainly a list of links to other notes.
- language: en, de or mixed (the note's own language).
{private_rule}{glossary}
Note title: {title}
Existing frontmatter keys: {keys}
Headings: {headings}

Note text (may be cut off):
<<<
{body}
>>>"""

# Private notes never get a free-text description from the model: a prompt rule alone
# leaked content in the pilot's first smoke test (Diary, qwen3.5:9b). The model picks
# from two fixed lists instead, and the description is assembled from them, so it
# cannot carry anything the lists do not contain.
KINDS = ["diary", "journal", "notes", "log", "records", "plan", "letter",
         "conversation", "guide", "research"]
AREAS = ["personal life", "health", "mental health", "relationships", "family",
         "finances", "substances", "work", "career", "legal and admin", "accounts and logins"]
PRIVATE_SCHEMA = {
    "type": "object",
    "properties": {
        "kind": {"type": "string", "enum": KINDS},
        "area": {"type": "string", "enum": AREAS},
        "type": {"type": "string", "enum": TYPES},
        "language": {"type": "string", "enum": ["en", "de", "mixed"]},
    },
    "required": ["kind", "area", "type", "language"],
}
PRIVATE_RULE = """
This note is PRIVATE. Instead of a description, return only:
- kind: one of {kinds}
- area: one of {areas}
plus type and language as above.
"""


def neutral(ans):
    """Assemble the description a private note gets: only words from the fixed lists."""
    kind, area = ans.pop("kind", "notes"), ans.pop("area", "personal life")
    ans["description"] = f"Private {kind} on {area}."
    return ans


def label_of(rel, fm):
    rank = {"secret": 2, "private": 1}
    best = ""
    rules = os.path.join(AI, "config", "sensitivity.local")
    if os.path.exists(rules):
        for line in open(rules, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            pat, lab = (x.strip() for x in line.split("=", 1))
            if fnmatch.fnmatch(rel, pat.replace("**", "*")) and rank.get(lab, 0) > rank.get(best, 0):
                best = lab
    m = re.search(r"^sensitivity:[ \t]*['\"]?([a-z]+)", fm, re.M)
    if m and rank.get(m.group(1), 0) > rank.get(best, 0):
        best = m.group(1)
    return best


def build(rel):
    text = open(os.path.join(VAULT, rel), encoding="utf-8", errors="ignore").read()
    m = FM.match(text)
    fm, body = (m.group(1) or "", text[m.end():]) if m else ("", text)
    keys = re.findall(r"^([A-Za-z_][\w -]*):", fm, re.M)
    heads = re.findall(r"^#{1,3} +(.+)$", body, re.M)[:25]
    label = label_of(rel, fm)
    prompt = PROMPT.format(
        types=", ".join(TYPES),
        private_rule=PRIVATE_RULE.format(kinds=", ".join(KINDS), areas=", ".join(AREAS)) if label else "",
        kinds=", ".join(KINDS), areas=", ".join(AREAS),
        glossary=f"\nFilename prefixes in this vault:\n{GLOSSARY}" if GLOSSARY else "",
        title=os.path.splitext(os.path.basename(rel))[0], keys=", ".join(keys) or "none",
        headings=" | ".join(heads) or "none", body=body[:MAX_CHARS])
    return prompt, label, len(text)


def ask_ollama(model, prompt, schema):
    req = {"model": model, "stream": False, "think": False, "format": schema,
           "options": {"temperature": 0.2, "num_ctx": 8192},
           "messages": [{"role": "user", "content": prompt}]}
    r = urllib.request.Request(OLLAMA + "/api/chat", json.dumps(req).encode(),
                               {"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=600) as resp:
        return json.loads(json.loads(resp.read())["message"]["content"])


def ask_claude(model, prompt, schema):
    # Lean on purpose: no tools, MCP, skills, settings or project CLAUDE.md. A default
    # `claude -p` from the vault loads the whole OS, about 45k tokens per call; this is
    # under 1k. cwd is outside the vault for the same reason.
    out = subprocess.run(
        ["claude", "-p", "--model", model, "--output-format", "json",
         "--json-schema", json.dumps(schema), "--tools", "", "--strict-mcp-config",
         "--disable-slash-commands", "--no-session-persistence", "--setting-sources", "",
         "--system-prompt", "You write frontmatter for notes. Answer only with the requested JSON."],
        input=prompt, capture_output=True, text=True, timeout=300, cwd=os.path.expanduser("~"),
        # An API key in the environment beats the subscription login, and a stale one
        # fails with 401; the backfill runs on the login.
        env={k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"})
    res = json.loads(out.stdout)
    if res.get("is_error"):
        raise RuntimeError(res.get("result", "claude error"))
    so = res.get("structured_output")
    return so if so else json.loads(re.search(r"\{.*\}", res["result"], re.S).group(0))


def problem(ans):
    """Why a free-text description fails the vault-map rules, or None."""
    d = ans.get("description", "").strip()
    words = len(d.split())
    if words < 8 or words > 35:
        return f"{words} words"
    if d.lower().startswith("this note"):
        return "starts with 'This note'"
    if d.count(". ") or "\n" in d:
        return "more than one sentence"
    return None


RETRY = "\n\nYour previous description was rejected ({why}). Write ONE sentence of 15-30 words, starting with the kind of note."


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", choices=["ollama", "claude"], default="ollama")
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--allow-private", action="store_true",
                    help="let private/secret notes go to a cloud backend")
    a = ap.parse_args()

    done = set()
    if os.path.exists(a.out):
        done = {json.loads(l)["path"] for l in open(a.out) if l.strip()}
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "a", encoding="utf-8") as o:
        for rel in (l.strip() for l in sys.stdin):
            if not rel or rel in done:
                continue
            prompt, label, size = build(rel)
            backend, model = a.backend, a.model
            if backend == "claude" and label and not a.allow_private:
                backend, model = "ollama", LOCAL_FALLBACK
            t0 = time.time()
            try:
                schema = PRIVATE_SCHEMA if label else SCHEMA
                ask = ask_claude if backend == "claude" else ask_ollama
                ans = ask(model, prompt, schema)
                if label:
                    ans = neutral(ans)
                else:
                    for _ in range(2):  # retry twice, then keep the answer flagged
                        why = problem(ans)
                        if not why:
                            break
                        ans = ask(model, prompt + RETRY.format(why=why), schema)
                    if problem(ans):
                        ans["flag"] = problem(ans)
                err = None
            except Exception as e:  # keep going; the row records the failure
                ans, err = {}, f"{type(e).__name__}: {e}"[:200]
            row = {"path": rel, "label": label, "bytes": size, "backend": backend,
                   "model": model, "secs": round(time.time() - t0, 1), **ans}
            if err:
                row["error"] = err
            o.write(json.dumps(row, ensure_ascii=False) + "\n")
            o.flush()
            print(f"{row['secs']:6.1f}s  {model:16} {rel}", file=sys.stderr)


if __name__ == "__main__":
    main()
