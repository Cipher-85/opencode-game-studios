#!/bin/bash
# OpenCode SessionStart hook: Load project context at session start
# Outputs context information that Claude sees when a session begins
#
# Input schema (SessionStart): No stdin input

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../lib/hooks.sh
source "$script_dir/../lib/hooks.sh"
ccgs_root="$(ccgs_find_root || pwd -P)"

echo "=== OpenCode Game Studios — Session Context ==="

# Current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Per-session review baseline (gitignored) consumed by the /handoff scope proof
START_HEAD=$(git -C "$ccgs_root" rev-parse HEAD 2>/dev/null || true)
STARTED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
mkdir -p "$ccgs_root/production/session-logs" 2>/dev/null || true
ccgs_write_session_baseline "$BRANCH" "$START_HEAD" "$STARTED_AT" \
    "$ccgs_root/production/session-logs/session-baseline.json"

if [ -n "$BRANCH" ]; then
    echo "Branch: $BRANCH"

    # Recent commits
    echo ""
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "  $line"
    done
fi

# Current sprint (find most recent sprint file)
LATEST_SPRINT=$(ls -t production/sprints/sprint-*.md 2>/dev/null | head -1)
if [ -n "$LATEST_SPRINT" ]; then
    echo ""
    echo "Active sprint: $(basename "$LATEST_SPRINT" .md)"
fi

# Current milestone
LATEST_MILESTONE=$(ls -t production/milestones/*.md 2>/dev/null | head -1)
if [ -n "$LATEST_MILESTONE" ]; then
    echo "Active milestone: $(basename "$LATEST_MILESTONE" .md)"
fi

# Open bug count
BUG_COUNT=0
for dir in tests/playtest production; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "BUG-*.md" 2>/dev/null | wc -l)
        BUG_COUNT=$((BUG_COUNT + count))
    fi
done
if [ "$BUG_COUNT" -gt 0 ]; then
    echo "Open bugs: $BUG_COUNT"
fi

# Code health quick check
if [ -d "src" ]; then
    TODO_COUNT=$(grep -r "TODO" src/ 2>/dev/null | wc -l)
    FIXME_COUNT=$(grep -r "FIXME" src/ 2>/dev/null | wc -l)
    if [ "$TODO_COUNT" -gt 0 ] || [ "$FIXME_COUNT" -gt 0 ]; then
        echo ""
        echo "Code health: ${TODO_COUNT} TODOs, ${FIXME_COUNT} FIXMEs in src/"
    fi
fi

# --- Canonical handoff + active session state recovery ---
HANDOFF_FILE="$ccgs_root/production/session-handoff.md"
STATE_FILE="$ccgs_root/production/session-state/active.md"
STATE_KIND="$(ccgs_active_state_kind "$STATE_FILE")"

if [ -f "$HANDOFF_FILE" ]; then
    echo ""
    echo "=== CANONICAL HANDOFF DETECTED ==="
    echo "Bounded preview of production/session-handoff.md:"
    ccgs_preview_bounded "$HANDOFF_FILE" 60
    echo "Run /resume-from-handoff to compile a fresh session worklist before selecting a lane."
    echo "=== END CANONICAL HANDOFF PREVIEW ==="
fi

if [ "$STATE_KIND" = "substantive" ]; then
    echo ""
    echo "=== ACTIVE SESSION STATE DETECTED ==="
    echo "A previous session left state at: production/session-state/active.md"
    echo "The canonical handoff above outranks this same-session cache when both exist."
    echo ""
    echo "Bounded active-state preview:"
    ccgs_preview_bounded "$STATE_FILE" 60
    echo "=== END SESSION STATE PREVIEW ==="
elif [ "$STATE_KIND" = "pointer" ]; then
    echo ""
    echo "=== POINTER-ONLY ACTIVE STATE DETECTED ==="
    echo "production/session-state/active.md is not a substantive worklist; use the canonical handoff."
    ccgs_preview_bounded "$STATE_FILE" 20
    echo "=== END POINTER STATE PREVIEW ==="
fi

echo "==================================="
exit 0
