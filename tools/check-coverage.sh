#!/bin/sh
# check-coverage.sh — the enumerations that must match reality.
#
# The OS describes itself in several places that are allowlists or counts: export.sh
# copies a named set, install.sh scaffolds a named set, settings.json registers a named
# set, CLAUDE.md counts the gates. Each is correct when written and silently wrong after
# the next change, and none of them fails loudly — an unregistered hook is simply dead,
# an unexported folder is simply missing.
#
# So they are checked mechanically rather than remembered. Run by harness/tests/run.sh
# and by the retro skill's system-impact step.
#
# Exit 0 when every enumeration matches; 1 with one line per mismatch.
set -u
AI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$AI_DIR" || exit 1
problems=0
say() { printf '  %s\n' "$1"; problems=$((problems + 1)); }

# 1. Every hook script is registered, or it is dead code that looks installed.
for h in harness/hooks/*.sh; do
  case "$h" in */lib.sh) continue ;; esac
  grep -Fq "$(basename "$h")" harness/settings.json \
    || say "hook not registered in settings.json: $h"
done

# 2. Every template is scaffolded by install.sh, or a fresh install lacks the file and
#    no one ever learns the knob exists. templates/integrations/ is exempt on purpose:
#    integrations/ stays empty because a file's existence is the on-switch.
for t in templates/*.template.*; do
  [ -e "$t" ] || continue
  # match the basename: install.sh refers to templates as "$TPL/name" as well as by path
  grep -Fq "$(basename "$t")" setup/install.sh \
    || say "template never scaffolded by install.sh: $t"
done

# 3. Every tracked top-level entry is copied by export.sh or declared not-exported.
excl=$(grep '^# NOT_EXPORTED:' setup/export.sh | sed 's/^# NOT_EXPORTED://')
tracked=$(git ls-files 2>/dev/null | sed 's|/.*||' | sort -u)
# A loop over nothing passes silently, which is how a check reports success for work it
# never did (ledger L005). Say so instead — this is the normal state in a fresh export.
[ -n "$tracked" ] || printf '  note: no tracked files here, so export coverage was not checked\n'
for e in $tracked; do
  case " $excl " in *" $e "*) continue ;; esac
  case "$e" in .gitignore|LICENSE) continue ;; esac   # copied by explicit filename
  grep -Fq "\$AI_DIR/$e" setup/export.sh \
    || say "top-level entry neither exported nor declared NOT_EXPORTED: $e"
done

# 4. No prose may CLAIM A COUNT of hooks or gates. Counts drift, and worse, they drift
#    across units: "five rules" is enforced by four scripts, one of which covers three
#    rules on its own. The lists in CLAUDE.md and README enumerate instead, which cannot
#    go stale by arithmetic. Check 1 is what actually guarantees coverage.
for f in CLAUDE.md README.md; do
  [ -f "$f" ] || continue
  bad=$(grep -inE '\b(one|two|three|four|five|six|seven|eight|nine|ten|[0-9]+)[[:space:]]+(of these[[:space:]]+)?(rules?[[:space:]]+are[[:space:]]+enforced|hooks?|deny gates?|gates?)\b' "$f" \
        | grep -viE 'two `?Stop`? hooks' | head -1)
  [ -n "$bad" ] && say "$f states a hook/gate count, which drifts — enumerate instead: $bad"
done

[ "$problems" -eq 0 ] || exit 1
