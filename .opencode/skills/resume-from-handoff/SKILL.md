---
name: resume-from-handoff
description: "Use when starting a fresh project session, resuming from saved state, asking where the project stands, choosing the next work item from handoff state, or saying resume, pick up where I left off, what should I work on, where am I, or catch me up."
---

# Resume From Handoff - Compile A Fresh Session Worklist

`/handoff` writes the canonical resume doc at the end of a session. This skill
reads it once at the start of the next session, merges the live backlog with
phase guardrails, and writes the current-session routing cache to
`production/session-state/active.md`.

This skill writes exactly one file: `production/session-state/active.md`. It
does not commit, push, run mutating `gh`, launch builds, or run boot smoke.
Explicit invocation of `/resume-from-handoff` counts as approval to write or
overwrite that one session-cache file; do not pause mid-flow to ask for
permission for `production/session-state/active.md`. A project-level CI status
rule in `AGENTS.md` may still require read-only `gh run` status checks when a
CI-green verification is explicitly owed; report those outputs as observed in
this turn if you run them.

Default invocation is a bounded resume. Read the full handoff and compact
index, then inspect only the bounded current section of the declared playable
or slice source before compiling a ranked `## Session Worklist`. Use
`/resume-from-handoff deep [focus]` only when the user explicitly requests the
full slice history. `deep` changes read depth only; a focus argument biases
ranking, it does not select a lane or broaden mutation authority. For
lightweight phase orientation use `/help`; for a full artifact gap audit use
`/project-stage-detect`.

## Step 0: Handle Missing Handoff

If `production/session-handoff.md` does not exist, do not substitute another
document as the canonical handoff. Report that no handoff exists yet, recommend
the appropriate route, and stop unless the user asked for a general project
audit:

- First-session setup: `/start`
- Broad phase orientation: `/help`
- Full gap discovery: `/project-stage-detect`
- Preserve future state once work exists: `/handoff`

## Step 1: Read Canonical State And Check Freshness

Use this source precedence. Surface conflicts; never silently normalize them:

1. `production/session-handoff.md` for durable narrative, decisions, blockers,
   and intended next action.
2. `production/stage.txt` for current stage and
   `production/sprint-status.yaml` for story status.
3. The fresh bounded current section of the declared slice source for playable
   state facts.
4. A fresh `production/resume-index.md` as a derived accelerator.
5. `production/session-state/active.md` as the lowest-priority same-session
   cache.

Read these in order:

1. `production/session-handoff.md` in full. Page through it until every line has
   been read. Do not analyze from the first page alone; the Next Action, Open
   Items table, carry-flags, and Most Recent Session narrative can be spread
   across the file.
2. Check the size of `production/resume-index.md` before reading it. Read it in
   full only when it is at most 10 KB. Mark an oversized index `oversized` and
   continue without ingesting it; the index is never canonical.
3. `production/stage.txt` if present, then `production/sprint-status.yaml` for
   per-story status if present.
4. `.opencode/docs/workflow-catalog.yaml` if present. This is the authoritative
   phase catalog and required-step sequence.
5. The file named by the handoff's `Playable/Slice State Source` field, if it is
   declared and exists. Do not assume a fixed path such as `src/README.md`.
   Locate the current slice/version heading from the handoff or index and read
   only that bounded current section: at most 200 lines or 32 KiB, whichever
   comes first. Default resume must not read the entire slice source. If the
   field is missing, blank, `Not declared`, or points to a missing file, report
   the slice detail as undeclared or unavailable and continue from the handoff.
6. `production/session-state/active.md` if present. It is a local scratchpad in
   many projects and may not exist on a fresh clone.
7. `production/session-archive.md` only to resolve a specific historical
   question the live handoff does not answer. Do not read it by default.

In `deep` mode only, read the entire declared slice source after the canonical
and guardrail files. Missing or stale index state never activates deep mode
automatically.

Check the index's recorded slice path and SHA-256 content hash against the
current declared source. Compute the hash locally without loading the whole
source into model context (for example `shasum -a 256 <file>`). Record it as
`fresh`, `missing`, `oversized`, `stale-hash`, `path-mismatch`, or
`unavailable`. Validate the recorded source HEAD as current or an ancestor of
the current HEAD; a later HEAD is provenance to record, not a substitute for
the slice hash. A non-ancestor is a source conflict. If the index is missing,
oversized, or stale, report that and continue with the bounded source read. If
authoritative sources disagree, keep the conflict visible in the briefing and
session cache.

If the user passed a focus area, bias the worklist toward it, but still surface
the handoff's own recommended Next Action and the vertical-slice forcing
function. A focus argument biases ranking; it does not select a lane.

## Step 2: Apply The Vertical-Slice Forcing Function

`AGENTS.md` may require this at every session entry before recommending any
action. Surface all four from the handoff and the declared playable/slice source
when available:

1. Current slice version or playable-state label.
2. Last successful end-to-end boot or playtest. Report it as a handoff or slice
   source claim unless you verified it in this turn.
3. Smallest next playable advance, concrete and no larger than about one
   session.
4. Extend, feed, or carve-out classification for each likely work item.

This check overrides the handoff's Next Action whenever the two diverge. If the
handoff recommends doc or process work that neither extends nor feeds the slice,
flag it as drift.

## Step 3: Locate Position In The Development Cycle

Give the user a concise "you are here" map:

- Stage from `production/stage.txt` if present and from the handoff Current
  Stage.
- Catalog phase from `.opencode/docs/workflow-catalog.yaml` if present.
- First incomplete required catalog step for that phase.
- Next gate and any mismatch between `stage.txt`, handoff stage, and catalog
  evidence.
- Pipeline position: concept -> systems design -> technical setup ->
  pre-production -> production -> polish -> release.
- Active milestone and sprint from the handoff or sprint status.
- Macro health signals: foundation architecture status, open director gates,
  blockers, and forward-roadmap estimates in sessions, never calendar time.

Keep this orientation tight. Put depth in the worklist.

## Step 4: Synthesize The Actionable Worklist

Mine the handoff's Next Action, Tracked Open Items, carry-flags, deferred
acceptance criteria, slice-track carve-out candidates, and sprint-status
stories. Produce a generous list, then rank it.

Group by lane:

- Primary path: the handoff's recommended next action or the slice forcing
  function's corrected top action. Give one clear lead recommendation.
- Sprint stories: ready-for-dev, in-progress, and blocked stories.
- Slice-track carve-outs: alternative slice advances named by the handoff or
  declared slice source.
- Hygiene, deferred, and owed: open items, doc reconciles, deferred ACs, owed
  playtests, owed CI, and integrity checks.
- Phase guard work: first incomplete required catalog step and the next gate
  from `.opencode/docs/workflow-catalog.yaml` when present.

For each item include:

- What it is and why it matters.
- Start command or skill, such as `/dev-story`, `/smoke-check sprint`, or
  `/design-system`.
- Slice tag: extend, feed, or carve-out.
- Rough size in sessions, never days or weeks.
- Source: handoff, sprint status, active state, slice source, stage file, or
  workflow catalog.

Do not silently truncate. If you cap the visible list, say what you left out.

### Ranking Rules

Rank in this order:

1. Owed verification and blockers.
2. Handoff Next Action and Tracked Open Items.
3. In-progress or ready sprint stories.
4. Slice-state playable advances.
5. Required phase work from `stage.txt` and `workflow-catalog.yaml` when present.
6. Optional hygiene or carve-outs.

`stage.txt` and `workflow-catalog.yaml` are guardrails, not the whole backlog.
Out-of-phase items may appear only when labeled as explicit carve-outs or user
overrides.

## Step 5: Surface Blockers, Gates, And Integrity Items

Before the user picks work, flag anything that must be checked or honored first:

- FIRST items: if the handoff says to verify CI green, a boot smoke, or a prior
  push, recommend the exact command. Run read-only CI status checks yourself only
  when `AGENTS.md` requires that; otherwise keep this skill read-only and label
  unrun checks as owed.
- Open merge, design-review, or director gates.
- Approved-but-unpersisted prose: scan for APPROVED markers without backing
  on-disk prose when project instructions require that integrity check.
- STOP conditions recorded by the prior session.

Reporting integrity: source size, branch/HEAD, and hash checks run in this turn
are verified freshness evidence. This skill runs no build, test, boot, or
playtest measurements by default. Report those handoff figures as claims, not
as facts you observed.

FIRST verification cannot be waived by choosing another lane. Run any required
read-only FIRST check before selection when project instructions authorize it.
Otherwise put that check at the front of every affected lane and do not enter
the selected workflow until the check clears or is reported blocked.

## Step 6: Write The Session Cache

Write `production/session-state/active.md` with the current session routing
cache. Preserve only concise current-state notes from the old `active.md` when
they are still relevant; stale scratchpad content should not outrank the live
handoff.

Required sections:

```markdown
# Active Session State

Updated: [date/time or current date if exact time unavailable]
Source: production/session-handoff.md

## Current Focus
- Stage: [stage from stage.txt or inferred]
- Handoff stage: [handoff Current Stage or unset]
- Milestone: [milestone or unset]
- Sprint: [sprint or unset]
- Slice: [version/label or undeclared]
- Playable/Slice State Source: [relative path, Not declared, or unavailable path]

## Phase Guard
- Stage file: [value or missing]
- Catalog phase: [phase key/label or unmatched]
- First incomplete required step: [step + command or unknown]
- Next gate: [current -> next phase, or none]
- Phase mismatch: [none, unset stage, handoff drift, or out-of-phase backlog]

## Source Freshness
- Branch / HEAD: [current branch and HEAD]
- Resume index: [fresh, missing, oversized, stale-hash, path-mismatch, or unavailable]
- Slice source: [path + bounded/deep mode + current hash state]
- Source conflict: [none or concise conflict that remains unresolved]

## Session Worklist
1. (Recommended) [lane title] - [why] -> `[command-or-skill]` [extend/feed/carve-out, ~N sessions, source]
2. [lane title] - [why] -> `[command-or-skill]` [tag, ~N sessions, source]

## Owed Before Starting
- [owed verification, blocker, gate, or "None"]

## Notes
- [handoff claims vs verified-now caveats]
```

The write is part of this skill's declared workflow. Do not commit, push, or
stage it here.

After writing, read `production/session-state/active.md` back in full. Verify
that `Source: production/session-handoff.md`, `## Source Freshness`,
`## Phase Guard`, `## Owed Before Starting`, and the recommended
`## Session Worklist` lane match the sources just read. Correct a derived-cache
mistake within this one authorized file and read it back again. Do not claim
the session cache was updated until this readback passes.

## Step 7: Present The Resume Briefing

Use this shape:

```text
## Resume - <project> - Session <N+1> entry

Stage: <stage> | Milestone: <milestone> | Sprint: <sprint> | Slice: <version or undeclared>
Pipeline: concept -> ... -> [current] -> ...   next gate: <gate>
Playable/Slice State Source: <relative path, Not declared, or unavailable path>
Resume index: <fresh, missing, oversized, stale-hash, path-mismatch, or unavailable>
Session cache: production/session-state/active.md updated

Vertical-slice forcing function:
- Slice version: <version and one-line real/stubbed state, or undeclared>
- Last clean boot: <when, and whether verified this turn or reported by handoff>
- Smallest next playable advance: <concrete, <=1 session>
- This session's likely work: <extend/feed/carve-out>

Phase guard:
- Stage file: <value or missing>
- Catalog phase: <phase>
- First incomplete required step: <step or unknown>
- Phase mismatch: <none/mismatch>

Recommended next action:
- <one top thing> - <why> -> `<command-or-skill>` [<tag>, ~<n> sessions]

Worklist:
Sprint stories:
- ...
Slice-track carve-outs:
- ...
Hygiene / deferred / owed:
- ...

Before you start - check / honor first:
- <owed verification or gate>
```

The briefing ends at a selection boundary. Never start an unselected lane.

- If multiple lanes are genuinely viable, use the `question` tool when
  available, with the recommendation as the first option. Keep the choices
  compact, preserve exactly one recommendation, and wait for the user's
  selection. If the `question` tool is unavailable, use the same ordered lanes
  in a numbered prompt and wait for the numeric reply.
- If exactly one lane is valid, present the numeric fallback:
  `Next action:` then `1. (Recommended) [action label] - [reason / command]`.
  Even for this single option, wait for the user to reply `1`; do not start it
  automatically.

Resume selection authorizes entering only the selected workflow. It does not
authorize that workflow's writes, builds, boot smoke, mutating `gh`, commits,
pushes, branch changes, design decisions, game-feel decisions, balance
decisions, or any other mutation beyond approvals already declared by that
workflow. A Follow-up fork inside the selected workflow is a new decision:
use the `question` tool when available, otherwise use a compact numbered or
lettered prompt, and wait again.

Do not end with an unstructured "what do you want to do?" line.

Do not point the user back to `/resume-from-handoff` after work completes. Later
closeouts should read or refresh the saved `## Session Worklist` in `active.md`.

## Collaborative Protocol

- Writes only `production/session-state/active.md`; no commits, pushes, mutating
  `gh`, or boot smoke from this skill.
- Explicit invocation authorizes that one write. Do not ask "May I write this
  session cache?" for `production/session-state/active.md` after the user has
  invoked `/resume-from-handoff`.
- Use the `question` tool, not a free-text prompt, for true multi-lane choices
  when the tool is available.
- Never start an unselected lane. A single obvious lane still waits for the
  user's numeric `1` selection.
- Treat later workflow forks as new structured decisions; the resume choice
  does not pre-answer them.
- FIRST verification remains mandatory regardless of lane choice.
- Default resume uses bounded slice reads; only explicit `deep` mode reads full
  slice history.
- Read the written cache back and verify source freshness, phase guard, owed
  verification, and the recommended lane before reporting success.
- Make one primary recommendation. The user should leave knowing the top thing
  to do, with the rest as a ranked menu.
- The vertical-slice forcing function overrides doc-track drift.
- Estimate in sessions, never calendar time.

## What This Skill Does Not Do

- Does not write anything except `production/session-state/active.md`.
- Does not start follow-on work before the user selects a lane.
- Does not commit or push; that is `/handoff`.
- Does not perform a full artifact gap audit; that is `/project-stage-detect`.
- Does not replace reading the handoff; it operationalizes the canonical handoff
  into an oriented, prioritized session worklist.

## Closeout Contract

Every final response from this skill must include completed work, verification
run or owed verification, and next-lane routing. Read or refresh the
`## Session Worklist` in `production/session-state/active.md` when present. End
with a numbered next-action prompt using numeric format only, even when there is
only one valid lane:

```md
Next action:
1. (Recommended) [action label] - [brief reason / command]
```

If multiple lanes are viable, add more numbered options and keep exactly one
`(Recommended)` option. The user can reply with `1`. Do not end with only a
static command list.
