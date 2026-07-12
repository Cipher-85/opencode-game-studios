#!/usr/bin/env bash
# uninstall.sh — Remove OpenCode Game Studios
#
# Coexistence-aware removal:
# - Strips model/variant from agents
# - Removes only OpenCode-owned files (preserves shared paths in coexistence mode)
# - Removes marker block from AGENTS.md (preserves user content)
# - Backs up modified files before removal
# - Cleans .gitignore allowlist
#
# Usage:
#   bash .opencode/uninstall.sh                # uninstall from current dir
#   bash .opencode/uninstall.sh --dry-run      # preview only
#   bash .opencode/uninstall.sh /path/to/target
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$script_dir/lib/models.sh"
source "$script_dir/lib/coexistence.sh"

dry_run=0
target_arg=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    -*) printf 'uninstall: unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) target_arg="$1"; shift ;;
  esac
done

target_root="$(cd "${target_arg:-$PWD}" && pwd -P)"
source_root="$(cd "$script_dir/.." && pwd -P)"

# ── Detect mode ──────────────────────────────────────────────────
install_mode="$(ccgs_detect_mode)"
printf '── OpenCode Game Studios Uninstall ──\n\n'
ccgs_print_mode_summary "$install_mode"

# ── Read install state for file list (fail-closed) ───────────────
state_file="$target_root/.opencode/install-state.json"

paths_file="$(mktemp "${TMPDIR:-/tmp}/ccgs-uninstall-paths.XXXXXX")"
trap 'rm -f "$paths_file"' EXIT

# Fail-closed: uninstall requires valid install-state ownership data.
# Missing, stale, malformed, path-traversing, or symlinked state aborts
# without removing project files. Never infer ownership from the source
# manifest or from file contents.
if ccgs_state_validate "$target_root"; then
  ccgs_state_owned_paths "$target_root" > "$paths_file"
else
  rc=$?
  reason="invalid"
  [ "$rc" -eq 2 ] && reason="missing"
  printf '\nERROR: cannot uninstall safely — install-state is %s.\n' "$reason" >&2
  printf 'Uninstall requires valid .opencode/install-state.json ownership data.\n' >&2
  printf 'Restore it from .opencode/backups/ or resolve ownership manually.\n' >&2
  printf 'No files were changed.\n' >&2
  exit 1
fi

if [ ! -s "$paths_file" ]; then
  printf 'install-state valid but records no owned files — nothing to remove.\n'
  printf 'No files were changed.\n'
  exit 0
fi

# ── Read shared-path tracking from install state ─────────────────
preserved_by_us=""
if [ -f "$state_file" ]; then
  preserved_by_us="$(python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
for p in state.get('shared_paths_created', []):
    print(p)
" 2>/dev/null)"
fi

# ── Dry-run summary ──────────────────────────────────────────────
if [ "$dry_run" -eq 1 ]; then
  printf '\nDRY RUN — no changes will be made.\n\n'
  total=$(wc -l < "$paths_file" | tr -d ' ')
  printf 'Would process %s files:\n' "$total"
  printf '  - Strip model/variant from agents\n'
  printf '  - Remove OpenCode-owned files (preserve shared in coexistence)\n'
  printf '  - Remove marker block from AGENTS.md\n'
  printf '  - Clean .gitignore allowlist\n'
  printf '  - Remove install-state.json, models.json\n'
  exit 0
fi

# ── Strip models from agents ─────────────────────────────────────
printf '\nStripping model configuration from agents...\n'
ccgs_strip_all_agents "$target_root"

# ── Remove primary model from opencode.json ──────────────────────
printf 'Removing primary model from opencode.json...\n'
ccgs_remove_primary_model "$target_root"

# ── Remove deployed files (coexistence-aware) ────────────────────
printf 'Removing deployed files...\n'

is_coexist() {
  case "$install_mode" in
    claude_ccgs_coexist|codex_ccgs_coexist|multi_runtime) return 0 ;;
    *) return 1 ;;
  esac
}

# Check if we created this shared path (from install state)
we_created() {
  local path="$1"
  if [ -n "$preserved_by_us" ]; then
    echo "$preserved_by_us" | grep -qxF "$path"
    return $?
  fi
  return 1  # assume we didn't create it if no state
}

removed=0
preserved=0

# Process files in reverse order (deepest first for dir pruning)
while IFS= read -r path; do
  ccgs_refuse_foreign_path "$path"

  target_file="$target_root/$path"
  [ -e "$target_file" ] || continue

  # Coexistence: preserve shared paths we didn't create
  if is_coexist && ccgs_is_shared_path "$path" && ! we_created "$path"; then
    preserved=$((preserved + 1))
    continue
  fi

  case "$path" in
    AGENTS.md|*/AGENTS.md)
      # Remove our marker block only. ccgs_remove_marker_block deletes the
      # file solely when its pre-strip content was nothing but the marker
      # block; it keeps any user-authored content and never uses emptiness
      # or file contents as ownership proof.
      ccgs_remove_marker_block "$target_file" 2>/dev/null || true
      ;;
    opencode.json)
      # Don't remove opencode.json (user may have other config)
      ;;
    *)
      # Backup if modified from source before removal
      source_file="$source_root/$path"
      if [ -f "$source_file" ] && ! cmp -s "$source_file" "$target_file"; then
        ccgs_backup_file "$path" "$target_root"
      fi
      rm -f "$target_file"
      ;;
  esac
  removed=$((removed + 1))
done < <(sort -r "$paths_file")

printf '  Removed: %d | Preserved (shared): %d\n' "$removed" "$preserved"

# ── Remove generated files ───────────────────────────────────────
for f in .opencode/models.json .opencode/install-state.json; do
  if [ -f "$target_root/$f" ]; then
    rm "$target_root/$f"
    printf '  Removed %s\n' "$f"
  fi
done

# ── Clean .gitignore allowlist ───────────────────────────────────
ccgs_remove_gitignore_allowlist "$target_root" 2>/dev/null || true

# ── Prune empty OpenCode-owned directories ───────────────────────
# Pruning is limited to the OpenCode runtime directory (.opencode/).
# Shared content roots (design/, docs/, production/, src/, assets/, tests/,
# tools/, "CCGS Skill Testing Framework/") are never deleted even when empty
# — emptiness is not ownership proof and they may be user scaffolds.
if [ -d "$target_root/.opencode" ]; then
  find "$target_root/.opencode" -depth -type d -empty -delete 2>/dev/null || true
fi

printf '\nDone. OpenCode Game Studios removed.\n'
if [ "$preserved" -gt 0 ]; then
  printf '%d shared paths preserved (coexistence mode).\n' "$preserved"
fi
