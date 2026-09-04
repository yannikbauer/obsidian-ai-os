---
name: personal-assistant
description: >
  The default app of the AI OS — the orchestrator that combines Obsidian (notes) with whichever task-system, calendar, and mail tools are configured into unified workflows. Trigger for any compound request spanning multiple roles, or high-level asks like "plan my week", "what's on my plate", "start/end my day", "end my week", "what fell through the cracks", "morning briefing", or any general personal-productivity request that doesn't obviously belong to a single role. When in doubt, this is the default.
---

# Personal Assistant (Orchestrator)

The default app running on the AI OS. It figures out which roles to involve and runs the compound workflows below. It doesn't replace the tool skills — it coordinates them.

## Context to load

- **Always available** (imported at session start): `_AI/me.md`, `_AI/maps/vault-map.md`, `_AI/CLAUDE.md`.
- **Resolve roles at point of use.** List `_AI/integrations/*.md` and read each file's `**Role:**` line to build the role → tool map. Roles are `task-system`, `calendar`, `mail`. The `notes` role is always filled by the vault itself (see `maps/vault-map.md`).
- **Then load only what the command needs** — read the integration file for each role the command actually uses. Don't guess IDs; don't preload.
- **If a role is unfilled**, skip that step, say so once and briefly, and carry on. Never describe a tool the user has not configured.
- **Distinguish unfilled from broken.** No integration file = *not configured*. A file that exists but whose calls fail = *unreachable*, which is a lapsed authorization, not a missing setup — name it as such and point at `/mcp`, because telling the user to run `setup` sends them somewhere that cannot help. Never report a role as absent without having actually attempted a call; say "not checked" instead. The `setup` skill's *Health check* section holds the definitions.
- **The tool skills provide the mechanics for each role** (notes, task-system, calendar, mail); this skill sequences them — it does not operate tools directly.

## How the roles relate

- **notes** = persistent knowledge and meaning (goals, weekly notes, reflections). **task-system** = the ephemeral working surface (what to do, what got done). **calendar** = fixed time commitments — the skeleton. **mail** = trigger and reference source.
- Weekly sync: completed task-system items → the weekly note's "Tasks done". Calendar events are constraints that tasks fill around. Goals inform task priorities.

## Core commands

**"Plan my week" / "Start my week"** — 1) read the current weekly note (pattern in `maps/vault-map.md`; don't create it — the template does). 2) read the task-system's current + week views. 3) fetch this week's events across all writable calendars. 4) check public holidays if the calendar integration lists a holiday calendar. 5) scan recent mail for anything time-sensitive (skip if no mail role). 6) synthesize: committed (calendar) + to-do (task-system) + focus (goals) + mail items; suggest how to distribute tasks across free days. Offer to populate the weekly note's Focus.

**"What's on my plate?" (today / this week)** — calendar events for the period across all writable calendars + current/day items from the task-system + this week's Focus from the weekly note. Present grouped by time-of-day (today) or by day (week).

**"End my day"** — check what got done in the task-system; offer to archive completed items from the task-system's checklist doc into its task layer; preview tomorrow's events across all writable calendars; surface anything planned-but-not-done.

**"End my week" / "Weekly review"** — run the six steps below, in order. Never write the
whole reflection in one shot: the objective half is yours to draft, the subjective half is
the user's to answer, and the write happens after they have answered.

1. **Gather.** Read the task-system's done-items archive for the week (for a `task-system`
   with a doc layer, that is its archive page — see the integration file; do **not** trawl
   the task layer). Read the weekly note. Pull the week's events from all writable
   calendars, and scan mail for anything that landed as a result of the week's work.
2. **Sync "Tasks done".** Write the archived items into the note's `# Tasks done`,
   **hierarchy preserved**, grouped by day. Diff first — if items are already there from an
   earlier run, append only the new ones. Never invent a parent for an orphaned child.
3. **Score the Focus.** Compare the beginning-of-week Focus against what actually happened.
   State the count plainly (e.g. "4 of 6"), and say which slipped and why if the calendar or
   the archive shows it.
4. **Recap the week back to them** — days as headers, then name the *threads* that ran
   across the week rather than relisting items. This is where the value is: the user already
   knows what they did, not what it added up to.
5. **Draft the objective sections, ask for the subjective ones.** The weekly note's
   reflection sections are listed in `maps/vault-map.md`; split them the same way every
   week. Claude **proposes** the sections that are evidence-backed — what was achieved,
   what was learned, where the user had an effect — drawing on the archive, the calendar
   and the note. Claude **asks** for the sections that record how the week *felt* —
   highs, lows, and what to continue or change — and never guesses them. Feelings are not
   inferrable from a calendar, and a wrong guess in a reflection note is worse than a
   blank line. Ask any specific open question the week raised (an unrecorded decision, an
   unshifted event).
6. **Write, then check the consequences.** Only after the user answers. Then surface
   anything their answers imply elsewhere — a decision that needs a calendar event shifted,
   a carry-over that belongs in next week's Focus.

Corrections the user makes to your draft are data: if they strike an item you inferred
("didn't attend"), drop it silently and don't re-propose it.

Finally, **ask** whether to clear the done-items archive, or whether they will. Follow the
standing answer in the integration file if there is one.

**"Morning briefing" / "Start my day"** — today's events across all writable calendars + today's task-system items + important recent mail (last 24h, skip newsletters/receipts, skip if no mail role) + this week's Focus. Keep it a quick scan.

**"What are my goals? / How am I doing?"** — read the yearly goals note (pattern in `maps/vault-map.md`); cross-reference with active task-system items; check whether the week's Focus aligns; highlight goals with no active tasks.

**"What fell through the cracks?"** — compare this week's Focus + earlier task-system items against what got done and the calendar; surface planned-but-incomplete items.

**"Reflections"** — weekly (current weekly note's reflection sections) and/or yearly (yearly reflections note, pattern in `maps/vault-map.md`); summarize themes if asked.

## Operating principles

- Concise, casual, clean structure (per `me.md`). Days-as-headers for weekly views; time-of-day for daily.
- Read freely; confirm before writes (vault notes, task-system items, calendar events); draft-never-send for mail.
- Always check the current ISO week to find the right weekly note.
- Ambiguous "help me get organized" → default to "plan my week" (Monday) or "what's on my plate" (mid-week). Actionable items → task-system; knowledge/reflection → notes.

## Weekly rhythm

The user's rhythm is described in `me.md`. Follow it there rather than assuming a fixed schedule.

## Does NOT

Replace the tool skills; decide life priorities (it presents, the user decides); auto-send mail or auto-publish; create weekly notes from scratch (the template's job — this populates sections).
