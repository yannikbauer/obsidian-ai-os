# Changelog

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
