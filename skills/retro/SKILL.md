---
name: retro
description: >
  Turn a session into durable lessons and apply them to the OS itself. Trigger on "/retro", "run a retro", "what did we learn", "capture the lesson from this", "retrospective", or when a Stop hook reports teaching signals. Also runs the consolidation pass that promotes recurring lessons into always-on rules — "/retro consolidate", "promote the lessons", "prune the lessons ledger".
---

# Retro (the learning loop)

The OS produces good lessons and then loses them. `history/session-log.md` is not
auto-imported, so a lesson written there never reaches behaviour. This skill closes
that gap: **extraction is automatic, application is gated by the user.**

```
/retro                extract from the session just had
/retro <session-id>   extract from a past session (backfill, or one I was not in)
/retro consolidate    promote recurring lessons; prune the ledger
```

## Hard rails

1. **Every change is proposed as a real diff and approved individually.** Never apply a
   batch on one "yes". The human gate is the point of the design — it is what caught a
   whole-branch leak that every per-task review had missed.
2. **Never `git add -A`, never `git commit -a`.** Commit only the paths this pass wrote,
   named explicitly. Other sessions run against the same working tree; a blanket add
   silently commits someone else's half-finished work.
3. **Never edit `me.md`.** Identity is asserted by the user, never inferred from how a
   session went.
4. **Never write outside `_AI/`.** No vault notes, so `history/file-log.md` is never
   involved — `_AI/` is version-controlled and git is its audit trail (framework rule 5).
5. **Never quote vault content into a tracked file.** Transcripts contain diary, health
   and financial notes verbatim. State the lesson; cite a session id as the evidence.
6. **≤3 lessons per pass.** Forcing the choice is what keeps them worth reading.
7. **"Nothing to learn here" is a correct result.** Most sessions teach nothing. Never
   manufacture a lesson to have output — a ledger of filler is worse than an empty one,
   because it makes the recurrence count meaningless.

## Extraction pass

**1. Get the evidence.** Run the reducer:

```
tools/session-digest.sh                      # the current session
tools/session-digest.sh --session <prefix>   # a past one
```

It prints the human's own turns, the ones that read as corrections, hook denials,
failed calls and framework writes — a few KB from a transcript of megabytes. Write it
to `tmp/` if it is long. **Never commit a digest.**

Read it *against* your own memory of the session, not instead of it. The digest holds
what happened; you hold why. A lesson usually lives in the gap between the two.

**2. Find at most three lessons.** A lesson is something that would change what a
future session does. Ask of each candidate: *what did this cost, and what would have
prevented it?* Strong sources, in order:

- a **hook denial** — a rule was nearly broken
- a **correction** from the user, especially one repeating an earlier correction
- a **failure that was not caught by the check that should have caught it**
- something that worked and is worth codifying

Not lessons: one-off tool errors, things already written down, restatements of the
obvious, and anything phrased as "be more careful".

**3. Classify each by kind — this decides the destination and the gate.**

| Kind | It is… | Destination | Gate |
|---|---|---|---|
| `tool-fact` | how an external tool really behaves | `integrations/<tool>.md` | apply now |
| `workflow` | an ordered step that worked | the relevant `skills/<x>/SKILL.md` | apply now |
| `rule` | a hard constraint that can be mechanised | a `harness/` hook **and a test** | apply now |
| `disposition` | how to think or verify | `history/lessons.md` as `candidate` | **wait for a 2nd sighting** |

Only dispositions compete for always-on `CLAUDE.md` tokens, so only dispositions wait.
The token budget is what makes this OS cheap; spending it on a lesson that fired once
is how always-on files bloat.

**Prefer a hook to a prose rule whenever the rule can be checked mechanically.** A hook
has a test, runs in milliseconds, and cannot be argued out of its answer. But a hook
that fires on legitimate work is worse than no hook — it teaches its owner to switch
hooks off. If you cannot state the condition precisely, it is a disposition, not a rule.

**4. Check the ledger before writing.** Read `history/lessons.md`. If an existing entry
says the same thing in different words, **add a sighting to it** rather than creating a
new entry — a lesson split across two entries never reaches two sightings and can never
be promoted. This check is the mechanism; skipping it disables the loop quietly.

**5. System-impact check — what did this session make untrue?**

A lesson finds a home for *new* knowledge. This step asks the opposite question: which
existing prose is now **false**? Nothing else in the OS asks it, and the answer is
rarely in the file you edited.

First the mechanical half:

```
tools/check-coverage.sh
```

It fails when an enumeration has drifted — a hook not registered in `settings.json`, a
template `install.sh` never scaffolds, a top-level entry `export.sh` neither copies nor
declares excluded, or prose that states a *count* of hooks or gates. Counts drift and
lists do not, so a count in prose is treated as the bug, not the number in it.

Then the judgment half. Two classes of file, and only the first needs looking at every
time:

- **System-level, always consider.** These describe the whole and rot on almost any
  change: the framework file (`CLAUDE.md`), the README, the roadmap, any explainer or
  brief in `docs/`, the presentation skill, and the three scripts that enumerate the
  tree — `install.sh` (does a new personal file need scaffolding?), `export.sh` (does a
  new folder ship, or is it deliberately left behind?), `publish.sh`. **Do not re-read
  them.** Grep each for the vocabulary of what changed — a `harness/` change greps
  `hook`, `gate`, `Stop`; a new skill greps the skills list and the file tree.
- **The roadmap needs a sharper signal than grep**, because its staleness does not share
  vocabulary with the change. An item still sitting in an active tier after quietly
  shipping, or a `Done` entry that stopped being true, reads as current intent and
  misleads silently. So instead: **read the item numbers this session's commits cite**
  (`git log --format=%s <base>..HEAD | grep -oE '#[0-9]+'`) and re-read exactly those
  items. Precise, cheap, no false positives. Grep the roadmap as well when the change
  altered something the roadmap argues *about* — an effort estimate, a rejection's
  *revisit-if*, a dependency between items.
- **Scoped, only when their subject changed.** A skill's own `SKILL.md`, an
  integration file whose tool behaved differently, `maps/` if the vault's shape moved.

Some of these files do not exist in every install — `docs/` is never exported. A missing
file is normal, not an error.

**A `Done` entry is written at the END of the session, never at the commit that closes
the item.** This is ordering, not detection, and no check substitutes for it: an entry
written when the work "finished" goes stale if the session then keeps going — which is
the normal case, because shipping something is what reveals the next thing to do. If an
entry already exists from earlier in the session, **re-read it as a claim and verify it**
rather than assuming you wrote it correctly.

**Propose new items, never add them.** When a pass finds work it is deliberately not
doing — a rule that wants a hook, a check that wants writing — that is a roadmap
candidate, and leaving it in prose is how it stays lost. Propose it with the same diff
and the same approval as everything else. Which tier it belongs in is the user's call,
not yours: the roadmap is their statement of intent, and an item's *placement* is the
judgment it exists to hold.

**Grep only catches staleness that shares vocabulary with the change.** It raises the
hit rate; it is not a net. And nothing here can tell you an item is no longer worth
doing — only that it looks untrue. When a change alters what the system *claims about
itself* — a new gate, a new folder, a capability gained or dropped — say so plainly and
look rather than grepping.

**6. Propose.** One numbered item per lesson **and per stale claim**: the statement, the
kind, the destination, and the actual diff. Then stop and wait.

**7. Apply what was approved**, update `history/lessons.md`, and commit `_AI/` with only
the paths touched. Add one line to `history/session-log.md` citing the ledger ids rather
than restating the lessons — one statement, one place.

## Consolidation pass

Run occasionally — quarterly, or when candidates pile up. Its whole job is deciding
what earns always-on tokens.

1. **Promote:** every `candidate` disposition with **≥2 sightings** becomes a proposed
   `CLAUDE.md` rule. Write it as an instruction, in the OS's voice, in one or two lines.
   Set status `promoted` and record the destination.
2. **Retire single sightings:** a `candidate` with one sighting older than a quarter did
   not recur. Propose `retired`. It was a one-off, and the ledger said so honestly.
3. **Re-check what is already promoted:** if a `harness/` hook now enforces a promoted
   rule, propose removing the prose. #26's finding applies to this loop too — a rule in
   a hook needs no words in `CLAUDE.md`.
4. **Report `CLAUDE.md`'s line count before and after.** Always. That number is the only
   thing standing between a learning loop and an always-on file that grows forever.

Same gate as extraction: propose diffs, wait, apply, commit named paths.

## The Stop hook

`harness/hooks/suggest-retro.sh` scores each session on mechanical signals and, above
threshold, asks whether to run a retro — **once per session, and only asks.** When it
fires, put the question to the user in one line and accept the answer. Do not run a
retro because the hook fired; do not raise it again if they decline.

It cannot see a purely conceptual lesson, and it fails open like every hook here. It is
a nudge, not a net — invoke `/retro` directly whenever a session taught something.
