# Working on the OS

Editing skills and hooks, adding a tool pack, and the checks that keep the docs true. [Back to the README](../README.md)

## Working on the OS

- **Edit skills** in `_AI/.claude/skills/` — those are the real files; the `.claude/skills` symlink just exposes them. Commit changes to `_AI/`.
- **Update your context** by editing `me.md`, `maps/vault-map.md` and `integrations/*.md` as things change. The `setup` skill can re-verify integration files against live APIs.
- **Add a skill**: create `_AI/.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`) plus instructions. It is discovered automatically through the symlink. Keep it under ~500 lines and push reference detail into files it points at.
- **Add a map**: new orientation docs (people-map, project-map) go in `_AI/maps/`, and if they should always load, get added to the root stub's `@import` list.
- **Change a hook** in `_AI/.claude/hooks/`, then run `sh tests/run.sh`. Settings edits are picked up live — no restart. Write commands as `"\"${CLAUDE_PROJECT_DIR}/_AI/.claude/hooks/x.sh\""`: braced *and* quoted, because an unquoted path containing a space fails silently.
- **Share something new with Claude Code** — a project agent, a slash command — by putting it in `_AI/.claude/<thing>/` and adding one `link_into_repo` line to `install.sh`. Without the link it lives only at the vault root, outside git.
- **Git lives in `_AI/`**, not the vault root. Run every git command from there.
- **Every commit runs `check-coverage.sh`** through `setup/git-hooks/pre-commit`
  (`install.sh` sets `core.hooksPath`). It takes about a second and refuses a commit that
  leaves the README tree, the hook registrations, the export list or the roadmap out of
  step with what exists. The full suite (`tests/run.sh`, about a minute) runs before every
  publish and in CI instead, because a slow commit hook gets skipped with `--no-verify`.
- **The AI logs its own changes to vault files outside `_AI/`** in `history/file-log.md`. Changes inside `_AI/` are covered by git history instead.

## Adding a tool pack

Packs come in two shapes, and picking the right one matters:

- **Role-named packs** (`.claude/skills/calendar/`, `.claude/skills/mail/`) hold provider-agnostic logic for a role — they must work for *any* provider (Fastmail, Proton, Apple Calendar, Outlook, …) and must name no specific product, timezone, or language.
- **Tool-named packs** (`.claude/skills/clickup/`) hold logic genuinely specific to one product's model — naming that product inside its own pack is correct.

**A new provider for a role you already have (e.g. you already use `calendar` but switch from Google Calendar to Fastmail) usually needs only a new `integrations/<tool>.md` file, not a new skill** — the existing role-named pack already handles it generically. Only write a new `.claude/skills/<tool>/` pack when the tool's operating model doesn't fit an existing role, or the role itself has no pack yet.

When you do need a new pack, it is three files:

| File | Contents | Ships? |
|------|----------|--------|
| `.claude/skills/<tool>/SKILL.md` | generic "how to operate this tool" logic | yes |
| `templates/integrations/<tool>.template.md` | menu entry, placeholders only | yes |
| `integrations/<tool>.md` | your IDs and conventions | never |

Use the `skill-creator` or `superpowers:writing-skills` skill to write the SKILL.md. Keep every real ID out of the first two files — `setup/export.sh` runs a leak check that will refuse to publish otherwise.

## Keeping the README an overview

The README gives each feature a paragraph and a link; the detail belongs in a guide here.
`check-coverage.sh` holds it there on every commit: the README stays under a line budget, and
so does each of its sections; every guide is linked from it; and every relative link and
anchor in the README and the guides resolves. When a section outgrows its budget, move the
detail into a guide rather than raising the number. Each bullet under *Where it's going* carries
a hidden `<!-- roadmap: N -->` tag naming the (private) roadmap item behind it, and the check
fails once that item is marked done, so the README cannot keep promising something that
already shipped.
