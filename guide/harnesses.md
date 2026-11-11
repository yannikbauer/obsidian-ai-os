# Other harnesses

The OS is built and used in Claude Code. This page says what carries over to another agent
harness (Codex, OpenCode, Cursor and the like), what does not, and how to use one safely
today. [Back to the README](../README.md)

## What carries over

- **The entry point.** `install.sh` writes an `AGENTS.md` at the vault root next to the
  `CLAUDE.md` stub. It points any harness at the framework, `me.md` and the vault map, and
  tells it to load skills and integration files only when needed.
- **The content.** Skills, maps and integration files are plain markdown. A capable model in
  any harness can read `_AI/.claude/skills/<name>/SKILL.md` and follow it; several harnesses
  now read the same `SKILL.md` format natively.
- **The scripts.** `tools/` and `tests/` are shell and Python; they run from any terminal.

## What does not, and what that means

| Piece | In Claude Code | Elsewhere |
|---|---|---|
| Safety rules (read-only zones, no sending, no whole-note overwrite, …) | hooks that refuse the call | **prose only**: the model can be argued out of them |
| Session-end checks (file-log line, retro prompt), the local-time line | lifecycle hooks | lapse silently |
| Skill discovery | automatic, from `.claude/skills/` | depends on the harness; otherwise point the model at the file |
| Mail, calendar, task connectors | claude.ai account connectors | the harness needs its own MCP servers |
| Subagents, scheduled tasks, Remote Control | built in | no portable equivalent |

**So in another harness, confirm everything irreversible yourself**: every note write, every
mail draft, every task or calendar change. `AGENTS.md` says the same to the model, but a
sentence is not a gate. Try it on a copy of the vault first.

## Where it is going

Two roadmap directions close the gap, in this order:

1. **Find out what actually works.** One real session in another harness, on a vault copy,
   recorded here as a compatibility table: each feature, and whether it works in Claude Code,
   Codex and OpenCode. Until that exists, the table above is reasoning, not measurement.
2. **Move the rules below the harness.** The hook logic becomes one policy engine that answers
   allow, ask or deny for an action on a path, with a thin adapter per harness; and a
   vault-gateway MCP server enforces the same rules for any harness that writes notes through
   it. Then the rules hold wherever the vault is opened from.

With a local model, the same applies plus the limits in [Local models](local-models.md):
fine as a fallback for reading and small jobs, weak for long sessions with many tool calls.
