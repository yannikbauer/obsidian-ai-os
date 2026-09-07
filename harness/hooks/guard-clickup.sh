#!/bin/sh
# PreToolUse (task-system doc pages): a whole-page replace silently destroys rich nodes.
# Roadmap #1 established that append is safe and replace is banned by default.
#
# TWO THINGS THIS GOT WRONG BEFORE 2026-09-07, both found the same minute:
#
# 1. IT WAS ABSOLUTE, AND THE RULE IT CAME FROM IS CONDITIONAL. integrations/ allowlists
#    one staging page for full rewrites. The hook denied it — and its own deny message
#    told the caller to "write to a staging page", which is exactly what was being denied.
#    That is L006: a "never" rule that fires on legitimate work teaches its owner to
#    switch hooks off. The allowlist now lives in _AI/clickup-replace-allow.local.
#
# 2. IT ONLY CAUGHT AN EXPLICIT `replace`. The tool's schema defaults content_edit_mode
#    to "replace", so OMITTING the field replaces the page — and the old `= "replace"`
#    test waved that through. A gate that reads the field but not the default protects
#    nothing against the most likely call shape. Absent + content present = replace.
. "$(dirname "$0")/lib.sh"

mode=$(field '.tool_input.content_edit_mode')
content=$(field '.tool_input.content')

# No content means no rewrite (a rename or subtitle change) — nothing to guard.
[ -n "$content" ] || exit 0
# The schema's default IS replace. Treat absent as replace; anything else is safe.
[ -z "$mode" ] || [ "$mode" = "replace" ] || exit 0

page=$(field '.tool_input.page_id')
AI_ROOT="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
ALLOW="$AI_ROOT/clickup-replace-allow.local"

if [ -n "$page" ] && [ -f "$ALLOW" ]; then
  while IFS= read -r id || [ -n "$id" ]; do
    case "$id" in ''|\#*) continue ;; esac
    # Trim surrounding whitespace without spawning a process.
    id=$(printf '%s' "$id" | tr -d '[:space:]')
    [ -n "$id" ] || continue
    if [ "$id" = "$page" ]; then
      # Allowlisted. The remaining conditions (page name, chip-signature scan) are
      # Claude's to check and are stated in integrations/ — this hook cannot read the API.
      exit 0
    fi
  done < "$ALLOW"
fi

deny "Whole-page replace on page '${page:-<unknown>}' is banned (roadmap #1): it flattens rich nodes and silently destroys content, and no diff or snapshot can detect the damage. Note the tool DEFAULTS to replace — pass content_edit_mode explicitly. Use 'append'/'prepend', or target the staging page listed in _AI/clickup-replace-allow.local and merge by hand."
