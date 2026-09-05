---
name: demo
description: >
  Present this AI OS to another person — what it is, what it does, how it works, why it is built the way it is, what it has already changed, and what is on the roadmap. Optionally runs a live, strictly read-only demonstration against the real system. Trigger on "/demo", "demo the AI OS", "show someone the OS", "explain this system to a visitor", "give an overview of the OS", "walk someone through this".
---

# Demo (presentation layer)

Presents the OS to an audience. This skill holds the **arc, the register and the
rails** — it does not hold the facts. Facts are read at point of use from the docs
listed below, so the demo cannot drift from the system it describes.

Everything here happens in front of someone who is not the user. That single fact
sets every rule below.

## Hard rails — not negotiable

1. **Read-only. Always.** This skill never writes a vault note, task, calendar
   event, mail draft, or git commit; it never runs `install.sh` or `export.sh`.
   If a demo beat seems to need a write, describe the write instead. Say so out
   loud when it comes up — the restraint is itself part of what is being shown.
2. **Never-surface categories.** Content in these classes is referred to *by
   category only*, never by content, and the underlying notes are never opened
   during a demo: health and medical; therapy and mental health; diary and private
   reflection; finances, salary, inheritance, investments; anything with legal
   exposure; active job applications and their counterparties; named third parties
   who have not consented to being in the room. A calendar item in one of these
   classes renders as "a health appointment, 14:00" and nothing more.
3. **Load the private block-list if it exists.** If `_AI/leak-patterns.local` is
   present, read it and treat every pattern as a substring that must not appear in
   any output. It is private and never exported (the export is an allowlist and leaves every `.local` file behind); absence is normal, not an error.
4. **Pre-flight gate — run it before anything reaches the screen.** Read what is
   actually on the board for the demo window, then ask the *user* (not the
   audience): "Here is what today's data contains — anything you want kept off
   screen?" One question, once, before the first live beat. The human is the gate;
   the categories above are the floor, not the ceiling.
5. **Never speculate about the audience.** If the demo is for someone whose
   relationship to the user matters (an employer, say), stay inside what the user
   authorised in the opening question.

## Context to load

Read lazily, in this order, and only what the chosen length needs:

- **Always available** (session-start imports): `_AI/CLAUDE.md`, `_AI/me.md`,
  `_AI/maps/vault-map.md`.
- `_AI/docs/aios-interview-brief.md` — the architecture, workflows, hard problem,
  what has already changed, and limitations. **Any section marked `KEEP OUT of
  demos` is off limits**: do not read it, quote it, or summarise it. Some sections
  of that file are written for a different audience entirely, and the marker is
  the authority on which — do not infer it from a heading.
- `_AI/docs/roadmap.md` — the tiers and the item numbers, for the roadmap beat.
- `_AI/README.md` — install path and the two-registry model, if asked.

**Degrade gracefully.** `docs/` is not exported, so a cloned copy of the OS will
not have the brief or the roadmap. If they are absent, run beats 1–4 and 7 from
`README.md` + `CLAUDE.md` alone, and say plainly that the detailed write-ups are
private to the original install rather than improvising their content.

## Opening — one question, then start

Ask once, compactly: **who is watching, how long do we have, and is a live run
against real data OK today?** Then pick a length and go. Do not interview the user.

- `/demo` — **≈5 minutes.** Beats 1, 2, a compressed 3, 4, 5, 7.
- `/demo full` — **≈15 minutes.** All beats.
- `/demo overview` — **no live run.** Beats 1, 2, 3, 5, 6, 7.

Adapt register to the answer: a peer gets the architecture and the seams; a
non-technical audience gets beat 1, a compressed beat 4, and one honest sentence
from beat 3. Never run the full architecture beat at someone who did not ask for it.

## The arc

**1. The hook — the problem, not the tooling.** Four systems (notes, tasks,
calendar, mail) with no shared schema, each holding a partial and slightly wrong
picture of the same week. No single view exposes the disagreement, and the
disagreement is exactly where things get dropped. Open here. Never open with
"I automated my to-do list."

**2. What it is.** A context layer plus a skill library, versioned in git, that
turns a general-purpose coding agent into a personal assistant — with the vault
itself as the substrate instead of a database. Show the real artifacts: the
six-line root `CLAUDE.md` stub, the `_AI/` tree, the fact that orchestration is
prose in `skills/personal-assistant/SKILL.md` and that there is no runtime, no
state machine, no code. Quote the line count from the brief rather than guessing it.

**3. Why it is built this way — three seams.** This is the beat with the actual
engineering content.
- *Generic vs. personal.* Skills describe how to operate a **role**; everything
  identifying lives in `integrations/` and `maps/`, which never ship. The seam is
  enforced by `export.sh`'s leak check, which greps a candidate export and aborts
  the publish on a match — mechanically, not by discipline. Say why that matters:
  a real merge once shipped hardcoded timezone and language into files meant to be
  provider-agnostic, and every per-task review missed it.
- *Always-on vs. on-demand — the token economy.* A thin core is imported at
  session start; a skill advertises itself by name and description and loads in
  full only when triggered; an integration file is read at point of use by the one
  skill that needs it. A session begins knowing *who* and *where*, and pays for the
  *how* only when it acts.
- *Existence is configuration.* A tool is configured if and only if
  `integrations/<tool>.md` exists. No registry, no enable flags, no schema to
  drift. Delete the file and the skills say "that isn't set up" instead of
  inventing a stack.

**4. Watch it work — live, read-only.** Run the pre-flight gate first. Then pick
by where the week actually is (compute the ISO week and weekday; do not assume):
- **Default, any day: the cross-tool drift check.** Commitments on the calendar
  that never reached the task system, task-system days that contradict the
  calendar, stale waiting-on items. This is the strongest beat because it is the
  part that is more than convenience — the manual version means opening four apps
  and diffing by eye, weekly, forever, which is precisely the chore that does not
  survive a low-energy week.
- **Monday: weekly planning.** Include the codified check that the query window
  runs one week *past* the horizon.
- **Mid-week: narrate, do not re-run.** The weekly note is already populated by
  then. Read it and say what a re-plan *would* change and why. Reasoning about
  existing state demos better than a blank slate, and it is honest about the day
  it is. Never overwrite, never pretend it is Monday.
- **Friday: the mechanical wrap-up** — completed Focus items, carry-overs, and the
  cancelled-versus-slipped distinction.

**5. What it has already changed.** Read the brief's *What has already changed in
practice* subsection, and give two or three of the dated items — not all
of them. The point is that the system changed the workflow rather than merely
describing it: the weekly loop is codified rather than remembered, drift checking
became part of planning instead of an occasional cleanup, the planning window
widened by a week after a near-miss, and a machine-writable surface exists where
previously every edit was applied by hand. Keep the counterweight attached: the
gains are in *catching* things, evidenced by dated sessions; there is no
minutes-saved measurement and none should be claimed.

**6. What it cannot do yet.** Do not skip this, and do not soften it — with a
technical audience the honesty buys more credibility than it costs. Writes to the
task system are deliberately constrained after a test proved a whole-page rewrite
silently destroys rich content; nothing runs on a schedule, so every workflow
starts because a human opened a session; there is no search index; the accumulated
lessons are written down but not yet fed back into behaviour, so it is a
well-organised archive rather than a learning system; and it has one user and a
short history, so everything above is n=1. State that last one plainly.

**7. The roadmap — three items, not sixteen.**
- *Agentic vault cleanup on a local model tier* (roadmap #11 + #15, one piece of
  work). Bulk mechanical relabelling across the notes, human-gated diffs,
  git-snapshotted per batch, run overnight on a small local model. Get the
  reasoning right: running it **locally dissolves the sensitivity blocker** rather
  than working around it — nothing leaves the laptop, so the privacy question and
  the cost question land on the same solution.
- *A sensitivity boundary* (#8). Now valuable on its own merits rather than as a
  prerequisite. The instructive part is why the obvious design fails: an in-band
  `sensitive: true` frontmatter flag cannot work, because a read returns
  frontmatter and body atomically — by the time the flag is visible the body is
  already in context. Enforcement has to sit at the tool boundary.
- *A search index* (#10). The largest item. Today, finding something means scanning.

**8. Offer the leave-behind.** Ask whether they want a page they can keep. If yes,
load the `artifact-design` skill, build it, and publish it as a private artifact —
architecture, the three seams, what has changed, limitations, roadmap. The rails
above apply to the page exactly as they apply to the screen.

## Register

Concise and casual, per `me.md`. Lead with problems, not features. Prefer showing
a real file over describing it. Concede limitations early and without hedging —
the write freeze and the n=1 are the most credible things available, because
shipping less automation than was built, on purpose, is a claim most demos cannot
make. Do not oversell: this is a small distributed-systems problem solved with
prose and version control, not a product.

## Does NOT

Write anything, anywhere, under any framing. Read any section the brief marks
keep-out. Open the
diary, therapy, health, financial or job-application notes. Name third parties.
Improvise facts when `docs/` is absent. Ask the audience questions — the user runs
the room, this skill supplies the material.
