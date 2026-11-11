---
id: vault-health-weekly
title: Vault health check (weekly)
cron: "30 7 * * 1"
description: Weekly read-only vault health report plus description proposals into _AI/tmp/health/ (no note writes)
needs: [notes, vault-maintenance skill, tools/vault-health-weekly.sh]
mode: unattended
---
Working directory: {{VAULT}}/_AI

First step, before anything else: turn on Remote Control for this session with `set_remote_control` (session_id "self", enabled true; load it via ToolSearch if deferred), so the user can follow the run from their phone. If it is refused or unavailable (unattended sessions may be refused), don't retry; say so in one line and carry on.

Start the weekly vault health run, detached so the app cannot kill it (ledger L035), with exactly this one command:

nohup "{{VAULT}}/_AI/tools/vault-health-weekly.sh" >/dev/null 2>&1 &

Then wait about 60 seconds and print the first line starting with "# " of _AI/tmp/health/<today's date YYYY-MM-DD>.md if it exists (the file opens with a short frontmatter block, so skip past it). If it doesn't exist yet, say the run is still going (proposing descriptions for private notes on the local model can take several minutes).

Rules: apart from the Remote Control step above, do nothing else. Don't run `vault-health.py report --save` yourself. Don't edit, apply or write any vault note, and don't run frontmatter-set.py; applying proposals is the user's "apply" in the Monday review. Ask no questions, because nobody is present.
