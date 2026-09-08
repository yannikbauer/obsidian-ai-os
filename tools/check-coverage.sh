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

# 3b. Every skill and tool appears in the README's tree.
#     This is the check that grep cannot be: the system-impact step greps the docs for
#     the vocabulary of a change, which finds a mention that went STALE and is blind to
#     one that is MISSING. A skill that never existed leaves no word to search for, so
#     the README simply stayed silent about `retro` and `usage` and read as complete.
#     Absence is only visible when you enumerate the thing itself and ask the document.
#     Scope matters here: grepping the WHOLE README passes on any passing mention in
#     prose, so removing a skill from the tree left the check green. It reads the first
#     fenced block — the tree — and nothing else.
if [ -f README.md ]; then
  tree=$(awk '/^```/{n++; next} n==1' README.md)
  if [ -z "$tree" ]; then
    say "README has no fenced tree block to check the skills and tools against"
  else
    for d in skills/*/; do
      n=$(basename "$d")
      printf '%s' "$tree" | grep -Fq "$n/" || say "skill missing from README tree: $n"
    done
    for f in tools/*.sh; do
      [ -e "$f" ] || continue
      printf '%s' "$tree" | grep -Fq "$(basename "$f")" || say "tool missing from README tree: $f"
    done

    # The same absence check, for the two sets that drifted on 2026-09-07 within a single
    # session: a new integration pack and a new .local knob both reached the tree late, and
    # `correction-words.local` had never reached it at all.
    #
    # ENUMERATE THE TEMPLATES, NOT THE USER'S FILES. integrations/ and *.local hold personal
    # config; the README is generic and exported, so it must describe what SHIPS. Checking
    # the user's own integrations/ against it would demand the shared README name their
    # tools -- the exact generic/personal leak the architecture exists to prevent (L004).
    # templates/ is the shipped set, so it is the right thing to hold the README to.
    for t in templates/integrations/*.template.md; do
      [ -e "$t" ] || continue
      n=$(basename "$t" .template.md)
      printf '%s' "$tree" | grep -Fq "$n.md" \
        || say "integration pack missing from README tree: $n.md (template: $t)"
    done
    for t in templates/*.template.local; do
      [ -e "$t" ] || continue
      n=$(basename "$t" .template.local)
      printf '%s' "$tree" | grep -Fq "$n.local" \
        || say "config knob missing from README tree: $n.local (template: $t)"
    done
  fi
fi

# 3c. Every knob in config/ has a template, and so is forced into the README tree by 3b.
#     Before 2026-09-08 the six .local files sat at the top level, where export.sh's
#     NOT_EXPORTED line forced a decision on each one BY NAME. Collapsing them into a
#     folder collapsed six declarations into one -- and a new file dropped into config/
#     would inherit the exclusion in silence, which is L008 happening inside the very
#     mechanism built to stop it.
#
#     This is the replacement forcing function, and it runs from the other direction:
#     the folder is enumerated, and each file must have a shipped template. 3b then
#     requires that template to appear in the README tree. So a knob still cannot exist
#     without being described -- the thing that fails is now "no template" rather than
#     "no NOT_EXPORTED entry".
if [ -d config ]; then
  for c in config/*.local; do
    [ -e "$c" ] || continue
    n=$(basename "$c" .local)
    [ -f "templates/$n.template.local" ] \
      || say "config knob has no template, so nothing forces it into the README: $c (expected templates/$n.template.local)"
  done
fi

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

# 5. No live prose may cross-reference a rule BY ORDINAL. Same latent bug as a count
#    (check 4): inserting a rule silently invalidates every reference past it, and
#    nothing fails. On 2026-09-07 one inserted rule broke two references and produced a
#    duplicate ordinal in the same list, undetected until a retro looked. Refer to rules
#    by NAME.
#    Scope is live prose only. history/ is an append-only record and docs/ is dated —
#    a numeric reference there was true when written and must stay untouched, so
#    flagging it would be exactly the rule that fires on legitimate work (L006).
for f in CLAUDE.md skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  bad=$(grep -inE '\brules?[[:space:]]+[0-9]+\b' "$f" | head -1)
  [ -n "$bad" ] && say "$f cites a rule by ordinal, which breaks when a rule is inserted — name it instead: $bad"
done

[ "$problems" -eq 0 ] || exit 1
