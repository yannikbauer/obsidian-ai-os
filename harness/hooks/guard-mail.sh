#!/bin/sh
# PreToolUse (mail send/reply/forward): draft, never send.
#
# There is no condition to test. The matcher decides what reaches this script, so
# arriving here at all is the violation. lib.sh still runs first, which is why the
# malformed-input case exits 0 rather than denying.
. "$(dirname "$0")/lib.sh"

deny "Draft, never send. This OS writes drafts and the user sends them; no session sends mail on their behalf. Use create_draft, then say it is ready for review."
