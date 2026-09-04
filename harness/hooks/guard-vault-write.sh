#!/bin/sh
# PreToolUse (Write|Edit): read-only zones, Templater blocks, live tasks queries.
# Enforces three of the "Respect read-only zones" rules in _AI/CLAUDE.md.
. "$(dirname "$0")/lib.sh"

path=$(field '.tool_input.file_path')
[ -n "$path" ] || exit 0

# Read-only zones are per-vault, so they are configuration, not code. Hardcoding
# them made this hook both a disclosure (the folder list describes someone's vault)
# and useless to anyone whose folders are named differently -- while the deny
# message claimed the list came from vault-map.md, which it never read.
#
# _AI/readonly-zones.local holds one shell glob per line and REPLACES the defaults
# below when present. It lives at the _AI root, alongside the other .local files,
# so the export allowlist leaves it behind.
AI_ROOT="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
ZONES="$AI_ROOT/readonly-zones.local"

zone_hit=''
if [ -f "$ZONES" ]; then
  while IFS= read -r pat || [ -n "$pat" ]; do
    case "$pat" in ''|\#*) continue ;; esac
    # $pat is deliberately unquoted: in `case`, that makes it a glob.
    case "$path" in $pat) zone_hit="$pat"; break ;; esac
  done < "$ZONES"
else
  # Defaults for a vault that has not configured any: the two folder names
  # Obsidian itself creates. Deliberately conservative -- a missing config
  # should under-block rather than block a folder the user actually writes in.
  case "$path" in
    */Archive/*|*/Attachments/*) zone_hit='built-in default' ;;
  esac
fi

if [ -n "$zone_hit" ]; then
  deny "Read-only zone: $path matches '$zone_hit' in _AI/readonly-zones.local (or the built-in defaults). Do not write here; if this is genuinely intended, ask the user first."
fi

old=$(field '.tool_input.old_string')

# Templater blocks are legitimate inside Templates/ (vault-map allows editing template
# logic on request) and always an accident outside it. So the gate is scoped by path.
case "$path" in
  */Templates/*) : ;;
  *)
    case "$old$(field '.tool_input.content')" in
      *'<%*'*)
        deny "Templater block outside Templates/: this writes a <%* ... %> block into $path, which only Obsidian executes. Template logic belongs in Templates/ and is changed deliberately, on request." ;;
    esac ;;
esac

# Rewriting an existing tasks query is banned; creating a new note containing one is not.
case "$old" in
  *'```tasks'*)
    deny "Live tasks query: this rewrites a fenced tasks block in $path. Those are evaluated by the Tasks plugin and define what the user sees. Edit the tasks themselves, not the query." ;;
esac

if [ "$(field '.tool_name')" = "Write" ] && [ -f "$path" ] && grep -Fq '```tasks' "$path" 2>/dev/null; then
  deny "Overwriting a file that contains a live tasks query: $path. A whole-file Write would replace the query block. Use Edit on the specific lines instead."
fi

exit 0
