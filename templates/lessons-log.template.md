# Lessons

The learning ledger. One entry per lesson the OS has been taught, written by the
`retro` skill. **Not auto-imported** — this is a waiting room, not a rulebook. A
lesson changes behaviour only once it reaches a file that *is* read at runtime.

## Why a ledger and not prose

Because "only repeat offenders graduate" has to be countable. A lesson's `Sightings`
list is the evidence that it recurred; its length is the promotion test. In prose that
is a re-read and a judgment call, and the quarterly prune would delete the evidence.

## Entry format

```markdown
## Lnnn · One-line statement of the lesson, in the imperative
- **Kind:** tool-fact | workflow | rule | disposition
- **Status:** candidate | applied | promoted | retired | rejected
- **Sightings:** YYYY-MM-DD `<session-id-prefix>` · YYYY-MM-DD `<session-id-prefix>`
- **Evidence:** what actually happened, in one sentence. No quotes from vault content.
- **Destination:** the file it was written into, or `—` while it waits.
```

- **IDs are stable identifiers assigned on creation**, never reused, never renumbered —
  same rule as roadmap item numbers. Cross-references stay valid when entries are pruned.
- **Newest first**, so the top of the file is the live material.

## Kinds decide the gate

| Kind | Destination | Gate |
|---|---|---|
| `tool-fact` | `integrations/<tool>.md` | applied immediately |
| `workflow` | the relevant `skills/<x>/SKILL.md` | applied immediately |
| `rule` | a `harness/` hook **and a test** | applied immediately |
| `disposition` | stays here as `candidate` | needs a **second sighting** |

Only dispositions compete for always-on `CLAUDE.md` tokens, so only dispositions wait.
A rule that can be mechanised belongs in `harness/`, not in prose.

## Statuses

- `candidate` — recorded, waiting for a second sighting.
- `applied` — written into an integration file, a skill, or a hook.
- `promoted` — became an always-on rule in `CLAUDE.md`.
- `retired` — was promoted or applied, and is no longer needed (usually because a hook
  now covers it). Kept, because the reasoning is the reusable part.
- `rejected` — considered and deliberately not adopted, with the reason.

## Rules for writing here

- **Never quote vault content.** Transcripts contain diary, health and financial notes
  verbatim. State the lesson; point at a session id for the evidence.
- **Cross-reference by bare id (`L003`), never `[[L003]]`.** This file sits inside an
  Obsidian vault, so a wikilink to an id is a broken link, not a reference.
- **Never invent an entry to have output.** A session that taught nothing produces no
  entry, and that is the expected result most of the time.
- Prune `retired` and `rejected` entries when they stop earning their line — but keep
  the reasoning somewhere before deleting.

---

<!-- ENTRIES BELOW — anything reading this file mechanically should skip everything above this line. -->

