#!/usr/bin/env bash
# lib/models.sh — Model tier injection for OpenCode Game Studios
#
# Reads metadata.ccgs_tier from each agent's YAML frontmatter and injects
# the user's chosen model ID into the model: field.
#
# This is a library — the calling script sets shell options (set -euo pipefail).

# ── Globals ──
CCGS_TIERS="opus sonnet haiku"

# --- Helpers ---

ccgs_find_root() {
  local dir="${1:-$PWD}"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.opencode/agents" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(cd "$dir/.." && pwd -P)"
  done
  return 1
}

# Get the value of metadata.ccgs_tier from an agent .md file
# Usage: ccgs_get_agent_tier <agent_file>
ccgs_get_agent_tier() {
  local file="$1"
  python3 -c "
import sys, re, yaml
with open('$file') as f:
    txt = f.read()
m = re.match(r'^---\n(.*?)\n---', txt, re.S)
if not m:
    sys.exit(1)
fm = yaml.safe_load(m.group(1))
meta = fm.get('metadata', {})
tier = meta.get('ccgs_tier', 'sonnet')
print(tier)
" 2>/dev/null
}

# Check if a model: field exists in an agent file
# Usage: ccgs_has_model <agent_file>
ccgs_has_model() {
  local file="$1"
  python3 -c "
import sys, re, yaml
with open('$file') as f:
    txt = f.read()
m = re.match(r'^---\n(.*?)\n---', txt, re.S)
if not m:
    sys.exit(1)
fm = yaml.safe_load(m.group(1))
if fm.get('model'):
    sys.exit(0)
else:
    sys.exit(1)
" 2>/dev/null
}

# Inject or replace model: and reasoningEffort: in an agent file's frontmatter
# Usage: ccgs_inject_model <agent_file> <model_id> [effort]
# Note: reasoningEffort maps to the provider's reasoning_effort API parameter.
# Z.AI/GLM accepts: "max", "high", "low". Other providers may differ.
ccgs_inject_model() {
  local file="$1" model_id="$2" effort="${3:-}"
  python3 -c "
import sys, re, yaml

with open('$file') as f:
    txt = f.read()

m = re.match(r'^(---\n)(.*?)(\n---)', txt, re.S)
if not m:
    print(f'ERROR: no frontmatter in {file}', file=sys.stderr)
    sys.exit(1)

fm = yaml.safe_load(m.group(2))
fm['model'] = '$model_id'
if '$effort':
    fm['reasoningEffort'] = '$effort'
else:
    fm.pop('reasoningEffort', None)
    fm.pop('variant', None)

# Re-dump frontmatter preserving key order
out = yaml.dump(fm, sort_keys=False, default_flow_style=False, allow_unicode=True, width=1000)
result = f'---\n{out}---{txt[m.end():]}'

with open('$file', 'w') as f:
    f.write(result)
" 2>/dev/null
}

# Remove model: from an agent file's frontmatter (restore model-agnostic state)
# Usage: ccgs_strip_model <agent_file>
ccgs_strip_model() {
  local file="$1"
  python3 -c "
import sys, re, yaml

with open('$file') as f:
    txt = f.read()

m = re.match(r'^(---\n)(.*?)(\n---)', txt, re.S)
if not m:
    sys.exit(0)

fm = yaml.safe_load(m.group(2))
changed = False
for key in ('model', 'variant', 'reasoningEffort'):
    if key in fm:
        del fm[key]
        changed = True
if not changed:
    sys.exit(0)

out = yaml.dump(fm, sort_keys=False, default_flow_style=False, allow_unicode=True, width=1000)
result = f'---\n{out}---{txt[m.end():]}'

with open('$file', 'w') as f:
    f.write(result)
" 2>/dev/null
}

# Get available models from opencode
# Usage: ccgs_get_available_models
ccgs_get_available_models() {
  if command -v opencode >/dev/null 2>&1; then
    opencode models 2>/dev/null || true
  elif [ -x "$HOME/.opencode/bin/opencode" ]; then
    "$HOME/.opencode/bin/opencode" models 2>/dev/null || true
  else
    return 1
  fi
}

# Validate a model ID against available models
# Usage: ccgs_validate_model <model_id>
# Returns 0 if valid, 1 if not found, 2 if can't check
ccgs_validate_model() {
  local model_id="$1"
  local available

  if ! available="$(ccgs_get_available_models 2>/dev/null)"; then
    printf 'WARN: cannot run opencode models — skipping validation\n' >&2
    return 2
  fi

  if echo "$available" | grep -qF "$model_id"; then
    return 0
  fi
  return 1
}

# Write the models.json config file
# Usage: ccgs_write_models_config <root> <opus_model> <sonnet_model> <haiku_model> <primary_model>
ccgs_write_models_config() {
  local root="$1" opus="$2" sonnet="$3" haiku="$4" primary="$5"
  cat > "$root/.opencode/models.json" << EOF
{
  "tiers": {
    "opus": "$opus",
    "sonnet": "$sonnet",
    "haiku": "$haiku"
  },
  "primary": "$primary"
}
EOF
}

# Inject models into all agents based on tier
# Usage: ccgs_inject_all_agents <root> <opus_model> <sonnet_model> <haiku_model> [opus_variant] [sonnet_variant] [haiku_variant]
ccgs_inject_all_agents() {
  local root="$1" opus="$2" sonnet="$3" haiku="$4"
  local opus_var="${5:-}" sonnet_var="${6:-}" haiku_var="${7:-}"
  local agents_dir="$root/.opencode/agents"
  local count=0

  for agent_file in "$agents_dir"/*.md; do
    [ -f "$agent_file" ] || continue
    name="$(basename "$agent_file" .md)"
    tier="$(ccgs_get_agent_tier "$agent_file" 2>/dev/null)" || tier="sonnet"

    case "$tier" in
      opus)   model_id="$opus";  variant="$opus_var" ;;
      sonnet) model_id="$sonnet"; variant="$sonnet_var" ;;
      haiku)  model_id="$haiku"; variant="$haiku_var" ;;
      *)      model_id="$sonnet"; variant="$sonnet_var" ;;
    esac

    ccgs_inject_model "$agent_file" "$model_id" "$variant"
    count=$((count + 1))
    if [ -n "$variant" ]; then
      printf '  %s (%s) → %s [%s]\n' "$name" "$tier" "$model_id" "$variant"
    else
      printf '  %s (%s) → %s\n' "$name" "$tier" "$model_id"
    fi
  done

  printf 'Configured %d agents\n' "$count"
}

# Strip model: from all agents (restore model-agnostic state)
# Usage: ccgs_strip_all_agents <root>
ccgs_strip_all_agents() {
  local root="$1"
  local agents_dir="$root/.opencode/agents"
  local count=0

  for agent_file in "$agents_dir"/*.md; do
    [ -f "$agent_file" ] || continue
    if ccgs_has_model "$agent_file"; then
      ccgs_strip_model "$agent_file"
      count=$((count + 1))
    fi
  done

  printf 'Stripped model from %d agents\n' "$count"
}

# Set the primary model in opencode.json
# Usage: ccgs_set_primary_model <root> <model_id>
ccgs_set_primary_model() {
  local root="$1" model_id="$2"
  python3 -c "
import json
with open('$root/opencode.json') as f:
    cfg = json.load(f)
cfg['model'] = '$model_id'
with open('$root/opencode.json', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
"
}

# Remove the primary model from opencode.json
# Usage: ccgs_remove_primary_model <root>
ccgs_remove_primary_model() {
  local root="$1"
  python3 -c "
import json
with open('$root/opencode.json') as f:
    cfg = json.load(f)
cfg.pop('model', None)
with open('$root/opencode.json', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
"
}
