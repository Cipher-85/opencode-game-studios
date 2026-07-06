---
name: studio-next
description: "Deprecated manual continuity reference. Normal post-work routing now reads the Session Worklist and Phase Guard in production/session-state/active.md."
---

# Studio Next - Deprecated Manual Reference

Do not use this skill as an automatic post-work router. The live continuity
contract now lives in `production/session-state/active.md`:

- `## Session Worklist` - ranked next lanes compiled from the handoff backlog,
  sprint status, slice state, owed verification, and phase guardrails.
- `## Phase Guard` - stage file, workflow-catalog phase, first incomplete
  required step, next gate, and phase mismatch notes.

`/resume-from-handoff` is the one-time session-entry compiler that creates or
refreshes those sections. Later closeouts should read or update that saved
worklist directly, surface owed verification, and recommend the top valid lane.

This file remains only as a compatibility reference for old handoffs or explicit
user requests for `/studio-next`.

## Relationship To Nearby Skills

- `/help` remains the phase router. It reads the workflow catalog and identifies
  the first required phase step.
- `/project-stage-detect` remains the full artifact audit.
- `/resume-from-handoff` compiles the live backlog into
  `production/session-state/active.md` when a canonical handoff exists.
- `/story-done` remains the story closure verifier.
- `producer` remains an escalation path for scope, milestone, production
  planning, and cross-discipline coordination. Do not make producer always-on.

## Manual Compatibility Procedure

Use this only when the user explicitly invokes `/studio-next` or an older
handoff points here:

1. Read `production/session-state/active.md`.
2. If `## Session Worklist` exists, surface owed verification and recommend the
   top valid lane.
3. If the worklist is missing, stale, or conflicts with the handoff, say so.
   Recommend `/resume-from-handoff` only for a fresh session-entry compile.
4. If there is one obvious valid lane, state the exact start command. If
   multiple lanes are genuinely viable, use a compact numbered prompt with
   exactly one `(Recommended)` option.

Do not rebuild a separate backlog here unless the user explicitly asks for a
manual recovery from stale session state.
