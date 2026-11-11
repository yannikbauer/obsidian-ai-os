---
id: life-coach-quarterly
title: Quarterly review with the Life Coach
cron: "0 11 * 1,4,7,10 0"
description: Quarterly review, the Life Coach checks the yearly goals, the quarter's direction and the goals themselves; interactive; first Sunday of Jan, Apr, Jul, Oct
needs: [notes, maps/advisors-map.md (hub advisor), advisors skill, daily-log skill]
mode: interactive
---
Working directory: {{VAULT}} (the vault root; its CLAUDE.md loads the AI OS framework — follow it).

Start guard: this task fires every Sunday of January, April, July and October. If today's day of the month is greater than 7, stop at once and report "Not the first Sunday: nothing to do." Only the first Sunday of the month runs.

First step after the guard: turn on Remote Control for this session with `set_remote_control` (session_id "self", enabled true; load it via ToolSearch if deferred), so the user can do the review from their phone. If it is refused or unavailable, don't retry; mention it in one short line and carry on. Then send a push notification if the tool is available: "Quarterly review is ready when you are (about an hour)."

Run the hub advisor's (the Life Coach's) **Quarterly review** (mode 9) through the `advisors` skill: `_AI/maps/advisors-map.md` names the prompt note and the plumbing. The review checks the yearly goals and whether the user is on track, summarises what happened in the quarter, shows where things are moving in the right or wrong direction or are stuck, judges whether the goals themselves are good ones and suggests missing ones, and gives what would help get to a better place or stay on track.

This is an interactive session, not an unattended report:
- Do the reading and computing silently first (the mode's *Read* list; numbers only from `_AI/tools/daily-log-stats.py`). If the quarter's last month has no monthly note, do its monthly part first (mode 8) inside this session.
- Then post one short opening: the quarter in three lines and the ratings questions from mode 8, and **wait** for the user's answer. Write nothing before they answer.
- Write only what the user confirms, where the mode says (a `## YYYY Qn review` section under *Intermediate* in the year's Reflections note; goal changes only on their yes, never inside Tasks query blocks or Templater code). Log vault-note changes in `_AI/history/file-log.md`.
- Tone: plain and warm, honest about drift, no moralising, no homework list. If the user is low, follow the prompt's rules and keep it short.
