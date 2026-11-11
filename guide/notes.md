# Notes: metadata, search and maintenance

How the OS finds, labels and looks after the notes in your vault. [Back to the README](../README.md)

## Note metadata: descriptions and sensitivity

Two frontmatter fields carry most of the routing. Both are conventions in
`maps/vault-map.md`, so the `obsidian` skill applies them whenever it creates or edits a note.

**`description`**: one plain-English sentence of 15–30 words, even for a note in another
language, saying what the note is *for* and what it holds. An agent or the search index
can decide whether to open a note from this line alone, which is the token saving. It is
not a summary. Notes whose filenames already route them (weekly notes, transcripts) go
without one. A sensitive note gets a neutral description that names its kind and never its
content: *"Private log on health."*

**`sensitivity`**: `private` or `secret`; no field means normal. **It labels; it doesn't
hide.** Hiding private notes would also make them unsearchable, and they are often exactly
what you want to find. So a labelled note stays indexed and readable, and:

- `guard-sensitive-read.sh` **asks** before a Read of it; it never denies. Opt a session in
  with `AIOS_INCLUDE_PRIVATE=1`.
- bulk jobs send it to a **local** model only, enforced in the script (see below).
- the search index returns it as a pointer (path, title, description), not text. Credential
  and ID-number lines are redacted in **every** note before indexing; `secret` (credentials,
  account numbers) also loses long tokens, and stays a pointer even for an opted-in session.

Whole folders get a label in `config/sensitivity.local` (`Periodic notes/* = private`) instead
of note by note; the stricter of folder and frontmatter label wins. **Known gap:** Grep and
shell reads bypass the gate.

### Backfilling existing notes

Three scripts, run from `_AI/`, with paths relative to the vault. Proposing never writes a
note, and applying never runs without a dry run first.

```bash
# 1. notes without a description
mkdir -p tmp/polish && (cd .. && grep -L '^description:' _NOTES/*.md) > tmp/polish/todo.txt
# 2. propose: Haiku for normal notes; labelled notes switch to the local model by themselves
python3 tools/frontmatter-polish/propose.py --backend claude --model haiku \
  --out tmp/polish/run.jsonl < tmp/polish/todo.txt
# 3. review side by side (several runs become columns)
python3 tools/frontmatter-polish/review.py tmp/polish/run.jsonl > tmp/polish/review.md
# 4. apply only these keys: dry run, then for real
python3 tools/frontmatter-set.py --from-jsonl tmp/polish/run.jsonl \
  --keys description,language --reason "frontmatter polish" --dry-run
```

- **`propose.py`** has two backends: `ollama` (default, needs a local model such as
  `qwen3.5:9b`) and `claude` (the `claude` CLI in print mode, on your subscription login).
  A note labelled private or secret always goes to the local model (`POLISH_LOCAL_MODEL`),
  and it gets a template description built from fixed word lists. In the pilot, a
  free-text prompt leaked diary content even though the prompt forbade it. Output is
  resumable JSONL; descriptions that break the length or one-sentence rule are retried
  twice, then flagged. Filename prefixes listed in `vault-map.md` (`XY_` = an employer)
  go into the prompt, because a model will otherwise guess.
- **`frontmatter-set.py`** is the only writer. It quotes YAML-unsafe values, refuses
  read-only zones and Templater frontmatter, checks the body is byte-identical afterwards,
  snapshots every note to `tmp/`, and logs each change to `history/file-log.md`. Re-running
  is a no-op. It also sets one key on many notes:
  `frontmatter-set.py --key sensitivity --value private --reason "…" < paths`.

**Cost and speed, from one real run** (843 notes on an M2 MacBook Air): Haiku took about
4 s per note, so 742 notes in about 12 minutes on four parallel shards. The local 9B model
took about 46 s per note for the 101 private ones. Two things to know: a plain `claude -p`
started inside the vault loads the whole OS, about 45k tokens per call, so the script runs it
with no tools, settings or MCP from your home directory, at under 1k tokens. And a stale
`ANTHROPIC_API_KEY` in your environment overrides the subscription login, so the script
drops it.

**Which notes are done?** The frontmatter is its own index: a note without `description`
is still to do, which is a grep or an Obsidian Bases filter away. No separate tracking file.

## Vault search

`tools/vault-search.py` answers "which note was about…" by meaning, not by string. A
question in English finds a German note, and a paraphrase finds a note that never uses
the words. It is one Python file with three commands:

```bash
tools/vault-search.py index            # incremental: only notes whose content changed
tools/vault-search.py search "train discount card" [-k 8] [--json]
tools/vault-search.py status           # notes, chunks, model, last update
```

**How it works.** Notes up to about 550 tokens become one chunk. Longer ones are split at
their H1–H3 headings, then at paragraphs, to about 450 tokens with a small overlap. Every
chunk is prefixed with `title — description · tags › heading path`, so a fragment like
"decided against it" still carries its context. A local model (`bge-m3` via Ollama,
multilingual, 1024 dimensions) embeds the chunks. Vectors (`sqlite-vec`, exact cosine) and
a keyword index (SQLite FTS5, BM25) live in one file. A query runs both, fuses the rankings
with weighted Reciprocal Rank Fusion, and returns notes, each with its best section.
Vectors catch meaning, and keywords catch names and IDs that vectors blur.

**Did it earn its place?** It was built only after an eval against the grep baseline: 24
known-item questions, with each target note picked *before* its question was written.
The right note landed in the top five for 18 questions, against 14 for grep plus filename
matching. The gain is in paraphrase, cross-language and flooded queries ("money I lent"
matches 176 files). Note that the set is small, one person wrote both the questions and
the grep terms, and grep got a single try where an agent would retry.

**Privacy.** Embedding is local by default, so no note leaves the machine. Sensitivity
labels travel with every chunk: private and secret hits come back as pointers, and text
that looks like credentials or ID numbers is redacted before storage and again on output.
Third-party folders (`external` in the config) are flagged so their snippets are read as
data, never instructions.

**How the OS uses it.** One rule in `CLAUDE.md` and a section in the `obsidian` skill send
meaning-questions to the search first. Grep stays the tool for exact strings. A hook adds
a one-line reminder the first time a session greps the notes, and a session-start hook
refreshes the index in the background, which usually takes seconds.

**Setting it up.** Needs [`uv`](https://docs.astral.sh/uv/) (it runs the script and
fetches `sqlite-vec`; a Python built without SQLite extension support cannot load it) and
[Ollama](https://ollama.com):

```bash
ollama pull bge-m3
tools/vault-search.py index            # first build: 30–90 min in the background on a laptop
tools/vault-search.py search "something you wrote about once"
```

Folders to skip, folders to flag as external, and the model live in
`config/search-index.local` (`install.sh` creates it, all comments; defaults skip `_AI/`,
archives, attachments and templates, and flag nothing as external). With `embedder = none` the index is keywords only: no model needed, but no
paraphrase either. Run the script directly, never as `python3 vault-search.py`.

## Vault maintenance

A notes vault drifts. Links break when notes are renamed, copies pile up, tags split into
spellings, and a note's one-line description stops matching what the note became. Vault
maintenance keeps that in check in three layers, and only the last one needs you.

| Layer | What it does | When |
|---|---|---|
| **Prevent** | The `obsidian` skill gives every note it writes a `description`, a sensitivity label where one applies, and quoted YAML values | on every write, automatically |
| **Detect** | A read-only report of what has drifted | every Monday, unattended |
| **Repair** | Fixes, proposed first and applied on your word | when you say so |

It is the `vault-maintenance` skill. Ask for it as "vault maintenance", "maintenance",
"health check" or "check the vault".

### What the report checks

Seven checks, and no model is involved in any of them:

- frontmatter that doesn't parse as YAML
- notes missing a `description`
- stale descriptions: the description hasn't changed, but the body has moved a lot
- broken wikilinks
- orphan notes, which nothing links to
- tags that differ only in case or separator
- likely duplicates, found two ways: Obsidian's "Note 1" copies, and note vectors from the
  search index that sit above a cosine threshold

Each section of the report names its fixer. The report carries paths and link targets only,
never note text, so it is safe to show for private notes. Links to date notes that were never
created (weekly navigation) are counted, not listed.

### How it runs, week to week

1. **Monday 07:30, without you.** A scheduled task runs `tools/vault-health-weekly.sh`. It
   writes the report to `tmp/health/YYYY-MM-DD.md` and proposes descriptions for notes still
   missing one. Normal notes go to Haiku. Notes labelled private or secret go to the local
   model, enforced in `propose.py`. It never writes a note. It needs the machine awake and the
   app running; if they aren't, the task runs the next time the app opens.
2. **In the Monday review.** "Plan my week" runs the report fresh, shows you one line ("nothing
   new", or the counts), and marks those findings as seen (`ack`). If descriptions were
   proposed, it offers the review sheet; on "apply", `frontmatter-set.py --from-jsonl` writes
   them, with a snapshot and a log line per note.
3. **Anything else is your call, one at a time:** a broken link, a duplicate to merge, a tag
   spelling.

**You don't need to remember any of this, only to do the Monday review.** A finding stays
"new" until a report has actually been shown to you. Only `ack` moves that line, and the
unattended run never acks, so skipped weeks pile up instead of disappearing.

### Recommended rhythm

- **Weekly:** a one-minute glance in the Monday review, and "apply" if descriptions are waiting.
- **Monthly, optional, about 20 minutes:** `report --all`, then clear a handful of broken links
  or duplicates.
- **Leave the orphan backlog alone.** Search finds unlinked notes anyway. An orphan is worth a
  look when it's *new*, because that is a note you just forgot to link.

### Commands

```bash
tools/vault-health.py report          # what's new since you last looked
tools/vault-health.py report --all    # every finding
tools/vault-health.py ack             # mark the current findings as seen (after showing a report)
tools/vault-health.py missing         # notes without a description, one path per line
```

**How "new" and "stale" work.** `databases/vault-health.json` holds the findings at the last
`ack` and, per note, a hash of its description plus the body's word count and headings. A
description is stale when it hasn't changed but the body has moved: at least 30% more or fewer
words (minimum 50), or two headings added or removed. The search index can't do this, because
it hashes the whole file and can't tell a body edit from a frontmatter edit. Links are resolved
from disk the way Obsidian resolves them, so the check works with Obsidian closed. It takes
about 15 s on 1,100 notes. Proposals accumulate in `tmp/health/proposals.jsonl`, so a note is
proposed once, and a proposal that failed (Ollama down) is retried the next week. Settings live
in `config/vault-health.local`.
