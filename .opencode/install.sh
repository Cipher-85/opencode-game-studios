#!/usr/bin/env bash
# install.sh — OpenCode Game Studios installer with model tier injection
#
# Usage:
#   bash .opencode/install.sh                              # interactive
#   bash .opencode/install.sh --tier-opus MODEL [...]      # CLI
#   bash .opencode/install.sh --dry-run                    # preview only
#   bash .opencode/install.sh /path/to/target              # deploy to target
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_root="$(cd "$script_dir/.." && pwd -P)"

source "$script_dir/lib/models.sh"
source "$script_dir/lib/coexistence.sh"

# ── Parse arguments ──────────────────────────────────────────────
dry_run=0
target_arg=""
opus_model=""
sonnet_model=""
haiku_model=""
primary_model=""
opus_variant=""
sonnet_variant=""
haiku_variant=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --tier-opus)         opus_model="${2:-}";   shift 2 ;;
    --tier-sonnet)       sonnet_model="${2:-}"; shift 2 ;;
    --tier-haiku)        haiku_model="${2:-}";  shift 2 ;;
    --primary)           primary_model="${2:-}"; shift 2 ;;
    --variant-opus)      opus_variant="${2:-}";      shift 2 ;;
    --variant-sonnet)    sonnet_variant="${2:-}";    shift 2 ;;
    --variant-haiku)     haiku_variant="${2:-}";     shift 2 ;;
    --variants)          opus_variant="${2:-}"; sonnet_variant="${3:-}"; haiku_variant="${4:-}"; shift 4 ;;
    -*) printf 'install: unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) target_arg="$1"; shift ;;
  esac
done

target_root="$(cd "${target_arg:-$PWD}" && pwd -P)"
interactive=0

# If no tier models provided via CLI, go interactive
if [ -z "$opus_model" ] && [ -z "$sonnet_model" ] && [ -z "$haiku_model" ]; then
  interactive=1
fi

# ── Coexistence detection ────────────────────────────────────────
install_mode="$(ccgs_detect_mode)"
ccgs_print_mode_summary "$install_mode" >&2

# Safety: warn for non-empty non-CCGS target
if [ -n "${target_arg:-}" ] && [ "$install_mode" = "opencode_clean" ]; then
  if [ -d "$target_root" ] && [ -n "$(ls -A "$target_root" 2>/dev/null)" ]; then
    if [ ! -f "$target_root/.opencode/install-state.json" ]; then
      printf 'WARNING: Target %s is not empty and has no prior OpenCode Game Studios install.\n' "$target_root" >&2
      printf 'The installer will deploy alongside existing content.\n\n' >&2
      if [ "$dry_run" -eq 0 ]; then
        printf 'Continue? [y/N] ' >&2
        read -r response || response="n"
        case "$response" in
          y|Y|yes|YES) ;;
          *) printf 'Aborted.\n'; exit 1 ;;
        esac
      fi
    fi
  fi
fi

# ── Welcome ──────────────────────────────────────────────────────
cat << 'BANNER'
╔══════════════════════════════════════════════════════════════╗
║         OpenCode Game Studios — Model Configuration          ║
╠══════════════════════════════════════════════════════════════╣
║  This template is model-agnostic. You'll choose a model for  ║
║  each tier. Models use the format provider/model-id.         ║
║                                                              ║
║  Run 'opencode models' to see available models.              ║
╚══════════════════════════════════════════════════════════════╝
BANNER

# ── Interactive prompts ──────────────────────────────────────────
if [ "$interactive" -eq 1 ]; then
  printf '\n'

  printf 'Tier 1 — Directors (3 agents: creative-director, technical-director, producer)\n'
  printf '  These handle strategic decisions, conflict resolution, and vision.\n'
  while true; do
    printf '  Model: '
    read -r opus_model </dev/tty || true
    [ -n "$opus_model" ] && break
    printf '  Please enter a model ID.\n'
  done
  printf '  Variant (reasoning effort, e.g. max/high/standard — press Enter to skip): '
  read -r opus_variant </dev/tty || true

  printf '\n'
  printf 'Tier 2 — Leads + Specialists (44 agents: game-designer, lead-programmer, etc.)\n'
  printf '  These own domains and do heavy analysis/design/implementation work.\n'
  while true; do
    printf '  Model: '
    read -r sonnet_model </dev/tty || true
    [ -n "$sonnet_model" ] && break
    printf '  Please enter a model ID.\n'
  done
  printf '  Variant (press Enter to skip): '
  read -r sonnet_variant </dev/tty || true

  printf '\n'
  printf 'Tier 3 — Light agents (2: community-manager, devops-engineer)\n'
  printf '  These do focused, lighter tasks. Press Enter to reuse Tier 2 model.\n'
  printf '  Model: '
  read -r haiku_model </dev/tty || true
  [ -z "$haiku_model" ] && haiku_model="$sonnet_model"
  printf '  Variant (press Enter to reuse Tier 2 variant): '
  read -r haiku_variant </dev/tty || true
  [ -z "$haiku_variant" ] && haiku_variant="$sonnet_variant"

  printf '\n'
  printf 'Primary agent (your main build agent). Press Enter to reuse Tier 1.\n'
  printf '  Model: '
  read -r primary_model </dev/tty || true
  [ -z "$primary_model" ] && primary_model="$opus_model"
fi

# Default primary to opus tier if not set
[ -z "$primary_model" ] && primary_model="$opus_model"

# ── Validate models ──────────────────────────────────────────────
printf '\n── Validating models ──────────────────────────────────────\n'

validation_failed=0
for tier in opus sonnet haiku; do
  eval "model=\"\${${tier}_model:-}\""
  [ -z "$model" ] && continue

  printf '  Checking %-8s %s ... ' "$tier" "$model"
  if ccgs_validate_model "$model"; then
    printf 'OK\n'
  else
    rc=$?
    if [ "$rc" -eq 2 ]; then
      printf 'SKIP (opencode models not available)\n'
    else
      printf 'NOT FOUND\n'
      printf '  ERROR: model "%s" not found in opencode models output\n' "$model" >&2
      printf '  Run: opencode models\n' >&2
      validation_failed=1
    fi
  fi
done

if [ "$validation_failed" -eq 1 ]; then
  printf '\nModel validation failed. Fix the model IDs and re-run.\n' >&2
  exit 1
fi

# ── Dry-run stop ─────────────────────────────────────────────────
if [ "$dry_run" -eq 1 ]; then
  printf '\n── Dry Run Summary ────────────────────────────────────────\n'
  printf '  Mode:   %s\n' "$install_mode"
  printf '  Tier 1 (opus):   %s [%s]\n' "$opus_model" "$opus_variant"
  printf '  Tier 2 (sonnet): %s [%s]\n' "$sonnet_model" "$sonnet_variant"
  printf '  Tier 3 (haiku):  %s [%s]\n' "$haiku_model" "$haiku_variant"
  printf '  Primary:         %s\n' "$primary_model"
  printf '\n(dry-run — no changes made)\n'
  exit 0
fi

# ── Deploy assets if target differs from source ──────────────────
if [ "$source_root" != "$target_root" ]; then
  printf '\n── Deploying assets to %s ──────────────────────────────\n' "$target_root"

  manifest="$source_root/.opencode/manifest/installed-files.json"
  if [ ! -f "$manifest" ]; then
    printf 'ERROR: manifest not found at %s\n' "$manifest" >&2
    exit 1
  fi

  # Temp files for tracking preserved/created shared paths
  preserved_file="$(mktemp "${TMPDIR:-/tmp}/ccgs-preserved.XXXXXX")"
  created_file="$(mktemp "${TMPDIR:-/tmp}/ccgs-created.XXXXXX")"
  trap 'rm -f "$preserved_file" "$created_file"' EXIT

  # Per-file deploy with coexistence guards
  python3 -c "
import json, os, shutil, re, sys, hashlib

source = '$source_root'
target = '$target_root'
mode = '$install_mode'
manifest_path = '$manifest'
preserved_path = '$preserved_file'
created_path = '$created_file'
dry_run = 0

marker_start = '$ccgs_marker_start'
marker_end = '$ccgs_marker_end'

FOREIGN_PATTERNS = [
    re.compile(r'^\\.claude/'), re.compile(r'^CLAUDE\\.md$'),
    re.compile(r'/\\.claude/'), re.compile(r'/CLAUDE\\.md$'),
    re.compile(r'^\\.codex/'), re.compile(r'/\\.codex/'),
    re.compile(r'^\\.agents/'), re.compile(r'/\\.agents/'),
]

SHARED_PREFIXES = [
    'CCGS Skill Testing Framework/',
    'docs/WORKFLOW-GUIDE.md',
    'docs/COLLABORATIVE-DESIGN-PRINCIPLE.md',
    'docs/engine-reference/',
    'docs/architecture/',
    'docs/examples/',
    'docs/registry/',
    'design/registry/',
    'design/AGENTS.md',
    'design/gdd/systems-index.md',
    'production/session-state/',
    'production/sprints/',
    'production/epics/',
    'src/.gitkeep',
]

def is_foreign(path):
    return any(p.search(path) for p in FOREIGN_PATTERNS)

def is_shared(path):
    return any(path == s or path.startswith(s) for s in SHARED_PREFIXES)

def is_coexist_mode(m):
    return m in ('claude_ccgs_coexist', 'codex_ccgs_coexist', 'multi_runtime')

with open(manifest_path) as f:
    data = json.load(f)

import filecmp

copied = 0
skipped_foreign = 0
preserved = 0
marker_files = 0

preserved_list = []
created_list = []

for entry in data.get('files', []):
    rel = entry['path']
    mode_flag = entry.get('mode', 'copy')
    src = os.path.join(source, rel)
    dst = os.path.join(target, rel)

    if not os.path.exists(src):
        continue

    # Hard guard: refuse foreign-runtime paths
    if is_foreign(rel):
        print(f'  REFUSED (foreign): {rel}', file=sys.stderr)
        skipped_foreign += 1
        continue

    # Coexistence: preserve shared paths that already exist
    if is_coexist_mode(mode) and is_shared(rel) and os.path.exists(dst):
        preserved_list.append(rel)
        preserved += 1
        continue

    os.makedirs(os.path.dirname(dst), exist_ok=True)

    if mode_flag == 'marker':
        # Marker-block splice
        if os.path.isfile(dst) and marker_start in open(dst).read():
            with open(src) as f:
                src_txt = f.read()
            with open(dst) as f:
                dst_txt = f.read()
            m = re.search(r'(' + re.escape(marker_start) + r'.*?' + re.escape(marker_end) + r')', src_txt, re.S)
            if m:
                dst_txt = re.sub(
                    re.escape(marker_start) + r'.*?' + re.escape(marker_end),
                    m.group(1), dst_txt, flags=re.S
                )
                with open(dst, 'w') as f:
                    f.write(dst_txt)
            marker_files += 1
        elif os.path.isfile(dst):
            with open(src) as f:
                src_txt = f.read()
            m = re.search(r'(' + re.escape(marker_start) + r'.*?' + re.escape(marker_end) + r')', src_txt, re.S)
            if m:
                with open(dst, 'a') as f:
                    f.write('\n' + m.group(1) + '\n')
            marker_files += 1
        else:
            shutil.copy2(src, dst)
            copied += 1
            if is_shared(rel):
                created_list.append(rel)
    elif rel == 'opencode.json':
        if not os.path.exists(dst):
            shutil.copy2(src, dst)
            copied += 1
    else:
        # Standard copy with backup-if-differs
        if os.path.isfile(dst) and not filecmp.cmp(src, dst, shallow=False):
            backup_path = os.path.join(
                target, '.opencode', 'backups',
                __import__('datetime').datetime.now(__import__('datetime').timezone.utc).strftime('%Y%m%dT%H%M%SZ'),
                rel
            )
            os.makedirs(os.path.dirname(backup_path), exist_ok=True)
            shutil.copy2(dst, backup_path)
        shutil.copy2(src, dst)
        copied += 1
        if is_shared(rel):
            created_list.append(rel)

# Write preserved/created lists
with open(preserved_path, 'w') as f:
    for p in sorted(set(preserved_list)):
        f.write(p + '\n')
with open(created_path, 'w') as f:
    for p in sorted(set(created_list)):
        f.write(p + '\n')

print(f'  Copied: {copied} | Marker-spliced: {marker_files} | Preserved (shared): {preserved} | Refused (foreign): {skipped_foreign}')
" 2>&1

  # Update .gitignore allowlist at target
  ccgs_update_gitignore_allowlist "$target_root"

  printf '  Assets deployed.\n'
fi

# ── Configure models ─────────────────────────────────────────────
printf '\n── Configuring agents ─────────────────────────────────────\n'

ccgs_inject_all_agents "$target_root" "$opus_model" "$sonnet_model" "$haiku_model" \
  "$opus_variant" "$sonnet_variant" "$haiku_variant"

printf '\n── Setting primary model ──────────────────────────────────\n'
ccgs_set_primary_model "$target_root" "$primary_model"
printf '  opencode.json → model: %s\n' "$primary_model"

# ── Write models config ──────────────────────────────────────────
ccgs_write_models_config "$target_root" \
  "$opus_model" "$sonnet_model" "$haiku_model" "$primary_model"
printf '  .opencode/models.json written.\n'

# ── Write install state (schema v2 with SHA256) ──────────────────
ccgs_write_install_state "$target_root" "$source_root" "$install_mode" "full" \
  "$opus_model" "$sonnet_model" "$haiku_model" "$primary_model" \
  "$opus_variant" "$sonnet_variant" "$haiku_variant" \
  "$preserved_file" "$created_file"

printf '  install-state.json written (schema v2).\n'

# ── Done ─────────────────────────────────────────────────────────
printf '\n╔══════════════════════════════════════════════════════════════╗\n'
printf '║  Setup complete!                                            ║\n'
printf '║                                                              ║\n'
printf '║  Run: opencode                                               ║\n'
printf '║  Then: /start                                                ║\n'
printf '╚══════════════════════════════════════════════════════════════╝\n'
