# Daily log

A spoken daily check-in that turns into data. [Back to the README](../README.md)

The `daily-log` skill is a spoken check-in: you talk for a minute or two about the
previous day, and it writes one daily note whose frontmatter is the data (mood, energy,
sleep, movement, people, work and more), asking only for what you left out. The schema is
not in the skill but in `maps/daily-log-map.md`, so the fields are yours to choose; without
that map the skill says it is not set up rather than inventing any. Calendar events and,
if you have a wearable integration, watch data are offered as suggestions, never filled
into a rating.

`tools/daily-log-stats.py` turns the notes into numbers the same way every time: a weekly
averages line for the Monday review, and a two-weekly summary that compares days by
factor, each number with its n. An advisor reads the summary and does the interpreting
(see below); the script never does. The notes are private by folder label, and the
optional scheduled check-in only opens a session and waits for you.

## How a check-in runs

1. **Before it says anything**, the skill reads the last two weeks of notes (for its watch
   rules), the day's calendar, the task system's done list, and, with a wearable connector,
   the night's sleep and the day's activity. None of that fills a rating: it lets the opening
   say "you had dinner with two friends and slept 7.6 h by the watch, right?" so you confirm
   instead of retelling.
2. **You talk.** One prompt, free speech, dictation is fine.
3. **It asks only for what is missing**, plus one rotating question from the map.
4. **Readback, then write.** One note per day, in update mode if it already exists (it fills
   empty fields and never overwrites a filled one unasked).
5. **At most one feedback line**, and only when a watch rule in the map fires (for example
   three short nights in a row). Factual, never a lecture.

Missed days within the wearable's reach get a *catch-up* note with the watch fields only, so
a gap in talking is not a gap in the data. A check-in held elsewhere (a phone chat with an
advisor that ends in a `# daily-log import` block) is accepted as the talk for that day.

## Scheduled, but never automatic

The optional morning task (`setup/scheduled-tasks/daily-log-checkin.md`) only opens a
session and waits. A session-start hook also offers a missed check-in once a day when you
open the OS for anything else. Nothing writes a daily note without you in the loop.

## Privacy

The notes are health data. They sit under a folder label (`private`) in
`config/sensitivity.local`, so the read gate asks before an agent opens one, search returns
them as pointers, and the stats script can leave the fields the map marks sensitive out of a
summary (`--no-sensitive`).
