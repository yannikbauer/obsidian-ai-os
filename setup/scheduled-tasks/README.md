# Scheduled tasks

The recurring tasks this OS runs, one file each, so they live under version control and a new
install (yours on another computer, or someone else's) can set them up from here.

The app keeps the live copies in `~/.claude/scheduled-tasks/<id>/SKILL.md`, and the schedule
in its own task list: neither is in git. These files are the reference; the `setup` skill
installs them and compares them with the app (*Scheduled tasks* in its SKILL.md).

## Format

```
---
id: <task id in the app>
title: <name shown in the task list>
cron: "<5-field cron, local time>"
description: <one line>
needs: [<roles, maps or skills the task depends on>]
mode: unattended | interactive
---
<the prompt, exactly as the app gets it, with placeholders>
```

**Placeholders** (filled in at install, never committed with real values):

| Placeholder | Meaning |
|---|---|
| `{{VAULT}}` | absolute path of the vault root (the folder holding `_AI/`) |
| `{{START_DATE}}` | first day a task may run, `YYYY-MM-DD`; drop the guard line if unused |

## Rules

- **Generic only.** No names, addresses, people, dates of personal requests or anything else
  personal: the prompts point to the skills and maps, which hold the specifics.
  `setup/leak-check.sh` scans this folder with the rest of the export.
- **Same text as the app.** The live prompt is this file's body with the placeholders filled.
  Change the prompt here and in the app together; the setup skill's comparison reports drift.
- **Recurring tasks only.** One-off reminders don't belong here.
- **Install only what the setup supports.** A task whose `needs` aren't configured (no mail
  role, no daily-log map) is not offered.
