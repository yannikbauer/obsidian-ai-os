#!/bin/sh
# UserPromptSubmit: put the local date and time in front of every user message.
#
# Why: time-of-day statements ("tonight", "go to sleep") were made without checking the
# clock while it was midday (L039). A context line on every prompt is cheaper and more
# reliable than a prose rule. Fails open: if date or jq is missing, it stays silent.
NOW=$(LC_TIME=C date '+%a %Y-%m-%d %H:%M %Z') || exit 0
/usr/bin/jq -n --arg m "Current local time: $NOW. Use it for any time-of-day or day statement; don't guess." \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}' 2>/dev/null
exit 0
