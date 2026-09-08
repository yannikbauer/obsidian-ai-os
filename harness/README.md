# `harness/` — the harness's own configuration

`.claude/settings.json` at the vault root symlinks to `settings.json` here, so the
configuration Claude Code runs on is version-controlled alongside the OS it runs.
Same pattern as `.claude/skills -> ../_AI/skills`, and `install.sh` creates both.

**What belongs here:** settings that are part of the OS — the model pin, and the hooks
that enforce the framework's absolute safety rules.

**What does not:** personal preferences — enabled plugins, TUI mode, notifications.
Those stay in `~/.claude/settings.json`, which is per-machine and not part of the OS.

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

- **Brace the variable and quote the path**: `"\"${CLAUDE_PROJECT_DIR}/_AI/harness/hooks/x.sh\""`.
  A vault path containing a space (this one does) splits an unquoted command and it
  **fails silently** — no log line, no warning.
- **`${CLAUDE_PROJECT_DIR}` is the vault root**, not `_AI/`.

Settings edits are picked up live by the file watcher; changing a hook needs no restart.
