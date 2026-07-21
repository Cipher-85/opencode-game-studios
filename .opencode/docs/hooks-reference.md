# Active Hooks

Hooks are wired in `opencode.json` (plugin ref) and invoked by the
`.opencode/plugins/ccgs-hooks.js` adapter, which maps OpenCode events to the
preserved shell scripts. The adapter builds a Claude-shaped stdin JSON so the
scripts stay nearly unchanged from the upstream project.

| Hook | OpenCode event | Upstream event | Trigger | Action |
| ---- | -------------- | -------------- | ------- | ------ |
| `validate-commit.sh` | `tool.execute.before` (bash) | PreToolUse (Bash) | `git commit` commands | Validates design doc sections, JSON data files, hardcoded values, TODO format |
| `validate-push.sh` | `tool.execute.before` (bash) | PreToolUse (Bash) | `git push` commands | Warns on pushes to protected branches (develop/main) |
| `validate-assets.sh` | `tool.execute.after` (write/edit/apply_patch) | PostToolUse (Write\|Edit) | Asset file changes | Checks naming conventions and JSON validity for files in `assets/` |
| `session-start.sh` | `session.created` | SessionStart | Session begins | Loads sprint context, milestone, git activity; records a local branch/HEAD/timestamp review baseline; previews the bounded canonical handoff before active state; recommends `/resume-from-handoff` |
| `detect-gaps.sh` | `session.created` | SessionStart | Session begins | Detects fresh projects (suggests /start) and missing documentation when code/prototypes exist, suggests /reverse-document or /project-stage-detect |
| `pre-compact.sh` | `experimental.session.compacting` | PreCompact | Context compression | Injects session state (substantive active.md first with a bounded handoff fallback, modified files, WIP design docs) into `output.context[]` so it survives summarization; elevates the canonical handoff when active state is missing or pointer-only |
| `post-compact.sh` | `session.compacted` | PostCompact | After compaction | Restores the same active-first/handoff-fallback order and elevates the canonical handoff when needed |
| `session-stop.sh` | `session.idle` | Stop | Session ends | Archives `active.md` to session log and records git activity |
| `log-agent.sh` | `tool.execute.before` (task) | SubagentStart | Agent spawned | Audit trail start — logs subagent invocation with timestamp |
| `log-agent-stop.sh` | `tool.execute.after` (task) | SubagentStop | Agent stops | Audit trail stop — completes subagent record |
| `validate-skill-change.sh` | `tool.execute.after` (write/edit) | PostToolUse (Write\|Edit) | Skill file changes | Advises running `/skill-test` after any `.opencode/skills/` file is written or edited |
| `notify.sh` | `tui.toast.show` (best-effort) or dropped | Notification | Notification event | Originally Windows-only PowerShell toast; OpenCode desktop app auto-notifies, so this is low-priority / best-effort |

**Exit semantics:** advisory scripts (exit 0) run silently for side-effects;
blocking scripts (exit 1 for `validate-assets`, exit 2 for `validate-commit`/
`validate-push`) cause the adapter to `throw`, aborting the tool call.

**Payload fixtures:** `.opencode/hooks/fixtures/` contains static payload-shape
tests (Stage 1) and a runtime-capture checklist (Stage 2).

Hook reference documentation: `.opencode/docs/hooks-reference/`
Hook input schema documentation: `.opencode/docs/hooks-reference/hook-input-schemas.md`
