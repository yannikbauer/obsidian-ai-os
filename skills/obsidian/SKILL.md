---
name: obsidian
description: >
  Read, create, edit, and search notes in the user's Obsidian vault (personal knowledge base). Trigger whenever the user mentions Obsidian, their vault, their notes, weekly notes, weekly planning, goals, reflections, diary, or their personal wiki — including casual asks like "check my notes" or "what are my goals".
---

# Obsidian Vault Assistant

Read/write access to the user's Obsidian vault (plain markdown files). This skill is generic; the specific folder layout, prefixes, tags, and conventions live in **`_AI/maps/vault-map.md`** — read it before working in the vault.

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
- Creating a weekly note → follow the exact filename pattern and section structure given in `vault-map.md`; don't invent either. The user usually creates these via Templater, so check before creating one at all.
- Goals vs reflections → these are **two different notes** (one holding task items, one holding narrative), named in `vault-map.md`. Check both; they complement each other.

## Cross-tool automations

Handled by the `personal-assistant` orchestrator, but this skill provides the Obsidian side: populating a weekly note's Focus (from the task system + goals + calendar), writing completed tasks into "Tasks done", comparing Focus vs. what got done, and cross-referencing goals against active task-system items.
