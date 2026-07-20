# Changelog

## v0.5.2 - 2026-07-20

Bridged Codex Game Studios v0.7.0 handoff push-flow corrections (upstream
commits `47e237c`, `7cf7f5e`, `b778a2b`) into the OpenCode-native port.

- Demoted the `/handoff` Phase 4 GitHub CLI dest-evidence gate
  (`gh auth status`, `gh api user`, `gh repo view … viewerPermission`) from
  mandatory precondition to optional advisory check. Upstream falsified the
  gate (risk R39): Git and `gh` can use different credentials, so an
  inconclusive `gh` result falsely blocked authorized pushes. The resolved
  push URL, branch/upstream, and explicit `/handoff` invocation are now the
  destination/authorization evidence; the actual `git push` is the
  authoritative network and Git-authentication check. This intentionally
  reverses part of the v0.5.1 bridge.
- Added exact-destination preflight via
  `git ls-remote --heads '<push-url>' 'refs/heads/<branch>'` (no matching ref
  is valid for a new remote branch), embedded-credential redaction for remote
  URLs, and a pre-push drift recheck that halts rather than pushing to an
  untested destination.
- Phase 0 review gate now records its verdict as `PASS` when it passes.
- Phase 2.5 explicitly notes the `active.md` stub is a derived checkpoint
  authorized by `/handoff` invocation — no separate write approval.
- Phase 5 now refreshes the Session Worklist / Phase Guard, surfaces owed
  verification, and ends with exactly one numbered `(Recommended)` next
  action.
- Permission-denial handling now forbids telling the user to change the whole
  session's permission mode; report the denied scoped action instead.

Codex-platform internals from the v0.7.0 release (`.codex/config.toml`
permission profile, `validate_rules.py`/`validate_runtime.py` contracts,
sandbox-escalation mechanics, codex-conversion docs) are intentionally not
ported — OpenCode has no sandbox/permission-profile model, and `audit.sh`
already covers the contract-validation role.

## v0.5.1 - 2026-07-16

Bridged Codex Game Studios handoff-push hardening (upstream commit `0c6df429`)
into the OpenCode-native port.

- Hardened `/handoff` Phase 4 push routing: existing-upstream branches use plain
  `git push`, branches without an upstream use `git push -u origin <branch>`.
- Added same-turn GitHub destination evidence (`gh auth status`, `gh api user`,
  `gh repo view … viewerPermission`) before handoff pushes, requiring
  `WRITE`/`MAINTAIN`/`ADMIN`; network-restricted sandbox failures are not
  treated as invalid credentials.
- Translated Codex's `["git","push"]` escalation + `/approve` dialect to the
  OpenCode native permission-prompt model; policy denial fails closed with no
  command-shape workaround.
- Preserved OpenCode-local rules: hesitate before pushing `main`/`master`/
  `develop`, and runtime push failures remain non-fatal (handoff valid locally).

Codex-platform internals from the v0.6.0/v0.6.1 releases (`.codex/*` validators,
`validate_smoke.py`, role-activation fixtures, CCGS frontmatter) are
intentionally not ported — OpenCode's Task/subagent model and `.opencode`
structure make them inapplicable or already-equivalent.

## v0.5.0 - 2026-07-12

Bridged Codex Game Studios v0.5–v0.6 (upstream commit 259cff8) into the
OpenCode-native port. Adopted the portable behavioral improvements only;
Codex-platform internals (MultiAgent V2 role-activation proof, `.codex`
installer/validators, CCGS framework frontmatter, skill delegation dialect)
are intentionally not ported — OpenCode's Task/subagent model and `.opencode`
structure make them inapplicable or already-equivalent.

### Phase 1 — Secret protection + trust/activation messaging

- Added `edit` and `glob` `*.env*` denies to `opencode.json` (the `edit` scope
  covers write/patch), closing a gap where agents could create/overwrite
  secrets via the write tool. Consolidated `read` to a single `*.env*`
  catch-all so nested files and `.envrc` are covered; `*.env.example` stays
  allowed for templates.
- Install banner, README, and UPGRADING now state that installer success is
  static-only and a new opencode session is required before hooks,
  permissions, and agents are active.
- `audit.sh config` now asserts an `edit` `*.env*` deny exists (regression guard).

### Phase 2a — Installer/uninstaller fail-closed hardening

- `coexistence.sh`: added `ccgs_state_validate` (exists/schema==2/valid
  JSON/no path-traversal/no symlink) and `ccgs_state_owned_paths`.
- `uninstall.sh`: fail-closed — removed the source-manifest fallback so
  missing/invalid state aborts without removing files; dropped the redundant
  emptiness-based AGENTS.md re-check; limited pruning to `.opencode/`.
- `install.sh`: `--replace-modified` opt-in + Python preflight that aborts
  before mutation on unowned collisions and locally-modified package files.
- `audit.sh`: `run_install_safety` validator (5 static guards) wired into
  `all` and exposed as `audit.sh install-safety`.

### Phase 2b — Transactional deploy + rollback

- `install.sh`: the cross-target deploy is now transactional — to-be-overwritten
  files are snapshotted and created files recorded before mutation; a
  mid-deploy failure restores modified files and removes created files, leaving
  the target at its pre-deploy state. A `rollback-<timestamp>/` record is kept
  for inspection.

### Phase 3 — Advisory coexistence + smoke-headless checks

- `audit.sh coexistence`: real install/uninstall matrix in a temp dir (fresh
  install, collision abort, modified abort, `--replace-modified`, uninstall
  missing-state, uninstall valid-state, transactional rollback).
- `audit.sh smoke-headless`: command→skill graph integrity; model-driven smoke
  deferred until a CI model runner exists.
- `.github/workflows/release-check.yml`: `coexistence-advisory` and
  `smoke-headless-advisory` jobs (`continue-on-error: true`); the existing
  `validate` job remains the blocking gate.

### Phase 4 — Runtime parity limits doc

- README: new "Runtime Parity Limits" section documenting OpenCode-specific
  enforcement limits honestly (advisory path rules, instruction-backed fences,
  model tiers as guidance, installer success ≠ activation).

## v0.4.2 - 2026-07-10

Bridged Codex Game Studios v0.4.5–v0.4.7 (bug lifecycle consolidation, handoff
two-round review gate, resume lane-selection boundary) into the OpenCode-native
port.

### v0.4.5 — Bug Lifecycle Consolidation

- Updated `/bug-report verify` so a VERIFIED FIXED result can complete
  verification evidence, closure, safe stale triage cleanup, and derived
  session-state routing under one approved changeset.
- Updated `/bug-report close` so already verified bugs can close and refresh
  stale triage metadata without a separate bookkeeping prompt.
- Clarified `/bug-triage` zero-open-bugs closure refresh as deterministic
  metadata cleanup when no priority, sprint-scope, severity, or Won't Fix
  decisions are needed.
- Added `run_bug_lifecycle` validator to `.opencode/audit.sh` (run via
  `audit.sh bug-lifecycle` or as part of `audit.sh all`) to prevent regression
  into forced verify → close → triage handoffs.

### v0.4.6 — Handoff Two-Round Review Gate

- Restored `/handoff`'s mandatory two-round review gate, including
  STANDARD/ADVERSARIAL tier selection, pure-document exemptions, finding
  triage, conditional second review, pass caps, and an auditable handoff record.
- Kept the cross-check inside the active OpenCode session and explicitly
  forbade nested CLI invocations, Task subagent reviewers, companion plugins,
  and external model services.
- Expanded the `/handoff` authorization boundary in `AGENTS.md` for narrow
  intent-preserving fixes and added a round-two non-trivial-finding stop rule.
- Added `run_handoff_review` validator to `.opencode/audit.sh` (run via
  `audit.sh handoff-review` or as part of `audit.sh all`) to prevent the review
  contract or its no-egress safeguards from regressing.

### v0.4.7 — Resume Lane-Selection Boundary

- Added a hard `/resume-from-handoff` lane-selection boundary: focus arguments
  only bias ranking, multiple lanes use the `question` tool for structured
  choice, single lanes wait for numeric `1`, and follow-up forks remain separate
  decisions.
- Kept FIRST verification mandatory across resume lane choices and clarified
  that entering a selected workflow grants no additional mutation authority.
- Expanded the `/resume-from-handoff` exception in `AGENTS.md` so a focus
  argument only biases ranking and selection authorizes entering only the
  selected workflow.
- Added explicit Ranking Rules (6-level priority) and separated session-cache
  write (Step 6) from the briefing (Step 7) in `/resume-from-handoff`.
- Added `run_resume_contract` validator to `.opencode/audit.sh` (run via
  `audit.sh resume-contract` or as part of `audit.sh all`) to enforce the
  selection-boundary contract and reject automatic lane startup.

## v0.4.1 - 2026-07-09

Bridged Codex Game Studios v0.4.4 (user-owned playtest focus contract) into
the OpenCode-native port.

- Added a user-owned playtest focus contract so closeouts and owed verification
  include a `Playtest focus:` brief (hypothesis, setup/build, 2-4 observation
  prompts, verdict/evidence) instead of generic playtest requests, while
  leaving game-feel and balance verdicts with the user.
- Updated `/playtest-report` templates and routing so new reports and follow-up
  playtests carry a concrete hypothesis before sending the user back to play.
- Updated `AGENTS.md` and `session-continuity.md` to preserve the playtest
  focus brief in closeouts and `## Session Worklist` entries.
- Added a `run_playtest_focus` validator to `.opencode/audit.sh` (run via
  `audit.sh playtest` or as part of `audit.sh all`) that enforces the
  playtest-focus contract across root instructions, continuity docs, and the
  playtest-report workflow.

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
