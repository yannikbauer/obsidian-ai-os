# AI OS

A personal AI operating system built on an Obsidian vault, driven by Claude Code. It gives
Claude a lasting picture of who you are, a map of your notes, and skills that work across
your notes and whichever task system, calendar and mail you connect: plan the week, digest
the inbox, log the day, keep the vault tidy. Every change to your notes, tasks or calendar
asks you first.

Designed to be **generic and shareable**: the framework contains no personal data. Your
identity (`me.md`), vault layout (`maps/`), and tool specifics (`integrations/`) are kept
separate and private.

This page is the overview. Each feature links to a guide in [`guide/`](guide/) with the
details.

## A week with it

Monday morning the newsletter and job digests are already in the vault, and the inbox holds
only the mails they kept for a reason. "Plan my week" reads the calendar, the task system, the
goals and the digests' deadlines, and proposes the week. Each morning a short spoken check-in
becomes a daily note with numbers in it. During a call, "what should I ask?" reads the meeting
transcript so far. On a walk, the same session answers from the phone, because the Mac at home
stays reachable. Every write to your notes, tasks or calendar waits for your yes, and the rules
that matter most are enforced by scripts, not by the model's good intentions.

## What's inside

**Notes.** Every note carries a one-line `description` and, where needed, a sensitivity label.
Search by meaning runs locally (an English question finds a German note), and a weekly
read-only health report finds broken links, duplicates and descriptions gone stale.
→ [Notes: metadata, search and maintenance](guide/notes.md)

**The week.** Weekday digests of newsletters and job alerts, with an inbox you can trust
afterwards; transcripts distilled into decisions and follow-ups, plus a live check during a
call; meal planning against the calendar; read-only finance snapshots.
→ [Everyday skills](guide/everyday.md)

**Daily log.** A minute of talk about yesterday becomes one structured note; watch data and
the calendar are offered as suggestions, and a script turns the notes into weekly numbers.
→ [Daily log](guide/daily-log.md)

**Advisors.** A coach, a therapist persona, a chef: each defined once, in a vault note. On the
computer an advisor works with the whole vault; on the phone the same advisor runs in a Claude
project from a generated stub, and what it learns there flows back.
→ [Advisors](guide/advisors.md)

**Always on.** The Claude desktop app's Remote Control lets the Claude app on your phone
drive a session running on your Mac. Keep the Mac awake, and the phone reaches a full
session with the vault behind it, and scheduled tasks do their work while you are away.
→ [Always on: the vault from your phone](guide/always-on.md)

**Phone mirror.** The OS can read (and, one confirmed action at a time, operate) apps on an
Android phone through a mirror window on the Mac. → [Phone mirror](guide/phone-mirror.md)

**Local models.** Search embeddings and anything written about a private note run on your
own machine through Ollama; everything else uses Claude, which is faster and better there.
→ [Local models](guide/local-models.md)

**Safety and learning.** Hooks deny or ask before the risky moves; email is data, never
instructions; after a session that taught something, the `retro` skill turns the correction
into a change to the right file; and the docs are
checked against the code on every commit and publish.
→ [Safety and learning](guide/safety-and-learning.md)

## How it is put together

The OS is a git repo at `<vault>/_AI`. The vault itself stays out of git; a few entries at the
vault root (a stub `CLAUDE.md` that imports the framework, and symlinks into `_AI/.claude/`)
let Claude Code find it. A **skill** holds generic logic ("how to operate a task system");
an **integration file** in `integrations/` holds your specifics (list ids, calendars), and its
existence is what switches a tool on. Skills load only when used, and read their integration
file only at that point, so the always-on core stays small.
→ [Architecture](guide/architecture.md) · [Tools, connectors and interfaces](guide/tools.md)

## Prerequisites

- **Claude Code** (`npm i -g @anthropic-ai/claude-code`, or the desktop app); `claude --version`.
- **git**, and **`jq`** at `/usr/bin/jq` (shipped with recent macOS); the safety hooks need it.
- An **Obsidian vault** that is not itself a git repo.
- *Optional:* **`uv`** and **Ollama** with `bge-m3`, for [vault search](guide/notes.md#vault-search).
- A **Claude account** with connectors for mail, calendar and tasks, if you want the OS to
  use them; each is optional ([Connectors](guide/tools.md#connectors)).

No Obsidian plugin is required; Templater, Periodic Notes and Tasks are assumed by the bundled
workflows, and each degrades in a named way ([Obsidian plugins](guide/tools.md#obsidian-plugins--none-required-several-assumed)).

## Quick start

Put the repo inside your vault, **named `_AI`**: the root stub imports `@_AI/CLAUDE.md` and the
symlinks point into `../_AI/`, so the name is load-bearing, and `install.sh` refuses to run
anywhere else.

```bash
cd "/path/to/your/obsidian/vault"
git clone https://github.com/yannikbauer/obsidian-ai-os.git _AI   # the name _AI is required
bash _AI/setup/install.sh   # root stub, .claudeignore, symlinks, git init + pre-commit check
claude                      # start a session, then say "set up my tools"
```

`install.sh` scaffolds your private files from `templates/` without overwriting anything and
checks its own work (it ends with `all checks passed`). Fill in `me.md` and
`maps/vault-map.md`, then ask the session to set up your tools: the **`setup`** skill probes
your connectors and writes your `integrations/` files from live API data. Skills are invoked
by asking in plain words, or as `/setup`.

## Before you install

- **Cost.** Claude Code needs a paid Claude plan or an API key. The scheduled tasks and long
  sessions use tokens like any session; the `usage` skill shows what you actually spend.
- **Your notes.** Installing touches none of them: it writes a stub `CLAUDE.md`, an
  `AGENTS.md`, a `.claudeignore` and three symlinks at the vault root, and skips any that
  already exist. Notes change only when a session asks and you agree; a `description` is
  added to a note only when the OS writes that note, or when you run the backfill.
  Uninstall by deleting `_AI/` and those root entries.
- **Your data.** Whatever a session reads is sent to Anthropic, as with any Claude Code
  session. Search embeddings are computed locally; notes labelled private ask before a
  session opens them, and bulk jobs send them to a local model only
  ([Notes](guide/notes.md#note-metadata-descriptions-and-sensitivity)).
- **Platform.** Built and used on macOS. The hooks and tests also run on Linux (CI runs
  there); the phone mirror and keep-awake setup are Mac-only. Windows is untested.

## What it can't do yet

Stated up front, because the honest version is more useful than a feature list — and
because these are design decisions, not a backlog of oversights.

- **Little runs on a schedule, and all of it is optional.** A few scheduled tasks (digests,
  the health report, a morning check-in that waits for you) live in `setup/scheduled-tasks/`.
  Everything else starts because a human opened a session: no daemon, no background agent
  watching your calendar. ([Always on](guide/always-on.md))
- **Writes to a task system are deliberately constrained.** In ClickUp, rewriting a whole
  doc page silently turns its embedded task and doc references into plain links, so the OS appends, and proposes the rest as text
  for you to apply. Less automation than was built, kept off on purpose.
- **Search is optional, and the first build is slow.** The `setup` skill offers it, but
  embedding about 1,100 notes locally takes 30–90 minutes on a laptop. Without it, grep.
- **Learning is human-gated.** Lessons become changes to files only through a diff you
  approve, and so far they all come from one user's sessions.
- **macOS-first.** The phone mirror, the keep-awake setup and some tools assume a Mac.
- **One user so far.** A few months of history. Everything above is one person's
  experience, not a validated design.

## Where it's going

Direction rather than plan — no dates, no ordering, and the detailed roadmap stays
private because its reasoning is entangled with one person's circumstances.

- **The repair layer of vault maintenance.** The weekly report detects; repair is still
  mostly by hand. Next: link-fix and orphan proposals drawn from the search index.
  <!-- roadmap: 46 -->
- **Closing the gaps in the sensitivity boundary.** Grep and shell reads still go around
  the Read gate, because a shell command's target is a string no hook can read reliably.
  <!-- roadmap: 8 -->
- **Running beyond Claude Code.** Skills and maps are plain markdown and an `AGENTS.md`
  points other harnesses at them, but the gates are Claude Code hooks, so another runtime
  meets none of them. Next: measure what works elsewhere, then a vault gateway (an MCP server
  every runtime goes through) that makes the policy the boundary
  ([Other harnesses](guide/harnesses.md)). <!-- roadmap: 48 --> <!-- roadmap: 52 -->
- **A way to test behaviour that lives in prose.** A capable agent's failure is not an
  error but a plausible artifact, so the learning loop stays human-gated; rules that can be
  mechanised keep moving into hooks, which have tests. <!-- roadmap: 35 -->

## Design principles

- **Generic vs. personal separation** at every layer — the seam that makes sharing safe.
- **Token efficiency** — thin always-on core; skills lazy-load; personal specifics load only when a skill needs them.
- **Version control + audit** — `_AI/` is a git repo; every AI change to a vault note is logged.
- **Safety first** — email treated as untrusted; snapshot-before-destructive-edit; draft-never-send.
- **Overview here, detail in guides** — this page stays short enough to read once.

## Guides

| Guide | Read it when you want to… |
|---|---|
| [Architecture](guide/architecture.md) | understand the layout, the file tree, and what `install.sh` creates |
| [Tools, connectors and interfaces](guide/tools.md) | connect mail, calendar and tasks, see one working set of connectors and plugins, or check which Obsidian plugins matter |
| [Notes](guide/notes.md) | set up descriptions, sensitivity labels, search and the weekly health report |
| [Everyday skills](guide/everyday.md) | use the digests, transcripts, meals, finances, usage and demo skills |
| [Daily log](guide/daily-log.md) | run the daily check-in and its numbers |
| [Advisors](guide/advisors.md) | set up advisor personas across computer and phone |
| [Always on](guide/always-on.md) | reach the vault from your phone |
| [Phone mirror](guide/phone-mirror.md) | connect an Android phone |
| [Local models](guide/local-models.md) | run search and private-note jobs on your own machine with Ollama |
| [Other harnesses](guide/harnesses.md) | run the OS from Codex, OpenCode or another agent tool, and know what you lose |
| [Safety and learning](guide/safety-and-learning.md) | see what is enforced, and how lessons are recorded |
| [Working on the OS](guide/working-on-the-os.md) | edit skills and hooks, or add a tool pack |
| [Sharing and publishing](guide/publishing.md) | export, publish, version, and review a public diff |

## Recommended companions

The connectors and Claude Code plugins one working setup uses (mail, calendar, tasks, the
**superpowers** plugin and others), all optional:
[What the author connects](guide/tools.md#what-the-author-connects-all-optional).

## Licence

**Apache-2.0** — see [LICENSE](LICENSE) and [NOTICE](NOTICE). Use it, fork it, adapt it,
commercially or not. Keep the `LICENSE` and `NOTICE` files if you redistribute it, and state
in modified files that you changed them. Why Apache, and the licence history:
[Sharing and publishing](guide/publishing.md#licence).
