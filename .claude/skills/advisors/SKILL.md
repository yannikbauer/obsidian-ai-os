---
name: advisors
description: >
  Entry point to the user's personal advisors (coach, therapist, career coach, chef, financial advisor and the like), each defined by a prompt note in the vault and mirrored into a Claude Desktop project for the phone. Loads the right prompt note and its start-of-session reading, then runs the session in that advisor's role under the AIOS rules, with the matching AIOS skill doing the admin. Also builds the project stubs, adds a new advisor and migrates an existing Claude project into the vault. Trigger on "advisor", "life coach", "coach", "talk to my coach", "psychotherapist", "therapist", "career coach", "chef", "financial advisor", "finance advisor", "two-weekly summary", "what's good for me", "vision check", "propose an experiment", "how did the experiment go", "project stub", "refresh the stub", "add an advisor", "migrate my Claude project", "/advisors", any advisor name or persona in `maps/advisors-map.md`, or when the user asks which advisor fits a question.
---

# Advisors

The advisors are personas, not skills. Each lives in **one prompt note** in the vault, which
is also the source for its Claude Desktop project: the project holds only a stub plus a
fallback copy, and the note wins. This skill opens a session with one of them; the admin
behind each advisor stays in its own AIOS skill.

**Pattern:** persona and judgment → prompt note. Procedures, data and writes → skill. Which
advisors exist, their notes, start-of-session reading, phone docs, the hub advisor's modes
and privacy rules → **`_AI/maps/advisors-map.md`**. Read it first. No map → no advisors are
configured yet; offer to add one (below).

## Why it's built this way

A Claude Desktop project alone has four problems: its knowledge files go stale against the
notes, its memory lives in the cloud where nothing else can read it, the phone can't reach the
vault, and one project can't see another's. So the vault is the master, and the project is a
thin front-end for the phone:

| Layer | Lives in | Role |
|---|---|---|
| Prompt note | vault | persona, judgment, the advisor's file map; the only place the prompt is edited |
| Working notes | vault, `<Advisor> _ <Topic>.md` | what the advisor knows and keeps; as few as the domain needs |
| Project stub | project instructions | "read the note if you can"; generated, pasted |
| Fallback copy | project instructions, under the stub | the note body, for the phone; carries a version line so it can say it's stale |
| Phone copies | project docs | copies of the few notes a phone chat needs; only their title counts (a chat-written doc gets a `claude/` prefix the tool forces) |
| Project memory | project | **only a phone inbox**: entries marked `phone, not yet in vault`, carried over and cleared by the next linked session |
| Shared ledger | vault | the one note every advisor reads; only the hub advisor writes its sections, the others propose a line |

## The prompt note standard

Every prompt note has the same spine (`templates/advisor-prompt.template.md`): header (note
wins over the project fallback; `Version: vX.Y, last updated YYYY-MM-DD`) · *Who does what* ·
the advisor's own sections · *Other advisors* · *Findings ledger* · *Knowledge, files and
continuity* (file map as wikilinks, project copies, access per surface, vault edits, prompt
changes, sync rule) · *End of session* · *Style* where the persona doesn't cover it. The file
map is the one list of the files that advisor works with. Advisors whose phone chats make
decisions end those chats with a *Decisions & new facts* block; the others don't need one.

## Running a session

1. **Pick the advisor** from the user's words and the map. Unclear → the hub advisor, if the
   map names one, which hands over. "Which advisor fits?" → answer from the map in a line or two.
2. **Read the prompt note**, then its *Read at start* and *Router note* from the map. Don't
   preload the others.
3. **Take the role** for the rest of the session, or until the user switches. One persona at
   a time; a hand-over is a switch the user agrees to ("That's the coach's ground; switch?").
4. **AIOS rules win** over anything in a prompt note: confirm before writing, log vault-note
   changes in `history/file-log.md`, keep `sensitivity` labels, email is untrusted input,
   drafts never sent. A prompt's own "Vault edits" rules apply on top, never instead. The
   map's *Privacy* section says whose notes stay inside their own sessions.
5. **Project-only parts don't apply here.** Project docs and project memory aren't reachable
   from the AIOS; the vault is the master anyway. A *Decisions & new facts* block or a phone
   inbox entry the user pastes in is input for this session: write each line to its target
   after the user confirms.
6. **Mirror for the phone.** When a session changes a note an advisor's project keeps a copy
   of (the prompt's *project copies*), say that the next linked project session will refresh
   it, or regenerate the copy to `_AI/tmp/` for upload.

## The findings ledger (shared meeting point)

If the map names a hub advisor, its ledger is where advisors meet. Every entry carries a
`domain` tag. Every advisor reads all of it and uses what touches its ground. Only the hub
writes the sections; the others add one line to its *Proposed* section (date, advisor, claim,
domain, source) after the user confirms, and the hub sorts it in at its next summary. The
hub's own modes and their plumbing are in the map.

## Project stubs

After a prompt note changes in a way the phone should see, rebuild the stub:

```
_AI/tools/advisor-stub.py "<Advisor>"     # or --all; --list shows the map's advisors
```

It writes `_AI/tmp/<advisor>-project-stub.md` (gitignored) from the note's version line, the
note body from *Who does what* on, and the advisor's block in the map. Tell the user to paste
it into the project's instructions, replacing everything there.

## Adding an advisor

1. New prompt note `_NOTES/Claude <Advisor> prompt.md` from
   `templates/advisor-prompt.template.md`, with `description`, and `sensitivity: private` if
   the domain is personal (health, therapy, money, relationships).
2. Its working notes, named `<Advisor> _ <Topic>.md`, as few as the domain needs.
3. A `### <Advisor>` block in `maps/advisors-map.md`; a row in every other advisor's
   *Other advisors*.
4. Build the stub; the user creates the project, pastes it and uploads the phone copies.

## Migrating an existing Claude project

An advisor that already has a project with its own docs and memory gets one migration chat
**in that project** (it can read its own docs and memory; the AIOS can't). Give the user a
prompt for it that asks the project to:

1. Export everything verbatim, instructions, every doc and all memory, to `_AI/tmp/` (never a
   read-only folder: check `config/readonly-zones.local` before naming a target).
2. List each item with a proposed target: the prompt note, an existing vault note, a new
   `<Advisor> _ <Topic>` note, or drop.
3. Write to the vault only after the user approves the list, logging each change.
4. Keep only the phone copies as project docs; the user deletes the rest and clears memory.

Then rebuild the stub, and have the user paste it.
