# Design Directory Rules

---
paths:
  - "design/**"
---

Use this before authoring or editing design files outside more specific rules.

## GDD Files

Every GDD in `design/gdd/` must include all eight required sections in this
order:

1. Overview
2. Player Fantasy
3. Detailed Rules
4. Formulas
5. Edge Cases
6. Dependencies
7. Tuning Knobs
8. Acceptance Criteria

- File naming: `[system-slug].md`, such as `movement-system.md`.
- Update `design/gdd/systems-index.md` when adding a new GDD.
- Design order is Foundation, Core, Feature, Presentation, Polish.
- Run `$design-review [path]` after authoring any GDD.
- Run `$review-all-gdds` after completing related GDDs.

## Quick Specs

Use `design/quick-specs/` for tuning changes, minor mechanics, or balance
adjustments. Author through `$quick-design`.

## UX Specs

- Per-screen specs: `design/ux/[screen-name].md`
- HUD design: `design/ux/hud.md`
- Interaction patterns: `design/ux/interaction-patterns.md`
- Accessibility requirements: `design/ux/accessibility-requirements.md`

Use `$ux-design` to author. Validate with `$ux-review` before passing to
`$team-ui`.
