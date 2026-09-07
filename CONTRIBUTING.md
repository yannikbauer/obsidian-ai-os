# Contributing

Thanks for looking. This is a small, opinionated project and contributions are welcome —
but it has one unusual constraint, described below, that is the single most common way a
well-meant patch goes wrong here.

## Before anything else: the generic / personal boundary

This repository is the **generic half** of a system whose other half is private. Every file
here ships to strangers; the owner's identity, vault layout, tool IDs and reasoning live
outside it, in files that are never exported.

So the rule is:

> **Generic code may not name a specific product, person, place, language, timezone, or
> circumstance.** Anything specific belongs in an `integrations/` or `maps/` file, which the
> user writes and the repo never sees.

This decays silently, and it has done so repeatedly. Real examples caught in review:

- A skill split into two shipped a hardcoded timezone, one provider's search syntax, and one
  language — because the task was framed as "a split, not a rewrite", so nobody re-applied
  the standard to the moved text.
- A comment justifying a configurable word list with *"this vault's owner writes notes in
  two languages"* — a personal circumstance in generic code, matching no leak pattern and
  invisible to every automated check.

**Moved or reused text must be re-checked against its new home's constraints.** If you
relocate a paragraph, read it again as though you had just written it there.

There are exceptions, and they are deliberate rather than sloppy: files under `skills/` that
are *named* for a tool may name that tool, and `harness/hooks/` may name the tool whose API
it gates. Role-named files (`skills/calendar/`, `skills/mail/`) may not.

## Sign-off (DCO)

This project uses the **Developer Certificate of Origin**, the same one the Linux kernel
uses. Read it at <https://developercertificate.org/>. It is a statement, not a form: you
assert that you wrote the contribution, or otherwise have the right to submit it under this
project's licence.

Add a sign-off line to every commit:

```bash
git commit -s -m "your message"
```

which appends:

```
Signed-off-by: Your Name <your.email@example.com>
```

Use your real name and an address you can be reached at. Sign-offs are permanent and public.

## Licensing of your contribution

By submitting a contribution you agree that:

1. It is licensed to the project and its users under the project's current licence (see
   `LICENSE`); **and**
2. You grant the maintainer a perpetual, worldwide, irrevocable, royalty-free licence to use,
   reproduce, modify and **sublicense or relicense** your contribution as part of this
   project, including under a different licence in future versions.

**Why point 2 exists, stated plainly rather than buried.** You keep your copyright — nothing
is assigned. But without an explicit relicensing grant, changing this project's licence later
would require the written permission of every past contributor, and one unreachable person
blocks it permanently. Point 2 keeps that door open. It also means a future version of this
project could be released under a more restrictive or a commercial licence. If that is not
acceptable to you, please do not contribute — that is a completely reasonable position, and
saying so now is better for both of us than discovering it later.

Already-published versions stay under the licence they were published with, for everyone,
forever. That is not something a later change can take back.

## Practical

- **Run the test suite**: `sh harness/tests/run.sh` — every assertion must pass.
- **Run the coverage check**: `sh tools/check-coverage.sh` — it enforces the enumerations
  that go stale silently (hooks registered, templates scaffolded, export coverage declared,
  no counts or rule-ordinals in prose).
- **A new hook needs a fixture.** A gate with no test is a gate that quietly stops working.
- **Negative tests must assert shape, not absence.** A test that passes because nothing ran
  is worse than no test — it reports success for work it never did.
- **A "never" rule that fires on legitimate work is worse than no rule.** If you cannot state
  a condition precisely enough to test it, it belongs in prose, not in a hook.
- Keep commits scoped and name the paths you changed. Never `git add -A`.

## What not to contribute

- Anything containing personal data — yours or anyone else's.
- A new abstraction layer over models or tools. The design deliberately rejects these; the
  portability comes from plain markdown plus standard protocols.
- Features that add process. This system's virtue is that it is thin.
