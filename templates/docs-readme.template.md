# `docs/` — thinking, not machinery

Working notes about the OS itself: why things are built the way they are, what is
planned, what was tried and rejected. Nothing here is loaded automatically — skills
read a file from here only when a beat needs it.

**Never exported.** `export.sh`'s allowlist leaves this folder behind, so you can
write freely here without weighing what a stranger would see.

Suggested starting points:

- `roadmap.md` — a living index of intent: what you want the OS to do next, and why.
- `working-notes/` — one dated file per in-flight roadmap item, so a session can pick it
  up cold. It has its own README explaining when a file there should stop existing.
- `artifacts/` — if you publish write-ups about the system, keep the *source* of each one
  here beside the published copy. A published page read back is not always byte-identical
  to what you sent, so the local source is the one you edit. Create it when you need it.

If a document here has sections that should never reach an audience, mark them
`KEEP OUT of demos` on their heading line — the `demo` skill respects that marker.
