---
name: vault-maintenance
description: >
  Keep the notes vault healthy: a read-only report of what has drifted (frontmatter that does not parse, missing or stale descriptions, broken links, orphan notes, tag variants, likely duplicates), then fixes that are proposed first and applied only on the user's word. Also does housekeeping of the scratch folder `_AI/tmp/`. Runs unattended every week; the Monday review shows the result. Trigger on "maintenance", "vault maintenance", "health check", "vault health", "check the vault", "clean up the vault", "housekeeping", "clean up tmp", "tidy up", "broken links", "orphan notes", "duplicate notes", "tag cleanup", "apply the descriptions", or from the Monday review.
---

# Vault Maintenance

Three layers. **Prevent** lives in the `obsidian` skill: every note it writes gets a
`description`, a sensitivity label where one applies, and quoted YAML values. **Detect** and
**repair** live here. The engine is `_AI/tools/vault-health.py`, which is read-only and runs no
model. Settings are in `_AI/config/vault-health.local`. Run the tools directly, never as
`python3 …`: the shebang runs them through `uv`, which provides their dependencies.

## Report

0. **Check whether this week is already handled.** Read the frontmatter of this week's
   `_AI/tmp/health/<date>.md`. If `status` is `applied` (or `partly applied`), it was dealt with
   in another session: say so in one line ("vault health: applied <applied>, <done>"), show
   what is still open, and don't offer the sheet again.
1. Run `_AI/tools/vault-health.py report`. It lists what is new since the user last looked;
   `--all` lists every finding.
2. Show it. In the Monday review, show only the summary line: the counts under the heading, or
   the one-line "nothing new".
3. **Then run `vault-health.py ack`.** It marks those findings as seen. Ack only after the
   user has actually been shown the report, never in an unattended run: an ack nobody saw
   swallows findings, and the weekly run relies on that so a skipped week loses nothing.

The report carries paths and link targets only, never note text, so it is safe to show for
private notes.

## Fix

Every fix is confirmed first. Each section of the report names its fixer:

- **Missing or stale description.** If this week's `_AI/tmp/health/<date>-review.md` exists,
  show it and apply on "apply":
  `tools/frontmatter-set.py --from-jsonl tmp/health/<date>-proposals.jsonl --keys description,language --reason "vault maintenance"`
  (dry run first). Otherwise pipe `vault-health.py missing`, or the stale paths, into
  `tools/frontmatter-polish/propose.py --backend claude --model haiku --out …`, then
  `review.py`, then the same apply. A stale description needs `--replace`. Labelled notes are
  sent to the local model by `propose.py` itself.
- **Invalid YAML.** Fix the line by hand through the notes API, or `Edit` when Obsidian is
  closed. Quote values that contain `: `.
- **Broken link, orphan, tag variant, duplicate.** One at a time, the user's call. Merging two
  notes rewrites every link to the one that goes, so list those links first. Rename a tag with
  Obsidian's Tag Wrangler, or note by note.
- **Mark the report when you're done.** After applying fixes from a weekly report, update the
  frontmatter of `_AI/tmp/health/<date>.md` (the weekly run writes `status: open`): set
  `status: applied` (or `partly applied` while findings that need the user's call are still
  open), `applied: YYYY-MM-DD HH:MM`, and `done:` as one short line of what changed. Other
  sessions, the Monday review above all, read this so they don't offer work that's already done.
  It's a tmp file, not a note: use `Edit`, and it gets no file-log line.
- **Never bulk-edit notes through Bash.** Writes go through `frontmatter-set.py` or the notes
  API, and every changed note gets a line in `history/file-log.md`.

A finding that comes back every week points at a missing convention. Name the skill that
wrote the note, so the prevent layer can catch it next time.

## Housekeeping

`_AI/tmp/` is scratch (see its README). `vault-health.py tmp` does the sort below (patterns
and thresholds: `tmp_*` keys in `config/vault-health.local`), the report ends with its one-line
summary, and the weekly run writes it to `tmp/health/<date>-tmp.md`. On the user's word,
`vault-health.py tmp --trash` moves the stale items to the Trash. The `prune-session-state`
hook already trashes hook state older than 14 days at session start. By hand, or to check the
tool:

1. List it and sort each item into **keep**, **stale** or **ask**:
   - **keep:** `README.md`, `health/`, `touches.log`, `vault-search-*.log`, `*.parked`, the
     advisor `*-project-stub.md` paste sources and `coach-snapshot.md`, plus `polish/` while
     the description backfill (roadmap #11) is open.
   - **stale:** a backup or snapshot older than 7 days, or a younger one whose edit the user
     has confirmed good; spent exports and migration prompts; per-session hook state
     (`writes-`, `denies-`, `collision-acks-`, `nudged-search-`, `.retro-asked-`,
     `.filelog-blocked-`) older than 14 days.
   - **ask:** anything else. Classify it from its name and date; never assume.
2. Propose the stale list grouped, with counts. Raw exports of sensitive material (therapy,
   money) go first: they should not linger.
3. On the user's word, move to the macOS Trash with `/usr/bin/trash`. Never `rm`, never
   permanent. No file-log line: nothing in `tmp/` is a note.
4. **Flag a vault-root `tmp/`.** It is not a folder of the vault: something resolved
   "`tmp/`" against the vault root instead of `_AI/`. Trash its contents on the user's word
   and name the prompt or skill that wrote there, so the path can be fixed.

## Weekly run

A scheduled task (`vault-health-weekly`, Monday 07:30) starts
`_AI/tools/vault-health-weekly.sh` detached. It writes into `_AI/tmp/health/` only:

- `<date>.md`: the report
- `proposals.jsonl`: description proposals, cumulative, so a failed one is retried next week
- `<date>-proposals.jsonl` and `<date>-review.md`: this week's sheet
- `<date>-tmp.md`: the tmp housekeeping sort

It never acks and never writes a note. It needs the machine awake and the app running; if they
aren't, the task runs the next time the app opens. The Monday review (`personal-assistant`)
runs the *Report* steps above and offers the sheet.

## Not here yet

Link-fix proposals, orphan triage, auto-apply for unlabelled notes, and more checks are roadmap
#46. Add them here as *Fix* entries, not as new skills.
