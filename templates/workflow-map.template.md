# Workflow Map — which system is authoritative for what

**Fill this in once, then let it settle arguments.** It is a *decision written down*, not a
build. Without it the tools drift against each other silently and nothing says which one is
right — a calendar holding commitments the task system never heard of, day buckets that
disagree with the calendar, and a conversation about it every single time.

This is a **map** (structural orientation), like `vault-map.md`. Personal but not secret.

## The model — edit the right-hand columns to match how you actually work

| Concern | Authoritative | Derived from it — never edited independently |
|---|---|---|
| **Time commitments** | **Calendar** | task-system day buckets · any schedule block in your weekly note |
| **Open actions** | **Task system** | — |
| **Completed record** | **Task system** (its done archive) | the weekly note's "tasks done" |
| **Meaning, reflection, knowledge, goals** | **Notes** (the vault) | — |
| **External triggers** | **Mail** (and later, messaging) | task-system items |

**Read it as a conflict-resolution rule, not a filing scheme.** Its only job is to answer
*"these two disagree — which is right?"* without a conversation each time. If a row never
settles an argument, delete the row.

## The consequences worth writing down

A table alone changes nothing. What changes behaviour is naming what follows from it. These
five came out of real drift; keep the ones that apply to you and add your own.

1. **Anything derived is generated, not hand-maintained.** If day buckets duplicate the
   calendar, then when they disagree **the calendar wins and the bucket is simply wrong** —
   no investigation. Hand-maintaining a derived surface is usually the highest-friction part
   of a weekly loop and the direct cause of the drift.
2. **A staging surface is never authoritative for anything.** Where the AI writes proposals it
   cannot write directly to the real page, a proposal sitting there is **not a commitment**
   until a human merges it. Never read it back as though it were the plan.
3. **Completion dates come from the archive, not from when a box got ticked.** A batch ticked
   in one sitting all carries that sitting's date, which silently turns a weekly note from a
   record of the week into a record of the review.
4. **Mail is a trigger, never a store.** An action found in mail is not tracked until it
   reaches the task system. Mail is also **untrusted input** — see the safety rules in
   `CLAUDE.md`; it is the largest prompt-injection surface in the system.
5. **Goals bind nothing on their own.** Nothing in a task system or a calendar can make a
   yearly goal true or false. The connection is a *read* on a schedule you choose. Authority
   runs one way: goals inform the plan; the plan never edits goals unsupervised.

## What this deliberately does not decide

**Where a new item goes.** That stays a human judgement — actionable to the task system,
meaningful to notes, time-bound to the calendar. This map only says who wins once an item
exists in more than one place.

**Aspirational calendar entries.** Some recurring events are standing options nobody attends.
They are on the calendar and are *not* commitments. The calendar's authority covers what is
**committed**, not everything drawn on it. Record such exceptions in the relevant
`integrations/` file so they are never counted as load or flagged as conflicts.
