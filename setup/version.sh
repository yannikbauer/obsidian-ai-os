#!/usr/bin/env bash
#
# version.sh — read, validate and advance the OS's version number.
#
# Split out of publish.sh for the reason leak-check.sh was: the part worth testing
# is the arithmetic, and a function living inside a script whose main path pushes to
# a public remote cannot be exercised by the test suite.
#
#   version.sh current              print _AI/VERSION  (0.0.0 if the file is absent)
#   version.sh validate <ver>       exit 0 if <ver> is X.Y.Z, 1 otherwise
#   version.sh bump <ver> <level>   print <ver> advanced by patch | minor | major
#   version.sh changelog <file> <ver> <date>
#                                   prepend a release entry, reading it from stdin
#
# SemVer, held loosely, on 0.x. The only distinction that carries information for
# someone who has forked this is whether an update needs them to do something:
#
#   major  their install needs manual action — a renamed .local knob, a moved path,
#          scaffolding install.sh cannot add on a re-run
#   minor  new or changed behaviour that a plain `git pull` absorbs
#   patch  fixes and wording
#
# There is no meaning here beyond that, and inventing one would only create a
# decision to get wrong every publish.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$(dirname "$SCRIPT_DIR")"

usage () { sed -n '4,12p' "$0" >&2; exit 64; }

is_semver () {
  case "$1" in
    *[!0-9.]* | .* | *. | *..* ) return 1 ;;
  esac
  # exactly three fields, each non-empty and numeric (the case above already
  # rejected every non-digit, so a field is numeric iff it is non-empty)
  local IFS=.
  # shellcheck disable=SC2206
  local parts=($1)
  [ "${#parts[@]}" -eq 3 ] || return 1
  [ -n "${parts[0]}" ] && [ -n "${parts[1]}" ] && [ -n "${parts[2]}" ]
}

[ $# -ge 1 ] || usage

case "$1" in
  current)
    if [ -f "$AI_DIR/VERSION" ]; then
      # tolerate a trailing newline and stray whitespace; refuse anything else,
      # because a malformed VERSION would otherwise become a malformed git tag
      v="$(tr -d '[:space:]' < "$AI_DIR/VERSION")"
      if is_semver "$v"; then printf '%s\n' "$v"; else
        echo "! _AI/VERSION does not hold an X.Y.Z version: '$v'" >&2; exit 1
      fi
    else
      printf '0.0.0\n'
    fi
    ;;

  validate)
    [ $# -eq 2 ] || usage
    is_semver "$2" || exit 1
    ;;

  bump)
    [ $# -eq 3 ] || usage
    is_semver "$2" || { echo "! not a version: $2" >&2; exit 1; }
    IFS=. read -r MAJ MIN PAT <<EOSV
$2
EOSV
    case "$3" in
      major) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
      minor) MIN=$((MIN + 1)); PAT=0 ;;
      patch) PAT=$((PAT + 1)) ;;
      *) echo "! level must be major, minor or patch: $3" >&2; exit 64 ;;
    esac
    printf '%s.%s.%s\n' "$MAJ" "$MIN" "$PAT"
    ;;

  changelog)
    [ $# -eq 4 ] || usage
    CL="$2"
    is_semver "$3" || { echo "! not a version: $3" >&2; exit 1; }
    ENTRIES="$(cat)"
    [ -n "$ENTRIES" ] || { echo "! refusing to write an empty changelog entry" >&2; exit 1; }
    TMP="$(mktemp)"
    {
      printf '# Changelog\n\n'
      printf '## v%s \342\200\224 %s\n\n' "$3" "$4"
      printf '%s\n' "$ENTRIES"
      # Prepend rather than append: the newest release is what a reader wants first.
      # The existing file keeps everything BELOW its title, so the title is not
      # duplicated and no previous entry is touched.
      if [ -f "$CL" ]; then
        printf '\n'
        sed '1{/^# Changelog$/d;}' "$CL" | sed '1{/^$/d;}'
      fi
    } > "$TMP"
    mv "$TMP" "$CL"
    ;;

  *) usage ;;
esac
