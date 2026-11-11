#!/bin/sh
# check-coverage.sh — the enumerations that must match reality.
#
# The OS describes itself in several places that are allowlists or counts: export.sh
# copies a named set, install.sh scaffolds a named set, settings.json registers a named
# set, CLAUDE.md counts the gates. Each is correct when written and silently wrong after
# the next change, and none of them fails loudly — an unregistered hook is simply dead,
# an unexported folder is simply missing.
#
# So they are checked mechanically rather than remembered. Run by tests/run.sh
# and by the retro skill's system-impact step.
#
# Exit 0 when every enumeration matches; 1 with one line per mismatch.
set -u
AI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$AI_DIR" || exit 1
problems=0
say() { printf '  %s\n' "$1"; problems=$((problems + 1)); }

# 1. Every hook script is registered, or it is dead code that looks installed.
for h in .claude/hooks/*.sh; do
  case "$h" in */lib.sh) continue ;; esac
  grep -Fq "$(basename "$h")" .claude/settings.json \
    || say "hook not registered in settings.json: $h"
done

# 1b. ...and every registered command actually RESOLVES. Check 1 proves a hook is NAMED in
#     settings.json; it cannot tell a live path from a stale one. Hooks fail OPEN, so a path
#     left behind by a move produces a settings file that reads as fully wired and a vault
#     with no gates at all. That is precisely what the .claude/ migration could have shipped
#     on 2026-09-09, and why its eight hook paths were checked by hand instead (L019).
for c in $(grep -o '${CLAUDE_PROJECT_DIR}/[^"\\]*\.sh' .claude/settings.json 2>/dev/null | sort -u); do
  rel=${c#*/}    # drop "${CLAUDE_PROJECT_DIR}/"
  rel=${rel#*/}  # drop the repo's own directory name, whatever it is called
  [ -f "$rel" ] || say "settings.json registers a hook whose file does not exist: $c"
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
# The tree lives in guide/architecture.md since the README became an overview
# (2026-11-11); a copy without guides falls back to the README's first fenced block.
TREE_FILE=README.md
[ -f guide/architecture.md ] && TREE_FILE=guide/architecture.md
if [ -f "$TREE_FILE" ]; then
  tree=$(awk '/^```/{n++; next} n==1' "$TREE_FILE")
  if [ -z "$tree" ]; then
    say "$TREE_FILE has no fenced tree block to check the skills and tools against"
  else
    for d in .claude/skills/*/; do
      # A symlinked skill is a plugin's, not the OS's (Obsidian Copilot links its own
      # in here): gitignored, stripped from the export, so not the README's business.
      [ -L "${d%/}" ] && continue
      n=$(basename "$d")
      printf '%s' "$tree" | grep -Fq "$n/" || say "skill missing from README tree: $n"
    done
    # Every entry in tools/, not just *.sh: the Python tools reached the folder for weeks
    # without reaching the tree, because the glob only asked about shell scripts.
    for f in tools/*; do
      [ -e "$f" ] || continue
      case "$(basename "$f")" in __pycache__|*.pyc) continue ;; esac
      printf '%s' "$tree" | grep -Fq "$(basename "$f")" || say "tool missing from README tree: $f"
    done

    # Every folder inside setup/ (scheduled-tasks/, git-hooks/, ...). A folder there is
    # shipped machinery, and the tree listed only the scripts beside it.
    for d in setup/*/; do
      [ -d "$d" ] || continue
      n=$(basename "$d")
      printf '%s' "$tree" | grep -Fq "$n/" || say "setup folder missing from README tree: setup/$n/"
    done

    # Every map that ships a template. maps/ is personal, but a map install.sh scaffolds is
    # part of what a fresh install contains, so the tree must name it.
    for t in templates/*-map.template.md; do
      [ -e "$t" ] || continue
      n=$(basename "$t" .template.md)
      printf '%s' "$tree" | grep -Fq "$n.md" || say "scaffolded map missing from README tree: $n.md (template: $t)"
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

    # 3b-ii. The vault-root glue must be in the tree too. It is the part of the layout a
    #        reader is most likely to get wrong, because it is the part that is NOT in
    #        this repo — install.sh writes it, so nothing in a fresh clone shows it. The
    #        enumeration therefore comes from install.sh itself: every path it touches
    #        under the vault root must be findable in the tree.
    #        Only the lines that CREATE something count: a copy, a link, a mkdir, or the
    #        variable holding one. install.sh also *probes* the vault root (it looks for
    #        .obsidian, and it re-reads the stub's own imports), and a probe is not an
    #        artifact anyone needs documented.
    #        This matches on BASENAMES, so it cannot tell `.claude/skills` from any other
    #        `skills`. That is deliberate: the failure it exists to catch is a new root
    #        file appearing with no mention at all, not a subtly misplaced one.
    made=$(grep -E '^[[:space:]]*(cp|ln|mkdir)|^[A-Z_]+="\$VAULT_DIR/' setup/install.sh \
           | grep -o '\$VAULT_DIR/[^"]*' | sed 's|^\$VAULT_DIR/||' | sort -u)
    for v in $made; do
      b=$(basename "$v")
      printf '%s' "$tree" | grep -Fq "$b" \
        || say "vault-root file written by install.sh is missing from README tree: $v"
    done

    # 3b-iii. The symlinks install.sh makes through link_into_repo. The grep above cannot
    #         see them (the path sits in a variable inside the function), and a basename
    #         match would pass anyway: `agents` is named under _AI/.claude/ even while the
    #         vault-root block lacks it, which is exactly how the third link went
    #         undocumented. So these are checked against the vault-root part of the tree
    #         only, everything above the `_AI/` line, and must appear as a link (`->`).
    root_part=$(printf '%s\n' "$tree" | awk '/── _AI\//{exit} {print}')
    for l in $(sed -n 's/^link_into_repo[[:space:]]\{1,\}\([^[:space:]]\{1,\}\).*/\1/p' setup/install.sh); do
      printf '%s\n' "$root_part" | grep -E "[[:space:]]$l[[:space:]]+->" >/dev/null \
        || say "vault-root symlink made by install.sh is missing from the README tree's root block: .claude/$l"
    done
  fi
fi

# 3d. Every skill's frontmatter is well-formed. A skill whose `name` does not match its
#     directory, or whose description is empty, does not fail loudly — it simply never
#     gets picked, which looks identical to the model deciding not to use it.
for d in .claude/skills/*/; do
  n=$(basename "$d")
  f="$d/SKILL.md"
  [ -f "$f" ] || { say "skill directory has no SKILL.md: $d"; continue; }
  head -1 "$f" | grep -q '^---$' || { say "skill has no frontmatter: $f"; continue; }
  fm=$(awk 'NR>1 && /^---$/{exit} NR>1' "$f")
  dn=$(printf '%s' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  [ "$dn" = "$n" ] \
    || say "skill name '$dn' does not match its directory '$n' — it is addressed by directory: $f"
  printf '%s' "$fm" | grep -q '^description:' \
    || say "skill has no description, so nothing can trigger it: $f"
  # `description: >` puts the text on following lines; either shape must carry words.
  body=$(printf '%s' "$fm" | sed -n '/^description:/,$p' | sed 's/^description:[[:space:]]*>*//' | tr -d '[:space:]')
  [ -n "$body" ] || say "skill description is empty: $f"
  if printf '%s' "$fm" | grep -q '^allowed-tools:'; then
    at=$(printf '%s' "$fm" | sed -n 's/^allowed-tools:[[:space:]]*//p' | head -1)
    [ -n "$at" ] || say "skill declares allowed-tools but names none, which grants nothing: $f"
  fi
done

# 3e. .claude/ is the one directory OTHER PROGRAMS write into, so its ignore rule is a
#     whitelist (see .claude/README.md). A whitelist cannot fail the dangerous way — it
#     will not commit the next tool's droppings — but it fails the quiet way instead: a
#     new KIND of file is simply never tracked, works locally forever, and is missing
#     from the export. L008, in the mechanism built to prevent L008.
#
#     So the directory is walked, and every file must be one of two things: tracked, or
#     named on the ignore file's LOCAL_ONLY line. Anything else is a decision nobody has
#     made yet. Needs git to answer 'tracked', so it is skipped where check 3 already
#     reported there is no index to read (a fresh export).
if [ -d .claude ] && [ -n "$tracked" ]; then
  local_only=$(grep '^# LOCAL_ONLY:' .claude/.gitignore 2>/dev/null | sed 's/^# LOCAL_ONLY://')
  if [ -z "$local_only" ]; then
    say ".claude/.gitignore has no '# LOCAL_ONLY:' line, so nothing declares what may stay untracked"
  fi
  # A `for` over find, not a pipe into `while`: a piped loop runs in a subshell, so its
  # increments to $problems are discarded and the check reports success while printing
  # failures. Same shape as check 3's loop, and the reason this file has no pipes in it.
  for f in $(find .claude -type f | sed 's|^\./||'); do
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 && continue
    rest=${f#.claude/}
    # Match the declaration against BOTH the top segment and the basename: `sessions`
    # names a folder, `.DS_Store` names a file that can appear at any depth.
    case " $local_only " in *" ${rest%%/*} "*) continue ;; esac
    case " $local_only " in *" $(basename "$f") "*) continue ;; esac
    # skills/ is linked as a WHOLE directory, so anything that installs a project skill
    # writes it straight into this repo. Name that case for what it is rather than
    # leaving it to read as a generic bookkeeping slip.
    case "$rest" in
      skills/*) say "a skill under .claude/skills/ that this repo does not track: $f — another tool may have installed it here, or it is new and unstaged"; continue ;;
    esac
    say "under .claude/ but neither tracked nor declared LOCAL_ONLY: $f"
  done
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
for f in CLAUDE.md README.md guide/*.md; do
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
for f in CLAUDE.md .claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  bad=$(grep -inE '\brules?[[:space:]]+[0-9]+\b' "$f" | head -1)
  [ -n "$bad" ] && say "$f cites a rule by ordinal, which breaks when a rule is inserted — name it instead: $bad"
done

# 6. The README's "Where it's going" and the roadmap must agree.
#    Each bullet there carries a hidden `<!-- roadmap: N -->` tag. The README went on
#    promising a vault health check for a week after it shipped, and the roadmap kept a
#    shipped skill under *Next* for a month: both are drift between a promise and a fact
#    that already lives in a file, so both can be checked.
#      a) every bullet in that section carries a tag (else nothing ties it to anything);
#      b) when docs/roadmap.md exists, each tagged item exists and is NOT under *Done*;
#      c) no roadmap item outside *Done* says it shipped (struck heading, SHIPPED or
#         RESOLVED in the heading, or a paragraph opening "**Built YYYY-" / "**Shipped YYYY-").
#    docs/ is never exported, so (b) and (c) skip in a fork or the public repo; (a) holds
#    everywhere, because the README ships.
if [ -f README.md ]; then
  untagged=$(awk '
    /^## /{ insec = ($0 ~ /^## Where it.s going/); if (!insec && b != "") { if (b !~ /roadmap:/) print substr(b,1,60); b="" } ; next }
    !insec { next }
    /^- /{ if (b != "" && b !~ /roadmap:/) print substr(b,1,60); b=$0; next }
    /^[[:space:]]+[^[:space:]]/{ if (b != "") b = b " " $0; next }
    /^$/{ if (b != "" && b !~ /roadmap:/) print substr(b,1,60); b=""; next }
    END{ if (insec && b != "" && b !~ /roadmap:/) print substr(b,1,60) }' README.md)
  [ -z "$untagged" ] || say "README 'Where it's going' bullet has no <!-- roadmap: N --> tag: $(printf '%s' "$untagged" | head -1)"
fi
if [ -f docs/roadmap.md ]; then
  # one line per item: "<tier> <number> <shipped-flag>"
  items=$(awk '
    # Flush the pending item BEFORE switching tier: the last item of a tier is otherwise
    # printed under the next tier, which put a shipped item at the end of Later "in Done".
    /^## /{ if (num != "") print tier, num, flag; num=""; tier=$2; next }
    /^### [0-9]+\./{
      if (num != "") print tier, num, flag
      num=$2; sub(/\.$/, "", num)
      flag = ($0 ~ /~~|SHIPPED|RESOLVED/) ? "shipped" : "open"; next }
    /^\*\*(Built|Shipped) [0-9][0-9][0-9][0-9]-/{ if (num != "") flag="shipped" }
    END{ if (num != "") print tier, num, flag }' docs/roadmap.md)
  for n in $(printf '%s\n' "$items" | awk '$1 != "Done" && $3 == "shipped" {print $2}'); do
    say "roadmap item #$n says it shipped but is not under Done — move it"
  done
  if [ -f README.md ]; then
    for n in $(grep -o '<!-- roadmap: [0-9]* -->' README.md | grep -o '[0-9][0-9]*'); do
      t=$(printf '%s\n' "$items" | awk -v n="$n" '$2 == n {print $1; exit}')
      if [ -z "$t" ]; then
        say "README 'Where it's going' cites roadmap item #$n, which the roadmap does not have"
      elif [ "$t" = "Done" ]; then
        say "README 'Where it's going' still promises roadmap item #$n, which is Done — move it into the README's description of what exists"
      fi
    done
  fi
fi

# 7. The README is an overview; detail lives in guide/. Three mechanical halves of
#    "is this the right level of detail for a first read" (the judgment half is the
#    first-reader agent at publish, see guide/publishing.md):
#      a) length budgets: the whole README, and each of its `##` sections. A section that
#         outgrows its budget is a guide waiting to be written. Budgets are deliberately
#         loose; raise one here, in the open, rather than letting the page grow by default.
#      b) every guide is linked from the README. A guide nobody can reach from the front
#         page is the same absence check 3b runs for skills.
#      c) every relative link in the README and the guides resolves, anchors included.
#         Moving a README section into a guide breaks every `#anchor` that pointed at it,
#         silently on GitHub.
README_MAX_LINES=250
README_MAX_SECTION=45
if [ -f README.md ]; then
  n=$(wc -l < README.md | tr -d ' ')
  [ "$n" -le "$README_MAX_LINES" ] \
    || say "README is $n lines, over its budget of $README_MAX_LINES: move detail into a guide in guide/"
  long=$(awk -v max="$README_MAX_SECTION" '
    /^## /{ if (h != "" && c > max) print c " lines: " h; h=$0; c=0 }
    { c++ }
    END{ if (h != "" && c > max) print c " lines: " h }' README.md)
  [ -z "$long" ] \
    || say "README section over its budget of $README_MAX_SECTION lines ($(printf '%s' "$long" | head -1)): move the detail into a guide"
fi
if [ -d guide ]; then
  for g in guide/*.md; do
    [ -e "$g" ] || continue
    grep -Fq "]($g" README.md 2>/dev/null || say "guide not linked from the README: $g"
  done
fi
if command -v python3 >/dev/null 2>&1; then
  broken=$(python3 -I - README.md guide/*.md <<'PY'
import os, re, sys
def slug(h):
    h = re.sub(r'[`*_~]|<[^>]+>', '', h.strip().lower())
    h = re.sub(r'[^\w\- ]', '', h)
    return h.replace(' ', '-')
anchors = {}
def heads(path):
    if path not in anchors:
        seen, out = {}, set()
        fence = False
        for line in open(path, encoding='utf-8'):
            if line.startswith('```'):
                fence = not fence
            if fence or not re.match(r'#{1,6} ', line):
                continue
            s = slug(re.sub(r'^#+ ', '', line))
            k = seen.get(s, 0); seen[s] = k + 1
            out.add(s if k == 0 else f'{s}-{k}')
        anchors[path] = out
    return anchors[path]
for f in sys.argv[1:]:
    if not os.path.isfile(f):
        continue
    fence = False
    for i, line in enumerate(open(f, encoding='utf-8'), 1):
        if line.startswith('```'):
            fence = not fence
        if fence:
            continue
        for target in re.findall(r'\]\(([^)\s]+)\)', line):
            if re.match(r'[a-z]+:', target):
                continue
            path, _, frag = target.partition('#')
            dest = os.path.normpath(os.path.join(os.path.dirname(f), path)) if path else f
            if path and not os.path.exists(dest):
                print(f'{f}:{i} -> {target} (no such file)'); continue
            if frag and dest.endswith('.md') and frag not in heads(dest):
                print(f'{f}:{i} -> {target} (no such heading)')
PY
)
  [ -z "$broken" ] || say "broken relative link: $(printf '%s' "$broken" | head -1)"
else
  printf '  note: python3 not found, so relative links were not checked\n'
fi

[ "$problems" -eq 0 ] || exit 1
