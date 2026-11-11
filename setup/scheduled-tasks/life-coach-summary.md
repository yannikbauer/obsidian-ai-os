---
id: life-coach-summary
title: Life Coach summary (1st and 15th)
cron: "0 10 1,15 * *"
description: Two-weekly Life Coach summary of the daily log, against the findings ledger and research priors, written to a private vault note; unattended, proposals only
needs: [notes, maps/daily-log-map.md, maps/advisors-map.md (hub advisor), advisors skill, daily-log skill]
mode: unattended
---
Working directory: {{VAULT}} (the vault root; its CLAUDE.md loads the AI OS framework — follow it).

Start guard: if today is before {{START_DATE}}, stop at once and report "Not started yet: first run is {{START_DATE}}."

First step after the guard: turn on Remote Control for this session with `set_remote_control` (session_id "self", enabled true; load it via ToolSearch if deferred). If it is refused or unavailable, don't retry; say so in one line of the final summary.

You run the hub advisor's (the Life Coach's) **two-weekly summary**, unattended. Nobody is present: ask no questions.

Read first:
- `_AI/maps/advisors-map.md`, *Hub advisor*: it names the hub advisor's prompt note, the findings ledger and the summaries note.
- The prompt note, sections *2. Two-weekly summary* and *4. The findings ledger* (you work in that role and format).
- The findings ledger, including its *Research priors* section (what wellbeing research says matters, each with evidence strength, level daily/monthly, fields and gaps).
- `_AI/maps/daily-log-map.md` (fields, scales, *Stats settings*, known confounds) and the `daily-log` skill's *Summary* section (`_AI/.claude/skills/daily-log/SKILL.md`).
These notes are private; the read guard may ask, which is expected.

Compute, never by hand:
- `_AI/tools/daily-log-stats.py summary --since <the 1st or 15th two weeks back> --until <yesterday>`, and `summary` over all days.
- `_AI/tools/daily-log-stats.py week` for each full ISO week in the window.

Write the summary as a new top section of the summaries note (create it if missing, with frontmatter `sensitivity: private`, `tags: [self, health/mental]`, `up:` a link to the prompt note, and a neutral `description:` line "Private running log of the Life Coach's two-weekly summaries of the daily log."). Newest first, heading `# Summary YYYY-MM-DD (window DD Mon – DD Mon)`. Use the notes API (`mcp__obsidian__vault_*`) if Obsidian runs, else the Write/Edit tools; never Bash. Sections:
1. **Week lines** for the window, with days logged, and sport and meditation counts against the targets the daily-log map or the user's profile names.
2. **Top factors** (at most five): direction, size, n per group, the chance check, confounds; lag-1 where it differs. Groups under the map's minimum are "too few days".
3. **Time view:** average hours or minutes per logged day for sleep, movement, people, outside, work, media, hobby, and the substance fields, plus what the `## Done` sections show the days filled with (kinds of activity, not a task list). Set each against the research reference in the matching research prior (sleep 7–9 h and regular bedtimes; ~150 min moderate movement a week; daily social contact; morning light and time outside; a day with structure; nicotine none) and name the one or two biggest gaps.
4. **Against the ledger:** which of the user's own priors and which research priors (daily level only) got support, none, or flipped. Monthly-level research priors are for the monthly review, not this summary.
5. **One proposal:** at most one new ledger entry, one move of a research prior into Seek / Avoid / Unclear, or one experiment (the prompt's rules for experiments). Close with one line on how this fits the current plan the prompt names. No homework list.

Do NOT edit the findings ledger, the map, the daily notes or anything else: ledger changes are proposals the user confirms later. Keep the fields the daily-log map's *Stats settings* mark sensitive out of anything but this private note and your final summary. Append one line for the summary note to `_AI/history/file-log.md` (format in that file).

Finish with a three-line summary for the user: days logged in the window, the strongest factor (with n), and the one proposal. Add one line only if Remote Control failed. Tone: plain and warm, no moralising.
