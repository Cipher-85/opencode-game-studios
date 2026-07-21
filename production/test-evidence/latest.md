# Latest Test Evidence

Date: 2026-07-22

Scope: OpenCode Game Studios v0.6.0 — bridge of Codex Game Studios v0.7.0
handoff/resume continuity hardening (upstream `b30c2d5` "Harden handoff and
resume continuity") and the fresh-context handoff reviewer (upstream `102849f`
"Add fresh-context handoff reviewer") into the OpenCode-native port. Baseline:
`b778a2b`. Plan: `.opencode/plans/migrate-codex-v0.7.0-continuity.md`.

## Commands Run

```bash
bash .opencode/audit.sh handoff-review
bash .opencode/audit.sh resume-contract
bash .opencode/audit.sh hook-behavior
bash .opencode/audit.sh fixtures
bash .opencode/audit.sh all
bash .opencode/audit.sh coexistence
bash .opencode/audit.sh smoke-headless
bash .opencode/audit.sh release
grep -rnE '\.codex|\.agents/skills|\$handoff|\$skill|\$resume|fork_turns|codex review|codex exec|codex-companion|request_user_input|sandbox_permissions|prefix_rule|/approve|CCGS skill' <all changed paths>
git status --short
```

## Result

All commands below ran on 2026-07-22 in
`/Users/yongatron/Development/opencode-game-studios` during this session.

- `bash .opencode/audit.sh handoff-review`: pass (0 violations) — authorization,
  capacity, scope-baseline, fresh-context reviewer, and resume-index phrase
  sets present on `handoff/SKILL.md`, `AGENTS.md`, `coordination-rules.md`,
  `context-management.md`, `session-continuity.md`; frontmatter description
  boundary and three forbidden patterns (same-session substitution, `task_id`
  history fork, silent fallback) enforced.
- `bash .opencode/audit.sh resume-contract`: pass (0 violations) —
  lane-selection, bounded default slice-read, cache readback, and source
  precedence contracts; unbounded-default-slice-read scan clean.
- `bash .opencode/audit.sh hook-behavior`: pass (0 errors across 5 scenarios) —
  handoff-first session-start ordering with baseline JSON written
  (branch/start_head/started_at verified against fixture HEAD), handoff-only
  fresh clone, pointer-only elevation, compaction active precedence,
  compaction pointer elevation, for all three session hooks.
- `bash .opencode/audit.sh fixtures`: pass (0 errors across 2 fixtures) — both
  negative fixtures are detected as invalid on every expected check. One
  implementation defect was found and fixed during verification (fixture line
  wrap defeated the `[^.\n]` silent-fallback pattern; fixture wording
  re-wrapped onto single lines).
- `bash .opencode/audit.sh all`: pass (0 errors) — 49 agents, 77 skills, 77
  commands, 12 hook scripts + 11 payload fixture tests, 17 agent-memory, 15
  rules; closeout, checkpoint, playtest-focus, bug-lifecycle, runtime (no
  `.claude/`/`CLAUDE.md` refs), config, install-safety (5 guards), and the two
  new runners all green.
- `bash .opencode/audit.sh coexistence`: pass (0 errors) — S1–S7 unchanged and
  green; new S8 confirms a project-created `production/resume-index.md`
  survives uninstall.
- `bash .opencode/audit.sh smoke-headless`: pass — 77 commands resolve to
  existing skills; model-driven boot remains deferred by design.
- `bash .opencode/audit.sh release`: pass — VERSION `0.6.0` ↔ CHANGELOG v0.6.0
  section; tag `opencode-v0.6.0` not yet created; latest tag `opencode-v0.5.0`.
- Token-leak grep over all changed paths: no `.codex`, `.agents/skills`,
  `$handoff`, `$resume`, `fork_turns`, `codex review/exec/companion`,
  `request_user_input`, `sandbox_permissions`, `prefix_rule`, `/approve`, or
  "CCGS skill" tokens in the ported surfaces. Remaining matches are
  pre-existing legitimate references: `.codex`/`.agents` coexistence detection
  in `lib/coexistence.sh`, historical CHANGELOG/README entries, and `$skill*`
  shell variables in `audit.sh`.
- `git status --short`: 18 modified files + new `.opencode/tests/` tree (2
  fixture files) + this evidence file + the plan file = exactly the approved
  22 paths. No out-of-scope changes.

## Notes

- Files changed this session (22 approved paths): the two continuity skills,
  `AGENTS.md`, five docs, three session hooks + `lib/hooks.sh`, `audit.sh`,
  `lib/coexistence.sh`, two negative fixtures (new), VERSION, CHANGELOG,
  README, UPGRADING, this evidence file, and the migration plan.
- OpenCode-local rules preserved: hesitate before pushing
  `main`/`master`/`develop`; runtime push failures remain non-fatal;
  fail-closed permission denial without session-mode advice; `ls-remote`
  exact-destination preflight + drift recheck + credential redaction;
  `question`-tool lane selection with numeric fallback; closeout/checkpoint/
  playtest validators; hook local scans (sprint/milestone/bugs/TODO-FIXME/WIP
  design docs, session logging); `ccgs-hooks.js` plugin untouched.
- The previous "no Task subagent reviewer" rule in the `/handoff` exception
  was intentionally replaced by the approved fresh-context `explore` reviewer
  (user decision D1a): default-fresh spawn, never `task_id`, conclusion-free
  bounded packet, instruction-read-only, before-and-after mutation snapshot,
  explicit-waiver-only same-session downgrade. No-external-egress preserved.
- Sessions started before this change have no
  `production/session-logs/session-baseline.json`; their first `/handoff`
  halts for explicit review-scope confirmation (by design, documented in
  UPGRADING.md).
- Codex-platform internals (`VALIDATION.md`, `config.toml` validators,
  manifest file-count bookkeeping, sandbox mechanics) intentionally not
  ported, per the established bridging policy.
