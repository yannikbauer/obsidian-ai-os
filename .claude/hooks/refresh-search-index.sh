#!/bin/sh
# SessionStart: refreshes the vault search index in the background, so a session
# searches notes as they are now, not as they were at the last full build (roadmap #10).
#
# Incremental: only notes whose mtime and hash changed are re-embedded, usually seconds.
# Detached and silent: the session never waits on it, and a failure (Ollama not running,
# uv missing) leaves the old index in place; search then warns that it is stale.
# The indexer's own lock file stops two sessions starting at once from both indexing.
#
# Only refreshes an index that already exists. Building the first one is a 30–90 minute
# job the setup skill starts deliberately, not something to spring on a session start.
. "$(dirname "$0")/lib.sh"

DB="${AIOS_SEARCH_DB:-$AIOS_DIR/databases/vault-search.db}"
[ -f "$DB" ] || exit 0
command -v uv >/dev/null 2>&1 || exit 0

mkdir -p "$AIOS_DIR/tmp" 2>/dev/null
nohup "$AIOS_DIR/tools/vault-search.py" index >"$AIOS_DIR/tmp/vault-search-refresh.log" 2>&1 </dev/null &
exit 0
