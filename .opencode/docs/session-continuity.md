# Session Continuity

Continuity keeps the next OpenCode session focused without depending on long chat
history. Prefer small, current, file-backed state over broad transcripts.

## File Roles

- `production/session-state/active.md`: live working checkpoint and current
  session routing cache. Use for current task, progress checklist, decisions,
  files touched, open questions, owed verification, `## Session Worklist`, and
  `## Phase Guard`. It is derived local session state; once the underlying
  artifact or decision is approved, skills may update only this file without a
  separate write-approval prompt.
- `production/session-handoff.md`: canonical resume narrative when a session has
  enough state that another session should continue from it.
- `production/resume-index.md`: tracked accelerator derived by `/handoff`,
  capped at 10 KB, and disposable. Its slice hash may speed ordinary resume,
  but it never outranks the handoff, stage/sprint state, or current slice
  section.
- `production/session-archive.md`: historical record only. Do not read by default
  unless the user asks for older context or the handoff points there.
- `src/README.md`: slice history and real-versus-stubbed status when present.
  Use a handoff-declared path rather than assuming this filename. Ordinary
  resume reads at most the current 200-line/32-KiB section; only explicit
  `/resume-from-handoff deep [focus]` reads full slice history.

Missing files are unset state. Do not create continuity files unless the task or
skill calls for it.

The checkpoint exception is narrow. It never authorizes new design, game-feel,
balance, architecture, source, registry, index, status-file, commit, push,
branch, build, boot-smoke, mutating `gh`, or additional file changes.

## User-Owned Playtest Focus

When owed verification or the next valid lane is a user-owned playtest, preserve
a concrete focus brief in both the closeout and any `## Session Worklist` entry.
Use the label `Playtest focus:` and include:

- **Hypothesis**: what feeling, behavior, or evidence the playtest is probing.
- **Setup/build**: the build, command, save state, or scenario to use when
  known.
- **Observation prompts**: 2-4 observation prompts for specific things the
  user should watch for.
- **Verdict/evidence to return**: the user-owned pass/fail/needs-rethink
  verdict plus the notes, screenshots, logs, or playtest report path needed to
  make the evidence usable.

The brief narrows the test; it does not make the game-feel, balance, keep,
revert, or tune decision for the user.

## Pause Procedure

Before pausing a meaningful work unit, check whether the invoked workflow still
has automatic read-only phases remaining. Do not convert self-checks, readbacks,
scans, candidate discovery, context gathering, or validation summaries into
selectable `Next action` prompts. Keep going until a mutation prompt, design
decision, blocker, or true stop point.

1. Record what changed and what remains.
2. Record verification that passed, failed, was blocked, or was not run.
3. Read or silently refresh `## Session Worklist` in
   `production/session-state/active.md` and recommend the top valid lane.
   The final response must include completed work, verification or owed
   verification, and a numbered next-action prompt with exactly one
   `(Recommended)` option. Use this numeric fallback even when there is only one
   clear next lane:
   `Next action:` then `1. (Recommended) [action label] - [brief reason /
   command]`. The user can reply with `1`.
   If that lane is a user-owned playtest, include the preserved `Playtest
   focus:` brief before the next-action prompt.
4. Preserve exact next commands only when they are known to be useful.
5. Keep local-only notes out of tracked docs unless they are project state.
6. Suggest `/handoff [short-label]` when installed and the next session would
   otherwise need to reconstruct context.

Generic pause, stop, checkpoint, or resume-later wording authorizes this
recommendation only. The review-through-push transaction requires explicit
`/handoff` invocation or an equally explicit instruction to commit and push
the handoff.

For mixed or executable changes, that explicit transaction includes a fresh
built-in `explore` integrity review with a fresh context after the parent's
self-review. The reviewer is instruction-read-only, receives bounded scope and
contract evidence without the author's conclusions, and is guarded by a
before-and-after mutation snapshot. If fresh delegation or the no-mutation
check fails, stop before continuity rotation; never silently replace it with a
same-session review. Pure design/process-document sessions are exempt unless
the user requests the reviewer, and an explicit user waiver is required for a
disclosed same-session downgrade.

## Resume Procedure

On resume:

1. Read `production/session-handoff.md` in full if present, then the compact
   `production/resume-index.md` when available.
2. Run the `/resume-from-handoff` workflow once to compile
   `production/session-state/active.md` from the handoff, sprint status, stage,
   workflow catalog, and slice state.
3. Check the index slice path/hash and read only the bounded current slice
   section named by the handoff unless explicit `deep` mode is active.
4. Verify drift-prone claims cheaply before acting on them.
5. Continue from the saved `## Session Worklist` unless there is a real
   inconsistency.
6. Write `## Source Freshness` to `active.md`, then read the cache back and
   verify its source, phase guard, owed verification, and recommended lane.

Resolve conflicts in this order: handoff narrative and decisions; stage and
sprint anchors; fresh current slice facts; fresh resume index; same-session
`active.md`. Surface disagreement rather than normalizing it silently.

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
