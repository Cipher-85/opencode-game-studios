# OpenCode Game Studios Package

This is the OpenCode-native runtime package for OpenCode Game Studios. It is an
unofficial port of [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
pinned to upstream commit `984023ddac0d5e27624f2baacde6105e45de375f`.

## Package version

Source of truth: `.opencode/VERSION`. Releases use `opencode-vX.Y.Z` git tags.

## Structure

| Directory | Contents |
|---|---|
| `agents/` | 49 subagent definitions (markdown + YAML frontmatter) |
| `skills/` | 77 skill definitions (one SKILL.md per subdirectory) |
| `commands/` | 77 slash-command wrappers (one per skill) |
| `hooks/` | 12 shell hook scripts + statusline.sh |
| `plugins/` | `ccgs-hooks.js` — OpenCode event adapter |
| `rules/` | 15 path-scoped rule reference files |
| `docs/` | Operational docs, workflow catalog, 40 templates |
| `lib/` | `models.sh` (model tier injection), `hooks.sh` (shared hook helpers) |
| `agent-memory/` | 17 MEMORY.md contract files |
| `manifest/` | Asset inventories for install tracking |
| `tests/` | Test fixtures for coexistence and validation scenarios |

## Commands

```bash
# Install (configure models + deploy to target)
bash .opencode/install.sh [--tier-opus MODEL ...] [target-path]

# Uninstall (restore model-agnostic state)
bash .opencode/uninstall.sh [target-path]

# Audit (validate agents, skills, runtime, config, hooks)
bash .opencode/audit.sh [all|agents|skills|runtime|config|hooks|smoke|release] [--root PATH]

# Release (version management)
bash .opencode/release.sh [current|bump|check|publish]
```

## Model tier injection

Unlike upstream (hardcoded `opus`/`sonnet`/`haiku`) and the Codex port
(hardcoded `gpt-5.5`/`gpt-5.4`/`gpt-5.4-mini`), this package is **truly
model-agnostic**. The install script lets users choose models per tier at
install time, with hard validation against `opencode models`.

See `install.sh --help` for details.

## Coexistence

OpenCode-owned files do not modify `.claude/` or `CLAUDE.md`. Shared neutral
project state (`production/`, `design/`, `docs/architecture/`) remains available
to all toolchains.
