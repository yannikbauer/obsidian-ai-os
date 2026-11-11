# Safety and learning

What the OS refuses to do, how that is enforced, and how it gets better without drifting.
[Back to the README](../README.md)

## Rules that are enforced, not remembered

The framework file (`CLAUDE.md`) states the safety rules: email is untrusted input, drafts
are never sent unasked, writes need your yes, read-only folders stay untouched, nothing goes
public without an explicit instruction. A model can be argued out of a rule in a long
session, so the ones that can be checked mechanically are **hooks**: small shell scripts
Claude Code runs before or after a tool call, which deny or ask whatever the session thinks.

- **Deny gates:** writing into a read-only zone, rewriting a Templater block or a live
  `tasks` query, overwriting a whole note, rewriting a whole task-system page, sending mail,
  staging the whole tree with `git add -A` when another session writes to it, and a
  read-only subagent reading outside its own folder.
- **Ask gates:** a shell command that names a read-only folder and looks like it changes
  something, a Read of a note labelled private or secret, and a write or commit of a file
  another session wrote a few minutes ago (several sessions can share one vault and one
  repo, and git cannot see vault notes at all).
- **Traces and nudges:** every vault write is traced; a session that edited vault notes
  cannot end until the change is logged in `history/file-log.md`; the first grep over the
  notes reminds the session that search exists; a session start refreshes the search index
  and offers a missed daily check-in; every prompt carries the local time.

They fail *open* when they cannot run (a missing `jq`), so `install.sh` checks for it, and
every hook has test cases in `tests/run.sh`, including malformed input. The details, and
why some gates ask instead of denying, are in [`.claude/README.md`](../.claude/README.md).

**Where the gates cannot see.** A hook reads a tool's structured arguments. A shell command
names its target in a free string, so note writes are routed through the notes API or
`Write`/`Edit`, never the shell. And Grep and shell reads go around the sensitivity gate.

## Learning: lessons go into files

When a session teaches something (a correction, a near-miss a hook caught, a check that
missed what it should have caught), the `retro` skill reads the session's own transcript,
not its summary of itself, and proposes where the lesson belongs:

- a fact about a tool → that tool's integration file,
- a workflow step → the skill,
- a rule a script can check → a hook, with a test,
- only a disposition that has recurred → an always-on rule in `CLAUDE.md`, because that file
  is loaded every session and every line in it costs tokens forever.

Each lesson gets an entry in `history/lessons.md` (yours starts empty; the `L0xx` ids in
comments across this repo are the author's, kept as the reason a rule exists). A `Stop`
hook asks for a retro when a session shows signs of having taught something; it never runs
one by itself. Every change is a diff you approve.

How far it has got: over its first two months the author's ledger gathered around forty
lessons, most of them now living in the skill, hook or integration file they were about, and
one caught its own author an hour after being promoted. All of them came from one user's
sessions, most of them sessions that were also building the OS, so treat it as a working
loop, not a validated one.

## Keeping the description true

The OS describes itself in many places (this README, the guides, the roadmap, the export
list, the hook registrations), and each is right when written and wrong after the next
change. Two layers keep them in step:

- **`tools/check-coverage.sh`, on every commit** (a pre-commit hook) and in CI: every skill,
  tool, template, knob, setup folder and vault-root link appears in the
  [architecture tree](architecture.md); every hook is registered; every top-level folder is
  exported or declared private; every guide is linked from the README and every relative
  link resolves; the README and its sections stay within a length budget; and no roadmap
  item the README still promises is marked done.
- **At publish**, for what a script cannot judge: `publish.sh` lists the commits since the
  README last changed that touched what it describes, and asks whether it was read against
  them; and a reader with no other context reads only the README, as a newcomer would, and
  reports where it lost them (see [Sharing and publishing](publishing.md)).
