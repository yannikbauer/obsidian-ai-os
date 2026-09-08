---
name: obsidian
description: >
  Read, create, edit, and search notes in the user's Obsidian vault (personal knowledge base). Trigger whenever the user mentions Obsidian, their vault, their notes, weekly notes, weekly planning, goals, reflections, diary, or their personal wiki — including casual asks like "check my notes" or "what are my goals".
---

# Obsidian Vault Assistant

Read/write access to the user's Obsidian vault (plain markdown files). This skill is generic; the specific folder layout, prefixes, tags, and conventions live in **`_AI/maps/vault-map.md`** — read it before working in the vault.

**Route: disk by default for reads, the API first for writes.** The vault is files, and the filesystem is the faster, tokenless route that also works while the app is closed — so *reads* go through disk. Some notes tools additionally expose a **local API** (a command endpoint, a URI scheme, a plugin server). If `_AI/integrations/<notes-tool>.md` exists it documents that layer and the exact endpoints; if it does not, there is no API and disk is the only route — which costs no capability, only the four items below. Reach for the API only to:

1. **Run a template.** Template blocks are code the *app* evaluates; a file written to disk gets none of it. Never hand-write a note whose template the app can render — trigger the app's own create-note command and let it render.
2. **Execute an app command** that has no filesystem equivalent.
3. **Patch one section** of a note without rewriting the file — the safe way to edit a note the user may have open.
4. **Ask the app what it knows** — search, tags, metadata — rather than re-deriving it by grepping. What the plugin returns is what the user sees; what grep returns is your reconstruction of it.

**Writes are different, and the reason is the harness, not capability.** A note write must happen on a route the safety hooks can *see*. An API call names its target in a structured argument, and a file tool names it in a dedicated field; both are matchable. **A shell command names it in a string, and no gate can read that** — so a `cat >`, `sed -i`, `tee` or heredoc into a note runs with every read-only-zone, template and live-query guard silently switched off. This is not hypothetical: on 2026-09-07 an entire session's vault edits took that route and fired nothing, including edits to a note built out of live query blocks.

So, in order: **the notes API if one is configured** (surgical, and it can check the file has not changed under you), **otherwise the file-editing tools**, and **never the shell**. Prefer editing one section over rewriting a file, whichever route you are on — a whole-file write is how live query blocks and template logic die.

**One writer per file.** API writes and disk writes are two uncoordinated writers with no locking — pick one route per write, never both in one operation. And **the API needs the app running**, so nothing scheduled, pushed or headless may depend on it; that is what the file-tool fallback is for.

**When a section address is involved, ask the app for it — never retype it.** Section targeting matches heading text, so a rename or a difference in capitalisation makes an edit miss. It should *fail* when it misses: leave any "create the target if it is absent" option off, because with it on, a mistyped heading quietly creates a second one and writes there instead of erroring.

## Core principles

- **Preserve existing patterns.** Match the style of surrounding notes. Don't introduce new formatting, heading, or organizational schemes unprompted.
- **Respect wikilinks.** Notes reference each other with `[[Note Name]]` and `[[Note#Section]]`. Renaming a note or a linked heading can break links elsewhere — flag before doing it.
- **Don't touch generated/query syntax.** Never edit Templater `<%* ... %>` blocks, live `\`\`\`tasks` query blocks, or `> [!Goals]-` callouts unless explicitly asked to change that logic.
- **Edit surgically.** Change only the requested content; don't reformat or re-whitespace whole files.
- **Log every change** to `_AI/history/file-log.md`.

## What you can do

- **Read / search** — find notes by name, content, tag, or folder; summarize notes or sections; answer questions like "what are my goals this year?"; cross-reference across notes.
- **Create** — new notes in the right folder (the default notes folder is named in `vault-map.md`), with frontmatter matching the note type. For periodic/yearly notes, follow the template pattern in `vault-map.md` closely.
- **Edit** — add content (e.g. fill weekly reflection sections), update task status (mark done + ✅ date), append diary/reflection entries, add properly-formatted tasks.
- **Weekly planning support** — summarize the week's Focus, compare it against yearly goals, help fill end-of-week reflections, suggest next-week focus from goals + what's outstanding.

## What NOT to do

- Don't impose a folder scheme the vault doesn't already use — `vault-map.md` states the organising philosophy (flat, foldered, or otherwise). Follow it.
- Don't reorganize vault structure, change existing frontmatter tags/creation dates, or bulk-reformat files without explicit permission.
- Don't confuse ephemeral task-system items with long-term Obsidian goals — different tools, different purposes.

## Edge cases

- Unsure where a note belongs → the default notes folder from `vault-map.md`.
- Creating a periodic note (weekly/monthly/…) → **prefer the app's own create-note command** via the API when one is configured; it renders the template properly and puts the file in the right place, so there is nothing to imitate and nothing to drift. Only if no API is configured, follow the exact filename pattern and section structure in `vault-map.md` — and say plainly that the result is a hand-built imitation of the template, not the template's output.
- Goals vs reflections → these are **two different notes** (one holding task items, one holding narrative), named in `vault-map.md`. Check both; they complement each other.

## Cross-tool automations

Handled by the `personal-assistant` orchestrator, but this skill provides the Obsidian side: populating a weekly note's Focus (from the task system + goals + calendar), writing completed tasks into "Tasks done", comparing Focus vs. what got done, and cross-referencing goals against active task-system items.
