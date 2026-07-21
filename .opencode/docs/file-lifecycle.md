# File Lifecycle

This repo treats tracked files as the durable project memory. Keep runtime
instructions compact and keep large rationale in docs.

## Track

- Root `AGENTS.md` startup instructions.
- `.opencode/instructions/path-rules/*.md` files that OpenCode must read before
  creating or editing matching paths.
- `.opencode/docs/` reference material that explains procedures, rationale, and
  lookup tables.
- Design, architecture, production, QA, and sprint artifacts that represent
  project decisions.
- Review logs and handoffs when a skill explicitly asks for them.
- `production/resume-index.md` when `/handoff` derives it from canonical state;
  keep it compact, tracked, and disposable. The installer allowlists this path
  for tracking but does not ship, own, or remove the project-created file.

## Ignore Or Keep Local

- Temporary command output, raw logs, caches, generated build artifacts, and
  local editor files.
- `production/session-logs/session-baseline.json`; the session-start hook
  rewrites this local review-scope anchor for each session.
- One-off transcripts unless converted into a concise project decision or
  handoff.
- Legacy Claude runtime files as OpenCode dependencies. They may exist for
  coexistence or migration history, but OpenCode instructions must not depend on
  them at runtime.

## Anti-Redundancy Policy

- Root `AGENTS.md` holds the hot-path startup contract only.
- Path-scoped Markdown files in `.opencode/instructions/path-rules/` hold
  discipline needed before editing matching paths.
- Long procedures belong in `.opencode/docs/`.
- If two files need the same rule, keep the short operational rule in the hot
  path and link to one longer explanation.

## Pause Audit

Before ending a work unit, check:

- Did every changed file belong to the requested scope?
- Are generated or temporary files left untracked?
- Are verification results labeled accurately?
- Is the next action discoverable from session state, handoff, or final reply?
- Would a fresh session know which docs to read without scanning the whole repo?
