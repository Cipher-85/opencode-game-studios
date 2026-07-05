# Audit: OpenCode Game Studios vs Codex Game Studios

> **Created:** 2026-07-05 (updated 2026-07-05)
> **Codex source:** https://github.com/Cipher-85/Codex-Game-Studios (v0.3.0, cloned `--depth 1`)
> **OpenCode target:** https://github.com/Cipher-85/opencode-game-studios (commit `2f72e8f`, `main`)

---

## Overview

The Codex-Game-Studios port (v0.3.0) has evolved significantly beyond a
mechanical port — it added **behavioral QoL improvements** and a **full
install/audit/release framework** that should be bridged to OpenCode.

The gap falls into 10 categories:
- **P0** (3): behavioral AGENTS.md sections, 3 new skills, path-rule routing table
- **P1** (3): operational docs, agent memory, root files
- **P2** (1): skill body continuity integration
- **P3** (1): install/uninstall + model tier injection framework
- **P4** (1): audit framework (validators + fixtures)
- **P5** (1): release tooling + manifest

---

## 🔴 P0 — Category 1: AGENTS.md behavioral sections (10 missing)

The OpenCode `AGENTS.md` is 42 lines (tech stack + collaboration protocol +
start note). The Codex `AGENTS.md` is 173 lines with these **additional
sections** that drive agent behavior at runtime:

| Section | What it does | Impact if missing |
|---|---|---|
| **Startup Contract** | Authoritative agent registration source; exact naming; no `.claude/` writes; no autonomous commits; context-% compaction decisions | Agents lack startup ground rules |
| **Resume & Wrap-Up Routing** | Routes "resume/pick up/catch up" → `/resume-from-handoff`; "what's next" → `/studio-next`; wrap-up epilogue vs durable `/handoff` | No structured resume flow |
| **Verification Integrity** | Hard rules: never claim unverified results; evidence labels (`verified this turn` / `file-reported` / `blocked` / `not run`); CI-read procedure; recovery procedure | Agents may claim unverified passes |
| **Vertical-Slice Forcing Function** | Classify work as `extend`/`feed`/`carve-out`; smallest playable advance wins unless owed verification blocks | Agents drift to non-slice work |
| **Code-Turn Discipline** | Think → define verifiable success → simplest design → surgical changes → narrowest verification | Agents may over-refactor |
| **Workflow Gates** | Explicit gate list (`/design-review` before GDD→code, `/story-done` before complete, `/smoke-check` before QA hand-off, `/team-qa` for sign-off, `/code-review` after major features) | Gates only in skill bodies, not globally visible |
| **File Lifecycle** | Track vs ignore policy; anti-redundancy (AGENTS.md = hot path only; path-rules = discipline; long procedures in docs); pause audit checklist | No file-tracking discipline |
| **Continuity Epilogue** | After each work unit: summarize → surface owed verification → recommend next → suggest handoff | No post-task continuity |
| **Available Role Agents** | Organized agent roster by tier (leadership / leads / design-content / engineering-QA-ops / engine) | Agents not discoverable from AGENTS.md |
| **Path-Scoped Instructions** | Routing table (see Category 7) | Path rules invisible to agents |

**Plan:** Rewrite `AGENTS.md` to incorporate all sections, adapted for
OpenCode (`/resume-from-handoff` instead of `$resume-from-handoff`,
`.opencode/` paths, `opencode.json` instructions mechanism).

---

## 🔴 P0 — Category 2: 3 new skills missing

| Skill | Lines | Purpose |
|---|---|---|
| **`studio-next`** | 176 | Lightweight continuity router — reads handoff/sprint/stage/slice state, applies vertical-slice forcing function, recommends single best next action. Read-only, never writes/commits/pushes. Includes Continuity Epilogue Pattern to apply after any work unit. |
| **`handoff`** | 167 | Write-side: creates durable `production/session-handoff.md` before pausing. Phases: review gate → choose label → update session state (rotate prior to archive) → refresh local scratchpad → commit when authorized → push when authorized → report and stop. Size check at 25 KB. |
| **`resume-from-handoff`** | 223 | Read-side: turns handoff into oriented prioritized plan. Steps: handle missing → read canonical state → apply vertical-slice forcing → "you are here" map → synthesize worklist by lane → surface blockers/gates → present resume briefing → structured work-item choice via `question` tool. |

The 4th Codex-new skill, `studio-status`, already exists in OpenCode as a
command wrapper. A full skill body is optional (Category 8).

**Plan:** Port all 3 skills to `.opencode/skills/` + matching
`.opencode/commands/` wrappers. Adapt:
- `request_user_input` → `question` tool
- `.agents/skills/` → `.opencode/skills/`
- `$skill-name` → `/skill-name`
- `.codex/docs/` → `.opencode/docs/`
- `apply_patch` references → `write`/`edit`

---

## 🔴 P0 — Category 3: Path-rule routing table (FUNCTIONAL GAP — was Cat 7)

**This was reclassified from "optional" to a functional gap after
investigation.** During the audit, I discovered that OpenCode's AGENTS.md
tree-walking goes **up from the session CWD to the worktree root** — it does
NOT discover nested `AGENTS.md` files in subdirectories below the CWD.

Verified empirically via `opencode debug config`:

```
Instructions actually loaded:     6 files (all in .opencode/docs/)
Nested AGENTS.md files on disk:  16 files (src/gameplay/AGENTS.md, design/gdd/AGENTS.md, etc.)
Nested AGENTS.md in instructions: NONE
```

The 11 path-scoped AGENTS.md files created during the initial port
(`src/gameplay/AGENTS.md`, `design/gdd/AGENTS.md`, etc.) are **on disk but
invisible to agents**. When an agent edits `src/gameplay/combat.gd`, it never
sees the gameplay-code rules.

This is the same problem the Codex port solved with its AGENTS.md routing
table. Neither Codex nor OpenCode auto-discovers path-scoped rules based on
the file being edited — the agent has to be *told* to read them.

**Plan:** Add a routing table to root `AGENTS.md` (which IS auto-loaded) that
tells agents which nested AGENTS.md to read before editing matching paths:

```markdown
## Path-Scoped Instructions

Before creating or editing files matching a path below, read the listed
AGENTS.md file(s) with your Read tool.

| Path | Rule file(s) |
| ---- | ---- |
| src/** | src/AGENTS.md |
| src/gameplay/** | src/AGENTS.md, src/gameplay/AGENTS.md |
| src/core/** | src/AGENTS.md, src/core/AGENTS.md |
| src/ai/** | src/AGENTS.md, src/ai/AGENTS.md |
| src/networking/** | src/AGENTS.md, src/networking/AGENTS.md |
| src/ui/** | src/AGENTS.md, src/ui/AGENTS.md |
| design/** | design/AGENTS.md |
| design/gdd/** | design/AGENTS.md, design/gdd/AGENTS.md |
| design/narrative/** | design/AGENTS.md, design/narrative/AGENTS.md |
| docs/** | docs/AGENTS.md |
| assets/data/** | assets/data/AGENTS.md |
| assets/shaders/** | assets/shaders/AGENTS.md |
| tests/** | tests/AGENTS.md |
| prototypes/** | prototypes/AGENTS.md |
| tools/** | tools/AGENTS.md (new — see below) |
```

Also add `tools/AGENTS.md` (new path coverage the Codex port introduced that
neither upstream nor the OpenCode port has).

This routing table is part of the P0 AGENTS.md rewrite (Category 1), not a
separate phase.

---

## 🟡 P1 — Category 4: 3 new operational docs

| Doc | Lines | Content |
|---|---|---|
| **`verification-integrity.md`** | 51 | Hard verification rules, evidence labels (`verified this turn` / `file-reported` / `blocked` / `not run`), CI-read handling, incident examples, 5-step recovery procedure |
| **`session-continuity.md`** | 58 | File roles (active.md / session-handoff.md / session-archive.md / src/README.md), pause/resume procedures, context thresholds (50% / 60-70% / >70%), 3 handoff depth tiers |
| **`file-lifecycle.md`** | 44 | Track vs ignore policy, anti-redundancy, pause audit checklist |

**Plan:** Port all 3 to `.opencode/docs/`, adapting paths. Add all 3 to the
`instructions` array in `opencode.json` so they're globally loaded.

---

## 🟡 P1 — Category 5: Agent memory expansion (1 → 17)

The OpenCode port has 1 agent-memory file (lead-programmer). The Codex port
has **17** — one for every agent that had `memory: project` or `memory: user`
in upstream. The `memory:` frontmatter was a Claude Code platform feature
(Claude CLI managed storage); Codex emulated it with file-based contracts
(agent instructions say "read this file before role work"). OpenCode also
lacks a native agent-memory mechanism, so the same emulation applies.

The 16 new files are **empty stubs** — a Memory Contract + Durable Notes
placeholder. Their value is structural: a defined landing zone for
role-specific rulings to accumulate over time. They pay off slowly as a real
game project evolves.

**Plan:** Create 16 new `MEMORY.md` files in `.opencode/agent-memory/`. Copy
the Codex contract text, adapting "Codex" → "OpenCode" and `.codex/` →
`.opencode/`.

---

## 🟡 P1 — Category 6: Root docs (CHANGELOG + ATTRIBUTION)

- `CHANGELOG.md` — version history documenting port milestones
- `ATTRIBUTION.md` — upstream attribution + coexistence constraints
- `production/session-handoff.md` and `production/session-archive.md` —
  created on demand by the new skills; only `.gitkeep` needed now

**Plan:** Add both root files adapted for OpenCode.

---

## 🟡 P2 — Category 7: Skill body continuity integration

After porting the 3 new skills, update closing sections of 5 existing skills:

| Skill | Change |
|---|---|
| `gate-check` | Phase 7: append `/studio-next` routing after gate verdict |
| `code-review` | Phase 9: suggest `/handoff`; route to `/studio-next` |
| `story-done` | Phase 8: append `/studio-next` routing; suggest `/handoff` |
| `help` | Step 7: route to `/studio-next` for post-task continuity |
| `start` | Closing: mention `/studio-next` as the continuity router |

Substantive phase/checklist content stays faithful to upstream — changes are
to closing/routing sections only.

---

## 🟢 P3 — Category 8: Install/uninstall + model tier injection

**This is the key OpenCode differentiator.** Unlike upstream Claude Code
(hardcoded `opus`/`sonnet`/`haiku`) and Codex (hardcoded `gpt-5.5`/
`gpt-5.4`/`gpt-5.4-mini`), the OpenCode port is **truly model-agnostic** —
`model` is unset on all 49 agents, with `metadata.ccgs_tier` as the routing
key. The install script lets users choose their models at install time.

### Install flow

```bash
# Clone the template
git clone https://github.com/Cipher-85/opencode-game-studios.git my-game
cd my-game

# Run the installer (interactive)
bash .opencode/install.sh

# Or non-interactive
bash .opencode/install.sh \
  --tier-opus zai-coding-plan/glm-5.2-max \
  --tier-sonnet zai-coding-plan/glm-5.2 \
  --tier-haiku zai-coding-plan/glm-5.2 \
  --primary zai-coding-plan/glm-5.2-max
```

Interactive prompts:
1. Tier 1 — Directors (3 agents): `opus` tier → user enters model ID
2. Tier 2 — Leads + Specialists (44 agents): `sonnet` tier → user enters model ID
3. Tier 3 — Light agents (2: community-manager, devops-engineer): `haiku` tier → user enters model ID
4. Primary agent (build): defaults to Tier 1 choice

**Hard validation:** each model ID is checked against `opencode models`
output. Unknown models are rejected (prevents typos, ensures provider is
configured).

### What the installer modifies

1. Each `.opencode/agents/*.md`: reads `metadata.ccgs_tier`, injects
   `model: <provider/model-id>` into frontmatter
2. `opencode.json`: sets `model` field (primary agent default)
3. `.opencode/models.json`: generated tier→model mapping (for reconfiguration)
4. `.opencode/install-state.json`: tracks installed files + model mapping (for clean uninstall)

### Two install modes

- **Clone-and-configure** (in-place): user cloned this repo as their game
  project. Script configures models + validates. No file copying.
- **Install-into-existing** (target path): user has an existing game repo.
  Script copies `.opencode/`, `AGENTS.md`, docs, etc. into target, then
  configures models. Uses manifest for file tracking.

### Codex tooling to port (full suite)

| Codex file | OpenCode target | Adaptation |
|---|---|---|
| `install.sh` | `.opencode/install.sh` | New: model tier injection + hard validation |
| `uninstall.sh` | `.opencode/uninstall.sh` | Restore model-agnostic state + remove assets |
| `lib/install.sh` (963 lines) | `.opencode/lib/install.sh` | Coexistence detection, patch modes, backup, AGENTS.md marker-block (`<!-- BEGIN/END CCGS OPENCODE PORT -->`), `.gitignore` allowlist |
| `lib/hooks.sh` | `.opencode/lib/hooks.sh` | Root discovery, payload parsing — largely portable |
| `lib/agents.sh` | `.opencode/lib/agents.sh` | Collision check (OpenCode built-ins: `build`, `plan`, `general`, `explore`) |
| `lib/state.sh` | `.opencode/lib/state.sh` | Direct port |
| `lib/validate.sh` | `.opencode/lib/validate.sh` | Direct port |
| **(new)** `lib/models.sh` | `.opencode/lib/models.sh` | Model validation + injection + stripping |

### Uninstall

Restores model-agnostic state: removes injected `model:` fields from agent
frontmatter (using install-state to know which were injected vs user-added),
removes deployed assets if installed-into-target, cleans `.gitignore`
allowlist entries.

---

## 🟢 P4 — Category 9: Audit framework (validators + fixtures)

| Codex validator | OpenCode adaptation |
|---|---|
| `lib/validate_manifest.py` | Rewrite for OpenCode paths (`.opencode/` not `.codex/`, `.md` agents not `.toml`) |
| `lib/validate_runtime.py` | Rewrite: check 49 `.md` agents for required frontmatter (`description`, `mode`, `steps`, `permission`, `metadata.ccgs_tier`); reject unsupported fields; 73 skills for `name`/`description`/`metadata`; no `.claude/`/`CLAUDE.md`/`AskUserQuestion` in runtime |
| `lib/validate_hooks.py` | Adapt: validate `ccgs-hooks.js` loads, test shell scripts with fixtures |
| `lib/validate_install.py` | Adapt: validate install-state.json, deployed path ownership |
| `lib/validate_rules.py` | Rewrite: validate `opencode.json` (JSON schema, permission format, instructions exist) instead of `config.toml`/`.rules` |
| `lib/validate_release.py` | Adapt: `opencode-vX.Y.Z` tags |
| `lib/validate_smoke.py` | Adapt: negative fixtures for OpenCode format |
| `audit.sh` | Direct port (dispatcher) |
| `tests/fixtures/` | `.opencode/tests/fixtures/` — hook payloads, coexistence fixtures, negative fixtures |

---

## 🟢 P5 — Category 10: Release tooling + manifest

| Item | OpenCode target |
|---|---|
| `release.sh` | `.opencode/release.sh` — `current`/`bump`/`check`/`publish` with `opencode-vX.Y.Z` tags |
| `VERSION` | `.opencode/VERSION` |
| `manifest/upstream-assets.json` | `.opencode/manifest/upstream-assets.json` — 417-row source inventory |
| `manifest/expected-targets.json` | `.opencode/manifest/expected-targets.json` — auto-generated at release time from repo tree |
| `manifest/installed-files.json` | `.opencode/manifest/installed-files.json` — deployed path ownership |
| `backups/` | `.opencode/backups/` — pre-overwrite backups |

Manifest auto-generated at release time (via `release.sh`) rather than
maintained manually — avoids drift between manifest and actual repo state.

---

## 🟢 P3 (optional) — Category 11: Studio-status skill + hook

The Codex port has a `studio-status` skill (30 lines) and a
`studio-status-on-start.sh` session-start hook. OpenCode already has the
`/studio-status` command. Porting the skill body is optional consistency;
the session-start hook is lower value (OpenCode's desktop app auto-notifies).

---

## Bridging Plan

| Priority | Category | Items | Effort |
|---|---|---|---|
| 🔴 **P0** | 1 | Rewrite `AGENTS.md` with behavioral sections + routing table | Medium |
| 🔴 **P0** | 2 | Port 3 new skills + command wrappers | Medium |
| 🔴 **P0** | 3 | Path-rule routing table in AGENTS.md (part of Cat 1 rewrite) | Small |
| 🟡 **P1** | 4 | Port 3 new docs + add to `instructions` | Small |
| 🟡 **P1** | 5 | Create 16 agent-memory MEMORY.md files | Small |
| 🟡 **P1** | 6 | Add `CHANGELOG.md` + `ATTRIBUTION.md` | Small |
| 🟡 **P2** | 7 | Update 5 skill bodies for continuity integration | Small |
| 🟢 **P3** | 8 | Install/uninstall + model tier injection framework | Large |
| 🟢 **P4** | 9 | Audit framework (validators + fixtures) | Large |
| 🟢 **P5** | 10 | Release tooling + manifest | Medium |
| 🟢 **P3** | 11 | Studio-status skill body (optional) | Trivial |

### Implementation order

1. **P0** — AGENTS.md rewrite (includes routing table) + 3 new skills + commands
2. **P1** — 3 new docs + 16 agent-memory + CHANGELOG/ATTRIBUTION
3. **P2** — Skill body continuity integration
4. **P3** — Install/uninstall framework + model tier injection
5. **P4** — Audit framework (validators, fixtures, audit.sh)
6. **P5** — Release tooling + manifest + VERSION

P0-P2 are content changes (behavioral docs, skills, memory stubs).
P3-P5 are infrastructure (install scripts, validators, release tooling).
P3 depends on P0-P1 being finalized (the installer deploys the content).

### Key adaptation rules (Codex → OpenCode)

| Codex | OpenCode |
|---|---|
| `$skill-name` | `/skill-name` |
| `.codex/docs/` | `.opencode/docs/` |
| `.codex/agents/*.toml` | `.opencode/agents/*.md` |
| `.agents/skills/` | `.opencode/skills/` |
| `request_user_input` | `question` |
| `.codex/instructions/path-rules/` | Routing table in root AGENTS.md + nested AGENTS.md |
| `config.toml` | `opencode.json` |
| `models.toml` (hardcoded tiers) | `.opencode/models.json` (user-chosen at install time) |
| `codex-vX.Y.Z` tags | `opencode-vX.Y.Z` tags |
| `<!-- BEGIN/END CCGS CODEX PORT -->` | `<!-- BEGIN/END CCGS OPENCODE PORT -->` |
| Codex built-ins: `default`, `worker`, `explorer` | OpenCode built-ins: `build`, `plan`, `general`, `explore` |

### Model tier structure (3 tiers)

| Tier | `ccgs_tier` | Agents | Count |
|---|---|---|---|
| Directors | `opus` | creative-director, technical-director, producer | 3 |
| Leads + Specialists | `sonnet` | game-designer, lead-programmer, art-director, audio-director, narrative-director, qa-lead, release-manager, localization-lead, systems-designer, level-designer, economy-designer, technical-artist, sound-designer, writer, world-builder, ux-designer, prototyper, performance-analyst, devops-engineer, analytics-engineer, security-engineer, qa-tester, accessibility-specialist, live-ops-designer, community-manager, gameplay-programmer, engine-programmer, ai-programmer, network-programmer, tools-programmer, ui-programmer, godot-specialist, godot-gdscript-specialist, godot-csharp-specialist, godot-shader-specialist, godot-gdextension-specialist, unity-specialist, unity-ui-specialist, unity-shader-specialist, unity-dots-specialist, unity-addressables-specialist, unreal-specialist, ue-blueprint-specialist, ue-gas-specialist, ue-replication-specialist, ue-umg-specialist | 44 |
| Light agents | `haiku` | community-manager, devops-engineer | 2 |

> Note: `community-manager` and `devops-engineer` are the only `haiku`-tier
> agents. In practice many users will use the same model for sonnet + haiku
> tiers. The installer supports this — just enter the same model ID for both.

---

## Codex reference inventory (for porting source material)

| Source path | Use |
|---|---|
| `.codex/AGENTS.md` (root, 173 lines) | Source for AGENTS.md rewrite |
| `.agents/skills/studio-next/SKILL.md` (176 lines) | Source for studio-next skill |
| `.agents/skills/handoff/SKILL.md` (167 lines) | Source for handoff skill |
| `.agents/skills/resume-from-handoff/SKILL.md` (223 lines) | Source for resume-from-handoff skill |
| `.codex/docs/verification-integrity.md` (51 lines) | Source for verification doc |
| `.codex/docs/session-continuity.md` (58 lines) | Source for continuity doc |
| `.codex/docs/file-lifecycle.md` (44 lines) | Source for lifecycle doc |
| `.codex/agent-memory/*/MEMORY.md` (17 dirs) | Source for 16 new memory files |
| `.codex/instructions/path-rules/` (15 files) | Reference for routing table content |
| `ATTRIBUTION.md` (21 lines) | Source for attribution doc |
| `CHANGELOG.md` (50 lines) | Source for changelog format |
| `.codex/install.sh` + `lib/install.sh` (1049 lines total) | Source for install framework |
| `.codex/uninstall.sh` (41 lines) | Source for uninstall |
| `.codex/lib/validate_*.py` (7 files, ~55K total) | Source for audit framework |
| `.codex/audit.sh` (60 lines) | Source for audit dispatcher |
| `.codex/release.sh` (393 lines) | Source for release tooling |
| `.codex/manifest/*.json` (3 files) | Source for manifest format |
| `.codex/models.toml` (11 lines) | Reference for tier mapping (OpenCode uses user-chosen) |
| `.codex/tests/fixtures/` | Source for test fixtures |
