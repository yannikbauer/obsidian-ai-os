# AI OS

A personal AI operating system built on an Obsidian vault, driven by Claude Code. It gives an AI assistant a persistent identity, a map of your vault and tools, and a set of skills — including a `personal-assistant` orchestrator that runs cross-tool workflows over Obsidian (the always-present notes substrate) plus whichever task-system, calendar, and mail tools you configure.

Designed to be **generic and shareable**: the framework contains no personal data. Your identity (`me.md`), vault layout (`maps/`), and tool specifics (`integrations/`) are kept separate and private.

## Layout

Three labels matter throughout: **generic** ships in the shared export, **personal** never
does, and **gitignored** is not tracked at all.

```
_AI/                        the git repo — git lives here, not at the vault root
├── CLAUDE.md               the framework / "soul"                     generic
├── me.md                   who you are, how to work with you          personal
├── LICENSE                 MIT — without it, nobody may reuse this    generic
├── leak-patterns.local     identifiers the export scans for           personal · never exported
├── leak-allow.local        literals that are deliberately public      personal · never exported
├── publish.local           where to publish, and as whom              personal · never exported
├── readonly-zones.local    folders the AI must never write into       personal · never exported
│
├── maps/
│   └── vault-map.md        how your vault is organised                personal
├── integrations/           a file's existence IS the on-switch        personal
│   ├── calendar.md           role: calendar
│   ├── clickup.md            role: task-system
│   └── gmail.md              role: mail
│
├── skills/                 capabilities, loaded on demand             generic
│   ├── personal-assistant/   the orchestrator — cross-tool workflows
│   ├── obsidian/             notes: the always-present substrate
│   ├── calendar/  clickup/  mail/    one per tool role
│   ├── setup/                configure and health-check integrations
│   ├── retro/                turn a session into lessons, and apply them
│   ├── usage/                what this account actually spends
│   └── demo/                 present the OS to someone else
│
├── harness/                the harness's own configuration            generic
│   ├── settings.json         model pin + hooks; symlinked from .claude/
│   ├── hooks/                deny gates, vault-write trace, two Stop hooks
│   └── tests/run.sh          fixtures — every hook, including malformed input
│
├── tools/                  read-only scripts skills call by path        generic
│   ├── session-digest.sh     reduce a transcript to what a retro needs
│   ├── check-coverage.sh     the enumerations that must match reality
│   └── usage.sh              token usage, read from Claude Code's own logs
│
├── history/                append-forever, fully tracked              personal
│   ├── file-log.md           AI changes to vault notes outside _AI/
│   ├── session-log.md        continuity between sessions
│   └── lessons.md            the learning ledger — what it has been taught
│
├── docs/                   thinking, not machinery                    personal · never exported
│   ├── roadmap.md            living index of intent
│   └── work/                 one file per in-flight roadmap item
│
├── templates/              skeletons for scaffolding and sharing      generic
│   └── integrations/         one per tool role
├── setup/                                                             generic
│   ├── install.sh            root glue, scaffolding, and a self-check
│   ├── export.sh             clean shareable copy + leak check
│   └── publish.sh            same, but preserves public git history
│
├── .github/workflows/                                                 personal · never exported
│   ├── verify.yml            gates + public diff on every push; publishes nothing
│   └── publish.yml           manual trigger; the only thing that goes public
│
├── tmp/                    snapshots, scratch, hook traces            gitignored
└── databases/              future search index                        gitignored
```

### What `install.sh` creates

Most of the tree above is **not** in the repo, because it is either personal or
machine-local. A fresh clone holds only the generic parts; `install.sh` scaffolds the
rest from `templates/` and never overwrites anything that already exists, so it is
safe to re-run:

| Created in `_AI/` | From | Why it is not committed |
|---|---|---|
| `me.md`, `maps/vault-map.md` | templates | yours to fill in |
| `history/file-log.md`, `history/session-log.md` | templates | your record, not the framework's |
| `history/lessons.md` | template | the learning ledger — what the OS has been taught |
| `docs/README.md` | template | creates the folder and says what it is for |
| `tmp/README.md` | template | `tmp/` is gitignored, so the folder needs creating |
| `leak-patterns.local`, `leak-allow.local` | templates | your identifiers |
| `readonly-zones.local` | template | your folder names |
| `publish.local` | template | your destination; ships commented out |
| `correction-words.local` | template | what counts as you correcting the AI; all comments by default, so the built-in English list stays in force |
| `integrations/` | — | **empty on purpose**: a file's existence is the on-switch, so a placeholder here would read as a half-configured tool. The `setup` skill writes the real files. |

`databases/` is not created: it is a placeholder for a search index that does not
exist yet.

`install.sh` also materialises four things at the **vault root**, outside this repo — which is
why they are created rather than committed:

```
<vault>/
├── CLAUDE.md               stub that @-imports CLAUDE.md, me.md, vault-map.md
├── .claudeignore           index exclusions
└── .claude/
    ├── skills    -> ../_AI/skills             native skill discovery
    └── settings.json -> ../_AI/harness/settings.json   model pin + hooks
```

Both symlinks point *into* the repo, so the OS and the harness it runs on are
version-controlled together while the vault root stays plain-local.

## What it can't do yet

Stated up front, because the honest version is more useful than a feature list — and
because these are design decisions, not a backlog of oversights.

- **Nothing runs on a schedule.** Every workflow starts because a human opened a
  session. No cron, no daemon, no background agent watching your calendar.
- **Writes to a task system are deliberately constrained.** A test showed that
  rewriting a whole page silently destroys rich content — task and doc references
  flatten to plain links on read, so writing the page back replaces every one of them.
  The OS appends, and proposes the rest as text for you to apply. That is less
  automation than was built, kept off on purpose.
- **There is no search index.** Finding something means scanning. This is the largest
  open item.
- **Learning is human-gated, and new.** A retro pass reads a session's own transcript
  rather than its summary of itself, and routes what it finds: a fact about a tool into
  that tool's integration file, a workflow step into a skill, a mechanisable rule into a
  hook *with a test*. Only a **disposition that has recurred** earns an always-on rule,
  because everything in the framework file is loaded every session. Every change is a
  diff the human approves. It does work — three lessons have reached files that are
  actually read, and one caught its own author an hour after being promoted — but it has
  run a handful of times, all in sessions that also built it.
- **n=1.** One user, a few months of history. Everything above is one person's
  experience, not a validated design.

## Where it's going

Direction rather than plan — no dates, no ordering, and the detailed roadmap stays
private because its reasoning is entangled with one person's circumstances.

- **A local model tier for bulk vault work.** Mechanical relabelling across hundreds
  of notes, human-gated per batch and snapshotted in git. Running it on a local model
  *dissolves* the privacy blocker rather than working around it — nothing leaves the
  machine, so the sensitivity question and the cost question land on the same answer.
- **A sensitivity boundary enforced at the tool layer.** The obvious design does not
  work, which is the interesting part: a `sensitive: true` flag in frontmatter cannot
  gate anything, because a read returns frontmatter and body atomically — by the time
  the flag is visible, the body is already in context. Enforcement has to sit where
  the read happens.
- **A search index**, which is what makes the vault queryable instead of scannable.
- **A way to test behaviour that lives in prose.** The learning loop stays human-gated
  precisely because nothing can yet catch a behavioural regression automatically: a
  capable agent's failure mode is not an error, it is a plausible artifact. Rules that
  can be mechanised keep moving into hooks, which have tests and cannot be argued out of
  their answer; what is left is judgment, and the human gate is the design rather than
  caution about it.

## Prerequisites

- **Claude Code** installed (`npm i -g @anthropic-ai/claude-code`, or via the desktop app). Verify with `claude --version`.
- **git** installed (`git --version`).
- **`jq`** at `/usr/bin/jq` — the hooks parse their input with it. Shipped with recent macOS; `install.sh` checks and fails loudly if it is missing, because the hooks fail *open* and a missing `jq` would silently stop the safety gates enforcing.
- An **Obsidian vault** that is not itself a git repo — `_AI/` becomes its own repo inside it, and the vault stays plain-local.
- A **Claude account** you are signed in to (`claude auth status`), if you want account connectors for mail/calendar/tasks — see [Connectors](#connectors).

## Quick start

**Step 0 — put the repo inside your vault, named `_AI`.** This is not optional:
the vault-root stub imports `@_AI/CLAUDE.md` and the skills symlink points at
`../_AI/skills`, so the directory name is load-bearing. `install.sh` refuses to
run from anywhere else rather than leaving you with broken links.

```bash
cd "/path/to/your/obsidian/vault"
git clone https://github.com/yannikbauer/obsidian-ai-os.git _AI   # the name _AI is required
```

Then:

```bash
# from the vault root
bash _AI/setup/install.sh          # root stub, .claudeignore, skills symlink, git init
# fill in me.md / maps if freshly scaffolded
claude                             # start a session, then run the setup skill
```

`install.sh` verifies its own output and exits non-zero if the symlink or any of
the root stub's imports fail to resolve. If it prints `all checks passed`, the
install is sound; if it exits `1` it refused to install in the wrong place, and
`3` means the tree is incomplete.

### Connectors

Claude Code reaches external tools over MCP, and there are **two independent
registries**. Knowing which one you are in saves a lot of confusion:

| | Account connectors | Self-registered servers |
|---|---|---|
| Added at | `claude.ai/customize/connectors` | `claude mcp add` |
| Stored | server-side, on your Claude account | `~/.claude.json` or `.mcp.json` |
| Follows you across machines | yes | no |
| Shown by `claude mcp list` | **no — never** | yes |
| Shown by `/mcp` | yes | yes |

**`/mcp` inside a session is the authoritative inventory.** `claude mcp list`
only ever shows the second column, so an empty-looking list is *not* evidence
that a connector is missing. Neither is a single `claude auth status` reporting
`loggedIn: false` — token expiry is transient and any client sharing the
keychain credential can refresh it.

Most people will use **account connectors** for mail, calendar and a task
system: add them once at claude.ai, authorize in the browser, and they work in
the terminal, the desktop app and the IDE extension alike. Nothing about them
lives in this repo, which is why the OS records *which tool fills which role* in
`integrations/` and stays silent about how the connection was registered.

If you do register your own servers, pick the scope deliberately:

| Scope | Stored in | Visible where | Shared via git |
|---|---|---|---|
| `local` *(default)* | `~/.claude.json`, under the project path | that one directory | no |
| `project` | `.mcp.json` at the project root | that one directory | yes |
| `user` | `~/.claude.json`, top level | **all your projects** | no |

**Prefer `--scope user`.** Note that `--scope project` writes `.mcp.json` to the
directory you launch `claude` from — the **vault root**, which is deliberately
not a git repo (only `_AI/` is). So the one scope meant for sharing lands
outside version control and outside `export.sh`.

Once your connectors are in place, run the **`setup`** skill from a session — it
probes which are actually reachable, shows the available tool packs, and writes
your `integrations/` files from live API data.

> **Caveat worth knowing:** account connectors are the *lowest* precedence
> (local → project → user → plugins → claude.ai), and they can be switched off
> wholesale with `ENABLE_CLAUDEAI_MCP_SERVERS=false` or
> `"disableClaudeAiConnectors": true` in settings. If every role suddenly reports
> unconfigured, check that before debugging anything else.

## Design principles

- **Generic vs. personal separation** at every layer — the seam that makes sharing safe.
- **Token efficiency** — thin always-on core; skills lazy-load; personal specifics load only when a skill needs them.
- **Version control + audit** — `_AI/` is a git repo; every AI file change is logged.
- **Safety first** — email treated as untrusted; snapshot-before-destructive-edit; draft-never-send.

## Choosing your tools

The OS assumes nothing about which tools you use. Start a session and run the **`setup`** skill: it probes which connectors are actually reachable, shows you the available tool packs, and writes your `integrations/` files by querying each API — so your IDs are right by construction rather than hand-copied.

A tool is configured if and only if `_AI/integrations/<tool>.md` exists. Delete the file and the tool is gone; the skills notice and say so.

## Adding a tool pack

Packs come in two shapes, and picking the right one matters:

- **Role-named packs** (`skills/calendar/`, `skills/mail/`) hold provider-agnostic logic for a role — they must work for *any* provider (Fastmail, Proton, Apple Calendar, Outlook, …) and must name no specific product, timezone, or language.
- **Tool-named packs** (`skills/clickup/`) hold logic genuinely specific to one product's model — naming that product inside its own pack is correct.

**A new provider for a role you already have (e.g. you already use `calendar` but switch from Google Calendar to Fastmail) usually needs only a new `integrations/<tool>.md` file, not a new skill** — the existing role-named pack already handles it generically. Only write a new `skills/<tool>/` pack when the tool's operating model doesn't fit an existing role, or the role itself has no pack yet.

When you do need a new pack, it is three files:

| File | Contents | Ships? |
|------|----------|--------|
| `skills/<tool>/SKILL.md` | generic "how to operate this tool" logic | yes |
| `templates/integrations/<tool>.template.md` | menu entry, placeholders only | yes |
| `integrations/<tool>.md` | your IDs and conventions | never |

Use the `skill-creator` or `superpowers:writing-skills` skill to write the SKILL.md. Keep every real ID out of the first two files — `setup/export.sh` runs a leak check that will refuse to publish otherwise.

## Interfaces

The same files and config are read by all of them, so the OS behaves consistently whether you use:

- **Claude Code in the terminal** — most control; best for building and debugging skills.
- **Claude Code in the desktop app** — same engine, GUI.
- **Claude Code in an IDE extension** — nice for editing skills and running the assistant side by side.

Pick per task; there is nothing to reconfigure between them — **provided your
tools are account connectors**, which follow your account onto every surface.
A server registered with the default `local` scope is bound to the one directory
it was added in and will not follow you; use `--scope user` if you want it
everywhere.

## Working on the OS

- **Edit skills** in `_AI/skills/` — those are the real files; the `.claude/skills` symlink just exposes them. Commit changes to `_AI/`.
- **Update your context** by editing `me.md`, `maps/vault-map.md` and `integrations/*.md` as things change. The `setup` skill can re-verify integration files against live APIs.
- **Add a skill**: create `_AI/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`) plus instructions. It is discovered automatically through the symlink. Keep it under ~500 lines and push reference detail into files it points at.
- **Add a map**: new orientation docs (people-map, project-map) go in `_AI/maps/`, and if they should always load, get added to the root stub's `@import` list.
- **Change a hook** in `_AI/harness/`, then run `sh harness/tests/run.sh`. Settings edits are picked up live — no restart. Write commands as `"\"${CLAUDE_PROJECT_DIR}/_AI/harness/hooks/x.sh\""`: braced *and* quoted, because an unquoted path containing a space fails silently.
- **Git lives in `_AI/`**, not the vault root. Run every git command from there.
- **The AI logs its own changes to vault files outside `_AI/`** in `history/file-log.md`. Changes inside `_AI/` are covered by git history instead.

## Sharing your copy

Two scripts, for two different jobs. Both run the same leak check; neither ever
touches your private `_AI/`.

| | `export.sh` | `publish.sh` |
|---|---|---|
| Produces | a fresh directory | a commit on the public repo |
| Git history | **new** (single commit) | **preserved** |
| Target must | not exist | already exist as a remote |
| Use for | a one-shot copy, a zip, a first push | every update after the first |

```bash
bash _AI/setup/export.sh ~/aios-export     # one-shot snapshot
bash _AI/setup/publish.sh --dry-run        # see what would change publicly
bash _AI/setup/publish.sh                  # export, diff, confirm, push
```

Both copy only the generic parts — framework, skills, harness, templates, setup,
LICENSE — via an **allowlist**, so a new personal folder is excluded by default
rather than by remembering to exclude it.

### The leak check

Every export greps the result for personal tokens. Patterns live in
`_AI/leak-patterns.local`, which is never exported; edit it as your identifiers
change. If anything matches, the run **aborts** rather than publishing.

Some personal tokens legitimately belong in a public repo — the copyright holder's
name in `LICENSE`, the repo URL in this README. `_AI/leak-allow.local` lists those
exact literals, which are stripped from a matched line before it is judged. The
exemption is per-literal, not per-pattern or per-file: your bare first name
appearing *anywhere else* in `LICENSE` still fails the check, verified by a
negative test. Keep entries as specific as possible — listing a bare first name
there would silently disable the check everywhere.

(This paragraph is why the allowlist holds `Firstname Lastname` and not
`Firstname`: prose that names you in an example would otherwise sail through.)

`publish.sh` syncs with `--delete`, so removing a file from the allowlist removes
it from the public repo too, and it **confirms before pushing** by default: the
leak check is the only barrier between this repo and a public one, and a push
cannot be taken back.


### Configuring the destination

`publish.sh` ships in the export, so it holds no personal defaults. Put yours in
`_AI/publish.local` (sourced as shell, never exported):

```sh
AIOS_PUBLIC_REMOTE=https://github.com/<you>/<repo>.git
AIOS_PUBLIC_GIT_NAME="Your Name"
AIOS_PUBLIC_GIT_EMAIL=<you>@users.noreply.github.com
```

The email matters more than it looks. **Commit metadata is not file content**, so
the leak check cannot see it — a plain `git commit` would stamp the address from
your `~/.gitconfig` onto every public commit, permanently and unscrubbably. The
script refuses to run without an explicit one for that reason. A
`users.noreply.github.com` address still links commits to your GitHub account.

## Automated publishing

Two workflows, split on a single principle: **verifying is automatic, publishing
is an act you take.**

Content pushed to a public repo is not retractable. The push enters GitHub's
public events stream, which third parties mirror, and a later force-push does not
remove the old commit — it stays reachable by SHA. So nothing here publishes on a
schedule or on a push.

| | `verify.yml` | `publish.yml` |
|---|---|---|
| Runs | every push to `main` | manual dispatch only, typing `publish` to confirm |
| Publishes | **never** | pushes to the public repo's `main` |
| Needs a secret | **no** — the public repo is readable anonymously | yes, `PUBLIC_REPO_TOKEN` |
| Produces | the exact public-facing diff, in the run summary and as an artifact | a public commit |

Both run the same gates first:

| Gate | Catches |
|---|---|
| `harness/tests/run.sh` | a broken hook — they fail *open*, so breakage is otherwise silent |
| `actionlint` | a workflow that is itself broken — the thing that runs every other gate |
| `export.sh` leak check | identifiers you listed in `leak-patterns.local` |
| **gitleaks** | the generic classes you would not have predicted — API keys, tokens, private keys |
| `install.sh` into a scratch vault | an export that passes every check and then does not install |

### What the gates cannot catch

The scanners catch *categories*: identifiers you listed, and strings shaped like
credentials. The realistic leak for a system like this is neither. It is **personal
content drifting into a file that is nominally generic** — a client's name in a
skill example, a health detail in a workflow, a former employer's process in
`CLAUDE.md`. Those are exactly the files you edit most, and no pattern will flag
them.

Only reading the diff catches that, which is why publishing is manual and the diff
is rendered before anything leaves the repo.

### The review checklist

Whoever reviews a sync — you, or Claude in a session on your behalf — reads the
diff against these, in order:

1. **Names of real people** other than the repo owner. Friends, partners,
   colleagues, clients. Examples are the usual culprit.
2. **Employer or client specifics** — internal process, tooling, terminology,
   anything learned under an obligation.
3. **Personal circumstances** — health, money, relationships, living situation.
   Skills describing "what to do when the user is low on energy" drift here easily.
4. **Identifiers** the patterns do not know yet: a new calendar, a new account, a
   new tool's workspace ID. Anything that matches, add to `leak-patterns.local`.
5. **Paths that expose vault structure** beyond what `templates/` already shows.
6. **Tone** — text written *to* you rather than *for* a reader. Not a leak, but it
   reads as unfinished in a public repo.

Claude can do this reading and report, so a clean sync costs you a yes. It is a
good first pass at 1–5 and an unreliable judge of what *you* consider private:
whether naming a former employer's method is acceptable depends on obligations
that are not in the text. Treat a flag as a question for you, not a verdict, and
treat "clean" as "nothing mechanical found", not as permission to never look.

### Publishing

The usual path is a session: ask Claude to publish, and it runs the gates, builds
the export, diffs it against the public repo, reads the diff against the checklist
above, reports, and pushes on your yes. Review and push stay in one operation, so
what you approved is what ships.

Without a session, run **Publish to public repo** from the Actions tab and type
`publish` to confirm. Locally, `bash _AI/setup/publish.sh` does the same with a
diffstat and a prompt.

### One-time setup

1. Create the public repo **with** a README:
   ```bash
   gh repo create <repo> --public --add-readme \
     --description "A personal AI OS for Obsidian, driven by Claude Code"
   ```
   `--add-readme` gives it a `main` branch immediately. A repo with no commits
   has no default branch, which makes the first diff and push fiddlier than it
   needs to be. The placeholder README is overwritten by the first sync
   (`rsync --delete`), so nothing is lost.

2. Create a **fine-grained personal access token** at
   *Settings → Developer settings → Personal access tokens → Fine-grained*:
   - Resource owner: your account
   - Repository access: **Only select repositories** → the public repo
   - Permissions: **Contents: Read and write**. That is the only one needed —
     `Metadata: Read-only` adds itself automatically and is mandatory.

   Scoping the token to the one public repo means a leaked token cannot reach
   anything private. Note the token is only used by `publish.yml`; `verify.yml`
   needs no credential at all, because it only reads a public repo.

3. Add it to the **private** repo as a secret named `PUBLIC_REPO_TOKEN`:
   ```bash
   gh secret set PUBLIC_REPO_TOKEN --repo <you>/<private-repo>
   ```
   It prompts for the value, so nothing lands in your shell history.

4. Set `PUBLIC_REPO` in the `env:` block of **both** workflows to `<you>/<repo>`.

5. Set a reminder for the token's expiry date. When it lapses, `publish.yml`
   fails at the push step — nothing publishes wrongly, it just stops — but the
   failure is easier to act on if you were expecting it.


## Recommended companions

This OS pairs well with the **superpowers** plugin (brainstorming, writing-plans, systematic-debugging, TDD). Install it as a plugin rather than copying it in — plugin skills are namespaced (`superpowers:brainstorming`), so they never collide with this repo's skills, and you keep getting updates.

## Licence

MIT — see [LICENSE](LICENSE). Use it, fork it, adapt it. The framework is the
shareable part; your `me.md`, `maps/` and `integrations/` are yours and never
leave your machine.

If you fork this, put your own destination in `_AI/publish.local` rather than
editing the script — see [Sharing your copy](#sharing-your-copy).
