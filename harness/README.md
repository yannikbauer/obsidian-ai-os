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
The list is **configuration, not code**: it lives in `_AI/readonly-zones.local`,
one shell glob per line, and **replaces** the built-in defaults (`Archive/`,
`Attachments/`) when present. The file sits at the `_AI` root next to the other
`.local` files, so `export.sh` leaves it behind — your folder names describe your
vault and do not belong in a shared repo.

Keep it in step with the read-only section of `maps/vault-map.md`. The hook is the
enforcement; the map is the documentation.

## Writing a hook command

Two rules, both learned by shipping a hook that looked installed and never ran:

- **Brace the variable and quote the path**: `"\"${CLAUDE_PROJECT_DIR}/_AI/harness/hooks/x.sh\""`.
  A vault path containing a space (this one does) splits an unquoted command and it
  **fails silently** — no log line, no warning.
- **`${CLAUDE_PROJECT_DIR}` is the vault root**, not `_AI/`.

Settings edits are picked up live by the file watcher; changing a hook needs no restart.
