---
name: calendar
description: >
  Calendar assistant for scheduling and time management. Trigger whenever the user mentions their calendar, schedule, events, meetings, or appointments — including "what's on my schedule", "am I free on…", "schedule something", "when's my next…".
---

# Calendar

Read `_AI/integrations/` for the file whose `**Role:**` is `calendar` (e.g. `calendar.md`) before operating. Never guess calendar IDs.

**Three states, three different answers — do not collapse them.** If no such file
exists, the calendar is **not configured**: say so and offer the `setup` skill. If the
file exists but a call fails, errors, or is denied, that is **unreachable**, not
unconfigured — usually a lapsed authorization. Say that, and point at `/mcp` in an
interactive session to re-authorize; **do not send the user to `setup`, which
cannot fix it.** If calls succeed but the IDs disagree with the file, that is
**stale** — offer re-verification. Definitions and the probe live in the `setup`
skill's *Health check* section.

Access to the user's calendar (read + write) via MCP tools, whatever the provider. This skill is generic; the specific provider, calendar IDs, timezone, and conventions live in the integrations file above.

## Calendar

- The user keeps **several themed calendars**. When reading their schedule, check **all writable calendars**, not just the primary (IDs in the integrations file).
- **"Writable" means listed as writable in the integration file — not whatever the API reports as writable.** A shared resource (meeting room, desk, booking calendar) often accepts writes but holds other people's bookings, so it is neither a record of the user's commitments nor somewhere to create events. The integration file is the authority; never widen the set from a live calendar list.
- Use the timezone declared in the calendar integration file. Never assume one.
- Creating events: pick the calendar by theme (default to primary/Inbox if unsure; ask if genuinely ambiguous). Keep titles short and casual; don't add descriptions/reminders unless asked. Never create on read-only calendars.
- Some calendars are synced task reminders from the configured task system rather than real appointments — the integrations file marks these; surface them as tasks, not appointments.

**Can do:** show schedule (today/week/range), find free time, check availability, create/update/delete events (delete with confirmation), suggest meeting times.

## Cross-tool automations

Provided to the `personal-assistant` orchestrator: "what's on my plate" (calendar + task-system + Obsidian focus), "plan my week" (calendar events as fixed constraints), "am I free for X", and morning briefings (today's events + tasks + important recent email).
