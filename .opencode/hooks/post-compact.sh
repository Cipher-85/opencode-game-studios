#!/usr/bin/env bash
# post-compact.sh — fires after conversation compaction
# Restores the active-first/handoff-fallback recovery order after summarization.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../lib/hooks.sh
source "$script_dir/../lib/hooks.sh"
ccgs_root="$(ccgs_find_root || pwd -P)"

ACTIVE="$ccgs_root/production/session-state/active.md"
HANDOFF="$ccgs_root/production/session-handoff.md"
STATE_KIND="$(ccgs_active_state_kind "$ACTIVE")"

echo "=== Context Restored After Compaction ==="

if [ "$STATE_KIND" = "substantive" ]; then
  echo "## Substantive Active Session State"
  ccgs_preview_bounded "$ACTIVE" 80
  if [ -f "$HANDOFF" ]; then
    echo ""
    echo "## Canonical Handoff Fallback"
    ccgs_preview_bounded "$HANDOFF" 60
  fi
else
  if [ -f "$HANDOFF" ]; then
    echo "## Canonical Handoff Recovery (elevated)"
    ccgs_preview_bounded "$HANDOFF" 60
  else
    echo "No canonical handoff found at production/session-handoff.md"
  fi
  if [ "$STATE_KIND" = "pointer" ]; then
    echo ""
    echo "## Pointer-Only Active State"
    ccgs_preview_bounded "$ACTIVE" 20
  else
    echo "No session state file found at production/session-state/active.md"
  fi
fi

echo "========================================="
