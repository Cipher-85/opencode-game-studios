# Session Continuity

Continuity keeps the next OpenCode session focused without depending on long chat
history. Prefer small, current, file-backed state over broad transcripts.

## File Roles

- `production/session-state/active.md`: live working checkpoint and current
  session routing cache. Use for current task, progress checklist, decisions,
  files touched, open questions, owed verification, `## Session Worklist`, and
  `## Phase Guard`.
- `production/session-handoff.md`: canonical resume narrative when a session has
  enough state that another session should continue from it.
- `production/session-archive.md`: historical record only. Do not read by default
  unless the user asks for older context or the handoff points there.
- `src/README.md`: slice history and real-versus-stubbed status when present.
  Use bounded reads for ordinary routing; deep history is for explicit resume or
  audit work.

Missing files are unset state. Do not create continuity files unless the task or
skill calls for it.

## Pause Procedure

Before pausing a meaningful work unit:

1. Record what changed and what remains.
2. Record verification that passed, failed, was blocked, or was not run.
3. Read or refresh `## Session Worklist` in
   `production/session-state/active.md` and recommend the top valid lane.
   The final response must include completed work, verification or owed
   verification, and a numbered next-action prompt with exactly one
   `(Recommended)` option. Use this numeric fallback even when there is only one
   clear next lane:
   `Next action:` then `1. (Recommended) [action label] - [brief reason /
   command]`. The user can reply with `1`.
4. Preserve exact next commands only when they are known to be useful.
5. Keep local-only notes out of tracked docs unless they are project state.
6. Suggest `/handoff [short-label]` when installed and the next session would
   otherwise need to reconstruct context.

## Resume Procedure

On resume:

1. Read `production/session-handoff.md` if present.
2. Read `production/session-state/active.md` if present.
3. Read only the bounded files named by the handoff unless a deep audit is
   needed.
4. Verify drift-prone claims cheaply before acting on them.
5. Continue from the saved `## Session Worklist` unless there is a real
   inconsistency.

## Context Thresholds

Use the active reported context percentage, not hardcoded token math.

- Around 50%: prefer bounded reads and summarize decisions into files.
- Around 60-70%: compact or hand off after the current coherent unit.
- Above 70%: avoid starting broad multi-agent or multi-file work unless it is
  the only safe way to close the current unit.

## Threshold Handoff Phases

- Light handoff: one paragraph, files touched, owed verification, next action.
- Standard handoff: add decisions, open questions, and exact commands.
- Deep handoff: only for multi-day or cross-discipline work; include evidence
  pointers and why the next session should not restart planning.
