#!/bin/sh
# PreToolUse (Bash): refuse a blanket `git add`/`git commit -a` in this repo.
#
# Mechanises ledger lesson L007. More than one session runs against this working tree,
# so staging everything commits another session's half-finished work — and it has
# already gone wrong once (2026-09-04: "you can commit only the roadmap.md"). The fix
# is always the same and always cheap: name the paths.
#
# WHY IT MAY BE ABSOLUTE. L006 says a "never" rule that fires on legitimate work is
# worse than no rule. This one clears that bar for a specific reason: it gates only
# what *Claude* runs. The user's own terminal is untouched, so the escape hatch exists
# and needs no exception here.
#
# COMMAND POSITION, NOT SUBSTRING. The naive matcher would deny writing the very files
# that document this rule — the skill body containing "never git add -A" was authored
# through a Bash heredoc. So the pattern requires the command to begin a segment
# (start of line, or after ; & | && ||), which prose mentions do not.
. "$(dirname "$0")/lib.sh"

cmd=$(field '.tool_input.command')
[ -n "$cmd" ] || exit 0

hit=$(printf '%s' "$cmd" | grep -oE '(^|[;&|]|&&|\|\|)[[:space:]]*git[[:space:]]+(add[[:space:]]+(-A[[:space:]]*|--all|\.([[:space:]]|$))|commit[[:space:]]+(-a[[:space:]]|-am|--all))' | head -1)
[ -n "$hit" ] || exit 0

deny "Blanket git staging is refused (ledger L007). Another session may be working in this same tree, and '$(printf '%s' "$hit" | sed 's/^[[:space:]|;&]*//')' would commit its unfinished work with no sign in the diff. Run 'git status --short', then 'git add' the paths this task actually wrote, named explicitly. If you genuinely intend to stage everything, ask the user to run it themselves."
