---
name: setup
description: >
  Configure, health-check, or re-verify the AI OS's tool integrations. Trigger when the user wants to set up the OS, add or remove a tool, connect a new service, check whether a tool is actually working, or check whether their integration files are still accurate — including "set up my tools", "add Todoist", "are my integrations working?", "check my tools", "is ClickUp connected?", "re-verify my integrations", "my calendar IDs look wrong", or a first run where `_AI/integrations/` is empty.
---

# Setup

Configures which tools the OS uses. A tool is configured **iff** `_AI/integrations/<tool>.md` exists; that file declares its `**Role:**`. This skill writes those files.

**Core principle: observe, don't transcribe.** Hand-copied IDs are the main source of error in this system. Query the live API and write what it returns. Only ask the user for things an API cannot tell you (preferences, conventions, which calendar is for what).

**This skill never writes to the user's tools.** It reads from APIs and writes local files only.

## First run

1. **Probe what is actually reachable.** Run one cheap read per connector — e.g. a calendar list, a task-system workspace/member lookup, a mail label list; the exact tool depends on which connectors are configured. Report what genuinely answered. Do not ask the user which connectors they have; find out.
2. **Show the menu.** List `_AI/templates/integrations/*.template.md` as the suggested tools, marking which are already reachable and which already have an integration file.
3. **For each tool the user picks:** copy its template to `_AI/integrations/<tool>.md`, then populate it by querying the API — real calendar IDs, workspace ID, list and doc IDs. Ask the user only for conventions the API cannot supply.
4. **Set the headers:** `**Role:** <role>`, `**Verified:** <today> (<what was checked>)`,
   and `**Health check:** <the cheap read you just used to probe it>` — record the
   actual call that worked, since that is what every later liveness check will run.
5. **Report** what is now configured and which roles remain unfilled.

## Vault map

`maps/vault-map.md` describes the user's vault. On first run, **propose it by scanning** rather than asking the user to fill in a template:

- folder structure at the vault root (skip anything in `.claudeignore`)
- which folders hold which note types; sample filenames to infer patterns
- the weekly-note filename pattern
- the tags actually in use

Present the proposal and confirm before writing.

## Health check — the three states

**This is the OS's only liveness signal.** `**Verified:** <date>` is a timestamp,
not a health check: it records that a file was once correct, never that the
connector answers now.

Each `integrations/<tool>.md` declares a **`**Health check:**`** header naming the
one cheap read-only call that proves its connector is live. To check a role,
**make that call and look at what comes back.**

> [!IMPORTANT]
> **Test by side effect, never by self-report.** Do not answer "is X connected?"
> by listing the tools you think you have. On 2026-08-26 that method gave three
> wrong answers in a row about this very system — a headless session omitted a
> connector from its self-listing while that connector's tools were resolvable
> and working. Asking a model what it can see is narration; a call that returns
> data is evidence. `claude mcp list` is also *not* an inventory — it never shows
> account connectors. `/mcp` is the authoritative panel, but only a human can read it.

Classify each role into exactly one state:

| State | How you know | What it means | Remedy |
|---|---|---|---|
| **not configured** | no `integrations/*.md` declares this `**Role:**` | never set up | run this skill's first-run flow |
| **unreachable** | file exists; the health-check call errors, is denied, or returns nothing | the connector is not answering — usually a lapsed authorization | **`/mcp` in an interactive session, re-authorize.** Re-running setup will *not* help |
| **stale** | file exists; the call succeeds; returned IDs/names disagree with the file | drift — the tool changed, the file didn't | run re-verification below |
| **live** | file exists; the call succeeds; values agree | working | nothing |

Report one line per role. Never report an absence you did not test — say "not
checked" rather than implying a negative result.

**When to run it.** On request; at the top of re-verification (below); and when
another skill hits a failing tool call and needs to explain why. **Not**
speculatively before ordinary work — the real call is itself the side-effect
test, so let work fail first and classify afterwards. A proactive probe on every
invocation is a token tax for a question that usually has the answer "fine".

## Re-verification

Trigger: the user asks, or something looks stale (a `**Verified:**` date long past, or an ID that didn't resolve).

1. **Run the health check above first.** A role that is *unreachable* cannot be
   re-verified — say so and stop there rather than reporting a spurious diff.
2. For every *live* role, re-query its API.
3. Diff live values against the integration file.
4. **Show the diff and ask before writing.** Never silently correct.
5. On confirmation, update the values and the `**Verified:**` date.

## Adding a tool that has no pack

First check whether it actually needs one. Packs come in two shapes: **role-named packs** (`skills/calendar/`, `skills/mail/`) hold provider-agnostic logic that already works for any provider in that role; **tool-named packs** (`skills/clickup/`) hold logic specific to one product. If the user is naming a *new provider for a role that already has a pack* (e.g. switching calendar providers), that usually needs only a new `integrations/<tool>.md` file pointing at the existing role-named pack — not a new skill.

If the tool genuinely doesn't fit any existing pack, say so, and offer to create a new tool-named pack with the `skill-creator` or `superpowers:writing-skills` skill. A pack is three files: `skills/<tool>/SKILL.md` (generic), `templates/integrations/<tool>.template.md` (menu entry, no personal data), and the user's `integrations/<tool>.md`.

The new integration file's `**Role:**` **must** be one of the fixed role values: `task-system`, `calendar`, `mail`. Don't invent a new role name per tool (not `todos`, not `tasks`, not `task_system`) — the orchestrator only resolves roles from this exact vocabulary, and an invented value silently fails to match. (`notes` is also a fixed role value, but it is substrate owned by the `obsidian` skill and isn't available for a new pack to claim.) If the tool genuinely doesn't fit any of the four, that's a change to the OS's role vocabulary itself, not a setup-time decision — it requires updating `skills/personal-assistant/SKILL.md` and `CLAUDE.md` in the same change, not just adding an integration file.

## Safety

- Confirm before every write. Reading APIs and the vault needs no permission.
- Never put real IDs, emails or names into `skills/` or `templates/` — those ship to other people.
