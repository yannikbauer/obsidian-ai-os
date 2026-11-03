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
#    switch hooks off. The allowlist now lives in _AI/config/clickup-replace-allow.local.
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
ALLOW="$AI_ROOT/config/clickup-replace-allow.local"

# An allowlist line is `<page-id>` (full rewrite) or `<page-id> headers-only`. The second
# form exists for an archive page that must be CLEARED, not rewritten (added 2026-10-19):
# the replace is allowed only if every non-blank line of the new content is a bold header
# like `**MON:**`. So the one write it permits leaves no items, links or chips behind,
# and a full rewrite of that page stays banned. That a clear is SAFE (everything on the
# page already reached the notes) is Claude's to verify, per integrations/.
#
# `<page-id> no-links` (added 2026-10-20) is for a plain page Claude rewrites in full, like a
# meal-plan checklist: the replace is allowed only if the new content contains no ClickUp
# URL. A chip always serialises with one, so a page written this way never gains a chip from
# Claude. Whether the page it replaces had one is Claude's to check before writing.
if [ -n "$page" ] && [ -f "$ALLOW" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    # shellcheck disable=SC2086 # word-splitting the line into id + qualifier is the point
    set -- $line
    id=${1:-}; qual=${2:-}
    [ -n "$id" ] || continue
    [ "$id" = "$page" ] || continue
    case "$qual" in
      '')
        # Allowlisted. The remaining conditions (page name, chip-signature scan) are
        # Claude's to check and are stated in integrations/ — this hook cannot read the API.
        exit 0 ;;
      headers-only)
        if printf '%s\n' "$content" | grep -v '^[[:space:]]*$' \
             | grep -qv '^[[:space:]]*\*\*[^*][^*]*:\*\*[[:space:]]*$'; then
          deny "Page '$page' is allowlisted for headers-only replace: the new content may contain only bold section headers (e.g. **MON:**), one per line. This content has other lines, so it would be a rewrite, not a clear."
        fi
        exit 0 ;;
      no-links)
        if printf '%s' "$content" | grep -qi 'clickup\.com'; then
          deny "Page '$page' is allowlisted for no-links replace: the new content must not contain a ClickUp URL (that is how chips serialise). Remove the link, or write it as plain text."
        fi
        exit 0 ;;
      *)
        deny "Allowlist line for page '$page' has an unknown qualifier '$qual' (known: 'headers-only', 'no-links'). Fix _AI/config/clickup-replace-allow.local." ;;
    esac
  done < "$ALLOW"
fi

deny "Whole-page replace on page '${page:-<unknown>}' is banned (roadmap #1): it flattens rich nodes and silently destroys content, and no diff or snapshot can detect the damage. Note the tool DEFAULTS to replace — pass content_edit_mode explicitly. Use 'append'/'prepend', or target the staging page listed in _AI/config/clickup-replace-allow.local and merge by hand."
