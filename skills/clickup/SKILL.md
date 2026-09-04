---
name: clickup
description: >
  Manage the user's ClickUp tasks and docs. Trigger whenever the user mentions ClickUp, their tasks, their TODO list, task management, or wants to create/update/search tasks — including "what's on my plate", "add a task", "mark that done", "what did I do this week", or references to their hub doc. Casual asks like "check my tasks" or "I need to remember to…" also trigger it.
---

# ClickUp Task Manager

Full access to the user's ClickUp workspace via the `clickup_*` MCP tools. This skill is generic; the specific workspace IDs, doc IDs, list IDs, structure, and workflow live in the integrations file below.

Read `_AI/integrations/` for the file whose `**Role:**` is `task-system` (e.g. `clickup.md`) before operating. Never guess workspace, list or doc IDs.

**Three states, three different answers — do not collapse them.** If no such file
exists, ClickUp is **not configured**: say so and offer the `setup` skill. If the
file exists but a call fails, errors, or is denied, that is **unreachable**, not
unconfigured — usually a lapsed authorization. Say that, and point at `/mcp` in an
interactive session to re-authorize; **do not send the user to `setup`, which
cannot fix it.** If calls succeed but the IDs disagree with the file, that is
**stale** — offer re-verification. Definitions and the probe live in the `setup`
skill's *Health check* section.

## The model (read this first)

The user runs ClickUp deliberately **minimally** — the value is low-friction capture, so don't add structure. Two layers:

- **Doc checklist items** (in the hub doc named in the integration file) = the primary working surface. `- [ ] thing`, no metadata. Most items live and die here.
- **ClickUp tasks** (in the default list named in the integration file) = the archive layer. Items become formal tasks only when done (for archiving) or when they genuinely need detail/a due date.

When the user says "add a task" or "what's on my plate", start with the **hub doc**, not the task lists — unless they clearly mean a formal task.

## What you can do

- **Claude-owned page** — the task-system doc may designate one page that Claude rewrites in
  full. Which page ids are allowlisted, and the guard to run before each write, are in the
  integration file. It is a **staging surface** the user merges from, not a source of truth.
- **Hub doc** — read it; **append** new items to the end of a page. Adding under a specific section/day, moving items across time horizons, and checking items off all require a full-page rewrite, which is banned (see Safety) — propose those as text for the user to apply by hand.
- **Tasks** — create (default to the list named in the integration file), search by keyword/status/time, update status, list recent/open.
- **Other docs** — read/search whichever reference docs the integration file lists.
- **Weekly support** — gather completed tasks for the Obsidian weekly note; compare the current-week section vs. what got done.

## Safety

**Doc pages: `append`/`prepend` only. Never use `content_edit_mode: replace` on a page that
contains ClickUp chips** — task, doc or view references, which render with icons and live
status badges. `replace` requires sending the whole page back as markdown, and the read
already flattened every chip to a plain link, so the rewrite destroys them all.

The damage is **irreversible and invisible to the API**: a chip and a plain link serialise
identically, so no read-back, diff or snapshot can detect or undo it. Snapshotting does not
make a `replace` safe — restoring the snapshot replays the same flattening.

`append`/`prepend` merge server-side and leave existing content untouched. Write links as
`[label](url)`; bare URLs stay plain text.

Consequence: checking items off, inserting under a specific section, and moving items across
horizons are **manual**. Read the task-system integration file for the tested rules and for
what remains untested. Log doc changes to `history/file-log.md`.

## What NOT to do

- Don't set priority/due-date/assignee/tags on tasks unless explicitly asked — lightweight is intentional.
- Don't restructure the workspace (spaces, folders, lists) or delete docs/tasks without permission.
- When it's unclear whether the user wants a doc checklist item or a formal task, ask.

## Cross-tool automations

Provided to the `personal-assistant` orchestrator: "end my day" (archive completed doc items into tasks in the default list), "start my week" (pull done tasks into the Obsidian weekly note "Tasks done", then mark done in ClickUp), and feeding the current-week section into "what's on my plate" / "plan my week".
