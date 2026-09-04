# `tmp/` — disposable working files

**Everything in this folder is gitignored except this README.** Nothing here is a record;
nothing here is safe to depend on. Delete freely.

## What belongs here

- **Pre-edit snapshots.** Before a destructive edit to an external doc (a task-system page
  whose API overwrites the whole thing), save the current content here first. The copy
  **on disk** is the recovery — not git. Prune it once the edit is confirmed good.
- **Test artefacts** — before/after dumps from a write test, kept only while the finding is
  being written up.
- Anything else scratch.

## What does NOT belong here

Anything worth reading next month. Reasoning goes in `docs/`, the audit trail in
`history/file-log.md`, continuity in `history/session-log.md`, tool facts in
`integrations/`. If you are tempted to put a *finding* here, you want one of those instead —
write the finding up and let the artefact that produced it be deleted.

## Why this is separate from `history/`

The two folders have opposite lifecycles. `history/` is append-forever and fully tracked.
`tmp/` is delete-on-sight and fully ignored. They were one folder behind a whitelist rule
until 2026-09-01, which meant the ignore had to guess — and it guessed toward ignoring, so a
new log file dropped into `history/` would have been silently untracked. Split by lifecycle,
neither folder needs a negation and neither can guess wrong.

## Why not a session scratchpad

A harness scratchpad is session-scoped and outside the vault. Snapshots must outlive the
session and be findable by the user, because the on-disk copy **is** the recovery path.
Keep them here.

## Caveat worth repeating

A snapshot is a **diff aid, not a guaranteed restore.** Where a page carries rich nodes that
flatten to plain markdown on read, restoring the snapshot replays the same flattening. See
the task-system's integration file for the specifics.
