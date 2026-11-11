---
name: daily-log
description: >
  Daily wellbeing check-in: the user talks for a minute or two about the previous day, the skill turns it into one structured daily note (frontmatter as data: mood, energy, anxiety, sleep, movement, people, work, substances, place and more), asks only for what is missing, adds one rotating question, and ends with at most one factual feedback line when a watch rule fires. Also gives the weekly averages line for the Monday review and computes the numbers for the Life Coach's two-weekly summary. Trigger on "daily check-in", "do my daily check-in", "daily log", "check-in", "log yesterday", "log today", "morning check-in", "/daily-log", "how was my week in numbers", "what's good for me", "analyze my log", "log summary", or from the scheduled 09:00 run. (A "morning briefing" of today's agenda is the personal-assistant's, not this.)
---

# Daily Log

Read `_AI/maps/daily-log-map.md` first: fields, scales, the note's location and name, the
rotating questions, the watch rules, privacy. **No map = not set up**: say so and offer to
build one; never invent fields. Uses the `notes` role. The map is the schema: if this file and
the map disagree, the map wins.

**What this is not.** Not a therapy session and not a coaching conversation. Keep it short,
warm and plain. Don't interpret the day, don't moralise, don't turn a feeling into a task. If
the user wants to talk more, say that's better with the support the map names, or carry on
only if they ask.

## 1. Set up (silent, before the first message)

- **Which day.** Default: yesterday. After 18:00, or when the user says "today", log today.
  The user may name any other date ("log Sunday"). Read the answer for the day it is about:
  facts and ratings about today go into today's note as *same-day, partial* (the map's rule),
  and when it is unclear which day a rating covers, ask in the follow-up.
- **Done items** for the logged day from the task-system's done archive (the map's *Done*
  section names where), for the note's *Done* section. They also help the readback suggest a
  best moment when the user can't recall one.
- **Catch-up from elsewhere.** If the user pastes or points to a check-in held somewhere else
  (a phone session, a chat), treat that text as their free talk for step 3, keep their dates,
  and ask only for what is still missing. A `# daily-log import` YAML block (the Life Coach
  project's phone check-in ends with one) maps onto the fields key for key; its `day:` text
  becomes the *Day* section. Still do the readback before writing.
- **Existing note** for that date → **update mode**: fill only empty fields, keep the rest, and
  say so in the readback. Never overwrite a filled field without the user saying so.
- **Last 14 notes**, frontmatter only, for the watch rules and streaks. Read them through the
  notes API or `Read`; they are private, so the read guard may ask once.
- **Auto-filled fields** (the map's Tier 3, e.g. weather): fetch them once `place` is known,
  from the source the map names. A failed fetch leaves them empty and is mentioned only in the
  readback; it never blocks the check-in.
- **Watch fields** (the map's Tier 4), when a wearable integration exists
  (`integrations/freddy.md`): one `query_metrics` call per Garmin date the map's date rule
  needs (D for day fields, D+1 for night fields), before the opening message. Offer the
  measured sleep in the opening or the follow-up as a suggestion for `sleep_h` ("watch says
  7.6 h, right?"); never fill a rating from it. Missing night data → the integration's
  sync-and-retry once, then leave it empty.
- **Calendar pre-fill** (always, when the calendar role is configured): the logged day and
  today, across the writable calendars in the integration file (events with people, travel →
  `place`, `day_type`). Mention what you saw in the opening, so the user can confirm instead of
  retell. Use it to ask better, never to fill a rating. One failed connector → try the other
  calendar connector before giving up.
- **Gaps for the catch-up** (only when a wearable integration exists): list the days in the
  wearable's reachable window (the integration says how far back) that have no note. They
  are handled in step 6a, after the day being logged; mention them in the readback.

## 2. Open

One short message. Name the day, invite free talk, and give the core in one line so they can
cover it without being asked. Example:

> Morning. Tell me about Tuesday: sleep, who you saw, what you did, how it felt. Just talk.
> (Mood, energy, anxiety 1–10; 5 = an ordinary day right now.)

Read the scale anchors out on the first few check-ins (fewer than 7 notes), then only the
short form.

## 3. Extract, then ask once

- Map what the user said onto the fields: **Tier 1 and Tier 2** from the map. Words → numbers
  per the map's rule, and say which number you picked.
- Tier 2 is extracted only, **never asked**. Not mentioned → empty.
- **Missing Tier 1 → one follow-up message**, all missing items in it, compact, grouped as the
  map's quick sweep if it has one, e.g. "Night: woke up? anything taken? · Day: time outside,
  caffeine?". Never ask one field per turn.
- A Tier 2 field the map marks with an "ask it when" condition may join that follow-up when
  its condition holds (e.g. what helped after a bad night). Nothing else in Tier 2 is asked.
- **Guess and sign off** for the fields the map marks as guessable: when the user didn't say,
  put your guess and what it rests on into the follow-up, so a yes settles it. A guess is
  never written without that yes; no answer leaves the field empty.
- If the user says "skip" or "don't know" for a field, leave it empty. Don't push.
- `themes`: reuse tags that already appear in recent notes before inventing a new one.

## 4. Rotating question

Pick it by the map's rule (id from the logged date). Ask it in the same message as the
follow-up, or alone if nothing is missing. Skippable; on a skip, drop it without comment.

## 5. Readback = confirmation

One compact block, the fields as `key value` pairs on two or three lines, plus the two
body sections in a sentence each. End with "Save?" A yes, or a correction, is the confirmation
to write. Writing a daily note is the user's own request, so no further approval is needed.

## 6. Write

- Path, name and frontmatter order from the map. Body sections from the map's template. No
  `- [ ]` checkboxes (Tasks queries would pick them up).
- Route: the notes API (`mcp__obsidian__vault_write` / `vault_patch`) when Obsidian runs, else
  `Write`/`Edit`. **Never Bash.** A frontmatter `vault_patch` re-serialises the note's
  whole frontmatter (empty keys become `null`, lists go multi-line). It
  parses the same, but for update mode prefer reading the note and writing it whole.
- Empty fields are written as the key with no value, so every note has the same keys.
- **Diary link** (if the map names a diary): add the day's heading to the diary in its date
  format, newest first, below the frontmatter, with one line linking the new note. If the
  heading exists already, add only the link under it. Check-in notes only, not catch-ups.
- Log one line in `_AI/history/file-log.md` per note touched: `[create]` or `[edit]`, path, "daily log".

## 6a. Catch-up of missed days

A wearable's history may only be reachable for a few days (see its integration file). So
every gap found in step 1 gets a **watch-only note** in the same write, so the body's data
survives the window:

- Same path, name and keys as a full note; `source: catch-up`. Only the fixed fields, the
  watch fields and the weather are filled. Ratings and everything he would have said stay
  empty. Never guess a rating.
- `place`: from the calendar for that day, else the nearest note's place. Say which in the
  readback ("Fri, Sat: watch-only, place berlin from the calendar").
- No body sections, no rotating question.
- Never touch an existing note here; that's update mode, on his word.
- If he later logs one of those days, it's update mode: fill the empty fields and set
  `source: check-in`.

The readback's "Save?" covers these notes too. Log each in the file log.

## 7. Feedback line

Check the map's **watch rules** against the new note plus the last 13. The **first rule that
fires**, as one plain line, facts with numbers ("5 days without movement; sleep under 6.5 h
the last 2 nights" is two rules: give only the first). None fires → say nothing more than
"Saved." Low-day rule → follow it exactly, and give no other feedback that day.

## 8. Blind spots

The log is meant to grow. Follow the map's *Blind spots* section: after "Saved.", at most one
question about a factor the user mentioned that no field covers, or one idea for improving the
check-in itself, and only with evidence from this conversation. Most days, ask nothing. An
accepted factor is added to the map (with its date) after the user's yes; never to the
schema silently.

## Week line (Monday review)

When the planning or review flow calls this skill: run
`_AI/tools/daily-log-stats.py week` (last full week, or `--week YYYY-Www`) and give the map's
one-line summary (averages of the outcome fields, days logged). Outcome averages only:
no substance or relationship fields in this line. Then the map's weekly blind-spot scan: last
week's weekly note and calendar against the log's fields, up to two candidate factors, each
with where it was seen. If the wearable window holds days without a note, offer the catch-up
(step 6a) as one line; write on a yes.

## Summary (every two weeks, and on request)

This skill computes; the **Life Coach** interprets. The coach owns the findings ledger, the
experiments and what the numbers mean (the hub advisor in `maps/advisors-map.md`, reached
through the `advisors` skill). Which fields count as sensitive or pre-registered is the map's
*Stats settings* section, not the script.

1. Run `_AI/tools/daily-log-stats.py summary` (add `--since`/`--until` for a window). It reads
   only, and computes the same way every time: groups per factor, same day and lag-1, by
   place, n per group, "too few days" under the map's minimum, a chance check per row,
   factors that travel together, themes on 5+ days, experiment days. Don't recompute by
   hand; if the script lacks something, say so and propose the change to it.
2. Add the confounds the map lists, and propose `themes` tags that reached the threshold as
   new fields.
3. Hand the output to the Life Coach's two-weekly summary. Ledger entries and tests are its
   proposals, written only after the user confirms and logged in the file log.

## Scheduled run

The 09:00 task starts a session with this skill. Nobody may be there yet:

- Do step 1, send a push notification ("Daily check-in: how was yesterday?") if the tool is
  available, then post the opening message (step 2) and **wait**. Don't write anything
  before the user answers.
- If a note for the day already exists and is complete, say so in one line and stop.

## Privacy

The notes are private (map). Never put log fields into the task system, the calendar, mail,
commit messages or anything shared. Don't quote substance or relationship fields back
outside the check-in and the summaries.
