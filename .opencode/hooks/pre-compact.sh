#!/bin/bash
# OpenCode PreCompact hook: Dump session state before context compression
# This output appears in the conversation right before compaction, ensuring
# critical state survives the summarization process.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../lib/hooks.sh
source "$script_dir/../lib/hooks.sh"
ccgs_root="$(ccgs_find_root || pwd -P)"

echo "=== SESSION STATE BEFORE COMPACTION ==="
echo "Timestamp: $(date)"

# --- Active session state file (with canonical handoff fallback) ---
STATE_FILE="$ccgs_root/production/session-state/active.md"
HANDOFF_FILE="$ccgs_root/production/session-handoff.md"
STATE_KIND="$(ccgs_active_state_kind "$STATE_FILE")"

if [ "$STATE_KIND" = "substantive" ]; then
    echo ""
    echo "## Active Session State (from production/session-state/active.md)"
    ccgs_preview_bounded "$STATE_FILE" 100
    if [ -f "$HANDOFF_FILE" ]; then
        echo ""
        echo "## Canonical Handoff Fallback"
        ccgs_preview_bounded "$HANDOFF_FILE" 60
    fi
else
    if [ -f "$HANDOFF_FILE" ]; then
        echo ""
        echo "## Canonical Handoff Recovery (elevated)"
        ccgs_preview_bounded "$HANDOFF_FILE" 60
    else
        echo ""
        echo "## No canonical handoff found"
        echo "Consider maintaining production/session-handoff.md via /handoff for better recovery."
    fi
    if [ "$STATE_KIND" = "pointer" ]; then
        echo ""
        echo "## Pointer-Only Active State"
        ccgs_preview_bounded "$STATE_FILE" 20
    else
        echo "No active session state file found."
    fi
fi

# --- Files modified this session (unstaged + staged + untracked) ---
echo ""
echo "## Files Modified (git working tree)"

CHANGED=$(git diff --name-only 2>/dev/null)
STAGED=$(git diff --staged --name-only 2>/dev/null)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)

if [ -n "$CHANGED" ]; then
    echo "Unstaged changes:"
    echo "$CHANGED" | while read -r f; do echo "  - $f"; done
fi
if [ -n "$STAGED" ]; then
    echo "Staged changes:"
    echo "$STAGED" | while read -r f; do echo "  - $f"; done
fi
if [ -n "$UNTRACKED" ]; then
    echo "New untracked files:"
    echo "$UNTRACKED" | while read -r f; do echo "  - $f"; done
fi
if [ -z "$CHANGED" ] && [ -z "$STAGED" ] && [ -z "$UNTRACKED" ]; then
    echo "  (no uncommitted changes)"
fi

# --- Work-in-progress design docs ---
echo ""
echo "## Design Docs — Work In Progress"

WIP_FOUND=false
for f in design/gdd/*.md; do
    [ -f "$f" ] || continue
    INCOMPLETE=$(grep -n -E "TODO|WIP|PLACEHOLDER|\[TO BE|\[TBD\]" "$f" 2>/dev/null)
    if [ -n "$INCOMPLETE" ]; then
        WIP_FOUND=true
        echo "  $f:"
        echo "$INCOMPLETE" | while read -r line; do echo "    $line"; done
    fi
done

if [ "$WIP_FOUND" = false ]; then
    echo "  (no WIP markers found in design docs)"
fi

# --- Log compaction event ---
SESSION_LOG_DIR="production/session-logs"
mkdir -p "$SESSION_LOG_DIR" 2>/dev/null
echo "Context compaction occurred at $(date)." \
    >> "$SESSION_LOG_DIR/compaction-log.txt" 2>/dev/null

echo ""
echo "## Recovery Instructions"
echo "After compaction, read substantive production/session-state/active.md first."
echo "Use production/session-handoff.md as the canonical fallback; elevate it when active.md is missing or pointer-only."
echo "Then read any files listed above that are being actively worked on."
echo "=== END SESSION STATE ==="

exit 0
