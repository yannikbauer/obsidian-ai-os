# Vault Map

How your Obsidian vault is organized, so the AI can navigate without scanning. A structural orientation doc (a "map"), not content. Fill in and delete guidance lines.

## Root

The vault root is `<VAULT>/`. Claude Code runs from here; the root `CLAUDE.md` is the entry point.

## Folder structure

```
<VAULT>/
├── CLAUDE.md       ← root stub (imports the _AI framework, me.md, this map)
├── _AI/            ← the AI OS
├── <notes folder>/ ← your main knowledge base — describe the philosophy (flat? foldered?)
├── ...             ← list your other top-level folders and what each is for
```

## Organization philosophy

- <flat + prefixes + links? folders? MOCs? — describe how you keep order>
- <any filename prefix namespaces (e.g. per-project, per-employer)>
- <work vs. personal separation approach>

## Key note types and where they live

| Type | Location | Filename pattern |
|------|----------|------------------|
| <goals> | <folder> | <pattern> |
| <weekly/periodic> | <folder> | <pattern> |
| ... | | |

## Conventions

- <frontmatter, task format, tags, link/naming conventions>

## Read-only / handle-with-care

- <template syntax, live query blocks, folders not to scan, default folder for new notes>
