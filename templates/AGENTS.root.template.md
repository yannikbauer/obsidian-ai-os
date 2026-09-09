# AI OS — entry point

This vault runs an AI OS. Its framework, identity and vault map live in `_AI/`. This file
exists so that any agent runtime finds them, not only Claude Code.

**Read these three files before doing anything else:**

1. `_AI/CLAUDE.md` — the operating framework: how to work here, and the safety rules.
2. `_AI/me.md` — who the user is and how they want to be worked with.
3. `_AI/maps/vault-map.md` — how this vault is organised.

Then load capabilities on demand from `_AI/.claude/skills/`, and a tool's specifics from
`_AI/integrations/<tool>.md` at the point you need them. Neither is preloaded.

**This file is a pointer, and has to stay one.** Nothing here may restate what those files
say. Two copies of a framework is two frameworks, and the one nobody is editing is the one
that goes quietly wrong. `CLAUDE.md` next to this file is the same pointer in Claude Code's
own import syntax; `_AI/setup/install.sh` writes both.

**The safety rules are only prose here.** In Claude Code they are also hooks, registered in
`_AI/.claude/settings.json`, which refuse the calls the rules forbid. No other runtime runs
those hooks. So in any other runtime this is the weaker environment, and anything
irreversible — writing notes, sending mail, changing tasks or calendar entries — needs the
human to say yes first, every time.
