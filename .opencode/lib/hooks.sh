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
