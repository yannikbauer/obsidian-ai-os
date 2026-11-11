# Architecture

How the repo, the vault and Claude Code fit together, and where every file comes from. [Back to the README](../README.md)

## Layout

### Why the files sit where they do

Three constraints pull against each other, and the layout is what satisfies all three at
once:

1. **Claude Code treats the project root as its world.** `CLAUDE.md`, `.claude/`, the
   hooks and the permission boundary are all anchored there. For the OS to work on your
   notes, that root has to be the vault.
2. **Git must not cover your notes.** Hundreds of personal notes and a folder of binaries
   do not belong in a repo built to be forked and published, and one blanket `git add` in
   a vault-wide repo would leak them irreversibly.
3. **The framework has to stay forkable as one self-contained repo**, so nothing it needs
   may live outside it.

So the repo lives at `<vault>/_AI` and *is* the whole OS, while the few things Claude Code
insists on finding at the vault root are glue pointing straight back into it: a stub that
`@`-imports the framework, its runtime-neutral twin, an ignore list, and three symlinks into
the repo. `install.sh` writes that glue
and then verifies it resolves, which is why those entries are created rather than
committed. The vault root stays plain-local, and the OS and the harness it runs on are
version-controlled together.

### The two `.claude/` folders, and what links them

There are two of them, and the tree below is confusing until you know why.

Claude Code only ever looks for `.claude/` at the **project root**, which here is the vault.
But everything that belongs in it — the skills, the hooks, the settings the OS runs on — has
to live inside `_AI/`, or it is not version-controlled and cannot be shared. Those two
requirements point at two different places, so the vault-root one holds nothing of its own.
It holds symlinks into the repo, where the real files are:

| At the vault root | points into the repo at | which holds |
|---|---|---|
| `.claude/skills` | `_AI/.claude/skills` | the skills Claude discovers |
| `.claude/settings.json` | `_AI/.claude/settings.json` | the model pin and the hook registrations |
| `.claude/agents` | `_AI/.claude/agents` | the subagents skills delegate to |

**Why one link per entry, rather than one link to the whole folder.** Because that folder is shared,
and the OS is not the only thing writing to it. Claude Code drops a per-machine permission
file there the first time you approve something permanently. A GUI wrapper drops its own
settings and session state. An agent or a slash command you write lands there too. Linking
the folder as a whole would pull every one of those into this repo, where an ignore rule
would have to hold them back — forever, and against tools nobody has written yet. Linking
only the entries the OS owns leaves the rest outside the repo *by construction*, which
is the same reasoning that keeps the vault itself out of git.

**What that costs.** One link per thing the OS wants to version: `agents/` was added
that way, and `commands/` later would be one more `link_into_repo` call in `install.sh`. Two consequences follow.
A real folder of that name already sitting at the vault root blocks the link, and
`install.sh` says so rather than replacing anything you have. And whatever you create at the
vault root under a name the OS does not link is simply not in git.

**The exception, which neither arrangement fixes.** `skills/` is linked as a whole folder, so
a skill that any tool installs into this project lands inside this repo. `.claude/.gitignore`
and the `.claude/` walk in `check-coverage.sh` exist for exactly that: the ignore rule admits
only the shapes the OS ships, and the walk reports anything under `.claude/` that is neither
tracked nor deliberately declared.

### Why skills and integrations are separate

A skill holds **generic logic** — how to operate a task system, not which lists you use.
Everything specific to you lives in `integrations/<tool>.md`, one file per tool, and those
files never ship. Two things fall out of that split, and the second is the one people miss:

- **It is what makes the skills shareable at all.** A skill with your list ids, folder
  names and doc urls baked in is personal data wearing a capability's clothes. Strip it
  and there is nothing generic left to publish.
- **Token economy.** A skill reads its integration file *at the point of use*, so a
  session that never touches your task system never loads your task-system setup.
  Hardcoded, every skill would be longer and would carry your whole configuration into
  every session that so much as mentions it.

The same file is also the **on-switch**: a tool is configured if and only if
`integrations/<tool>.md` exists. A skill that resolves a role and finds no file degrades
and says so, rather than describing a tool you do not have. `CLAUDE.md` states the rule
under *Layered design*; the tree below is the shape it produces on disk.

The right-hand column answers one question for every entry: where it comes from, and who
gets to see it. **generic** ships in the shared export, **personal** never does,
**gitignored** is not tracked at all, and **created by install.sh** marks the glue that is
written at install time instead of committed.

```
<vault>/                    your Obsidian vault — deliberately NOT a git repo
│
├── CLAUDE.md               stub; @-imports CLAUDE.md, me.md, vault-map.md      created by install.sh
├── AGENTS.md               the same pointer, for non-Claude runtimes           created by install.sh
├── .claudeignore           what Claude Code must not index                     created by install.sh
├── .claude/
│   ├── skills        -> ../_AI/.claude/skills          native skill discovery  created by install.sh
│   ├── settings.json -> ../_AI/.claude/settings.json   model pin + hooks       created by install.sh
│   └── agents        -> ../_AI/.claude/agents          native subagent discovery  created by install.sh
│
└── _AI/                    the git repo — everything below here is the OS
    ├── CLAUDE.md               the framework / "soul"                          generic
    ├── me.md                   who you are, how to work with you               personal
    ├── VERSION                 the version a fork has; nothing else states it  generic
    ├── LICENSE                 Apache-2.0 — without it, nobody may reuse       generic
    ├── NOTICE                  attribution that redistributions must keep      generic
    ├── CONTRIBUTING.md         the generic/personal rule, DCO, licence grant   generic
    │
    ├── config/                 the knobs — one folder, one lifecycle           personal · never exported
    │   ├── leak-patterns.local     identifiers the export scans for
    │   ├── leak-allow.local        literals that are deliberately public
    │   ├── publish.local           where to publish, and as whom
    │   ├── readonly-zones.local    folders the AI must never write into
    │   ├── correction-words.local  what counts as you correcting the AI
    │   ├── clickup-replace-allow.local  doc pages the AI may rewrite whole
    │   ├── sensitivity.local       folders whose notes are private or secret
    │   ├── search-index.local      what the search index skips, and which folders are third-party
    │   ├── vault-health.local      what the health check skips, and its duplicate threshold
    │   └── README.md               what reads each knob, and how each one degrades
    │
    ├── maps/                   orientation — structure, not content            personal
    │   ├── vault-map.md          how your vault is organised
    │   ├── workflow-map.md       which system is authoritative for what
    │   ├── advisors-map.md       your advisors, their prompt notes and phone docs
    │   └── <topic>-map.md        on-demand maps a skill reads (people, finance, meals, …)
    ├── integrations/           a file's existence IS the on-switch             personal
    │   ├── calendar.md           role: calendar
    │   ├── clickup.md            role: task-system
    │   ├── gmail.md              role: mail
    │   ├── macwhisper.md         role: transcription
    │   ├── phone.md              role: phone — the mirror app, modes, start checklist, troubleshooting
    │   ├── <budgeting-app>.md    no role — an app on the phone role; app map for the finances skill
    │   └── obsidian.md           role: notes — OPTIONAL; absent means no API, not no notes
    │
    ├── .claude/                everything Claude Code reads                    generic
    │   ├── settings.json         model pin + hooks; symlinked from the vault root
    │   ├── hooks/                deny and ask gates, write trace, session-start, prompt and Stop hooks (see .claude/README.md)
    │   ├── .gitignore            a whitelist — other programs write here too
    │   ├── agents/               subagents; symlinked from the vault root
    │   │   ├── newsletter-reader.md  reads newsletter threads + its own saved output, nothing else
    │   │   ├── job-mail-reader.md    same shape, for job-alert mails
    │   │   └── first-reader.md       reads the README as a newcomer; used in the publish review
    │   └── skills/               capabilities, loaded on demand
    │       ├── personal-assistant/   the orchestrator — cross-tool workflows
    │       ├── obsidian/             notes: the always-present substrate
    │       ├── vault-maintenance/    weekly health report on the vault, and fixes on confirmation
    │       ├── calendar/  clickup/  mail/    one per tool role
    │       ├── transcripts/          meeting & memo transcripts: triage, distill, recall
    │       ├── newsletter-digest/    weekly cross-source digest of newsletters
    │       ├── job-digest/           job-alert mails scored against the search, plus a market log
    │       ├── meals/                meal-plan logistics: cooked-tracking, calendar slots, suggestions
    │       ├── daily-log/            spoken daily check-in → one structured note; watch rules, summaries
    │       ├── advisors/             entry point to the prompt-note advisors (life coach, therapist, chef, …)
    │       ├── finances/             read-only finance snapshots, sheet + advisor-brief upkeep
    │       ├── phone/                drive Android apps through a scrcpy mirror; read-only by default
    │       ├── setup/                configure and health-check integrations
    │       ├── retro/                turn a session into lessons, and apply them
    │       ├── usage/                what this account actually spends
    │       └── demo/                 present the OS to someone else
    │
    ├── tools/                  scripts skills call by path; most read-only     generic
    │   ├── session-digest.sh     reduce a transcript to what a retro needs
    │   ├── check-coverage.sh     the enumerations that must match reality
    │   ├── usage.sh              token usage, read from Claude Code's own logs
    │   ├── macwhisper-live.sh    a recording's transcript, live, from MacWhisper's database
    │   ├── phonemirror.sh        check the phone mirror (may `adb connect`); rebuild writes its app bundle
    │   ├── phonemirror-launcher.sh   the mirror's launcher: picks USB or Wi-Fi, execs scrcpy
    │   ├── phonemirror-stub.c        the bundle executable; only execs the launcher
    │   ├── vault-search.py       hybrid search over the notes: local embeddings + keywords, one SQLite file
    │   ├── vault-health.py       vault maintenance: read-only report on frontmatter, descriptions, links, tags, duplicates
    │   ├── vault-health-weekly.sh  the unattended weekly run: report + description proposals into tmp/health/
    │   ├── advisor-stub.py       builds an advisor's paste-ready Claude project stub from its prompt note
    │   ├── daily-log-stats.py    numbers from the daily-log notes: weekly averages, two-weekly summaries
    │   ├── garmin-export.py      a Garmin Connect export as a daily CSV, for a health baseline
    │   ├── frontmatter-set.py    the bulk frontmatter writer: checked, snapshotted, logged
    │   └── frontmatter-polish/   propose a description and language per note (local or cloud model); review table
    │
    ├── tests/                  fixtures for every hook, gate and script        generic
    │   ├── run.sh                every hook and gate, including malformed input
    │   └── fixtures/             recorded transcripts the usage fixtures read
    │
    ├── history/                append-forever, fully tracked                   personal
    │   ├── file-log.md           AI changes to vault notes outside _AI/
    │   ├── session-log.md        continuity between sessions
    │   ├── lessons.md            the learning ledger — what it has been taught
    │   └── usage-baseline.md     what this account normally spends, to compare against
    │
    ├── guide/                  the detail behind the README, one page per area  generic
    ├── docs/                   thinking, not machinery                         personal · never exported
    │   ├── roadmap.md            living index of intent
    │   ├── artifacts/            published write-ups, with their sources
    │   └── working-notes/        one file per in-flight roadmap item
    │
    ├── templates/              skeletons for scaffolding and sharing           generic
    │   └── integrations/         one per tool pack that ships a template
    ├── setup/                                                                  generic
    │   ├── install.sh            root glue, scaffolding, and a self-check
    │   ├── export.sh             clean shareable copy + leak check
    │   ├── leak-check.sh         the scan itself — refuses to run if it cannot find _AI
    │   ├── version.sh            reads and bumps VERSION; used only when releasing
    │   ├── publish.sh            same as export, but preserves public git history
    │   ├── scheduled-tasks/      one generic file per optional scheduled run; the setup skill installs them
    │   └── git-hooks/            pre-commit: the fast coverage check; install.sh wires it in
    │
    ├── .github/workflows/                                                      personal · one exception
    │   ├── verify.yml            gates + public diff on every push; publishes nothing
    │   ├── publish.yml           manual trigger; the only thing that goes public
    │   └── public-ci.yml         the PUBLIC repo's CI; ships as ci.yml
    │
    ├── tmp/                    snapshots, scratch, hook traces                 gitignored
    └── databases/              the search index; rebuildable, never committed  gitignored
```

### What `install.sh` creates

`install.sh` verifies its own output and exits non-zero if a symlink or any of the root
stub's imports fail to resolve. `all checks passed` means the install is sound; exit `1`
means it refused to install in the wrong place, and `3` means the tree is incomplete.

Most of the tree above is **not** in the repo, because it is either personal or
machine-local. A fresh clone holds only the generic parts; `install.sh` scaffolds the
rest from `templates/` and never overwrites anything that already exists, so it is
safe to re-run:

| Created in `_AI/` | From | Why it is not committed |
|---|---|---|
| `me.md`, `maps/vault-map.md` | templates | yours to fill in |
| `maps/workflow-map.md` | template | which system is authoritative for what — a decision to make once, not a build. Ships pre-filled with a sane default; edit the rows that do not match how you work |
| `maps/advisors-map.md` | template | your advisors, their prompt notes and phone docs; empty until you add one (see [Advisors](advisors.md)) |
| `history/file-log.md`, `history/session-log.md` | templates | your record, not the framework's |
| `history/lessons.md` | template | the learning ledger — what the OS has been taught. **Yours starts empty.** Comments across this repo cite lessons as `L001`, `L006` and so on: those are entries from the author's ledger, kept as the *reason* a rule or a test exists. They are provenance, not a cross-reference you can follow — read the sentence around them, not the id. |
| `docs/README.md` | template | creates the folder and says what it is for |
| `tmp/README.md` | template | `tmp/` is gitignored, so the folder needs creating |
| `config/leak-patterns.local`, `config/leak-allow.local` | templates | your identifiers |
| `config/readonly-zones.local` | template | your folder names |
| `config/publish.local` | template | your destination; ships commented out |
| `config/correction-words.local` | template | what counts as you correcting the AI; all comments by default, so the built-in English list stays in force |
| `config/clickup-replace-allow.local` | template | task-system page ids the AI may rewrite in full; empty by default, so every whole-page rewrite is denied |
| `config/sensitivity.local` | template | folders whose notes are private or secret; all comments by default, so only frontmatter labels count |
| `config/search-index.local` | template | which folders the search index skips or flags as third-party; all comments by default, so the built-in defaults apply |
| `config/vault-health.local` | template | which folders the health check skips, which notes need no description; all comments by default |
| `integrations/` | — | **empty on purpose**: a file's existence is the on-switch, so a placeholder here would read as a half-configured tool. The `setup` skill writes the real files. |

`databases/` is not created either: the first `tools/vault-search.py index` makes it (see
[Vault search](notes.md#vault-search)). Deleting it costs a rebuild, nothing else.

The same run also writes the **vault-root** entries marked *created by install.sh* in the tree above. They are
the glue described under [Why the files sit where they do](#why-the-files-sit-where-they-do),
and both symlinks point *into* this repo, so nothing of substance lives outside it.
