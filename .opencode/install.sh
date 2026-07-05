#!/usr/bin/env bash
# install.sh — OpenCode Game Studios installer with model tier injection
#
# Usage:
#   bash .opencode/install.sh                              # interactive
#   bash .opencode/install.sh --tier-opus MODEL [...]                      # CLI
#   bash .opencode/install.sh --dry-run                    # preview only
#   bash .opencode/install.sh /path/to/target              # deploy to target
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_root="$(cd "$script_dir/.." && pwd -P)"

# Source model injection library
source "$script_dir/lib/models.sh"

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
    --variants)          opus_variant="${2:-}"; sonnet_variant="${3:-}"; haiku_variant="${4:-}"; shift 3 ;;
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
  printf '  Tier 1 (opus):   %s\n' "$opus_model"
  printf '  Tier 2 (sonnet): %s\n' "$sonnet_model"
  printf '  Tier 3 (haiku):  %s\n' "$haiku_model"
  printf '  Primary:         %s\n' "$primary_model"
  printf '\n(dry-run — no changes made)\n'
  exit 0
fi

# ── Deploy assets if target differs from source ──────────────────
if [ "$source_root" != "$target_root" ]; then
  printf '\n── Deploying assets to %s ──────────────────────────────\n' "$target_root"

  # Core directories
  for dir in .opencode/agents .opencode/skills .opencode/commands \
             .opencode/hooks .opencode/plugins .opencode/docs \
             .opencode/rules .opencode/agent-memory .opencode/lib; do
    if [ -d "$source_root/$dir" ]; then
      mkdir -p "$target_root/$dir"
      cp -R "$source_root/$dir/"* "$target_root/$dir/" 2>/dev/null || true
    fi
  done

  # AGENTS.md — marker-block splice (preserve user content)
  if [ -f "$target_root/AGENTS.md" ] && grep -q '<!-- BEGIN CCGS OPENCODE PORT -->' "$target_root/AGENTS.md" 2>/dev/null; then
    # Target has the marker block — replace just the block, preserve user content
    python3 -c "
import re
with open('$source_root/AGENTS.md') as f:
    src = f.read()
with open('$target_root/AGENTS.md') as f:
    dst = f.read()

src_block = re.search(r'(<!-- BEGIN CCGS OPENCODE PORT -->.*?<!-- END CCGS OPENCODE PORT -->)', src, re.S)
if src_block:
    dst = re.sub(
        r'<!-- BEGIN CCGS OPENCODE PORT -->.*?<!-- END CCGS OPENCODE PORT -->',
        src_block.group(1),
        dst, flags=re.S
    )
    with open('$target_root/AGENTS.md', 'w') as f:
        f.write(dst)
    print('  AGENTS.md: marker block updated (user content preserved)')
else:
    print('  AGENTS.md: no source marker block found — skipped')
" 2>/dev/null
    printf '  AGENTS.md: marker block updated (user content preserved)\n'
  elif [ -f "$target_root/AGENTS.md" ]; then
    # Target has AGENTS.md but no marker block — append the block
    src_block="$(python3 -c "
import re
with open('$source_root/AGENTS.md') as f:
    src = f.read()
m = re.search(r'(<!-- BEGIN CCGS OPENCODE PORT -->.*?<!-- END CCGS OPENCODE PORT -->)', src, re.S)
print(m.group(1) if m else '')
" 2>/dev/null)"
    if [ -n "$src_block" ]; then
      printf '\n%s\n' "$src_block" >> "$target_root/AGENTS.md"
      printf '  AGENTS.md: marker block appended (existing content preserved)\n'
    fi
  else
    # No target AGENTS.md — copy the full file
    cp "$source_root/AGENTS.md" "$target_root/AGENTS.md"
    printf '  AGENTS.md: copied (new file)\n'
  fi

  # opencode.json — merge plugin + instructions into existing if present
  if [ -f "$target_root/opencode.json" ]; then
    printf '  opencode.json: target already exists — not overwritten (merge manually)\n'
  else
    cp "$source_root/opencode.json" "$target_root/opencode.json"
    printf '  opencode.json: copied (new file)\n'
  fi

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

# ── Write install state ──────────────────────────────────────────
cat > "$target_root/.opencode/install-state.json" << EOF
{
  "version": 1,
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source_root": "$source_root",
  "models": {
    "opus": "$opus_model",
    "sonnet": "$sonnet_model",
    "haiku": "$haiku_model",
    "primary": "$primary_model"
  },
  "variants": {
    "opus": "$opus_variant",
    "sonnet": "$sonnet_variant",
    "haiku": "$haiku_variant"
  }
}
EOF

# ── Done ─────────────────────────────────────────────────────────
printf '\n╔══════════════════════════════════════════════════════════════╗\n'
printf '║  Setup complete!                                            ║\n'
printf '║                                                              ║\n'
printf '║  Run: opencode                                               ║\n'
printf '║  Then: /start                                                ║\n'
printf '╚══════════════════════════════════════════════════════════════╝\n'
