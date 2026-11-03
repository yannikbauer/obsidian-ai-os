#!/bin/sh
# macwhisper-live.sh: print the transcript of a MacWhisper recording, including one
# still running, from the app's history database.
#
# Read-only. Opens the database with -readonly and mode=ro, and writes nothing anywhere.
#
# WHY THE DATABASE. MacWhisper pushes a transcript to the vault only after a recording
# ends, and that push drops speaker labels. The history database gets each line 2-10 s
# after it is spoken (verified 2026-09-18), with speaker and timing. It is the only live
# source, and the richer one afterwards too. Its format is undocumented, so this script
# is the one place that knows it: when an update breaks it, fix it here.
#
# Usage:
#   macwhisper-live.sh                 newest recording, all lines
#   macwhisper-live.sh --since N       only lines after line N (the footer prints N; it
#                                      repeats the last line, which may still be growing)
#   macwhisper-live.sh --session ID    a specific recording (hex id prefix, from --list)
#   macwhisper-live.sh --list          the 10 most recent recordings
#   macwhisper-live.sh --recording-start [--session ID]
#                                      when the recording really started, as local
#                                      YYYY-MM-DDTHH:MM:SS plus its source
#
# Output: a header, then one block per speaker turn (consecutive lines of one speaker are
# merged), then a footer naming the value for the next --since. Merging and --since keep
# repeated checks during a long meeting cheap: the caller keeps what it has already read.
#
# RECORDING START. session.dateCreated (the note's "Recorded At") is when MacWhisper
# created the entry, which for a voice memo is when transcription began: seconds after
# the recording ends, or hours later if it was transcribed later. MacWhisper keeps the
# memo's audio as ExternalMedia/<session-uuid>_voicememo_*.m4a, whose birth time is the
# start (birth + duration = mtime, checked on three memos 2026-10-13). Meetings write
# their audio at the end, but their dateCreated already is the start.
set -u

DB="${MACWHISPER_DB:-$HOME/Library/Application Support/MacWhisper/Database/main.sqlite}"
SINCE=0
SESSION=""
LIST=0
START=0

while [ $# -gt 0 ]; do
  case "$1" in
    --since)   SINCE="${2:-0}"; shift 2 ;;
    --session) SESSION="${2:-}"; shift 2 ;;
    --list)    LIST=1; shift ;;
    --recording-start) START=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

case "$SINCE" in ''|*[!0-9]*) echo "--since takes a line number" >&2; exit 64 ;; esac
case "$SESSION" in *[!0-9A-Fa-f]*) echo "--session takes a hex id prefix" >&2; exit 64 ;; esac
command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 not found" >&2; exit 69; }
[ -f "$DB" ] || { echo "MacWhisper database not found: $DB" >&2; exit 66; }

q() { sqlite3 -readonly -separator '	' "file:$DB?mode=ro" "$1"; }

if [ "$LIST" -eq 1 ]; then
  q "select substr(hex(id),1,8), datetime(dateCreated,'localtime'),
            coalesce(userChosenTitle, aiTitle, '(untitled)'),
            coalesce(cast(round(playbackDuration) as int), '?') || ' s',
            (select count(*) from transcriptline t where t.sessionId = session.id) || ' lines'
     from session where dateDeleted is null order by dateCreated desc limit 10;" \
    | awk -F'\t' '{ printf "%s  %s  %-40s %8s  %s\n", $1, $2, $3, $4, $5 }'
  exit 0
fi

if [ -n "$SESSION" ]; then
  sel="hex(session.id) like upper('$SESSION') || '%'"
else
  sel="session.id = (select id from session where dateDeleted is null order by dateCreated desc limit 1)"
fi

head=$(q "select substr(hex(id),1,8), datetime(dateCreated,'localtime'),
              coalesce(userChosenTitle, aiTitle, '(untitled)'),
              cast((julianday('now') - julianday(coalesce(
                (select max(t.dateCreated) from transcriptline t where t.sessionId = session.id),
                dateCreated))) * 86400 as int)
          from session where $sel and dateDeleted is null order by dateCreated desc limit 1;")
[ -n "$head" ] || { echo "no matching recording" >&2; exit 1; }

if [ "$START" -eq 1 ]; then
  uuid=$(q "select lower(substr(hex(id),1,8)||'-'||substr(hex(id),9,4)||'-'||substr(hex(id),13,4)||'-'
                  ||substr(hex(id),17,4)||'-'||substr(hex(id),21,12))
            from session where $sel and dateDeleted is null order by dateCreated desc limit 1;")
  media="$(dirname "$DB")/ExternalMedia"
  for f in "$media"/*; do
    case "$(basename "$f" | tr 'A-F' 'a-f')" in "${uuid}"_voicememo_*)
      # BSD stat gives the birth time. MacWhisper only runs on macOS, so the GNU fallback
      # (modification time) exists for the Linux CI runner, where birth time can't be set.
      t=$(stat -f %SB -t %Y-%m-%dT%H:%M:%S "$f" 2>/dev/null) \
        || t=$(date -r "$f" +%Y-%m-%dT%H:%M:%S)
      printf '%s\tvoice memo audio\n' "$t"; exit 0 ;;
    esac
  done
  printf '%s\n' "$head" | awk -F'\t' '{ sub(" ", "T", $2); printf "%s\tsession created (start for meetings; transcription time for imported files)\n", $2 }'
  exit 0
fi

printf '%s\n' "$head" | awk -F'\t' '{
  printf "# %s · started %s · session %s · last line %ss ago\n", $3, substr($2, 12, 5), $1, $4 }'

q "select t.orderIndex, t.start, coalesce(s.name, 'Unknown'),
          replace(replace(t.text, char(10), ' '), char(9), ' ')
   from transcriptline t
   join session on session.id = t.sessionId
   left join speaker s on s.id = t.speakerID
   where $sel and coalesce(t.orderIndex, 0) > $SINCE
   order by coalesce(t.orderIndex, t.start);" \
| awk -F'\t' -v since="$SINCE" '
  function ts(ms,  s) { s = int(ms / 1000); return sprintf("%02d:%02d", int(s / 60), s % 60) }
  {
    if ($3 != spk) { if (NR > 1) printf "\n\n"; printf "[%s] %s: %s", ts($2), $3, $4; spk = $3 }
    else printf " %s", $4
    last = $1; n++
  }
  END {
    if (n) printf "\n\n"
    else   printf "(no new lines since %s)\n\n", since
    # The newest line keeps growing while it is being spoken (seen 2026-09-18: updated
    # 4 s after it was created), so the next check starts one line back and re-reads it.
    printf "# %d new line(s) · next check: --since %s\n", n, (n ? (last > 0 ? last - 1 : 0) : since)
  }'
