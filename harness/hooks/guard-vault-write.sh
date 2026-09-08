#!/bin/sh
# PreToolUse: read-only zones, Templater blocks, live tasks queries.
# Enforces three of the "Respect read-only zones" rules in _AI/CLAUDE.md.
#
# Matches TWO tool shapes, because the vault has two write routes (roadmap #31):
#   Write | Edit                  -> .tool_input.file_path (absolute)
#   mcp__*__vault_(write|append|patch|delete|move|copy)
#                                 -> .tool_input.path (vault-relative)
# The MCP route is the surgical one and the reason this gate exists at all: on
# 2026-09-07 an entire session's vault edits went through Bash, so this hook and
# trace-write did not fire once -- including eight edits to a note holding 20+
# live query blocks. A tool name is a representation, not the act (ledger L003).
. "$(dirname "$0")/lib.sh"

tool=$(field '.tool_name')
VAULT="${CLAUDE_PROJECT_DIR:-.}"

# Vault-relative MCP paths are normalised to absolute so that config/readonly-zones.local
# keeps its single documented form (*/Folder/*) and needs no change for this route.
abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$VAULT" "$1" ;; esac; }

path=$(field '.tool_input.file_path')
[ -n "$path" ] || path=$(field '.tool_input.path')
[ -n "$path" ] || exit 0
path=$(abspath "$path")

# Read-only zones are per-vault, so they are configuration, not code. Hardcoding
# them made this hook both a disclosure (the folder list describes someone's vault)
# and useless to anyone whose folders are named differently -- while the deny
# message claimed the list came from vault-map.md, which it never read.
#
# _AI/config/readonly-zones.local holds one shell glob per line and REPLACES the defaults
# below when present. It lives at the _AI root, alongside the other .local files,
# so the export allowlist leaves it behind.
AI_ROOT="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
ZONES="$AI_ROOT/config/readonly-zones.local"

zone_of() { # zone_of <path> -- prints the matching pattern, or nothing
  _p=$1
  if [ -f "$ZONES" ]; then
    while IFS= read -r pat || [ -n "$pat" ]; do
      case "$pat" in ''|\#*) continue ;; esac
      # $pat is deliberately unquoted: in `case`, that makes it a glob.
      case "$_p" in $pat) printf '%s' "$pat"; return ;; esac
    done < "$ZONES"
  else
    # Defaults for a vault that has not configured any: the two folder names
    # Obsidian itself creates. Deliberately conservative -- a missing config
    # should under-block rather than block a folder the user actually writes in.
    case "$_p" in
      */Archive/*|*/Attachments/*) printf 'built-in default' ;;
    esac
  fi
}

zone_hit=$(zone_of "$path")
if [ -n "$zone_hit" ]; then
  deny "Read-only zone: $path matches '$zone_hit' in _AI/config/readonly-zones.local (or the built-in defaults). Do not write here; if this is genuinely intended, ask the user first."
fi

# vault_move / vault_copy carry a second path. A gate that checked only the source
# would let a file be moved INTO a read-only zone -- the same fail-open shape as
# L014, one argument along.  vault_patch also has a `destination`, but it is an
# object (a heading move), so only a string is treated as a path.
dest=$(printf '%s' "$INPUT" | /usr/bin/jq -r '.tool_input.destination | select(type=="string") // empty' 2>/dev/null)
if [ -n "$dest" ]; then
  dest=$(abspath "$dest")
  zone_hit=$(zone_of "$dest")
  if [ -n "$zone_hit" ]; then
    deny "Read-only zone as destination: $dest matches '$zone_hit' in _AI/config/readonly-zones.local. Moving or copying a file into a read-only zone is still a write into it."
  fi
fi

old=$(field '.tool_input.old_string')
content=$(field '.tool_input.content')

# Templater blocks are legitimate inside Templates/ (vault-map allows editing template
# logic on request) and always an accident outside it. So the gate is scoped by path.
case "$path" in
  */Templates/*) : ;;
  *)
    case "$old$content" in
      *'<%*'*)
        deny "Templater block outside Templates/: this writes a <%* ... %> block into $path, which only Obsidian executes. Template logic belongs in Templates/ and is changed deliberately, on request." ;;
    esac ;;
esac

# Rewriting an existing tasks query is banned; creating a new note containing one is not.
case "$old" in
  *'```tasks'*)
    deny "Live tasks query: this rewrites a fenced tasks block in $path. Those are evaluated by the Tasks plugin and define what the user sees. Edit the tasks themselves, not the query." ;;
esac

# --- whole-file overwrites -------------------------------------------------
# `Write` and `vault_write` both replace a file entirely; vault_write's own
# description says it "overwrites without warning".
case "$tool" in
  Write|*vault_write)
    if [ -f "$path" ] && grep -Fq '```tasks' "$path" 2>/dev/null; then
      deny "Overwriting a file that contains a live tasks query: $path. A whole-file write would replace the query block. Use a surgical edit instead -- Edit on the specific lines, or vault_patch scoped to one heading."
    fi ;;
esac

# --- vault_patch: the two flags the fixture proved dangerous ---------------
case "$tool" in
  *vault_patch)
    if [ "$(field '.tool_input.createTargetIfMissing')" = "true" ]; then
      deny "vault_patch with createTargetIfMissing:true. Proven on a TEST fixture 2026-09-08: with this flag a heading address that is merely MIS-CASED ('Tasks Done' for 'Tasks done') silently creates a SECOND heading and writes there, instead of failing. Left at its default (false) the same call returns 'could not resolve heading target' and touches nothing. Drop the flag; if the section genuinely may not exist yet, create it in a deliberate, separate call."
    fi
    # A heading- or block-scoped replace/delete takes out the whole target subtree,
    # which is how a live query block dies without ever appearing in an argument.
    # `within` narrows the edit to one body block, so it is exempt.
    op=$(field '.tool_input.operation')
    tt=$(field '.tool_input.targetType')
    win=$(field '.tool_input.within')
    case "$op:$tt:$win" in
      replace:heading:|delete:heading:|replace:block:|delete:block:)
        if [ -f "$path" ] && grep -Fq '```tasks' "$path" 2>/dev/null; then
          deny "vault_patch $op on a $tt in $path, which contains a live tasks query. Without 'within', this operation replaces or deletes the target's whole subtree, and a fenced tasks block inside it would go with it. Narrow the edit with 'within' (one body block), or edit the tasks themselves rather than the section."
        fi ;;
    esac ;;
esac

# --- permanent deletion ----------------------------------------------------
# "Permanently deleting data" is prohibited outright. The default is trash, which
# is recoverable; the flag is what turns it into a one-way door.
case "$tool" in
  *vault_delete)
    if [ "$(field '.tool_input.permanent')" = "true" ]; then
      deny "vault_delete with permanent:true on $path. Permanent deletion is prohibited -- it bypasses Obsidian's trash and nothing recovers it. Delete to trash (drop the flag), and let the user empty it."
    fi ;;
esac

exit 0
