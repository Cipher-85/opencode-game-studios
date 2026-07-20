# Migration Plan: Codex Game Studios v0.7.0 → OpenCode Game Studios

> **Status**: APPROVED by user (0.5.2 patch bump; gh dest-evidence demoted to
> advisory; ls-remote preflight + drift check; Phase 5 closeout). Executing.
> **Source**: Codex commits `47e237c` (2026-07-19) — "Fix permission and handoff
> push parity", `7cf7f5e` (2026-07-19) — "Fix handoff approval escalation",
> `b778a2b` (2026-07-19) — "Fix complete handoff permission profile",
> `af8c42f` (2026-07-20) — "Bump Codex package to 0.7.0" (metadata only).
> **Target**: OpenCode Game Studios, `.opencode/VERSION` = `0.5.1`.
> **Scope**: Single feature — handoff skill push-flow corrections + closeout.
> 6 files.

## What's new upstream since the last bridge

Four commits land after the v0.6.1 bridge (`352741b`, 2026-07-16). The three
substantive commits converge on one story: the v0.6.1 push-hardening we ported
in v0.5.1 was falsified upstream (risk R39/R40) and reworked.

### Portable (genuine fixes)

1. **Demote `gh` CLI push prechecks to advisory** (`47e237c`). The mandatory
   `gh auth status` / `gh api user` / `gh repo view viewerPermission` gate —
   ported by us in v0.5.1 — falsely blocks authorized pushes: `gh` and Git use
   different credentials, and network-restricted `gh` failures say nothing
   about the Git credential. Replacement: resolved push URL + branch/upstream +
   explicit `/handoff` invocation is the destination/authorization evidence;
   `gh` checks are optional, read-only, advisory; the actual `git push` is the
   authoritative network/auth check; never claim an authenticated
   account/permission unless actually verified. **This intentionally reverses
   part of our v0.5.1 bridge.**
2. **Exact-destination preflight + drift check** (`b778a2b`). Before pushing,
   run `git ls-remote --heads '<verified-push-url>' 'refs/heads/<branch>'`
   (exit 0 with no matching ref is valid for a new remote branch); redact
   embedded credentials from URLs; recheck branch/upstream/remote/push-URL
   immediately before push and halt if anything drifted from the preflighted
   destination.
3. **Phase 0 verdict recorded as `PASS`** (`7cf7f5e`) — one line.
4. **Phase 2.5 explicit checkpoint authorization** (`7cf7f5e`): derived
   checkpoint authorized by explicit `/handoff` invocation; no separate
   "May I write?" for `production/session-state/active.md`.
5. **Phase 5 closeout** (`7cf7f5e`): refresh `## Session Worklist` /
   `## Phase Guard` from `active.md` (fall back to handoff doc when it is a
   pointer stub), surface owed verification, end with exactly one numbered
   `(Recommended)` next action.
6. **Denial guidance** (`b778a2b`): report the denied scoped action; never
   instruct the user to change the whole session's permission mode.

### Codex-specific (not ported)

- `.codex/config.toml` permission profile (writable `.git`/`.agents`/`.codex`,
  `github.com`-only network, approval-policy experiments) — OpenCode has no
  sandbox/permission-profile model; Git metadata writability is a non-issue.
- `validate_rules.py` / `validate_runtime.py` contract validators — Codex
  package internals; OpenCode's equivalent coverage lives in `audit.sh`.
- Sandbox-escalation mechanics (`sandbox_permissions`, `prefix_rule`, DNS
  retry, `/permissions` mode guidance) — no OpenCode analog.
- `docs/codex-conversion/*`, VERSION/CHANGELOG/README release metadata.

## Adaptation decisions (Codex → OpenCode)

1. **Path/dialect**: `.agents/skills/handoff/SKILL.md` →
   `.opencode/skills/handoff/SKILL.md`; `$handoff` → `/handoff`.
2. **Preflight placement**: Codex puts the preflight in a pre-Phase-0
   capability gate tied to sandbox checks. OpenCode has no sandbox, so the
   portable preflight (`ls-remote` + credential redaction) lives inside
   Phase 4 before the push, with the drift recheck immediately before the push
   command.
3. **gh demotion**: replaces the v0.5.1 mandatory dest-evidence block. The
   "network-restricted sandbox failure is not evidence of invalid credentials"
   sentence is superseded by the advisory framing.
4. **Preserved local improvements** (must not be lost):
   - Hesitate before pushing `main`/`master`/`develop` — ask the user first.
   - Runtime push failures (auth/network/rejected) remain non-fatal — handoff
     is valid locally; continue to Phase 5.
5. **Version**: OpenCode owns its line. Patch bump `0.5.1` → `0.5.2`.
6. **Audit gate**: `run_handoff_review` (`.opencode/audit.sh:333-406`) enforces
   Phase-0 review-gate phrases only — all preserved; edits are additive there.
   The runtime token-scan forbids `.codex`, `.agents/skills`, `$handoff`,
   "CCGS skill" — ported text avoids them.

---

## File 1: `.opencode/skills/handoff/SKILL.md`

- Phase 0 "Pass Cap And Audit Trail": append "and record the review gate
  verdict as `PASS`" to the gate-pass sentence.
- Phase 2.5: append the derived-checkpoint authorization sentence.
- Phase 4 rewrite:
  - Replace the mandatory `gh auth status`/`gh api user`/`gh repo view` block
    with: push URL + branch/upstream + explicit invocation as evidence;
    advisory optional `gh` checks; `git push` authoritative.
  - Add `git ls-remote --heads '<verified-push-url>' 'refs/heads/<branch>'`
    preflight (no matching ref = valid new branch) and credential redaction.
  - Add pre-push drift recheck of branch/upstream/remote/push URL; halt on
    drift instead of pushing to an untested destination.
  - Justification names the verified push URL; do not claim an authenticated
    account or repository permission unless actually verified.
  - On permission denial: fail closed, report the denied action, never tell
    the user to change the whole session's permission mode.
  - Preserve main/master/develop hesitation and non-fatal runtime failures.
- Phase 5: prepend Session Worklist / Phase Guard refresh + owed-verification
  + exactly one numbered `(Recommended)` next action block.

## File 2: `.opencode/VERSION`

`0.5.1` → `0.5.2`.

## File 3: `CHANGELOG.md`

Prepend `## v0.5.2 - 2026-07-20` section: gh precheck demotion (citing the
v0.5.1 reversal and upstream R39), ls-remote preflight + drift check, Phase 0
verdict line, Phase 2.5 checkpoint line, Phase 5 closeout; note Codex-platform
internals intentionally not ported.

## File 4: `README.md`

Update version references: badge (line 16), package-version text (line 72),
tree comment (line 445) — all `0.5.1` → `0.5.2`.

## File 5: `production/test-evidence/latest.md`

Refresh to v0.5.2/2026-07-20; record the actual `audit.sh all` result.

## File 6: `.opencode/plans/migrate-codex-v0.7.0.md`

This plan.

---

## Verification

1. `bash .opencode/audit.sh all` — expect pass, 0 errors; watch
   `handoff-review`, `release` (VERSION↔CHANGELOG), `closeout`, `runtime`
   token-scan.
2. Token-leak grep on the edited skill — expect no matches for `.codex`,
   `.agents/skills`, `$handoff`, `sandbox_permissions`, `prefix_rule`,
   "CCGS skill".
3. Exercise the Phase 4 snippets on a no-upstream branch and on the current
   branch (which has `origin` upstream) to confirm the upstream-detection,
   preflight, and drift-check logic reads correctly.
