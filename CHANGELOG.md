# Changelog

## v0.7.0 — 2026-11-11

- Drift checks: a pre-commit hook (setup/git-hooks/pre-commit, wired in by install.sh) runs check-coverage.sh on every commit; publish.sh runs the full test suite first and asks whether the README was read against the commits that changed what it describes (--readme-reviewed for non-interactive runs).
- check-coverage.sh now covers every tools/ entry, setup/ folders, scaffolded maps, the vault-root symlinks, and README "Where it's going" bullets against the roadmap.
- README brought up to date: the agents symlink, the Python tools, scheduled tasks, search in the setup flow, a Daily log section, review-checklist item 7.
- newsletter-digest and job-digest: weekday runs; archive digested mail under a standing permission recorded in the mail integration file, keeping threads worth a look in the inbox with a reason.
- daily-log: offers a missed check-in at session start, a diary link per check-in, schema 2; monthly and quarterly reviews through the advisors skill.
- garmin-export.py: a Garmin Connect export as a daily CSV for a health baseline.
- Answers drawn from vault notes end with a Sources line.
- inject-time.sh hook: the local time on every prompt.
- Weekly review: daily-log line, alerts on created events; archive zones accept moves in.
- Version-controlled scheduled tasks in setup/scheduled-tasks/.

## v0.6.0 — 2026-11-05

- **Advisors: Claude projects as front-ends to the vault.** A new `advisors` skill runs long-lived advisor personas (a coach, a chef, a financial advisor, …) whose prompt lives in one vault note. The Claude Desktop project keeps only a generated stub, a fallback copy and phone copies, and project memory becomes a phone inbox the next linked session empties into the vault. New: `tools/advisor-stub.py`, `templates/advisor-prompt.template.md`, `maps/advisors-map.md` (scaffolded), a README section, and an authority row in the workflow-map template.
- **Daily log.** A new `daily-log` skill turns a spoken daily check-in into one structured daily note whose frontmatter is the data, with optional wearable fields. `tools/daily-log-stats.py` computes weekly lines and group comparisons the same way every time; which fields are sensitive or pre-registered is configured in your own map, not in the script, and `--no-sensitive` fails closed without that list.
- **Vault maintenance.** A new `vault-maintenance` skill and `tools/vault-health.py`: a read-only weekly report on frontmatter that does not parse, missing descriptions, broken links, orphans, tag variants and likely duplicates, plus housekeeping of `_AI/tmp/`. Fixes are proposed and applied only on your word. A SessionStart hook moves stale hook markers to the Trash instead of deleting them.
- **Smaller changes.** The newsletter digest drops its Scout subagent (it found nothing in three real runs); `usage.sh` counts API responses once and includes subagents; the obsidian skill mentions private search hits it left unopened; snapshot paths are spelled out as `_AI/tmp/`.

## v0.5.0 — 2026-11-04

- Record the v0.4.0 release
- description: frontmatter convention (roadmap item 11 phase 1)
- Sensitivity labels: label, don't block (roadmap item 8, item 11)
- frontmatter-polish: propose and review scripts, pilot run (roadmap item 11)
- vault-search: hybrid semantic search over the vault (roadmap item 10)
- vault-search: nudge on Bash grep too, hint when run via python3
- frontmatter polish: JSONL apply mode, subscription auth, prefix glossary
- job-digest: quote frontmatter values that contain ': '
- README: note metadata section (description, sensitivity, frontmatter-polish); refresh Where it's going
- vault-search: redact every note, not only secret ones; README search section
- propose.py: generic wording in the prefix-glossary docstring
- vault-search: external folders move to config; setup step for the index
- vault-search: a killed run's lock no longer blocks indexing for two hours
- guard-mail: exempt Claude Desktop's session-to-session send_message by exact name

## v0.4.0 — 2026-11-03

> **Upgrading from v0.3.0: re-run `bash _AI/setup/install.sh` once after pulling.** This
> release adds `.claude/agents/` (read-only subagents), and the link that makes Claude Code
> discover them is created by the installer. Without it the digest skills stop at their
> reader step rather than read mail in the main session.

**New skills**
- `newsletter-digest`: weekly cross-source digest of email newsletters, with a mid-week update mode, a read-aloud version, an optional web-research Scout section, and an archive question.
- `job-digest`: weekly digest of job-alert mail scored against the user's job search, a cumulative market log, a read-only job-board browser pass on request, and a scheduled Monday run.
- `transcripts`: triage, tidy and distill meeting and voice-memo transcripts, plus a live check of a meeting still running; adds the `transcription` role.
- `meals`: meal-planning logistics around a separate cooking assistant: cooked-meal review, calendar slots, suggestions from recipe notes.
- `finances`: read-only finance snapshots into a sheet, advisor-brief upkeep, and a monthly budgeting-app check.
- `phone`: operate Android apps through a scrcpy mirror (USB or Wi-Fi), read-only by default.

**Subagents**
- `newsletter-reader`, `job-mail-reader`, `scout-researcher`: read-only by construction, so untrusted mail and web text never reach the main session.

**Hooks**
- `guard-collision.sh`: asks before a write or a commit touches a file another session wrote recently.
- `guard-agent-read.sh`: confines a reader subagent's Read to its own saved tool output.
- Every hook is now parse-checked by the test suite (a hook that fails to parse blocks everything it matches).

**Tools**
- `phonemirror.sh` and launcher: start and stop the phone mirror.
- `macwhisper-live.sh`: read a running recording from the transcription app's database.

**Existing skills**
- `personal-assistant`: creates a missing weekly note through the notes app's own command; the Monday plan asks about meals first and mentions the week's job digest.
- `clickup`: clearer rules for resetting the done page and staging the week.

**Pipeline**
- `export.sh` keeps plugin symlinks out of the export and replaces connector ids in agent tool lists with a placeholder.
- `publish.sh` works without a terminal (no prompt, push fails closed) and takes `--notes FILE` for curated release notes.
- The test suite passes on the Linux CI runner again.

## v0.3.0 — 2026-09-10

- Record the v0.2.1 release
- README: name the two .claude/ folders instead of the choice between links
- publish.sh: a release now also becomes a GitHub Release

## v0.2.1 — 2026-09-09

- Record the v0.2.0 release
- Fix the gates on a published clone, and ship CI to the public repo (item 38)

## v0.2.0 — 2026-09-09

> **Upgrading from v0.1.0 takes one command, not just a pull.** `harness/` and `skills/`
> moved into `.claude/`, so the two symlinks a v0.1.0 install created now point at
> directories that no longer exist. A dangling link is silent, and hooks **fail open**, so
> the result is an install that looks fine and enforces none of the safety gates. After
> pulling, run `bash _AI/setup/install.sh`. It repoints stale links and verifies its own
> output; nothing else is needed.

- Record the v0.1.0 release
- README: lead with the architecture; add AGENTS.md as a second entry point
- Resolve the vault root once, and lint what the checks could not see
- Migration phase 0: the ignore rule for .claude/, before anything moves there
- Migration phases 1-2: harness/ and skills/ move into .claude/
- Migration phase 3: keep two symlinks, and say why in the README
- Retro: L019 mechanised, L020 recorded, stale harness/ paths retired
- Lift the item 38 publish hold; drop a product name from a shipped file

## v0.1.0 — 2026-09-08

- Initial tagged release.
