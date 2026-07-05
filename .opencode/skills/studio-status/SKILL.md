---
name: studio-status
description: "Render the OpenCode Game Studios project-stage, review-mode, and active-session breadcrumb from shared project state."
---

# Studio Status

Render the current project-stage, review-mode, and active-session breadcrumb
from shared project state files. This is an on-demand status read — it does
not modify anything.

## State Files Read

Read each of these if it exists. Missing files are reported as `unset`; do not
create them.

1. `production/stage.txt` — the current workflow stage.
2. `production/review-mode.txt` — the review intensity mode.
3. `production/session-state/active.md` — the live session checkpoint (read
   the `<!-- STATUS -->` block if present for the Epic/Feature/Task breadcrumb).

## Output Shape

```text
Stage: <stage or unset> | Review mode: <mode or unset>
Active: <Epic > Feature > Task breadcrumb, or none>
```

If the `<!-- STATUS -->` block is present in `active.md`, parse the `Epic:`,
`Feature:`, and `Task:` lines to build the breadcrumb.

## Notes

- This skill complements OpenCode's built-in context display. It does not
  replace the TUI footer.
- All values are file-reported (read from disk), not verified at runtime.
- If no project state has been initialized, report `Stage: unset` and suggest
  running `/start`.
