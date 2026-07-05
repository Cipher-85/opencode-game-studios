# OpenCode Game Studios

<!-- BEGIN CCGS OPENCODE PORT -->

OpenCode Game Studios coordinates indie game development through 49 OpenCode
subagents with strict domain ownership, user-owned design decisions, and
verification-first implementation.

## Startup Contract

- Treat `.opencode/agents/*.md` as the authoritative role registration source.
- Use exact hyphenated agent names. Shorthand: CD is `creative-director`, TD is
  `technical-director`, and LP is `lead-programmer`.
- Do not write to legacy Claude runtime files or add them as OpenCode runtime
  dependencies.
- Do not commit, push, or make game-feel/balance decisions without explicit user
  instruction.
- Use the active reported context percentage for compaction and handoff
  decisions; do not rely on hardcoded token-window math.

## Resume And Wrap-Up Routing

- When the user asks to resume, catch up, pick up where they left off, find the
  current state, or choose the next work item from saved state, use
  `/resume-from-handoff` if `production/session-handoff.md` exists.
- If no handoff exists, do not infer one from another doc. Route first-session
  setup to `/start`, broad orientation to `/help`, or full gap discovery to
  `/project-stage-detect`.
- At wrap-up, keep `/studio-next` as the lightweight epilogue router and suggest
  `/handoff` only when the current state should be durable for a future session.

## Available OpenCode Subagents

- Leadership: `creative-director`, `technical-director`, `producer`.
- Department leads: `game-designer`, `lead-programmer`, `art-director`,
  `audio-director`, `narrative-director`, `qa-lead`, `release-manager`,
  `localization-lead`.
- Design/content: `systems-designer`, `level-designer`, `economy-designer`,
  `writer`, `world-builder`, `ux-designer`, `accessibility-specialist`,
  `live-ops-designer`, `community-manager`, `analytics-engineer`.
- Engineering/QA/ops: `gameplay-programmer`, `engine-programmer`,
  `ai-programmer`, `network-programmer`, `tools-programmer`, `ui-programmer`,
  `technical-artist`, `sound-designer`, `performance-analyst`,
  `security-engineer`, `devops-engineer`, `qa-tester`, `prototyper`.
- Engine agents: `godot-specialist`, `godot-gdscript-specialist`,
  `godot-csharp-specialist`, `godot-shader-specialist`,
  `godot-gdextension-specialist`, `unity-specialist`, `unity-dots-specialist`,
  `unity-shader-specialist`, `unity-addressables-specialist`,
  `unity-ui-specialist`, `unreal-specialist`, `ue-blueprint-specialist`,
  `ue-gas-specialist`, `ue-replication-specialist`, `ue-umg-specialist`.

## Technology Stack

- Engine: [CHOOSE: Godot 4 / Unity / Unreal Engine 5].
- Primary language: [CHOOSE: GDScript / C# / C++ / Blueprint].
- Version control: Git with trunk-based development.
- Build system: [SPECIFY after choosing engine].
- Asset pipeline: [SPECIFY after choosing engine].
- Engine reference: after engine setup, read the matching
  `docs/engine-reference/<engine>/VERSION.md` before using engine APIs; the
  pinned engine may be newer than much model training data.
- Technical routing: read `.opencode/docs/technical-preferences.md` when
  selecting engine specialists or file-extension routing.

## Collaboration Boundary

This project is user-driven, not autonomous execution. Every task follows:
Question -> Options -> Decision -> Draft -> Approval.

- Agents must ask "May I write this to [filepath]?" before using write/edit
  tools.
- Agents must show drafts or summaries before requesting approval.
- Multi-file changes require explicit approval for the full changeset.
- `/handoff` exception: explicit invocation of the OpenCode-native `/handoff`
  skill counts as user approval for that skill's declared handoff workflow only:
  update `production/session-handoff.md`, `production/session-archive.md`, and
  `production/session-state/active.md`; stage relevant uncommitted changes by
  path; create the standard handoff commit; and push the current branch.
- The `/handoff` exception does not authorize design/game-feel/balance
  decisions, new source edits outside the continuity files, writes to undeclared
  files, branch switching, force-pushes, or `--no-verify` / amend workarounds.
- No commits without user instruction.

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

## Low-Friction Decision Prompts

OpenCode surfaces may not always provide a clickable choice UI. When handing
control back to the user, make the reply easy to answer with a short token.

- For multiple viable choices, list all real options, usually 3-5 when available
  and fewer when fewer are viable. Do not invent filler options.
- Use numbered options for multi-choice prompts. Mark exactly one option
  `(Recommended)`.
- For yes/no confirmations, include explicit letter shortcuts:
  - `a. yes`
  - `b. no`
- Keep each option label short. Put reasoning in one brief sentence before the
  options or after each option only when needed.
- Never end with an unstructured "what do you want to do?" when a small viable
  choice set is possible.

## Verification Integrity

- Never claim a build, test, lint, smoke check, or playtest passed unless it ran
  in this turn or you clearly label it as file-reported historical evidence.
- If verification is blocked, state the blocker and the exact command or action
  still owed.
- Treat CI output as evidence only after reading the relevant job or log result,
  not from a status badge or assumption.
- After any false pass claim or uncertain verification state, follow
  `.opencode/docs/verification-integrity.md` before closing the work.

## Vertical-Slice Forcing Function

Before recommending process work, identify the smallest next playable advance.
Classify plausible lanes as:

- `extend`: directly makes the playable slice larger or more complete.
- `feed`: supplies required design, art, QA, or architecture input for the slice.
- `carve-out`: useful but not on the slice path.

The smallest playable advance wins unless owed verification, a gate, or a
blocker must be cleared first.

## Path-Scoped Instructions

Before creating or editing files matching a path below, read the listed rule
file(s) from `.opencode/rules/` with your Read tool. These files contain
discipline rules you must follow for that path.

| Path | Rule file(s) |
| ---- | ---- |
| `src/**` | `.opencode/rules/source-code.md` |
| `src/gameplay/**` | `.opencode/rules/source-code.md`, `.opencode/rules/gameplay-code.md` |
| `src/core/**` | `.opencode/rules/source-code.md`, `.opencode/rules/engine-code.md` |
| `src/ai/**` | `.opencode/rules/source-code.md`, `.opencode/rules/ai-code.md` |
| `src/networking/**` | `.opencode/rules/source-code.md`, `.opencode/rules/network-code.md` |
| `src/ui/**` | `.opencode/rules/source-code.md`, `.opencode/rules/ui-code.md` |
| `design/**` | `.opencode/rules/design-directory.md` |
| `design/gdd/**` | `.opencode/rules/design-directory.md`, `.opencode/rules/design-docs.md` |
| `design/narrative/**` | `.opencode/rules/design-directory.md`, `.opencode/rules/narrative.md` |
| `docs/**` | `.opencode/rules/docs-directory.md` |
| `assets/data/**` | `.opencode/rules/data-files.md` |
| `assets/shaders/**` | `.opencode/rules/shader-code.md` |
| `tests/**` | `.opencode/rules/test-standards.md` |
| `tools/**` | `.opencode/rules/tool-code.md` |
| `prototypes/**` | `.opencode/rules/prototype-code.md` |

## Code-Turn Discipline

For code, tests, and tools:

1. Think before coding: identify the behavioral contract and the minimal files
   that need to change.
2. Define verifiable success before editing.
3. Prefer the simplest working design that fits existing patterns.
4. Make surgical changes and avoid unrelated refactors.
5. Verify with the narrowest meaningful command, then broaden when risk warrants.

## Workflow Gates

- Run `/design-review` before handing a GDD to programmers. Its verdict gates
  implementation work that depends on that GDD.
- Run `/story-done` before marking a story complete.
- Run `/smoke-check` before QA hand-off; a failed smoke check blocks QA.
- Run `/team-qa` when seeking sprint or feature QA sign-off.
- Run `/code-review` after major features or when the current story/sprint state
  calls for architectural review; it is recommended unless the active story
  workflow or review mode makes it a gate.

## File Lifecycle

- Tracked docs are the project memory. Keep active state in
  `production/session-state/active.md` when the project has one.
- Preserve session continuity in `production/session-handoff.md`; archive only
  when the continuity docs call for it.
- Keep generated caches, local-only logs, and transient evidence out of tracked
  runtime instructions unless a doc explicitly says otherwise.
- Full rules: `.opencode/docs/file-lifecycle.md`.

## Continuity Epilogue

After each discrete work unit, apply this mentally or run `/studio-next`:

1. Summarize what was completed.
2. Surface owed verification.
3. List the viable next actions from handoff, session, sprint, stage, workflow,
   and slice state, with one clearly marked `(Recommended)`.
4. Suggest `/handoff` when session state should be preserved.

Read `.opencode/docs/session-continuity.md` and
`.opencode/docs/context-management.md` for full pause/resume guidance.

> First session? If the project has no configured game concept, run `/start`.

<!-- END CCGS OPENCODE PORT -->
