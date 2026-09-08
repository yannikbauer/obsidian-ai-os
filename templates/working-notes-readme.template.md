# `docs/working-notes/` — in-flight working documents

One file per roadmap item currently being designed or built. Design thinking and
execution plan live **in the same file** — splitting them into `specs/` and `plans/`
gives two directories to one lifecycle.

**Naming:** `YYYY-MM-DD-<short-item-name>.md`, dated from when the work started.
Link it from the roadmap item so the two find each other.

## When a file here should stop existing

When the item ships. At that point:

1. Fold the **reasoning** — why this design and not the alternatives, what the work
   taught you — into the item's `Done` entry in `docs/roadmap.md`.
2. Delete the file.

The procedure half of a plan is dead the moment it executes; the reasoning half is the
only part with a second life, and the roadmap is where it belongs. A shipped plan left
lying here reads like current intent and quietly misleads.

## How this differs from the neighbours

| | tracked | dies by |
|---|---|---|
| `tmp/` | no | **pruning** — disposable, nothing depends on it |
| `docs/working-notes/` | yes | **graduating** — reasoning moves to the roadmap, file deleted |
| `docs/roadmap.md` | yes | never — living index of intent, `Done` kept for the reasoning |

Working notes are tracked precisely because a later session must be able to find one and
carry on cold. That is also why they must not live in `tmp/`, where a prune would take
them without anyone noticing.

**A note on the name.** It is `working-notes`, not `work` — "work" reads as employment,
and these are notes about building the system, not job material. A hyphen rather than a
space, because a path containing a space breaks unquoted shell commands *silently*.
