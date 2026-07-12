<p align="center">
  <h1 align="center">OpenCode Game Studios</h1>
  <p align="center">
    Turn a single OpenCode session into a full game development studio.
    <br />
    49 agents. 77 skills. 77 commands. One coordinated AI team.
  </p>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href=".opencode/agents"><img src="https://img.shields.io/badge/agents-49-blueviolet" alt="49 Agents"></a>
  <a href=".opencode/skills"><img src="https://img.shields.io/badge/skills-77-green" alt="77 Skills"></a>
  <a href=".opencode/commands"><img src="https://img.shields.io/badge/commands-77-yellow" alt="77 Commands"></a>
  <a href=".opencode/hooks"><img src="https://img.shields.io/badge/hooks-12-orange" alt="12 Hooks"></a>
  <a href=".opencode/VERSION"><img src="https://img.shields.io/badge/version-0.4.2-blue" alt="v0.4.2"></a>
  <a href="https://opencode.ai"><img src="https://img.shields.io/badge/built%20for-OpenCode-f5f5f5" alt="Built for OpenCode"></a>
</p>

---

> **A faithful port of [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
> (commit `984023d`) to a native OpenCode project.**
> See [PORTING_NOTES.md](PORTING_NOTES.md) for the full porting log, decisions, and known gaps.

## Why This Exists

Building a game solo with AI is powerful — but a single chat session has no
structure. No one stops you from hardcoding magic numbers, skipping design docs,
or writing spaghetti code. There's no QA pass, no design review, no one asking
"does this actually fit the game's vision?"

**OpenCode Game Studios** solves this by giving your AI session the structure of
a real studio. Instead of one general-purpose assistant, you get 49 specialized
agents organized into a studio hierarchy — directors who guard the vision,
department leads who own their domains, and specialists who do the hands-on
work. Each agent has defined responsibilities, escalation paths, and quality
gates.

The result: you still make every decision, but now you have a team that asks the
right questions, catches mistakes early, and keeps your project organized from
first brainstorm to launch.

## What Is Included

- **49 OpenCode subagents** in `.opencode/agents/*.md` with deny-by-default
  permissions, model-tier metadata, and structured delegation paths
- **77 repo-local skills** in `.opencode/skills/*/SKILL.md`
  - 73 upstream workflow skills ported to OpenCode
  - 4 OpenCode-native support skills: `studio-status`, `studio-next`,
    `handoff`, and `resume-from-handoff`
- **77 slash commands** in `.opencode/commands/*.md` — one per skill, all run
  inline in the main conversation (no subtask isolation)
- **12 hook scripts** + `ccgs-hooks.js` plugin adapter mapping OpenCode events
  to shell-based validation (commits, pushes, assets, session lifecycle, agent
  audit trail, gap detection)
- **15 path-scoped rule files** in `.opencode/rules/*.md` with a routing table
  in `AGENTS.md` that tells agents which rules to read before editing matching
  paths
- **17 agent memory contracts** in `.opencode/agent-memory/*/MEMORY.md`
- **41 document templates** for GDDs, UX specs, ADRs, sprint plans, HUD design,
  accessibility, and more
- Root `AGENTS.md` startup instructions with behavioral sections (Startup
  Contract, Verification Integrity, Vertical-Slice Forcing Function, Code-Turn
  Discipline, Workflow Gates, File Lifecycle, Continuity Epilogue)
- Installer, uninstaller, audit framework, release tooling, and manifest tracking
- Coexistence rules for repositories that already contain Claude Code or Codex
  Game Studios files

## Current Status

Package version: `0.4.2` (see [`.opencode/VERSION`](.opencode/VERSION)).

This release includes:
- Hard `/resume-from-handoff` lane-selection boundary: focus arguments only bias
  ranking, multiple lanes use the `question` tool for structured choice, single
  lanes wait for numeric `1`, and follow-up forks remain separate decisions.
  FIRST verification cannot be waived by lane choice, and entering a selected
  workflow grants no additional mutation authority.
- `/handoff` mandatory two-round review gate with STANDARD/ADVERSARIAL tier
  selection, pure-document exemptions, finding triage, conditional second
  review, pass caps, and an auditable handoff record. The review stays inside
  the active OpenCode session with no external egress.
- Bug lifecycle consolidation: `/bug-report verify` with a VERIFIED FIXED
  verdict can complete verification, closure, stale triage cleanup, and derived
  session-state routing under one approved changeset instead of forcing separate
  verify → close → triage handoffs.
- User-owned playtest focus routing: when owed verification or the next action
  is a manual playtest, closeouts include a `Playtest focus:` brief with the
  hypothesis, setup/build, observation prompts, and verdict/evidence to return.
  `/playtest-report` templates and follow-up routing now require concrete
  hypotheses before sending the user back to play, while preserving the user's
  ownership of game-feel and balance verdicts. A `run_playtest_focus` validator
  keeps the contract present in root instructions, session-continuity docs, and
  the playtest-report workflow.
- Session Worklist routing cache (`## Session Worklist` + `## Phase Guard` in
  `production/session-state/active.md`); `/resume-from-handoff` compiles it,
  post-work closeouts read it, and `/studio-next` is now a deprecated manual
  reference
- Numbered closeout on completion skills: final responses end with a
  `Next action:` prompt and exactly one numeric `(Recommended)` option
- Central role-agent delegation contract: explicit skill invocation authorizes
  only the declared spawns, with review-mode filtering and no simulated
  specialist/director verdicts
- Full behavioral alignment with upstream CCGS (Startup Contract, Resume &
  Wrap-Up Routing, Verification Integrity, Vertical-Slice Forcing Function,
  Code-Turn Discipline, Workflow Gates, File Lifecycle, Continuity Epilogue)
- Model-agnostic installer with 3-tier model selection and hard validation
- Coexistence detection for Claude Code, Codex, and mixed-runtime projects
- Manifest-driven deploy with backup-before-overwrite and shared-path preservation
- Spawn-based plugin with payload capture for runtime verification
- `'*': deny` permission model with `question`/`todowrite` allowed for all agents

## Studio Hierarchy

Agents are organized into three tiers, matching how real studios operate:

```
Tier 1 — Directors (opus-tier)
  creative-director    technical-director    producer

Tier 2 — Department Leads (sonnet-tier)
  game-designer        lead-programmer       art-director
  audio-director       narrative-director    qa-lead
  release-manager      localization-lead

Tier 3 — Specialists (sonnet/haiku-tier)
  gameplay-programmer  engine-programmer     ai-programmer
  network-programmer   tools-programmer      ui-programmer
  systems-designer     level-designer        economy-designer
  technical-artist     sound-designer        writer
  world-builder        ux-designer           prototyper
  performance-analyst  devops-engineer       analytics-engineer
  security-engineer    qa-tester             accessibility-specialist
  live-ops-designer    community-manager

Engine Specialists
  godot-specialist + 4 sub-specialists (GDScript, C#, Shaders, GDExtension)
  unity-specialist + 4 sub-specialists (DOTS, Shaders, Addressables, UI Toolkit)
  unreal-specialist + 4 sub-specialists (GAS, Blueprints, Replication, UMG)
```

> **Model tiering:** Unlike upstream (hardcoded `opus`/`sonnet`/`haiku`) and
> the Codex port (hardcoded `gpt-5.5`/`gpt-5.4`/`gpt-5.4-mini`), this package
> is **truly model-agnostic**. The original Claude tier is preserved as
> `metadata.ccgs_tier` — a routing key the installer uses to inject your chosen
> model per tier. See [Install](#install) below.

## Slash Commands

Type `/` in OpenCode to access all 77 commands. Every command runs inline in
the main conversation — no subtask isolation, no context switching.

**Onboarding & Navigation**
`/start` `/help` `/project-stage-detect` `/setup-engine` `/adopt`
`/resume-from-handoff` `/studio-next` `/studio-status`

**Game Design**
`/brainstorm` `/map-systems` `/design-system` `/quick-design` `/review-all-gdds` `/propagate-design-change`

**Art & Assets**
`/art-bible` `/asset-spec` `/asset-audit`

**UX & Interface Design**
`/ux-design` `/ux-review`

**Architecture**
`/create-architecture` `/architecture-decision` `/architecture-review` `/create-control-manifest`

**Stories & Sprints**
`/create-epics` `/create-stories` `/dev-story` `/sprint-plan` `/sprint-status` `/story-readiness` `/story-done` `/estimate`

**Reviews & Analysis**
`/design-review` `/code-review` `/balance-check` `/content-audit` `/scope-check` `/perf-profile` `/tech-debt` `/gate-check` `/consistency-check` `/security-audit`

**QA & Testing**
`/qa-plan` `/smoke-check` `/soak-test` `/regression-suite` `/test-setup` `/test-helpers` `/test-evidence-review` `/test-flakiness` `/skill-test` `/skill-improve`

**Production**
`/milestone-review` `/retrospective` `/bug-report` `/bug-triage` `/reverse-document` `/playtest-report`

**Release**
`/release-checklist` `/launch-checklist` `/changelog` `/patch-notes` `/hotfix` `/day-one-patch`

**Creative & Content**
`/prototype` `/onboard` `/localize`

**Session Continuity**
`/handoff` `/resume-from-handoff` `/studio-next` `/studio-status`

**Team Orchestration** (coordinate multiple agents on a single feature)
`/team-combat` `/team-narrative` `/team-ui` `/team-release` `/team-polish` `/team-audio` `/team-level` `/team-live-ops` `/team-qa`

## Install

### Prerequisites

- [Git](https://git-scm.com/)
- [OpenCode](https://opencode.ai) v1.17+
- **Recommended**: Python 3 (for model injection and validation), jq (for hooks)

### Quick start (clone and configure)

```bash
git clone https://github.com/Cipher-85/OpenCode-Game-Studios.git my-game
cd my-game
bash .opencode/install.sh
```

The installer prompts interactively for your model choices (see below), then
configures all 49 agents and starts OpenCode.

### Model tier configuration

The installer is the key differentiator — it's **truly model-agnostic**. You
choose models per tier at install time:

**Interactive:**

```bash
bash .opencode/install.sh

# Prompts:
# Tier 1 — Directors (3 agents):       Model: zai-coding-plan/glm-5.2
#   Variant (max/high/standard):        max
# Tier 2 — Leads + Specialists (44):   Model: zai-coding-plan/glm-5.2
#   Variant:                            high
# Tier 3 — Light agents (2):           Model: (Enter to reuse Tier 2)
#   Variant:                            (Enter to reuse Tier 2)
# Primary agent:                       (Enter to reuse Tier 1)
```

**Non-interactive (CLI):**

```bash
bash .opencode/install.sh \
  --tier-opus "zai-coding-plan/glm-5.2" \
  --tier-sonnet "zai-coding-plan/glm-5.2" \
  --tier-haiku "zai-coding-plan/glm-5.2" \
  --primary "zai-coding-plan/glm-5.2" \
  --variant-opus "max" \
  --variant-sonnet "high" \
  --variant-haiku "high"
```

**Dry-run (preview without changes):**

```bash
bash .opencode/install.sh --dry-run \
  --tier-opus "zai-coding-plan/glm-5.2" \
  --tier-sonnet "zai-coding-plan/glm-5.2"
```

Each model ID is hard-validated against `opencode models` output. Unknown
models are rejected.

### Deploy to an existing game project

```bash
bash .opencode/install.sh /path/to/existing-game-project \
  --tier-opus "provider/model" \
  --tier-sonnet "provider/model" \
  --tier-haiku "provider/model"
```

The installer deploys all framework files alongside existing content. It detects
prior installs, foreign runtimes (Claude Code, Codex), and preserves shared
project files. See [Coexistence](#coexistence) below.

### What the installer modifies

1. **`.opencode/agents/*.md`** — injects `model:` and `variant:` into each
   agent's frontmatter based on its `metadata.ccgs_tier`
2. **`opencode.json`** — sets the primary model
3. **`.opencode/models.json`** — records the tier→model mapping
4. **`.opencode/install-state.json`** — schema-v2 with SHA256 hashes, detected
   mode, preserved/created paths, and model configuration

> **Static install only.** Installer success proves package deployment and
> static verification only. Trust the target project and start a **new
> `opencode` session** before treating its hooks, rules, permission profile,
> or agents as active.

## Uninstall

Restore the model-agnostic state (strips injected `model:` and `variant:` from
agents, removes generated files):

```bash
bash .opencode/uninstall.sh
```

Or uninstall from a target:

```bash
bash .opencode/uninstall.sh /path/to/project
bash .opencode/uninstall.sh --dry-run /path/to/project
```

In coexistence mode, the uninstaller preserves shared paths it didn't create,
removes only OpenCode-owned files, and extracts the marker block from
`AGENTS.md` without deleting user content.

## Coexistence

OpenCode Game Studios is intentionally additive. The installer detects the
target's runtime state before deploying:

| Mode | Detected by | Behavior |
|------|-------------|----------|
| `opencode_clean` | No foreign runtimes | Full deploy |
| `opencode_prior` | Prior OpenCode CCGS install | Incremental update |
| `claude_present` | `CLAUDE.md` or `.claude/` exists | Deploy alongside |
| `claude_ccgs_coexist` | `.claude/agents/` with CCGS names | Preserve shared paths, refuse `.claude/*` |
| `codex_present` | `.codex/` exists | Deploy alongside |
| `codex_ccgs_coexist` | `.codex/VERSION` or `.codex/agents/` | Preserve shared paths, refuse `.codex/*` |
| `multi_runtime` | Multiple foreign runtimes | Most cautious — preserve all existing files |

Rules:
- **Never modifies** `.claude/`, `CLAUDE.md`, `.codex/`, or `.agents/` paths
- **Preserves all existing non-`.opencode/` files** in coexistence mode
- **Backs up** any file before overwriting (to `.opencode/backups/<timestamp>/`)
- **Shared paths** (CCGS Skill Testing Framework, `docs/engine-reference/`,
  `design/registry/`, etc.) are preserved silently if they already exist
- **AGENTS.md** is created via marker-block splice — existing content is
  preserved, only the `<!-- BEGIN/END CCGS OPENCODE PORT -->` block is inserted

## Validation

Validate the framework's structural integrity:

```bash
# Full audit (agents, skills, runtime refs, config, hooks, smoke counts)
bash .opencode/audit.sh all

# Individual checks
bash .opencode/audit.sh agents
bash .opencode/audit.sh skills
bash .opencode/audit.sh runtime
bash .opencode/audit.sh config
bash .opencode/audit.sh hooks
bash .opencode/audit.sh smoke
bash .opencode/audit.sh release

# Validate against an external root
bash .opencode/audit.sh all --root /path/to/project

# Python structural validator (CI-ready, JSON output)
python3 .opencode/lib/validate_port.py --root .
python3 .opencode/lib/validate_port.py --root . --json
```

## Release Workflow

`.opencode/VERSION` is the package version source of truth. Releases use
namespaced `opencode-vX.Y.Z` GitHub tags.

```bash
bash .opencode/release.sh current                  # print version
bash .opencode/release.sh bump patch|minor|major   # bump version
bash .opencode/release.sh check                    # validate release readiness
bash .opencode/release.sh publish --dry-run        # preview release
bash .opencode/release.sh publish                  # create tag + GitHub release
```

The release sequence is manual: bump, update CHANGELOG, run `check`, commit
and push to `main`, then `publish`. GitHub Actions (`release-check.yml`) runs
validation on every push and PR.

## Project Structure

```
AGENTS.md                            # Master instructions + routing table + behavioral sections
opencode.json                        # Permissions, plugin ref, instruction files
.opencode/
  agents/                            # 49 subagent definitions (markdown + YAML frontmatter)
  skills/                            # 77 skill definitions (one SKILL.md per subdirectory)
  commands/                          # 77 slash-command wrappers (one per skill)
  hooks/                             # 12 shell hook scripts + statusline.sh
  plugins/
    ccgs-hooks.js                    # Event adapter: OpenCode events → shell scripts
  docs/                              # Operational docs, workflow catalog, templates
    workflow-catalog.yaml            # 7-phase pipeline definition (read by /help)
    templates/                       # 41 document templates
  rules/                             # 15 path-scoped rule files (read via routing table)
  lib/                               # models.sh, hooks.sh, coexistence.sh, validate_port.py
  agent-memory/                      # 17 agent memory contract files
  manifest/                          # Asset inventories for install/uninstall tracking
  install.sh                         # Installer with model tier injection
  uninstall.sh                       # Coexistence-aware uninstaller
  audit.sh                           # Validation dispatcher
  release.sh                         # Version management + GitHub releases
  VERSION                            # Package version (0.4.2)
design/                              # GDDs, narrative docs (AGENTS.md + registry/)
docs/                                # Technical docs, ADRs, engine reference
production/                          # Sprint plans, milestones, session state
src/                                 # Game source code (created during development)
```

> Path-scoped coding standards live in `.opencode/rules/*.md` (15 flat files).
> The routing table in `AGENTS.md` tells agents which rule file to read before
> editing files matching each path glob. Directories like `assets/`, `tests/`,
> and `prototypes/` are created during game development — the rules already
> apply when they exist.

## How It Works

### Agent Coordination

Agents follow a structured delegation model:

1. **Vertical delegation** — directors delegate to leads, leads delegate to specialists
2. **Horizontal consultation** — same-tier agents consult but can't make binding cross-domain decisions
3. **Conflict resolution** — disagreements escalate to the shared parent (`creative-director` for design, `technical-director` for technical)
4. **Change propagation** — cross-department changes coordinated by `producer`
5. **Domain boundaries** — agents don't modify files outside their domain without explicit delegation

### Collaborative, Not Autonomous

Every agent follows a strict collaboration protocol:

1. **Ask** — agents ask questions before proposing solutions
2. **Present options** — agents show 2-4 options with pros/cons
3. **You decide** — the user always makes the call
4. **Draft** — agents show work before finalizing
5. **Approve** — nothing gets written without your sign-off

### Automated Safety

The `ccgs-hooks.js` plugin maps OpenCode events to shell-based validation:

| Script | OpenCode event | What it does |
|--------|---------------|--------------|
| `validate-commit.sh` | `tool.execute.before` (bash) | Checks hardcoded values, TODO format, JSON validity, design doc sections |
| `validate-push.sh` | `tool.execute.before` (bash) | Warns on pushes to protected branches |
| `validate-assets.sh` | `tool.execute.after` (write/edit) | Validates naming conventions and JSON structure for `assets/` files |
| `session-start.sh` | `session.created` | Shows branch, recent commits, active sprint |
| `detect-gaps.sh` | `session.created` | Detects fresh projects, missing design docs |
| `pre-compact.sh` | `experimental.session.compacting` | Injects session state into compaction context |
| `post-compact.sh` | `session.compacted` | Reminds to restore session state from `active.md` |
| `session-stop.sh` | `session.idle` | Archives `active.md`, records git activity |
| `log-agent.sh` | `tool.execute.before` (task) | Audit trail — logs subagent invocation |
| `log-agent-stop.sh` | `tool.execute.after` (task) | Audit trail — logs subagent completion |
| `validate-skill-change.sh` | `tool.execute.after` (write/edit) | Advises running `/skill-test` after skill file changes |

The plugin also captures runtime payloads to `porting-reports/runtime-payload-captures/`
for debugging and Stage 2 verification.

**Permission rules** in `opencode.json` auto-allow safe operations (git status,
test runs) and block dangerous ones (force push, `rm -rf`, reading `.env` files).

### Session Continuity

Three skills manage session persistence, centered on the live worklist cache in
`production/session-state/active.md`:

- **`/handoff`** — creates a durable `production/session-handoff.md` before
  pausing. Includes review gate, session state rotation, commit/push when
  authorized, and a structured report.
- **`/resume-from-handoff`** — one-time session-entry compiler. Reads the
  handoff at session start, merges sprint and slice state, and writes a ranked
  `## Session Worklist` plus `## Phase Guard` into `active.md`. Applies the
  vertical-slice forcing function. Explicit invocation authorizes that single
  write.
- **`/studio-next`** — deprecated manual reference. Normal post-work routing now
  reads the saved `## Session Worklist`; invoke `/studio-next` only for manual
  recovery from stale session state.

### Design Philosophy

Grounded in professional game development practices:

- **MDA Framework** — Mechanics, Dynamics, Aesthetics analysis for game design
- **Self-Determination Theory** — Autonomy, Competence, Relatedness for player motivation
- **Flow State Design** — Challenge-skill balance for player engagement
- **Bartle Player Types** — Audience targeting and validation
- **Verification-Driven Development** — Tests first, then implementation

## Customization

This is a **template**, not a locked framework:

- **Add/remove agents** — delete agent files you don't need, add new ones
- **Edit agent prompts** — tune behavior, add project-specific knowledge
- **Modify skills** — adjust workflows to match your team's process
- **Add rules** — create new `.opencode/rules/*.md` files and update the routing table
- **Pick your engine** — use the Godot, Unity, or Unreal agent set (or none)
- **Set review intensity** — `full` (all director gates), `lean` (phase gates only), or `solo` (none). Set during `/start` or edit `production/review-mode.txt`
- **Reconfigure models** — re-run `install.sh` with new model choices; previous models are replaced

## Platform Support

All hooks use POSIX-compatible patterns (`grep -E`, not `grep -P`) and include
fallbacks for missing tools. Runs on macOS, Linux, and Windows (Git Bash/WSL).

## Key Docs

- [PORTING_NOTES.md](PORTING_NOTES.md) — porting decisions, known gaps, corrections
- [CHANGELOG.md](CHANGELOG.md) — version history
- [ATTRIBUTION.md](ATTRIBUTION.md) — upstream attribution and coexistence constraints
- [UPGRADING.md](UPGRADING.md) — migration instructions
- [.opencode/README.md](.opencode/README.md) — package overview
- [.opencode/docs/verification-integrity.md](.opencode/docs/verification-integrity.md) — evidence labeling rules
- [.opencode/docs/session-continuity.md](.opencode/docs/session-continuity.md) — pause/resume procedures
- [.opencode/docs/file-lifecycle.md](.opencode/docs/file-lifecycle.md) — track vs ignore policy

## Attribution

This project is an unofficial OpenCode-native port of
[Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
by Donchitos, pinned to upstream commit `984023ddac0d5e27624f2baacde6105e45de375f`.
The upstream project is distributed under the MIT License.

See [ATTRIBUTION.md](ATTRIBUTION.md) for full attribution and coexistence constraints.

## License

MIT License. See [LICENSE](LICENSE) for details.
