#!/bin/sh
# PreToolUse (Bash): the coarse second gate over the vault's read-only zones.
#
# guard-vault-write.sh sees Write/Edit and the MCP vault_* tools. Bash reaches the
# same files and is matched by neither -- proven 2026-09-07, when every vault edit of
# a long session went through the shell and the read-only-zone gate did not run once.
# Roadmap #31 narrows that hole by routing note writes through the API; this hook is
# the admission that narrowing is not sealing.
#
# It ASKS, it does not deny -- the same posture as suggest-retro.sh, and for the same
# reason. Deciding correctly would mean parsing target paths out of arbitrary shell,
# which is either leaky or maddening. So the test is deliberately dumb: does this
# command name a read-only zone AND look like it mutates something? A false ask costs
# one keystroke. A false deny teaches its owner to switch hooks off, which costs
# every gate in the repo.
. "$(dirname "$0")/lib.sh"

cmd=$(field '.tool_input.command')
[ -n "$cmd" ] || exit 0

AI_ROOT="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)"
ZONES="$AI_ROOT/config/readonly-zones.local"

# The zone list is globs meant for whole paths (*/Archive/*). Here they are used as
# substrings of a command line, so the glob decoration is stripped down to the bare
# name -- coarse on purpose.
zone_hit=''
if [ -f "$ZONES" ]; then
  while IFS= read -r pat || [ -n "$pat" ]; do
    case "$pat" in ''|\#*) continue ;; esac
    bare=$(printf '%s' "$pat" | sed 's#^\*/##; s#/\*$##; s#^\*##; s#\*$##')
    [ -n "$bare" ] || continue
    case "$cmd" in *"$bare"*) zone_hit="$bare"; break ;; esac
  done < "$ZONES"
else
  case "$cmd" in
    *Archive*)     zone_hit='Archive' ;;
    *Attachments*) zone_hit='Attachments' ;;
  esac
fi

[ -n "$zone_hit" ] || exit 0

# Mutating shapes. `2>&1` is excluded by requiring the character after the redirect
# to be something other than `&` -- a `>` is not a write (session-digest, 2026-09-07).
if printf '%s' "$cmd" | grep -qE '(^|[^0-9A-Za-z_])(rm|mv|cp|tee|truncate|dd|install|touch|mkdir)[[:space:]]|(sed|perl|ruby)[[:space:]]+[^|]*-i|>>?[[:space:]]*[^&[:space:]=]'; then
  ask "This Bash command names '$zone_hit', a read-only zone from _AI/config/readonly-zones.local, and looks like it modifies something. guard-vault-write.sh cannot inspect shell commands, so this is a coarse check that asks rather than guesses. If the command only READS from that folder, or touches an unrelated path that happens to share the name, allow it. If it writes into the zone, it should not run."
fi

exit 0
