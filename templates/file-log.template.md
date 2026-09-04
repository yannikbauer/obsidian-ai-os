# File Modification Log

Append-only audit trail of AI changes to **vault notes outside `_AI/`** (files under `_AI/` are version-controlled by git, which is their audit trail). One line per change. Newest at the bottom.

Format:
```
- YYYY-MM-DD HH:MM  [create|edit|delete]  <path>  — <one-line reason>
```

When snapshotting a task-system doc before a destructive edit, save the snapshot to `tmp/` (e.g. `tmp/<tool>-<page-id>_YYYY-MM-DD-HHMM.md`) and log it here. **`tmp/` is entirely gitignored**; everything in `history/` is tracked. Delete a snapshot once the edit it protected is confirmed good — see `tmp/README.md`.

---
