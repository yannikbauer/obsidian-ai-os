# Everyday skills

The skills that run a week: digests, transcripts, meals, money, and a few small habits of
the OS itself. Each one needs a map or an integration file to switch on, and says so when it
is missing. [Back to the README](../README.md)

## Newsletter and job digests

`newsletter-digest` and `job-digest` read the mail you would otherwise skim or ignore, and
keep one note per week, updated every weekday by an optional scheduled run.

- **The newsletter digest** looks for what several independent sources say in the same
  week, what it means for you, suggested todos, events with their registration deadline,
  and a verdict on the newsletters themselves (unsubscribe, keep, try).
- **The job digest** lists every posting from your job alerts, drops duplicates and what you
  already track, scores the rest against your search criteria, and keeps a running market
  log (regions, salary ranges).

**You can trust the inbox afterwards.** Under a standing permission you record in the mail
integration file, each run archives the mail it digested, and keeps in the inbox only the
threads worth a look, writing the reason into the note: an event you might register for, a
posting you should open, a mail it could not read. So a newsletter or alert still in the
inbox was kept on purpose. Archive means removing it from the inbox, nothing else, and only
for senders the map marks archivable. Nothing in a mail can get a thread archived; a mail
can only argue for being kept. Without the permission, the digests ask every time.

Both read mail through read-only subagents (`.claude/agents/`), because mail is the
largest prompt-injection surface the OS touches: the reader can fetch a thread and nothing
else, and its output is data, never instructions.

## Transcripts and the live meeting check

The `transcripts` skill works on what a transcription app drops into the vault: tidy the
note, distil it into decisions and action items, draft the follow-up mail, route a voice
memo's reflections to the diary, search across past meetings. If the transcription tool
exposes the recording while it is still running (MacWhisper does, read by
`tools/macwhisper-live.sh`), you can ask "check the meeting" or "what should I ask?" during a
call and get, in under 120 words, the questions worth raising now and what has been decided
so far. It runs only when you ask; it never polls.

## Meals

`meals` does the admin around cooking: which planned meals got cooked (recorded on the
recipe notes), how many cooking slots the calendar leaves this week, suggestions from your
own recipe notes, and the week's plan on the task-system page. The weekly planning asks one
question, "plan meals this week?", near the top so it is not lost.

## Finances, read-only

`finances` reads balances, positions and spending from your banks, broker and budgeting app,
appends a dated snapshot to a spreadsheet, and keeps a brief for an advisor persona current.
It never trades, moves money or touches credentials; that line is in the skill and in the
framework, not left to judgment.

## Small habits worth knowing

- **Sources lines.** An answer that draws on vault notes ends with a short *Sources* line
  naming each note and section, so you can check it.
- **The local time on every prompt.** A hook adds the current date and time to each message
  (about 25 tokens), so "this morning" and "tomorrow" come from the clock, not from a guess
  based on how long the conversation has run.
- **Usage.** The `usage` skill reads Claude Code's own logs and reports what you spend
  against your session limits, by project and session, compared with a recorded baseline.
- **Demo.** The `demo` skill presents the OS to someone else: what it is, why it is built
  this way, what it has changed, and optionally a strictly read-only live run.
