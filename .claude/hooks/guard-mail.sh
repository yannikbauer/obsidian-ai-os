#!/bin/sh
# PreToolUse (mail send/reply/forward): draft, never send.
#
# The matcher decides what reaches this script, so arriving here is the violation, with
# one exception: the matcher is a name pattern, and Claude Desktop's own tool for
# messaging another session (`mcp__ccd_session_mgmt__send_message`) matches it. That is
# not mail. It is exempted by exact name, so any new mail connector still lands on the
# deny. lib.sh runs first, which is why the malformed-input case exits 0 rather than
# denying.
. "$(dirname "$0")/lib.sh"

case "$(field '.tool_name')" in
  mcp__ccd_session_mgmt__send_message) exit 0 ;;
esac

deny "Draft, never send. This OS writes drafts and the user sends them; no session sends mail on their behalf. Use create_draft, then say it is ready for review."
