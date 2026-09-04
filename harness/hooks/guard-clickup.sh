#!/bin/sh
# PreToolUse (ClickUp doc pages): a whole-page replace silently destroys rich nodes.
# Roadmap #1 established that append is safe and replace is banned.
. "$(dirname "$0")/lib.sh"

if [ "$(field '.tool_input.content_edit_mode')" = "replace" ]; then
  deny "content_edit_mode 'replace' is banned (roadmap #1): a whole-page rewrite flattens rich nodes and silently destroys content. Use 'append', or write to a staging page and let the user merge."
fi
exit 0
