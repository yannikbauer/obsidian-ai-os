# Tools, connectors and interfaces

Which tools the OS can use, how they connect, and which Obsidian plugins it assumes. [Back to the README](../README.md)

## Choosing your tools

The OS assumes nothing about which tools you use. Start a session and run the **`setup`** skill: it probes which connectors are actually reachable, shows you the available tool packs, and writes your `integrations/` files by querying each API — so your IDs are right by construction rather than hand-copied.

A tool is configured if and only if `_AI/integrations/<tool>.md` exists. Delete the file and the tool is gone; the skills notice and say so.

## Connectors

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

## What the author connects (all optional)

One working setup, as a starting point rather than a requirement. Every role degrades when its
tool is missing, and the `setup` skill writes the integration files for whatever you choose.

**Connectors and servers, by role**

| Role or job | Tool | How it connects | Used by |
|---|---|---|---|
| mail | Gmail | account connector | `mail`, the digests |
| calendar | Google Calendar | account connector | `calendar`, weekly planning, meals |
| task system | ClickUp | account connector | `clickup`, weekly planning |
| notes API | Obsidian Local REST API | self-registered MCP server | every vault write, while Obsidian is open |
| transcription | MacWhisper | writes files into the vault (no server) | `transcripts` |
| health data | a health-data aggregator (watch, sleep) | account connector | `daily-log` suggestions |
| spreadsheets | Google Sheets and Drive | account connector | `finances` snapshots |
| scheduled runs | the desktop app's scheduled tasks | built in | digests, health report, check-in |
| browser | Claude in Chrome | browser extension | job-board passes, web reading |
| phone apps | computer use + a mirror window | built in | `phone` ([Phone mirror](phone-mirror.md)) |

**Claude Code plugins.** Install them as plugins rather than copying them in: plugin skills are
namespaced (`superpowers:brainstorming`), so they never collide with this repo's skills.

| Plugin | Why it fits here |
|---|---|
| **superpowers** | brainstorming, writing plans, systematic debugging, TDD: the working style for changing the OS itself |
| **humanizer** | rewrites prose that reads machine-written; useful for the README, guides and drafted mail |
| **context7** | current library and API docs, for the Python and shell tools |
| **code-review** | a review pass over a diff before committing changes to hooks or tools |
| **github** | releases and the public repo, when you publish ([Sharing and publishing](publishing.md)) |

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

## Obsidian plugins — none required, several assumed

**The OS itself needs no plugin.** It reads and writes markdown files, which is why disk
access stays the default route for note content: faster than any API, no token, and it works
while Obsidian is closed.

What the plugins buy is the *conventions* the bundled workflows assume. Each degrades in a
specific, named way, so pick the ones whose loss you would actually notice.

| Plugin | What it unlocks here | Without it |
|---|---|---|
| **Templater** | Periodic and yearly notes whose dates, navigation links and tags are *computed*, not typed. | The OS would have to re-implement each template in prose, which drifts from the template silently. Its `<%* … %>` blocks are also a read-only zone the OS never edits. |
| **Periodic Notes** | One command creates the correctly named, correctly foldered, template-rendered daily / weekly / monthly note. | The OS hand-builds an imitation — and is instructed to *say* it is an imitation rather than pass it off as the template's output. |
| **Tasks** | The task vocabulary the weekly loop reads and writes: statuses, priorities, start and completion dates, and the live query blocks that make a goals note self-updating. | Tasks stay plain checkboxes. The loop still runs, more crudely; goals notes stop answering questions on their own. |
| **Local REST API** *(optional)* | The four things the filesystem structurally cannot do — run a template, execute an app command, `PATCH` one section without rewriting a file, and ask the app what it knows (search, tags, metadata). | Disk-only. Nothing is lost except those four. |
| **Advanced URI** *(optional)* | Fire-and-forget command triggering with no token and no open port. | Nothing, if the REST API is installed — that does the same and returns results. |

**Both API plugins need Obsidian to be running**, so nothing scheduled, pushed or headless may
depend on them. And the REST API is an authenticated localhost listener with full vault
read/write *and* command execution, whose key sits in plaintext in its own config — see the
security notes in `templates/integrations/obsidian.template.md` before enabling it.

Mentioned in passing but **not** required: Dataview, Calendar, and an unlinked-files finder.
