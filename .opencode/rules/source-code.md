# Source Code Rules

---
paths:
  - "src/**"
---

Use this before editing game code in `src/**`, then also load the more specific
rule for `src/gameplay/**`, `src/core/**`, `src/ai/**`, `src/networking/**`, or
`src/ui/**` when applicable.

## Code-Turn Discipline

1. Identify the behavior, owner node or resource, and smallest implementation
   surface before editing.
2. Define verifiable success: name the test, scene run, or manual check that
   proves the change.
3. Prefer idiomatic engine and language patterns already used in the repo.
4. Avoid unrelated refactors.

## Engine Version

The pinned engine may be newer than model training data. Check
`docs/engine-reference/` before using engine APIs.

## Coding Standards

- Public APIs require doc comments.
- Gameplay values must be data-driven, not hardcoded.
- Prefer dependency injection over singletons for testability.
- New systems need a corresponding ADR in `docs/architecture/`.
- Source changes should reference the relevant story or design document when one
  exists.

Tests live in `tests/`, not `src/`. Run `/test-setup` to scaffold the test
framework if it does not exist yet.
