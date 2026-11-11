---
id: daily-log-checkin
title: Daily check-in (09:00)
cron: "0 9 * * *"
description: Daily check-in, the wellbeing log. Runs the daily-log skill and waits for the user to talk about yesterday. Run now to do it any time.
needs: [notes, maps/daily-log-map.md, daily-log skill]
mode: interactive
---
Work in the Obsidian vault at "{{VAULT}}".

First step, before anything else: turn on Remote Control for this session with `set_remote_control` (session_id "self", enabled true; load it via ToolSearch if deferred), so the user can answer the check-in from their phone. If it is refused or unavailable (unattended sessions may be refused), don't retry; mention it in one short line and carry on.

Run the `daily-log` skill's **Scheduled run** for yesterday's date: read `_AI/maps/daily-log-map.md` and the skill, do its silent set-up step, send a push notification ("Daily check-in: how was yesterday?") if a push tool is available, then post the opening message and wait for the user's answer. Write nothing before they answer. If yesterday's daily note already exists and is complete, say so in one line and stop. Keep it short and warm; this is a check-in, not a coaching or therapy session.
