---
name: handoff
description: "Use when the user wants to stop, pause, checkpoint, switch machines, or preserve current session state for a future OpenCode session."
---

# Handoff

Create a durable OpenCode session handoff for this project. This is the write-side
pair for `/resume-from-handoff`.

## Preconditions

- Respect the current branch. Never switch branches during handoff.
- Pushing the handoff to the current branch's remote is expected behavior,
  not a merge to main. Do not conflate the two.
- Do not edit legacy Claude runtime files or instruction surfaces.
- Explicit invocation of `/handoff` authorizes this skill's declared handoff
  workflow without a second approval confirmation: update continuity files, stage
  relevant uncommitted changes by path, create the standard handoff commit, and
  push the current branch.
- Declared continuity files:
  `production/session-handoff.md`, `production/session-archive.md`, and
  `production/session-state/active.md`.
- Show the user the intended handoff label and concise update summary, then
  run the declared handoff workflow directly. Do not pause between the summary,
  continuity writes, commit, and push unless the work would leave the declared
  workflow.
- This authorization does not include making new source edits outside the
  continuity files, design decisions, game-feel/balance calls, writes outside
  declared continuity files, branch switching, force-pushes, or `--no-verify` /
  amend workarounds.
- Use evidence from the current turn for every status, count, and verification
  claim.
- If a command fails, halt the current phase and report the exact failure.

## Phase 0: Review Gate

Before rotating continuity files or committing, run this mandatory two-round
gate over every file created or materially changed in this session. The gate can
halt the skill: if triage requires user direction, stop before Phase 1 and do
not rotate, commit, or push.

The review stays inside the current OpenCode session. A native cross-check is a
distinct native review pass performed by this session after setting aside its
authoring conclusions and re-reading the deliverables with a reviewer lens.
Never invoke `opencode` in a subshell, spawn a Task subagent reviewer, use a
companion plugin, call another model service, or create an external data-egress
approval path for this gate.

### Pure Design/Process-Document Exemption

If the entire session changed only pure design/process-document content,
self-review is sufficient and the native cross-check is skipped. This exemption
covers instruction/rule files, skills, `AGENTS.md`, ADRs with no runtime impact,
`design/gdd/**`, and memory files. Mixed code-and-document changes are not
exempt. Executable specifications, CI configuration, tools, tests, public API
contracts, and ADRs with runtime-behavioral requirements are not pure documents.

### Round 1

1. Self-review every touched file end-to-end, not just the diff. Check the
   applicable ADRs, GDDs, project rules, naming, test standards, design gates,
   verification claims, and recorded caveats.
2. Unless the pure-document exemption applies, select exactly one native tier:
   - `STANDARD` is the default for routine session work: individual ADR
     amendments, tool / lint additions, tests, GDD system authoring, doc edits,
     and CI tweaks.
   - `ADVERSARIAL` is reserved for this exact major-deliverable trigger list:
     Foundation ADR cluster closure, master architecture doc, control-manifest
     v1.0+ promotion, batch ADR Proposed→Accepted events, stage-gate advances,
     release candidates / gold masters, or explicit user `red-team / challenge`
     language.
   - If uncertain whether the work meets a major trigger, use `STANDARD`.
3. Perform the selected cross-check as a fresh reasoning pass by the current
   OpenCode session. Inspect the complete touched files and their relevant
   contracts. Report each finding as `HIGH`, `MEDIUM`, or `LOW` with an exact
   `path:line` reference, the violated contract or risk, and a concrete
   recommendation. If there are no findings, report `CLEAN`.
4. Triage every finding:
   - Agree and confident that the fix preserves approved intent: apply it only
     within files already created or materially modified during this session,
     then run the narrowest meaningful verification.
   - Agree but out of scope: do not apply it; record it in the handoff Deferred
     section with the native finding quoted verbatim.
   - Disagree, uncertain, disputed, design-changing, architectural,
     game-feel/balance-changing, or scope-changing: halt and surface the finding
     plus analysis to the user. Do not proceed to rotation or commit.

### Round 2

Run Round 2 only when Round 1 caused a fix.

1. Always self-review the complete Round 1 fix set against the original finding,
   surrounding behavior, and verification evidence.
2. Run a second native cross-check only when Round 1 included at least one
   `HIGH` finding or the fix changed cross-cutting executable behavior. This
   includes shared helpers, CI configuration, determinism-critical paths such as
   `src/core/sim/**`, public APIs, or ADR executable specifications. Use the
   same `STANDARD` or `ADVERSARIAL` tier selected in Round 1. Pure
   design/process-document fixes remain exempt from the second native
   cross-check.
3. Triage Round 2 with a stop bias because a new finding means the first fix was
   incomplete:
   - Trivial and confidently intent-preserving only: fix a typo, document-text
     error, off-by-one in a named constant, or one-line obvious syntax error;
     inline-self-review that exact edit, verify it, and record it in the
     handoff. Do not run a third pass for this trivial fix.
   - Any non-trivial fix, ambiguity, disagreement, scope change, design or
     architecture decision, balance/game-feel decision, or finding outside the
     Round 1 fix set: halt and surface it to the user before Phase 1.

### Pass Cap And Audit Trail

- Cap the gate at three native review passes total, counting Round 1, a
  conditional Round 2 cross-check, and any user-directed rerun after a scope
  extension. A fourth native review pass requires explicit user approval. When
  asking, report the active reported context percentage and the estimated
  additional percentage cost; never substitute fixed token-window or time
  estimates. If the active percentage is unavailable, say so explicitly.
- Record the review audit trail in `production/session-handoff.md`: exemption or
  tier, `CLEAN` or findings, fixes applied and verified, findings deferred with
  quotations, user-cleared findings, and any stopped pass.
- The gate passes only when every finding is fixed and verified, explicitly
  deferred as out of scope, or cleared by the user, with nothing blocking on
  user input. Only then proceed to Phase 1 and record the review gate verdict
  as `PASS`.

## Phase 1: Choose The Label

Use the user-provided argument as the handoff label. If none is provided, infer
a short noun phrase from the active work. If still ambiguous, use
`session-checkpoint`.

The standard commit subject is:

```text
WIP: <label> - CONTEXT HANDOFF
```

## Phase 2: Update Session State

Read these before editing when they exist:

- `production/session-handoff.md`
- `production/session-archive.md`
- `production/session-state/active.md`

Create `production/session-handoff.md` if it does not exist. Create
`production/session-archive.md` only when rotating a prior live session or when a
repo-local continuity rule requires it.

### Maintain The Slice Source Pointer

`production/session-handoff.md` is the contract consumed by
`/resume-from-handoff`. It must contain a project-specific pointer named:

```text
Playable/Slice State Source: <relative path or Not declared>
```

Do not hardcode a project path in this skill. Preserve the current value when it
is still supported by the files you read. Update it only when the user gives a
new path, an existing handoff/template already declares a better path, or the
current work created a clearly canonical playable-state document. If no source
is known, write `Playable/Slice State Source: Not declared`.

### Rotate The Prior Session

If `production/session-handoff.md` contains a `## Most Recent Session` entry,
move that prior session block to the top of `production/session-archive.md`
under `## Session Narratives`. Preserve the moved prose verbatim.

### Write The New Live Handoff

Update only the live sections that changed:

- Last updated pointer.
- Current Stage / Next Action.
- `Playable/Slice State Source`.
- Tracked Open Items.
- Director Gates / Architecture Registry / Systems Index when changed.
- Key Decisions Summary, appending durable decisions only.
- `## Most Recent Session`, with trigger, work completed, files touched,
  decisions, blockers, review outcome, deferred items, and next action.

If approved content exists only in conversation, stop and surface it. Do not hide
an approved-but-unpersisted state.

### Size Check

Run:

```bash
wc -c production/session-handoff.md
```

If the live handoff is over 25 KB, investigate rotation or bloated live sections
before continuing.

## Phase 2.5: Refresh Local Scratchpad

Overwrite `production/session-state/active.md` with a short pointer stub to
`production/session-handoff.md`. It is gitignored scratch state in many
projects; keep it coherent but do not stage it unless the repo explicitly tracks
it. This is a derived checkpoint authorized by explicit `/handoff` invocation.
Do not ask a separate "May I write?" for this file.

## Phase 3: Commit Handoff

Run:

```bash
git status --short
git diff
git log -5 --oneline
```

If there are no relevant uncommitted changes, skip the commit and say why.

Otherwise stage only the relevant paths by name. Avoid broad staging unless the
user explicitly asked for it. `/handoff` invocation is commit authorization for
the relevant handoff work. Before committing, verify:

```bash
git diff --cached --name-status
```

Commit with the standard handoff subject.

Never use `--no-verify`. Never amend as a workaround for a failed hook.

## Phase 4: Push Handoff

Determine the current branch and its configured upstream:

```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --abbrev-ref --symbolic-full-name '@{u}'
```

Treat a non-zero upstream lookup as the expected no-upstream case, not as a
Phase failure. Do not substitute a different branch. If an upstream exists,
derive its remote name from the returned `<remote>/<branch>` value and verify
that remote's push URL. If no upstream exists, verify `origin` because it is the
only remote authorized for the setup push:

```bash
git remote get-url --push <upstream-remote>
git remote get-url --push origin
```

Run only the command that matches the detected upstream state. Halt if the
required push remote is missing. Never display embedded credentials; redact
them if the configured URL contains any.

Treat the resolved push URL, current branch/upstream, and explicit `/handoff`
invocation as the destination and user-authorization evidence. Show the push
URL and branch in commentary immediately before the push. Do not require
`gh auth status`, `gh api user`, or `gh repo view` as push preconditions. Git
and the GitHub CLI may use different credentials. Optional GitHub CLI checks
must be read-only and remain advisory. Never request or display a token. Do
not halt before the authorized push solely because a GitHub CLI check is
unavailable, network-blocked, unauthenticated, or inconclusive.

Preflight the exact destination before pushing:

```bash
git ls-remote --heads '<verified-push-url>' 'refs/heads/<current-branch>'
```

An exit code of zero with no matching ref is valid for a new remote branch. If
the preflight fails, halt Phase 4 and report Git's exact error.

Immediately before the push, recheck the branch and configured upstream with
the two `git rev-parse` commands above and verify that the branch, upstream
state, remote, and push URL still match the destination that passed the
preflight. If any changed, halt instead of pushing to an untested destination.

Push the handoff commit only if the handoff trigger or user instruction
authorizes it. This is a routine backup of the handoff state — not a merge
decision and not a push to main. Use exactly one of these command shapes:

- If the branch has an upstream: `git push`.
- If the branch has no upstream: `git push -u origin <branch>`.

Explicit `/handoff` invocation is normal push authorization for the standard
handoff commit; the OpenCode session will surface its native permission prompt
for the `git push` command. The justification must state that this is the
explicitly authorized, non-force handoff push; name the verified push URL; and
identify the current branch/upstream. Do not claim an authenticated account or
repository permission unless it was actually verified. The actual `git push`
is the authoritative network and Git-authentication check. If it fails,
report Git's exact error and do not reinterpret a preceding GitHub CLI result
as proof of the cause.

Never force-push. If the OpenCode permission prompt or approval review denies
the push, halt Phase 4 — report the exact denied action and do not retry with
another command shape, indirect execution, or workaround. Do not instruct the
user to change the whole session's permission mode. The user may re-run the
handoff push once the permission is granted; do not bypass the prompt.

If the push instead fails for runtime reasons (auth token rejected, network,
remote rejected), report it and continue to Phase 5 — the handoff is valid
locally regardless.

Pushing to a feature or test branch is expected handoff behavior. Only hesitate
if the current branch is `main`, `master`, or `develop` — in that case, ask the
user before pushing.

## Phase 5: Report And Stop

Before reporting, read or refresh the `## Session Worklist` and `## Phase Guard`
in `production/session-state/active.md` when present. If the scratchpad is only
a pointer stub, use the handoff document's recorded next action. Surface any
owed verification and finish with exactly one numbered recommendation:

```text
Next action:
1. (Recommended) [action label] - [brief reason / command]
```

Report in 15 lines or fewer:

- Label.
- Branch.
- Commit, or why commit was skipped.
- Push result, or why push was skipped.
- Handoff doc next action.
- Playable/slice source path, or `Not declared`.
- Open blockers or deferred items.

After reporting, stop. Do not start new feature work in the same turn.
