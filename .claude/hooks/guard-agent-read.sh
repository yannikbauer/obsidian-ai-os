#!/bin/sh
# PreToolUse (Read): scopes Read for the mail-reader subagents (newsletter-reader,
# job-mail-reader) to their own saved tool output.
#
# The reader handles untrusted mail, so it is built with as little as possible to act
# with. It needs Read for one reason: Claude Code saves any MCP result over 50,000
# characters to <session>/tool-results/ and hands back only a pointer, and long
# newsletters cross that line every week (5 of 33 threads in W43). Without Read those
# bodies were lost, and the fallback was a general-purpose agent with every tool,
# reading the same untrusted text. Everything else on disk -- me.md, finance notes --
# stays out of the reader's reach.
#
# Keyed on agent_type, which hooks receive for calls made inside a subagent. No field
# means the main session or an older harness: allow, fail open like every hook here.
# Whether the harness really sends the field is proven live, not by the fixtures
# (ledger L033).
. "$(dirname "$0")/lib.sh"

agent=$(field '.agent_type')
case "$agent" in
  newsletter-reader|job-mail-reader) ;;
  *) exit 0 ;;
esac

p=$(field '.tool_input.file_path')
case "$p" in
  *..*) ;;
  "$HOME"/.claude/projects/*/tool-results/*) exit 0 ;;
esac

deny "$agent may only Read its own saved get_thread output under ~/.claude/projects/*/tool-results/. It reads untrusted mail, so the rest of the filesystem is out of its scope."
