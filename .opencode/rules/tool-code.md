# Tool Code Rules

---
paths:
  - "tools/**"
---

## Code-Turn Discipline

1. Identify the tool contract, inputs, outputs, and failure modes before
   changing implementation.
2. Choose the narrowest command or fixture that proves the tool still works.
3. Prefer explicit parsing, clear errors, and standard library behavior.
4. Preserve existing CLI flags, output shape, and exit-code semantics.

## Tool Standards

- Tools must be deterministic and safe to run repeatedly.
- Prefer structured parsers over ad hoc string splitting when a format has a
  standard parser.
- Print actionable error messages and return non-zero on failure.
- Do not reach outside the workspace unless the user explicitly asks and the
  command is approved.
- Add or update focused tests when behavior changes.
