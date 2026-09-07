# Obsidian — My Setup

**Role:** notes
**Verified:** <!-- date you last checked the endpoint against the live plugin -->
**Health check:** `GET https://127.0.0.1:27124/` — returns `status: OK` without a token, so it
proves the listener is up without spending the key.

**This file is OPTIONAL, and it is the one integration file whose absence means something
different.** The vault is the substrate: without this file the OS still has full notes
capability through the filesystem. What is missing is only the API layer below. Delete it and
nothing breaks; every route falls back to disk.

## The boundary rule — decide the route before every write

**Disk for content. The API only for what disk structurally cannot do.**

Disk is faster, needs no token, and works while the app is closed, so it is the default for
reading and writing note *content*. The API earns its place for four things:

| # | Capability | Route |
|---|---|---|
| 1 | **Run a template** (Templater `<%* … %>` is code only the app evaluates) | `POST /commands/{id}/` |
| 2 | **Execute any app command** with no filesystem equivalent | `POST /commands/{id}/` |
| 3 | **Patch one section** without rewriting the file | `PATCH /vault/{path}` |
| 4 | **Search / tags / metadata** as the *plugin* answers it, not as grep reconstructs it | `POST /search/`, `GET /tags/` |

**One writer per file.** API writes and disk writes are two uncoordinated writers with no
locking — pick one route per write, never both in one operation.

**The app must be running.** Nothing scheduled, pushed or headless may depend on this file.

## Access

- **Local REST API** (community plugin) — the one to build on; it returns results.
  - HTTPS `https://127.0.0.1:27124/`, HTTP (off by default) `27123`.
  - `Authorization: Bearer <key>`; the key lives in the plugin's own `data.json`.
  - Self-signed CA → `curl -k`, or trust the CA the plugin serves.
  - MCP server at `/mcp/`. **Register it at user scope, never project scope** — project
    scope writes the bearer token into a file inside the vault you sync and export.
- **Advanced URI** (community plugin) — `open "obsidian://advanced-uri?vault=…&commandid=…"`.
  Tokenless and portless, but fire-and-forget: it returns nothing. Largely redundant once
  the REST API is installed.

**Never print, echo or log the key.** Read it into a shell variable and use it there.

## Fill these in for your vault

- Periodic-note cadences: which are enabled, their filename formats, and which template each
  uses. **Check that a configured template file actually exists** — a cadence pointing at a
  missing template produces an empty note.
- The command ids you actually use (`…:open-weekly-note` and friends).
- Anything you verified, with the date — and anything you did *not*, said plainly. Two worth
  testing before relying on them: whether task/query plugin blocks can be **read back**
  (executing a command may return no body), and whether **backlinks / unresolved links** are
  exposed at all.

## Security posture

An authenticated localhost listener with full vault read/write **and command execution**, whose
key sits in plaintext in a plugin config file. Two consequences worth stating rather than
assuming:

1. **Any process that can read that file has the key** — including every other plugin, since
   plugins share the filesystem and run unsandboxed. This is the plugin model, not a flaw in
   this plugin. The practical boundary is therefore *which plugins you install*, not the key.
2. **Command execution widens the blast radius beyond file access.** A read bug leaks notes;
   command execution can drive the app. Read the source, pin the version, keep it local-only,
   and leave the plain-HTTP endpoint disabled.
