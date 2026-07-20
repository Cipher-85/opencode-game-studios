# Latest Test Evidence

Date: 2026-07-20

Scope: OpenCode Game Studios v0.5.2 — port of Codex Game Studios v0.7.0
handoff push-flow corrections (upstream commits `47e237c` "Fix permission and
handoff push parity", `7cf7f5e` "Fix handoff approval escalation", `b778a2b`
"Fix complete handoff permission profile") into the OpenCode-native port.
Version-bump metadata from upstream `af8c42f` ("Bump Codex package to 0.7.0")
applied in OpenCode form (own version line). Plan:
`.opencode/plans/migrate-codex-v0.7.0.md`.

## Commands Run

```bash
bash .opencode/audit.sh all
grep -nE '\.agents/skills|\.codex|\$handoff|\$skill|sandbox_permissions|prefix_rule|/approve|Codex surface|CCGS skill' .opencode/skills/handoff/SKILL.md
git rev-parse --abbrev-ref HEAD
git rev-parse --abbrev-ref --symbolic-full-name '@{u}'
git remote get-url --push origin
git ls-remote --heads '<verified-push-url>' 'refs/heads/main'
```

## Result

- `bash .opencode/audit.sh all`: pass (0 errors)
  - handoff-review: 2 surfaces — `handoff/SKILL.md (review gate contract)`
    and `AGENTS.md (handoff review exception)` both pass; the Phase 0/2.5/4/5
    edits did not disturb the required review-contract phrases (all live in
    the Round-1/Round-2 sections; the Phase 0 verdict line is additive)
  - resume contract: 0 violations
  - runtime: no `.claude/` or `CLAUDE.md` references
  - config: opencode.json valid; all instruction files exist
  - install-safety: 5 guards pass
  - hooks: 12 checked; fixture tests 11 passed, 0 failed
  - smoke: 49 agents, 77 skills, 77 commands, 12 hooks, 17 agent-memory, 15 rules
- Token-leak grep over the edited skill: no matches (exit 1) — no
  `.agents/skills`, `.codex`, `$handoff`/`$skill`, `sandbox_permissions`,
  `prefix_rule`, `/approve`, "Codex surface", or "CCGS skill" tokens leaked
  into the OpenCode skill.
- Phase 4 snippet exercise:
  - Current branch resolves to `main`; upstream detection returns
    `origin/main` (exit 0) — the existing-upstream case routes to plain
    `git push`.
  - `git remote get-url --push origin` returns the verified github.com push
    URL.
  - Preflight `git ls-remote --heads '<push-url>' 'refs/heads/main'` exits 0
    and returns the matching remote ref — destination reachable and exact.
  - A temporary no-upstream branch yields the expected non-zero lookup
    (`fatal: no upstream configured`, exit 128), which the skill treats as the
    no-upstream case routing to `git push -u origin <branch>` — not a Phase
    failure. Temp branch created and deleted during the check.

## Notes

- Verification ran in `/Users/yongatron/Development/opencode-game-studios`.
- Files changed this session: `.opencode/skills/handoff/SKILL.md` (Phase 0
  verdict line, Phase 2.5 checkpoint authorization, Phase 4 rewrite, Phase 5
  closeout), `.opencode/VERSION` (`0.5.1` → `0.5.2`), `CHANGELOG.md`
  (v0.5.2 section), `README.md` (version badge + two text refs),
  `production/test-evidence/latest.md` (this file), and the migration plan at
  `.opencode/plans/migrate-codex-v0.7.0.md`.
- The v0.5.1 mandatory GitHub CLI dest-evidence gate was demoted to advisory,
  reversing part of that bridge; upstream falsified it (risk R39 — `gh` and
  Git credentials differ, so inconclusive `gh` checks falsely blocked
  authorized pushes).
- OpenCode-local rules preserved through the port: hesitate before pushing
  `main`/`master`/`develop`; runtime push failures (auth/network/rejected)
  remain non-fatal.
- Codex-platform internals from the v0.7.0 release (`.codex/config.toml`
  permission profile, `validate_rules.py`/`validate_runtime.py` contracts,
  sandbox-escalation mechanics, codex-conversion docs) intentionally not
  ported — out of scope per the established bridging policy.
