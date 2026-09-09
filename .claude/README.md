# `.claude/` — everything Claude Code reads

The settings the OS runs on, the hooks that enforce its safety rules, and the skills it
discovers. The vault root's `.claude/skills` and `.claude/settings.json` symlink in here,
so the configuration Claude Code runs on is version-controlled alongside the OS it runs.
`install.sh` creates both links, and repoints them if they are stale.

**What belongs here:** the OS's own configuration — the model pin, the hooks, the skills.

**What does not:** personal preferences — enabled plugins, TUI mode, notifications. Those
stay in `~/.claude/settings.json`, which is per-machine and not part of the OS.

## Why the ignore rule is a whitelist

This is the one directory in the repo that other programs write into. Claude Code leaves a
per-machine permission file here the first time you approve something permanently, and
plugins leave settings and session state beside it. A blacklist would have to predict what
the next tool drops, and guessing wrong means committing it to a repo meant to be forked
and published from.

A whitelist fails the other way: something legitimate is silently not committed and works
locally forever. That is the failure the ledger calls out — an allowlist's safe default for
personal data is its silent default for generic code. So both halves are covered:

- `.gitignore` admits the **shapes** the OS ships, not a list of filenames. A new hook or
  a new skill is tracked without anyone remembering this file exists.
- `tools/check-coverage.sh` walks this directory and reports anything that is neither
  tracked nor named on the ignore file's `LOCAL_ONLY` line. A new *kind* of file — an
  agents folder, an output style, some future tool's cache — forces a decision instead of
  disappearing.

Neither check is worth much on its own. The whitelist without the walk hides new work; the
walk without the whitelist has nothing to hold anything to.

## Configuring read-only zones

`guard-vault-write.sh` blocks writes into folders you never want the AI touching.
The list is **configuration, not code**: it lives in `_AI/config/readonly-zones.local`,
one shell glob per line, and **replaces** the built-in defaults (`Archive/`,
`Attachments/`) when present. The file sits in `_AI/config/` with the other
knobs, so `export.sh` leaves the whole folder behind — your folder names describe your
vault and do not belong in a shared repo.

Keep it in step with the read-only section of `maps/vault-map.md`. The hook is the
enforcement; the map is the documentation.

## The two vault-write gates, and why there are two

`guard-vault-write.sh` is the real gate: read-only zones, Templater blocks, live
`tasks` queries, whole-file overwrites, and the two `vault_patch` flags that turn a
wrong heading address into a silent duplicate section. It matches **`Write`, `Edit`,
and the `mcp__*__vault_*` tools** — the three routes that name their target in a
structured argument the hook can read.

**Bash names its target in a string, and no gate can read it reliably.** On 2026-09-07
an entire session's vault edits went through the shell, so this gate did not run once.
`guard-bash-vault.sh` is the response, and it is deliberately weaker: it **asks** when a
command mentions a read-only zone *and* looks mutating, and stays silent otherwise. It
does not parse paths, so it cannot be correct — it can only be visible.

That asymmetry is the design. A false *ask* costs a keystroke; a false *deny* teaches
its owner to switch hooks off, which costs every gate here. The seal is the routing
convention, not this hook: **note writes go through the MCP tools, and fall back to
`Write`/`Edit` — never Bash.**

## Writing a hook command

Two rules, both learned by shipping a hook that looked installed and never ran:

- **Brace the variable and quote the path**: `"\"${CLAUDE_PROJECT_DIR}/_AI/.claude/hooks/x.sh\""`.
  A vault path containing a space (this one does) splits an unquoted command and it
  **fails silently** — no log line, no warning.
- **`${CLAUDE_PROJECT_DIR}` is the vault root**, not `_AI/` — in the settings file, which
  is the one place a hook's path has to be written out before `lib.sh` can run.

Inside a hook, do not read `${CLAUDE_PROJECT_DIR}` at all. `lib.sh` resolves two paths and
exports them, so every hook agrees on where things are:

| Variable | What it is | Resolved from |
|---|---|---|
| `AIOS_DIR` | this install of the OS | the hook's own location, `<AI>/.claude/hooks/` |
| `VAULT_DIR` | the vault it serves | `$AIOS_VAULT_DIR`, else `$CLAUDE_PROJECT_DIR`, else the parent of `AIOS_DIR` |

`AIOS_VAULT_DIR` is the seam. Nothing sets it today, because the session starts at the
vault and the harness's own signal is right. It exists so that the day a session starts
somewhere else — from inside `_AI/`, or against a second vault — one variable moves
instead of four hooks. It is covered by a test for the same reason: an override nothing
exercises is a comment, not a seam.

Settings edits are picked up live by the file watcher; changing a hook needs no restart.
