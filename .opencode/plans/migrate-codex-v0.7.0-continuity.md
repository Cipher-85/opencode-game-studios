# Migration Plan: Codex Game Studios v0.7.0 Handoff/Resume Continuity → OpenCode Game Studios

> **Status**: APPROVED by user (0.6.0 minor bump; fresh-context reviewer adopted
> per D1a with `explore` default-fresh spawn per D2a; plan filename per D4a;
> command wrapper description unchanged per D5a; baseline written every session
> per D6a). Executed.
> **Source**: Codex commits `b30c2d5` (2026-07-21) — "Harden handoff and resume
> continuity", `102849f` (2026-07-22) — "Add fresh-context handoff reviewer"
> (source tip). Baseline `b778a2b`; `af8c42f` (0.7.0 bump) is metadata-only and
> its behavior already shipped here as v0.5.2.
> **Deployment evidence**: stillcurrent `8805526` (Codex 0.7.0 deploy, 26 files)
> — evidence only, not integration source.
> **Target**: OpenCode Game Studios, `.opencode/VERSION` `0.5.2` → `0.6.0`.
> **Scope**: 22 paths — 19 existing files modified, 3 new files created.

## What's new upstream since the last bridge

Two substantive commits land after `b778a2b` (whose push-flow content shipped
here as v0.5.2):

1. **`b30c2d5` — handoff/resume continuity hardening.** Explicit invocation
   boundary (generic pause/stop wording is not commit/push authority);
   pre-Phase-0 Context Capacity Gate; session-start review baseline
   (`session-baseline.json`) + deterministic Phase-0 scope proof with
   bulk-directory trackability; tracked derived `production/resume-index.md`
   (≤10 KB) with freshness states, source precedence, `## Source Freshness`,
   and cache readback; bounded default resume (≤200 lines/32 KiB current slice
   section) + explicit `deep [focus]`; handoff-first, pointer-elevating
   session-start/pre-compact/post-compact hooks; validator + negative-fixture
   + behavioral-hook-fixture enforcement; installer allowlist sentinel.
2. **`102849f` — fresh-context handoff reviewer.** Phase 0 pairs the parent
   self-review with exactly one built-in `explorer` reviewer spawned with
   `fork_turns: "none"`: bounded conclusion-free packet,
   instruction-read-only, before-and-after Git/index/worktree mutation
   snapshot with SHA-256 content hashes; delegation/mutation failure blocks
   the gate; same-session downgrade requires an explicit user waiver;
   pure-document sessions exempt. Replaces the "no subagent reviewer" rule
   inside the runtime while keeping the no-external-egress boundary.

### Codex-specific (not ported)

- `.codex/docs/VALIDATION.md` validator-policy prose — OpenCode's equivalent
  lives in `audit.sh` command docs.
- `.codex/config.toml` permission profile, `validate_rules.py`,
  `validate_install.py` expected-file-count bookkeeping, sandbox-escalation
  mechanics — no OpenCode analog (established bridging policy).
- Codex manifest fixture rows — target manifests are release-generated.
- `validate_*.py` as separate files — OpenCode keeps a single `audit.sh`
  dispatcher; the new enforcement lands as inline runners.

## Adaptation decisions (Codex → OpenCode)

1. **Fresh-context reviewer mapping** (D1a/D2a): Codex `explorer` +
   `fork_turns: "none"` → OpenCode built-in `explore` agent via the Task tool,
   which starts with a fresh context by default; the contract forbids passing
   `task_id` (the history-resume mechanism). Bounded packet, snapshot guard,
   waiver-only downgrade, and no-egress boundary carried over verbatim in
   meaning. The reviewer is not a director/lead gate, so review modes do not
   filter it; the `/handoff` exception authorizes the declared spawn.
2. **Validator lockstep**: `run_handoff_review` was rewritten (bash grep →
   Python heredoc, matching `run_resume_contract` style) because it previously
   *required* the old same-session phrases; both contract checkers now enforce
   the new wording plus forbidden patterns (same-session substitution,
   `task_id:`, silent fallback). New inline `hook-behavior` (5 temp-project
   scenarios) and `fixtures` (2 negative fixtures) runners; `coexistence` gains
   S8 (project-created resume-index survives uninstall).
3. **Hooks**: target hooks did not source `lib/hooks.sh`; the three session
   hooks now do, gaining `ccgs_write_session_baseline`,
   `ccgs_active_state_kind`, `ccgs_preview_bounded`. All local extras retained
   (sprint/milestone/bug scans, TODO/FIXME counts, WIP design-doc scan,
   session logging, plugin `output.context[]` injection).
4. **Installer**: uninstall was already fail-closed via state-owned paths, so
   no sentinel ownership machinery is needed; one static
   `!production/resume-index.md` allowlist line in `coexistence.sh` keeps the
   project-created index trackable in install-into-existing targets.
5. **Preserved local improvements**: hesitate before pushing
   `main`/`master`/`develop`; runtime push failures non-fatal; fail-closed
   denial without session-mode advice; `ls-remote` preflight + drift recheck +
   credential redaction; `question`-tool lane selection + numeric fallback;
   closeout/checkpoint/playtest validators; single-dispatcher audit.sh.
6. **Version**: OpenCode owns its line. Minor bump `0.5.2` → `0.6.0` (new
   user-facing behavior: deep mode, resume index, fresh-context reviewer).

---

## Files (22 approved paths)

1. `.opencode/skills/handoff/SKILL.md` — description boundary; generic-wording
   exclusion; Context Capacity Gate; Prove The Review Scope; Fresh-Context
   Reviewer Contract; exemption/tiers/Round-1/Round-2/Pass-Cap rewiring;
   Refresh The Resume Index; Phase 2.5/3/4/5 authorization + index lines.
2. `.opencode/skills/resume-from-handoff/SKILL.md` — bounded default + `deep`;
   precedence + freshness/index validation; `## Source Freshness`; readback;
   briefing + protocol lines.
3. `AGENTS.md` — deep-mode routing; generic-pause boundary; `/handoff`
   exception rewrite (declared `explore` reviewer spawn, snapshot, waiver;
   no-egress preserved); resume-index authorization + lifecycle line; `deep`
   boundary.
4. `.opencode/docs/session-continuity.md` — index file role; explicit
   transaction + reviewer paragraphs; resume procedure (index, precedence,
   freshness, readback, deep); conflict ordering.
5. `.opencode/docs/context-management.md` — Task spawn context-inheritance
   contract; handoff-first crash recovery with pointer elevation.
6. `.opencode/docs/coordination-rules.md` — Handoff Integrity Reviewer section.
7. `.opencode/docs/file-lifecycle.md` — resume-index track note;
   session-baseline.json local-ignore note.
8. `.opencode/docs/hooks-reference.md` — three hook action descriptions.
9. `.opencode/lib/hooks.sh` — three new helpers.
10. `.opencode/hooks/session-start.sh` — baseline write (every session) +
    handoff-first preview + kind detection.
11. `.opencode/hooks/pre-compact.sh` — active-first/handoff-fallback + pointer
    elevation (local scans retained).
12. `.opencode/hooks/post-compact.sh` — same ordering/elevation.
13. `.opencode/audit.sh` — contract lockstep; `hook-behavior` + `fixtures`
    runners; S8; wiring + command docs.
14. `.opencode/lib/coexistence.sh` — static resume-index allowlist line.
15. `.opencode/VERSION` — `0.6.0`.
16. `CHANGELOG.md` — v0.6.0 section.
17. `README.md` — badge, version refs, release bullets, Session Continuity
    section.
18. `UPGRADING.md` — v0.5.x → v0.6.0 section + TOC.
19. `production/test-evidence/latest.md` — refreshed evidence.
20. `.opencode/tests/fixtures/invalid-handoff-contract/.opencode/skills/handoff/SKILL.md` (new)
21. `.opencode/tests/fixtures/invalid-resume-contract/.opencode/skills/resume-from-handoff/SKILL.md` (new)
22. `.opencode/plans/migrate-codex-v0.7.0-continuity.md` — this plan.

Explicitly not changed: `.opencode/hooks/fixtures/test-fixtures.js` (Stage 1
payload harness, untouched), both manifest JSONs (release-generated),
`opencode.json`, command wrappers, any runtime-generated state.

---

## Verification (all run this session, 2026-07-22)

1. `bash .opencode/audit.sh handoff-review` — pass, 0 violations.
2. `bash .opencode/audit.sh resume-contract` — pass, 0 violations.
3. `bash .opencode/audit.sh hook-behavior` — pass, 0 errors across 5 scenarios
   (ordering + baseline JSON + elevation).
4. `bash .opencode/audit.sh fixtures` — pass, 0 errors across 2 fixtures (one
   line-wrap defect in the handoff fixture found and fixed during
   verification).
5. `bash .opencode/audit.sh all` — pass, 0 errors (all 13 validator groups).
6. `bash .opencode/audit.sh coexistence` — pass, 0 errors; S1–S8 green.
7. `bash .opencode/audit.sh smoke-headless` — pass; 77 commands resolve.
8. `bash .opencode/audit.sh release` — pass; VERSION ↔ CHANGELOG consistent.
9. Token-leak grep over all changed paths — no Codex-dialect tokens in ported
   surfaces; only pre-existing legitimate matches (coexistence detection,
   historical docs, `$skill*` shell variables).
10. `git status --short` — changed set equals exactly the 22 approved paths.
