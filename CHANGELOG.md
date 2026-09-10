# Changelog

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
