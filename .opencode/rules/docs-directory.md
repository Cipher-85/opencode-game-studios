# Docs Directory Rules

---
paths:
  - "docs/**"
---

Use this before authoring or editing docs outside more specific rules.

## Architecture Decision Records

Use `.opencode/docs/templates/architecture-decision-record.md`.

Required sections: Title, Status, Context, Decision, Consequences, ADR
Dependencies, Engine Compatibility, GDD Requirements Addressed.

- Status lifecycle: `Proposed` -> `Accepted` -> `Superseded`.
- Never skip `Accepted`; stories referencing a `Proposed` ADR are auto-blocked.
- Use `$architecture-decision` to create ADRs through the guided flow.

## Traceability Registry

`docs/architecture/tr-registry.yaml` contains stable requirement IDs that link
GDD requirements to stories.

- Never renumber existing IDs; only append new ones.
- `$architecture-review` Phase 8 updates the registry.

## Control Manifest

`docs/architecture/control-manifest.md` is the flat programmer rules sheet:
Required / Forbidden / Guardrails per layer.

- Include a date-stamped `Manifest Version:` in the header.
- Stories embed this version; `$story-done` checks for staleness.

## Engine Reference

Always check `docs/engine-reference/` before using engine APIs. The pinned
engine version may be newer than model training data.
