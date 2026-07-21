#!/usr/bin/env bash
# lib/hooks.sh — Shared helpers for OpenCode Game Studios hook scripts
#
# Provides root discovery, JSON field extraction, payload path parsing,
# and standardized output helpers. Hook scripts source this via:
#
#   source "$(dirname "$0")/../lib/hooks.sh"

# ── Root discovery ───────────────────────────────────────────────

ccgs_find_root() {
  if [ -n "${CCGS_ROOT:-}" ]; then
    printf '%s\n' "$CCGS_ROOT"
    return 0
  fi
  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$git_root" ] && [ -d "$git_root/.opencode" ]; then
    printf '%s\n' "$git_root"
    return 0
  fi
  local d
  d="$(pwd -P)"
  while [ "$d" != "/" ]; do
    if [ -d "$d/.opencode" ]; then
      printf '%s\n' "$d"
      return 0
    fi
    d="$(cd "$d/.." && pwd -P)"
  done
  return 1
}

# ── JSON field extraction (jq with Python fallback) ─────────────

ccgs_json_field() {
  local input="$1" field="$2"
  if command -v jq >/dev/null 2>&1; then
    echo "$input" | jq -r "$field // empty" 2>/dev/null
  else
    echo "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    parts = '$field'.lstrip('.').split('.')
    val = data
    for p in parts:
        if isinstance(val, dict):
            val = val.get(p, '')
        else:
            val = ''
            break
    print(val if val else '')
except:
    print('')
" 2>/dev/null
  fi
}

# ── Extract file paths from tool payloads ───────────────────────
# Handles current OpenCode JSON payloads and legacy apply_patch formats.
# Reads JSON from stdin, prints extracted file paths (one per line).

ccgs_payload_paths() {
  local input
  input="$(cat)"

  # Try JSON field extraction first
  local file_path
  file_path="$(ccgs_json_field "$input" '.tool_input.file_path')"
  if [ -n "$file_path" ]; then
    echo "$file_path" | sed 's|\\|/|g'
    return 0
  fi

  # Try legacy apply_patch raw text format: *** Add/Update/Delete File: <path>
  echo "$input" | grep -oE '^\*\*\* (Add|Update|Delete) File: .+' 2>/dev/null \
    | sed 's|^\*\*\* \(Add\|Update\|Delete\) File: ||' \
    | sed 's|\\|/|g' \
    | while IFS= read -r line; do
        [ -n "$line" ] && [ "$line" != "/dev/null" ] && echo "$line"
      done
}

# ── Git subcommand detection ────────────────────────────────────
# Returns 0 if the input command is a git subcommand matching $1.

ccgs_is_git_subcommand() {
  local subcmd="$1"
  local input command_line
  input="$(cat)"
  command_line="$(ccgs_json_field "$input" '.tool_input.command')"
  echo "$command_line" | grep -qE "^git[[:space:]]+${subcmd}" 2>/dev/null
}

# ── Python discovery ────────────────────────────────────────────

ccgs_first_python() {
  for cmd in python3 python py; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%s\n' "$cmd"
      return 0
    fi
  done
  return 1
}

# ── Session review baseline ───────────────────────────────────
# Writes the gitignored per-session review-scope anchor consumed by the
# /handoff Prove The Review Scope check. Never fails the hook.

ccgs_write_session_baseline() {
  local branch="$1"
  local start_head="$2"
  local started_at="$3"
  local output="$4"
  local python_cmd
  python_cmd="$(ccgs_first_python || true)"
  if [ -z "$python_cmd" ]; then
    printf 'WARNING: Python not found; session review baseline was not recorded.\n' >&2
    return 0
  fi
  "$python_cmd" - "$branch" "$start_head" "$started_at" "$output" <<'PY'
import json
import sys
from pathlib import Path

branch, start_head, started_at, output = sys.argv[1:]
payload = {
    "schema_version": 1,
    "branch": branch or None,
    "start_head": start_head or None,
    "started_at": started_at,
}
Path(output).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

# ── Active session state classification ───────────────────────
# Prints: missing | pointer | substantive

ccgs_active_state_kind() {
  local state_file="$1"
  if [ ! -f "$state_file" ]; then
    printf 'missing\n'
  elif grep -Eq '^## (Current Focus|Phase Guard|Source Freshness|Session Worklist|Owed Before Starting)' "$state_file" 2>/dev/null; then
    printf 'substantive\n'
  else
    printf 'pointer\n'
  fi
}

# ── Bounded file preview ──────────────────────────────────────
# Full file when within max_lines, else first/last halves with a marker.

ccgs_preview_bounded() {
  local file="$1"
  local max_lines="$2"
  local total_lines
  total_lines="$(wc -l < "$file" 2>/dev/null | tr -d ' ' || echo 0)"
  if [ "${total_lines:-0}" -le "$max_lines" ] 2>/dev/null; then
    cat "$file"
    return
  fi

  local first_lines=$((max_lines / 2))
  local last_lines=$((max_lines - first_lines))
  head -n "$first_lines" "$file"
  echo "... (bounded preview - $total_lines total lines)"
  tail -n "$last_lines" "$file"
}

# ── Output helpers ──────────────────────────────────────────────
# Advisory output goes to stderr (visible but non-blocking).
# Deny output exits with code 2 (blocking).

ccgs_hook_pass() {
  local msg="${1:-OK}"
  printf '%s\n' "$msg" >&2
  exit 0
}

ccgs_hook_warn() {
  local msg="${1:-WARNING}"
  printf '%s\n' "$msg" >&2
  exit 0
}

ccgs_hook_deny() {
  local msg="${1:-BLOCKED}"
  printf '%s\n' "$msg" >&2
  exit 2
}
