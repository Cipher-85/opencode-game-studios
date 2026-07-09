# Changelog

## v0.4.0 - 2026-07-09

Bridged Codex Game Studios v0.4.2–v0.4.3 (silent active-session checkpoints,
read-only-phase closeout boundary, and delegation-consent simplification) into
the OpenCode-native port.

- Added a narrow active-session checkpoint exception to the Collaboration
  Boundary in `AGENTS.md`, `context-management.md`, `session-continuity.md`, and
  `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`: after the user approves the workflow
  artifact or decision, skills may update only `production/session-state/active.md`
  without a separate "May I write?" prompt when the change is a derived
  checkpoint (current task, completed sections, files touched, decisions,
  verification, `## Session Worklist`, or `## Phase Guard`). The exception never
  authorizes design/balance/architecture decisions, durable edits, source,
  commits, pushes, branch changes, or writes to any other path.
- Updated the 6 authoring skills (`/design-system`, `/create-architecture`,
  `/ux-design`, `/map-systems`, `/prototype`, `/vertical-slice`) and 9 role
  agents to use silent derived-checkpoint language at their `active.md` update
  points, plus `/architecture-review`, `/consistency-check`, `/dev-story`,
  `/qa-plan`, `/review-all-gdds`, `/story-done`, `/team-qa`, and `/skill-test`.
- Added a `run_checkpoint` validator to `.opencode/audit.sh` (run via
  `audit.sh checkpoint` or as part of `audit.sh all`) that enforces the
  no-extra-approval contract: any skill or agent that writes to `active.md` must
  carry the derived-checkpoint language and must not request a separate
  "May I write?" prompt for that file. 37 files checked, 0 violations.
- Added a closeout boundary rule to `AGENTS.md` and the `session-continuity.md`
  Pause Procedure: do not close out or ask for a user-selected next action while
  an invoked workflow still has automatic read-only phases remaining
  (readbacks, scans, self-checks, candidate discovery, context gathering,
  validation summaries); keep going until a mutation prompt, design decision,
  blocker, or true stop point.
- Simplified role-agent delegation consent: removed the redundant "May I spawn
  those role agents?" fallback from `coordination-rules.md`,
  `director-gates.md`, and `AGENTS.md`. OpenCode's `Task` tool does not require
  per-spawn consent — the skill invocation is already the request, so declared
  gates that survive review-mode filtering spawn without a duplicate
  confirmation.
- Gitignored `production/session-state/active.md` (machine-local checkpoint) and
  added an install guard in `.opencode/lib/coexistence.sh` so the live
  checkpoint stays local while `session-state/.gitkeep` remains trackable.

## v0.3.0 - 2026-07-06

Bridged Codex Game Studios v0.3.3 continuity-routing rework plus the v0.4.0
numbered-closeout and v0.4.1 role-agent delegation contract into the
OpenCode-native port.

- Introduced the `## Session Worklist` and `## Phase Guard` routing cache in
  `production/session-state/active.md`. Post-work recommendations and resume now
  route through the live worklist instead of `/studio-next`.
- Reworked `/resume-from-handoff` into the one-time session-entry compiler that
  writes those two sections to `active.md`. Explicit invocation of
  `/resume-from-handoff` now authorizes that single file write.
- Deprecated `/studio-next` to a manual compatibility reference that points at
  the saved worklist. Note: this reverses the v0.2.1 enhancement to
  `/studio-next`, intentionally aligning with upstream v0.3.3.
- Required numbered closeout on 21 completion skills and shared continuity docs:
  final responses now end with a `Next action:` prompt and exactly one numeric
  `(Recommended)` option, even when only one valid lane remains. Updated
  `/quick-design`, `/project-stage-detect`, and `/resume-from-handoff` with
  worklist-backed routing language.
- Added a central Role-Agent Delegation Authorization contract to `AGENTS.md`,
  `.opencode/docs/coordination-rules.md`, and `.opencode/docs/director-gates.md`
  so explicit skill invocation authorizes only the declared role-agent spawns,
  with review-mode filtering and a runtime fallback that never simulates a
  skipped specialist or director verdict.
- Extended `/skill-test` with a hard closeout-routing check and delegation
  behavioral checks.
- Translated the upstream `validate_runtime.py` CLOSEOUT enforcement into a new
  `run_closeout` command in `.opencode/audit.sh` (run via `audit.sh closeout` or
  as part of `audit.sh all`).

## v0.2.1 - 2026-07-05

Bridged Codex Game Studios v0.3.1–v0.3.2 decision-prompt and handoff improvements
into the OpenCode-native port.

- Added low-friction decision-prompt rules so next-step handoffs list real viable
  options (usually 3-5, fewer when fewer are real), mark one `(Recommended)`, and
  support short numbered or `a. yes` / `b. no` replies when OpenCode has no
  clickable choice UI.
- Updated `/studio-next` to rank viable next actions instead of collapsing most
  situations to a single next step, while keeping mandatory gates as go/no-go
  prompts.
- Made explicit `/handoff` invocation authorize the OpenCode-native handoff
  workflow end to end: continuity-file updates, path-scoped staging, the standard
  handoff commit, and a normal push of the current branch. Kept the exception
  narrowly scoped — no source edits, no branch switching, no force-push, and no
  `--no-verify` or amend workarounds.
- Added the `Low-Friction Decision Prompts` section and the `/handoff` exception
  to `AGENTS.md`.
- Modernized `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`: added the no-clickable-UI
  fallback guidance and renamed `AskUserQuestion` → `question` throughout (the
  original port only renamed tools in agent/skill bodies, leaving this doc on the
  legacy Claude tool name).

## v0.2.0 - 2026-07-05

- Bridged Codex Game Studios QoL improvements:
  - Rewrote root `AGENTS.md` with 10 behavioral sections (Startup Contract,
    Resume & Wrap-Up Routing, Verification Integrity, Vertical-Slice Forcing
    Function, Code-Turn Discipline, Workflow Gates, File Lifecycle, Continuity
    Epilogue, Available Role Agents, Path-Scoped Instructions routing table).
  - Added 3 new continuity skills: `/studio-next`, `/handoff`,
    `/resume-from-handoff` + command wrappers.
  - Added 3 operational docs: `verification-integrity.md`,
    `session-continuity.md`, `file-lifecycle.md` (loaded globally via
    `opencode.json` instructions).
  - Expanded agent memory from 1 to 17 files (all upstream `memory:` scoped
    agents now have repo-local MEMORY.md contracts).
  - Added `tools/AGENTS.md` path rule.
  - Added path-rule routing table to AGENTS.md (nested AGENTS.md files are not
    auto-discovered by OpenCode — agents must be told to read them).
- Added `CHANGELOG.md` and `ATTRIBUTION.md`.
- Fixed post-audit issues:
  - `question` and `todowrite` permissions set to `allow` on all 49 agents
    (implicitly available in Claude Code; deny-by-default was stricter than
    upstream).
  - Updated 72 testing-framework spec files for OpenCode `metadata` frontmatter.
  - Updated `hooks-reference.md` with OpenCode event mapping.
  - Renamed `CLAUDE-local-template.md` → `AGENTS-local-template.md`.
  - Hardened plugin `$` API with `.cwd()` availability guard.

## v0.1.0 - 2026-07-04

Initial OpenCode Game Studios public release.

- Ported the Claude Code Game Studios role-agent and workflow-skill structure to
  OpenCode-native agents, skills, commands, hooks, plugin adapter, and startup
  instructions.
- 49 agents (permission deny-by-default, `metadata.ccgs_tier` model-tier routing).
- 73 skills (frontmatter normalized: `name`/`description` top-level, extras in
  `metadata`).
- 74 commands (73 skill wrappers + `/studio-status`).
- 12 hooks + `ccgs-hooks.js` plugin adapter (OpenCode events → shell scripts).
- 11 path-scoped rules as nested `AGENTS.md`.
- Static fixture tests for hook payload shapes.
- Preserved upstream MIT attribution.
