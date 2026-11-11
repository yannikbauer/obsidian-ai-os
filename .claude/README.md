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

A line can end in ` | move-in` (e.g. `*/Archive/* | move-in`). That folder becomes an
**archive**: a `vault_move` into it is allowed when the target name is free, and
everything else stays denied — writes, edits, copies, overwrites, moves back out. Added
2026-11-05 because archiving old versions was a chore the user kept doing by hand; the
point of the zone is that nothing *in* it changes, not that nothing can arrive. The
built-in defaults never carry the flag. `guard-bash-vault.sh` ignores it: a shell `mv`
into the archive still asks.

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

## A scoped tool for an untrusted reader: `guard-agent-read.sh`

`newsletter-reader` reads untrusted mail, so it gets nothing to act with. It does get
`Read`, because Claude Code saves any MCP result over 50,000 characters to
`~/.claude/projects/*/tool-results/` and returns only a pointer. A subagent's `tools:`
list cannot scope a path, so the hook does: when `agent_type` is `newsletter-reader`, a
Read outside that directory (or containing `..`) is denied. Every other caller passes
untouched. Fixtures prove the logic; whether the harness sends `agent_type` has to be
proven live, from a session started after the change (ledger L033).

## Private notes: `guard-sensitive-read.sh`

A note marked `sensitivity: private|secret` in its frontmatter, or matched by a folder
rule in `config/sensitivity.local`, stays readable: the hook **asks** before `Read` or
`vault_read` opens it, and never denies. The label is there so private text does not
reach a cloud model unwatched (a batch job, a digest, a search for something else). It
is not there to keep the owner out. The hook reads the frontmatter itself, so nothing of
the note enters the context before the yes. `AIOS_INCLUDE_PRIVATE=1` in the session's
environment skips the question; it is an env var because the model cannot set it from
inside the session. Grep and a Bash `cat` still read past it: this closes the routine
route, not every route.

## Search over grep: `nudge-vault-search.sh`, `refresh-search-index.sh`

Two hooks that support the vault search index (`tools/vault-search.py`, roadmap #10),
neither of which blocks anything. **`nudge-vault-search.sh`** (PreToolUse, Grep and Bash)
adds one line of context the first time in a session that the model greps the notes,
pointing it at `vault-search.py search`. Bash is matched too because Claude Desktop
sessions have no Grep tool and grep through the shell; there the test is a coarse
string match (grep/rg in the command, not aimed at `_AI/`). It stays silent for greps in
`_AI/`, outside the vault, or when no index exists. It nudges and never denies, because grep is still the right
tool for an exact string. **`refresh-search-index.sh`** (SessionStart, `startup`) starts
an incremental index run in the background and returns at once. It never builds a first
index: that takes 30–90 minutes and belongs to setup. If Ollama is down, the old index
stays in place and search warns that it is stale.

## Missed check-in: `nudge-daily-log.sh`

**`nudge-daily-log.sh`** (SessionStart, `startup`) covers the daily-log check-in when its
scheduled task did not run (a local task needs the app running at that hour). If
yesterday's daily note is missing, it adds one context line asking Claude to offer the
check-in once. Off unless `maps/daily-log-map.md` carries a
`<!-- daily-log-note-path: … -->` line (a strftime pattern), so the hook names no folder.
Once a day (`tmp/nudged-daily-<date>`), not before 07:00. It offers; it runs nothing.

## Housekeeping: `prune-session-state.sh`

**`prune-session-state.sh`** (SessionStart, `startup`) moves hook markers in `tmp/`
(`writes-`, `denies-`, `collision-acks-`, `nudged-search-`, `nudged-daily-`, `.retro-asked-`,
`.filelog-blocked-`) that no session has touched for 14 days (`AIOS_STATE_DAYS`) to the
macOS Trash. Age, not session end, is the signal: Stop fires every turn, and a resumed
session needs its markers again. It never uses `rm`; without `/usr/bin/trash` it does
nothing, and `vault-health.py tmp` still lists the markers. Everything else in `tmp/` is
the `vault-maintenance` skill's housekeeping, on the user's word.

## Concurrent sessions: `guard-collision.sh`

Several sessions can run against one vault and one `_AI/` tree. Claude Code already
refuses a `Write`/`Edit` to a file that changed since it was read, so bytes are rarely
lost. What goes wrong is *intent*: two sessions reshape one file in different
directions, or one commits the other's unfinished work. Git sees none of this for vault
notes. This hook records every write per session in `tmp/touches.log` (PostToolUse).
It **asks**, once per file and session, before a write to a file another session wrote
in the last 30 minutes (`AIOS_COLLISION_WINDOW`), and before a `git add`/`commit` that
would stage such a file. `_AI/history/` is exempt because every session appends to it by design.

## Writing a hook command

**A hook that does not parse fails closed.** A shell syntax error exits 2, and exit 2
is a deny. So unlike every failure `lib.sh` handles, a hook that doesn't parse blocks
every tool call it matches, including the edit that would fix it (2026-09-18). Run
`sh -n` on a hook before wiring it into settings. `tests/run.sh` parses every hook for
this reason. If one is already live and broken, `chmod -x` it from your own terminal: a
hook that cannot execute exits 126, which does not block.

Two more rules, both learned by shipping a hook that looked installed and never ran:

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
