---
name: resume-from-handoff
description: "Use when starting a fresh project session, resuming from saved state, asking where the project stands, choosing the next work item from handoff state, or saying resume, pick up where I left off, what should I work on, where am I, or catch me up."
---

# Resume From Handoff - Compile A Fresh Session Worklist

`/handoff` writes the canonical resume doc at the end of a session. This skill
reads it once at the start of the next session, merges the live backlog with
sprint and slice state, and compiles a ranked `## Session Worklist` (plus a
`## Phase Guard`) into `production/session-state/active.md`.

This skill writes exactly one file: `production/session-state/active.md`. It
does not commit, push, run mutating `gh`, launch builds, or run boot smoke.
Explicit invocation of `/resume-from-handoff` counts as approval to write or
overwrite that one session-cache file; do not pause mid-flow to ask for
permission for `production/session-state/active.md`. A project-level CI status
rule in `AGENTS.md` may still require read-only `gh run` status checks when a
CI-green verification is explicitly owed; report those outputs as observed in
this turn if you run them.

This is a deep read, not a glance. Read the full handoff, follow the playable or
slice-state pointer declared by the handoff, cross-reference sprint status,
stage, active state, and the workflow catalog, then compile a ranked
`## Session Worklist`. For lightweight phase orientation use `/help`; for a full
artifact gap audit use `/project-stage-detect`. This skill is neither: it
operationalizes the canonical handoff narrative into the session cache.

## Step 0: Handle Missing Handoff

If `production/session-handoff.md` does not exist, do not substitute another
document as the canonical handoff. Report that no handoff exists yet, recommend
the appropriate first-session setup or `/handoff` once there is state to
preserve, and stop unless the user asked for a general project audit.

## Step 1: Read The Canonical State In Full

Read these in order. The handoff is the source of truth.

1. `production/session-handoff.md` in full. Page through it until every line has
   been read. Do not analyze from the first page alone; the Next Action, Open
   Items table, carry-flags, and Most Recent Session narrative can be spread
   across the file.
2. The file named by the handoff's `Playable/Slice State Source` field, if it is
   declared and exists. Do not assume a fixed path such as `src/README.md`. If
   the field is missing, blank, `Not declared`, or points to a missing file,
   report the slice detail as undeclared or unavailable and continue from the
   handoff.
3. `production/sprint-status.yaml` for per-story status if present.
4. `production/session-state/active.md` if present. It is a local scratchpad in
   many projects and may not exist on a fresh clone.
5. `production/session-archive.md` only to resolve a specific historical
   question the live handoff does not answer. Do not read it by default.

If the user passed a focus area, bias the worklist toward it, but still surface
the handoff's own recommended Next Action and the vertical-slice forcing
function.

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

For each item include:

- What it is and why it matters.
- Start command or skill, such as `/dev-story`, `/smoke-check sprint`, or
  `/design-system`.
- Slice tag: extend, feed, or carve-out.
- Rough size in sessions, never days or weeks.

Do not silently truncate. If you cap the visible list, say what you left out.

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

Reporting integrity: this skill runs no measurements by default, so it has no
verified numbers of its own unless you actually produced them in this turn.
Report handoff figures as claims, not as facts you observed.

## Step 6: Present The Resume Briefing

Use this shape:

```text
## Resume - <project> - Session <N+1> entry

Stage: <stage> | Milestone: <milestone> | Sprint: <sprint> | Slice: <version or undeclared>
Pipeline: concept -> ... -> [current] -> ...   next gate: <gate>
Playable/Slice State Source: <relative path, Not declared, or unavailable path>

Vertical-slice forcing function:
- Slice version: <version and one-line real/stubbed state, or undeclared>
- Last clean boot: <when, and whether verified this turn or reported by handoff>
- Smallest next playable advance: <concrete, <=1 session>
- This session's likely work: <extend/feed/carve-out>

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

Phase Guard:
- Stage file: <value or missing>
- Catalog phase: <phase key/label or unmatched>
- First incomplete required step: <step + command or unknown>
- Next gate: <current -> next phase, or none>
- Phase mismatch: <none, unset stage, handoff drift, or out-of-phase backlog>

Session Worklist:
1. (Recommended) <lane title> - <why> -> `<command-or-skill>` [extend/feed/carve-out, ~N sessions, source]
2. <lane title> - <why> -> `<command-or-skill>` [tag, ~N sessions, source]
```

Write the `## Phase Guard` and `## Session Worklist` sections above into
`production/session-state/active.md` (creating or overwriting only that file).
This write is authorized by the `/resume-from-handoff` invocation; do not ask
for permission mid-flow. Keep the rest of `active.md` if it already exists; only
replace or add these two sections.

After the briefing, do not end with a free-text "which would you like?" line.
Proceed to Step 7.

## Step 7: Ask Which Work Item To Start With The `question` Tool

After the briefing, capture the user's lane choice with the `question` tool when
that tool is available in the current surface. Do not satisfy this step with an
ordinary prose question when the `question` tool is available.

Build 2-3 mutually exclusive lane options from the ranked worklist:

- Put the recommended primary path first and append `(Recommended)` to its
  label.
- Keep each label short, such as `Primary path`, `Sprint story`,
  `Slice carve-out`, or `Hygiene`.
- Each option description must include the one-line reason, start command or
  skill, slice tag, and rough size in sessions.
- Include owed FIRST checks in the option description or immediately before the
  question so they cannot be skipped silently.
- If the worklist has more than three viable lanes, show the full ranked menu in
  the briefing text, then put only the top three choices in the picker.

Use one `question` call with the recommended lane first and labeled
`(Recommended)`.

If the `question` tool is not available, fall back to a concise numbered prompt
with the same options and make clear that the user should pick a number or name.

Honor any FIRST verification owed regardless of the selected lane. Once the user
selects, confirm the chosen lane and exact starting command. The selection is
the user's explicit go-ahead for that lane; start that lane or hand off the exact
command according to the lane's normal skill and project instructions.

When the selected lane completes, read or refresh the saved `## Session Worklist`
in `production/session-state/active.md` and present the next lane as a numbered
next-action prompt. Do not point the user back to `/resume-from-handoff` after
work completes.

## Collaborative Protocol

- Writes only `production/session-state/active.md`; no commits, pushes, mutating
  `gh`, or boot smoke from this skill. Explicit invocation authorizes that one
  write. Do not ask "May I write this session cache?" for
  `production/session-state/active.md` after the user has invoked
  `/resume-from-handoff`.
- Use the `question` tool, not a free-text prompt, for the work-item choice and
  follow-up decisions when the tool is available.
- Never jump to work the user did not select.
- Make one primary recommendation. The user should leave knowing the top thing
  to do, with the rest as a ranked menu.
- The vertical-slice forcing function overrides doc-track drift.
- Estimate in sessions, never calendar time.

## What This Skill Does Not Do

- Does not write any file other than `production/session-state/active.md`; does
  not commit, push, or run mutating `gh` — that is `/handoff`.
- Does not perform a full artifact gap audit; that is `/project-stage-detect`.
- Does not replace reading the handoff; it operationalizes the canonical handoff
  into the session routing cache.

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
