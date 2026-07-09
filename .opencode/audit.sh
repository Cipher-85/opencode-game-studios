#!/usr/bin/env bash
# audit.sh — OpenCode Game Studios validation dispatcher
#
# Usage:
#   bash .opencode/audit.sh [command] [--root PATH]
#
# Commands:
#   all          Run all validators (default)
#   agents       Validate agent files
#   skills       Validate skill files
#   closeout     Check closeout-routing contract on completion skills
#   checkpoint   Check active.md silent-checkpoint contract on skills/agents
#   runtime      Check for stale references
#   config       Validate opencode.json
#   hooks        Test hook scripts
#   smoke        Run negative fixture tests
#   release      Validate release readiness (version, changelog, tags)
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$script_dir/.." && pwd -P)"
command="${1:-all}"
[ "$command" = "--root" ] && command="all"

# Parse --root option
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) root="$(cd "$2" && pwd -P)"; shift 2 ;;
    all|agents|skills|runtime|config|hooks|smoke|release|closeout|checkpoint) command="$1"; shift ;;
    *) shift ;;
  esac
done

pass() { printf '  ✓ %s\n' "$1"; }
fail() { printf '  ✗ %s\n' "$1"; errors=$((errors + 1)); }
errors=0

run_agents() {
  printf '\n── Agents ──────────────────────────────────────────────────\n'
  local count=0
  for f in "$root"/.opencode/agents/*.md; do
    [ -f "$f" ] || continue
    count=$((count + 1))
    name="$(basename "$f" .md)"
    # Check required fields
    python3 -c "
import sys, re, yaml
with open('$f') as fh:
    txt = fh.read()
m = re.match(r'^---\n(.*?)\n---', txt, re.S)
if not m:
    print('no frontmatter')
    sys.exit(1)
fm = yaml.safe_load(m.group(1))
for field in ('description', 'mode', 'steps', 'permission'):
    if field not in fm:
        print(f'missing {field}')
        sys.exit(1)
if fm.get('mode') != 'subagent':
    print(f'mode != subagent')
    sys.exit(1)
meta = fm.get('metadata', {})
if 'ccgs_tier' not in meta:
    print('missing metadata.ccgs_tier')
    sys.exit(1)
sys.exit(0)
" 2>/dev/null && pass "$name" || fail "$name (invalid frontmatter)"
  done
  printf '  %d agents checked\n' "$count"
}

run_skills() {
  printf '\n── Skills ──────────────────────────────────────────────────\n'
  local count=0
  for d in "$root"/.opencode/skills/*/; do
    [ -d "$d" ] || continue
    local skill_file="$d/SKILL.md"
    [ -f "$skill_file" ] || { fail "$(basename "$d") (no SKILL.md)"; continue; }
    count=$((count + 1))
    name="$(basename "$d")"
    python3 -c "
import sys, re, yaml
with open('$skill_file') as fh:
    txt = fh.read()
m = re.match(r'^---\n(.*?)\n---', txt, re.S)
if not m:
    print('no frontmatter')
    sys.exit(1)
fm = yaml.safe_load(m.group(1))
if 'name' not in fm or 'description' not in fm:
    print('missing name/description')
    sys.exit(1)
if fm.get('name') != '$name':
    print(f'name mismatch: {fm.get(\"name\")} != $name')
    sys.exit(1)
sys.exit(0)
" 2>/dev/null && pass "$name" || fail "$name (invalid)"
  done
  printf '  %d skills checked\n' "$count"
}

run_closeout() {
  printf '\n── Closeout Routing ────────────────────────────────────────\n'
  local -a skills=(
    architecture-decision architecture-review art-bible asset-spec brainstorm
    code-review consistency-check design-system dev-story gate-check help
    map-systems project-stage-detect quick-design smoke-check story-done
    story-readiness team-qa ux-design
  )
  local -a markers=(
    "Verdict: **COMPLETE**"
    "Verdict: COMPLETE"
    "**Verdict: COMPLETE**"
    "## Recommended Next Steps"
  )
  local -a required=(
    "Session Worklist"
    "production/session-state/active.md"
    "completed work"
    "owed verification"
    "numbered next-action prompt"
    "Next action:"
    "1. (Recommended)"
    "(Recommended)"
  )
  local -a forbidden=(
    "one recommended next action"
    "numbered choice set"
  )
  local checked=0
  for s in "${skills[@]}"; do
    local f="$root/.opencode/skills/$s/SKILL.md"
    [ -f "$f" ] || { fail "$s (no SKILL.md)"; continue; }
    checked=$((checked + 1))
    # Trigger only when the skill declares a closeout marker.
    local has_marker=0 m
    for m in "${markers[@]}"; do
      if grep -qF "$m" "$f" 2>/dev/null; then has_marker=1; break; fi
    done
    if [ "$has_marker" -eq 0 ]; then
      pass "$s (no closeout marker; skipped)"
      continue
    fi
    local missing=() bad=()
    for m in "${required[@]}"; do
      if ! grep -qF "$m" "$f" 2>/dev/null; then missing+=("$m"); fi
    done
    for m in "${forbidden[@]}"; do
      if grep -qF "$m" "$f" 2>/dev/null; then bad+=("$m"); fi
    done
    if [ "${#missing[@]}" -eq 0 ] && [ "${#bad[@]}" -eq 0 ]; then
      pass "$s (closeout routing complete)"
    else
      local detail=""
      [ "${#missing[@]}" -gt 0 ] && detail+=" missing: ${missing[*]}"
      [ "${#bad[@]}" -gt 0 ] && detail+=" forbidden-present: ${bad[*]}"
      fail "$s (closeout contract)$detail"
    fi
  done
  printf '  %d closeout skills checked\n' "$checked"
}

run_checkpoint() {
  printf '\n── Active State Checkpoint ────────────────────────────────\n'
  if python3 - "$root" <<'PY'
import os, re, sys
root = sys.argv[1]
ACTIVE_PATH = "production/session-state/active.md"
REQUIRED = ["derived checkpoint", 'Do not ask a separate "May I write?" for this file']
EXEMPT = {"handoff", "resume-from-handoff"}
VERBS = r"(?:create|update|append|overwrite|write)"
targets = []
sd = os.path.join(root, ".opencode", "skills")
if os.path.isdir(sd):
    for d in sorted(os.listdir(sd)):
        f = os.path.join(sd, d, "SKILL.md")
        if os.path.isfile(f):
            targets.append((d, f, d in EXEMPT))
ad = os.path.join(root, ".opencode", "agents")
if os.path.isdir(ad):
    for fn in sorted(os.listdir(ad)):
        if fn.endswith(".md"):
            targets.append((fn, os.path.join(ad, fn), False))
checked = fails = 0
for name, path, exempt in targets:
    with open(path) as fh:
        text = fh.read()
    if exempt or ACTIVE_PATH not in text:
        continue
    checked += 1
    rel = os.path.relpath(path, root)
    norm = re.sub(r"\s+", " ", text)
    lower = norm.lower()
    npath = re.escape(ACTIVE_PATH)
    verb = rf"(?<!does not )(?<!do not )(?<!must not )\b{VERBS}\b(?!\s+(?:is|was|complete))"
    wpatt = rf"(?is){verb}[^.!?;]{{0,180}}`?{npath}`?|`?{npath}`?[^.!?;]{{0,180}}{verb}"
    bad = False
    if re.search(wpatt, norm):
        missing = [p for p in REQUIRED if p.lower() not in lower]
        if missing:
            print(f"  ! {rel}: active.md write missing: " + ", ".join(missing))
            fails += 1; bad = True
    if not bad:
        prompt = norm
        for p in REQUIRED:
            prompt = re.sub(re.escape(p), "", prompt, flags=re.IGNORECASE)
        ppatt = rf"(?is)May I (?:write|update)\b(?:\s+[\w/-]+){{0,10}}\s+(?:to\s+|at\s+)?`?(?:{npath}|active\.md)`?[^?]*\?"
        if re.search(ppatt, prompt):
            print(f"  ! {rel}: active.md checkpoint must not request a separate May I write/update prompt")
            fails += 1
print(f"  {checked} active.md-writing files checked, {fails} violation(s)")
sys.exit(1 if fails else 0)
PY
  then
    pass "checkpoint contract satisfied"
  else
    fail "checkpoint contract violations"
  fi
}

run_runtime() {
  printf '\n── Runtime References ──────────────────────────────────────\n'
  # Check for stale Claude references
  local stale=0
  if grep -rq '\.claude/' "$root"/.opencode/agents/ "$root"/.opencode/skills/ 2>/dev/null; then
    fail "stale .claude/ references in agents/skills"
    stale=1
  else
    pass "no .claude/ references"
  fi
  if grep -rq 'CLAUDE\.md' "$root"/.opencode/agents/ "$root"/.opencode/skills/ 2>/dev/null; then
    fail "stale CLAUDE.md references"
    stale=1
  else
    pass "no CLAUDE.md references"
  fi
  # Check no .claude/ directory shipped
  if [ -d "$root/.claude" ]; then
    fail ".claude/ directory exists"
  else
    pass "no .claude/ directory"
  fi
}

run_config() {
  printf '\n── Configuration ───────────────────────────────────────────\n'
  python3 -c "
import json, sys
with open('$root/opencode.json') as f:
    cfg = json.load(f)
if '\$schema' not in cfg:
    print('missing \$schema'); sys.exit(1)
if 'permission' not in cfg:
    print('missing permission'); sys.exit(1)
if 'instructions' not in cfg:
    print('missing instructions'); sys.exit(1)
if 'plugin' not in cfg:
    print('missing plugin'); sys.exit(1)
sys.exit(0)
" 2>/dev/null && pass "opencode.json valid" || fail "opencode.json invalid"

  # Check instruction files exist
  python3 -c "
import json, os, sys
with open('$root/opencode.json') as f:
    cfg = json.load(f)
for path in cfg.get('instructions', []):
    full = os.path.join('$root', path)
    if not os.path.isfile(full):
        print(f'missing instruction file: {path}')
        sys.exit(1)
sys.exit(0)
" 2>/dev/null && pass "all instruction files exist" || fail "missing instruction files"
}

run_hooks() {
  printf '\n── Hooks ───────────────────────────────────────────────────\n'
  local count=0
  for f in "$root"/.opencode/hooks/*.sh; do
    [ -f "$f" ] || continue
    count=$((count + 1))
    if [ -x "$f" ] || head -1 "$f" | grep -q 'bash'; then
      pass "$(basename "$f")"
    else
      fail "$(basename "$f") (not executable)"
    fi
  done
  printf '  %d hook scripts checked\n' "$count"

  # Run fixture tests
  if [ -f "$root/.opencode/hooks/fixtures/test-fixtures.js" ]; then
    printf '  Running fixture tests...\n'
    node "$root/.opencode/hooks/fixtures/test-fixtures.js" 2>&1 | tail -1
  fi
}

run_smoke() {
  printf '\n── Smoke Tests ─────────────────────────────────────────────\n'
  # Verify counts
  local agents skills commands hooks
  agents=$(ls "$root"/.opencode/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  skills=$(ls -d "$root"/.opencode/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
  commands=$(ls "$root"/.opencode/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
  hooks=$(ls "$root"/.opencode/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')

  [ "$agents" -eq 49 ] && pass "49 agents ($agents)" || fail "expected 49 agents, got $agents"
  [ "$skills" -ge 77 ] && pass "$skills skills (≥77)" || fail "expected ≥77 skills, got $skills"
  [ "$commands" -ge 77 ] && pass "$commands commands (≥77)" || fail "expected ≥77 commands, got $commands"
  [ "$hooks" -ge 12 ] && pass "$hooks hooks (≥12)" || fail "expected ≥12 hooks, got $hooks"

  # Agent memory
  local mem
  mem=$(find "$root"/.opencode/agent-memory -name 'MEMORY.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$mem" -eq 17 ] && pass "17 agent-memory files" || fail "expected 17 agent-memory, got $mem"

  # Rules
  local rules
  rules=$(ls "$root"/.opencode/rules/*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$rules" -ge 15 ] && pass "$rules rules (≥15)" || fail "expected ≥15 rules, got $rules"
}

run_release() {
  printf '\n── Release Check ───────────────────────────────────────────\n'
  local version_file="$root/.opencode/VERSION"
  local changelog="$root/CHANGELOG.md"

  if [ ! -f "$version_file" ]; then
    fail "VERSION file missing"
    return
  fi

  local version
  version="$(cat "$version_file" | tr -d '[:space:]')"
  pass "VERSION: $version"

  # Check CHANGELOG has the section
  if [ -f "$changelog" ] && grep -q "^## v${version}" "$changelog" 2>/dev/null; then
    pass "CHANGELOG has v$version section"
  else
    fail "CHANGELOG missing v$version section"
  fi

  # Check for existing tags
  local tag="opencode-v${version}"
  if git -C "$root" rev-parse "$tag" >/dev/null 2>&1; then
    pass "Tag $tag exists"
  else
    pass "Tag $tag not yet created"
  fi

  # List previous tags
  local latest_tag
  latest_tag="$(git -C "$root" tag -l 'opencode-v*' --sort=-v:refname 2>/dev/null | head -1)"
  if [ -n "$latest_tag" ]; then
    pass "Latest tag: $latest_tag"
  else
    pass "No previous opencode-v* tags"
  fi
}

case "$command" in
  all)
    run_agents
    run_skills
    run_closeout
    run_checkpoint
    run_runtime
    run_config
    run_hooks
    run_smoke
    ;;
  agents)   run_agents ;;
  skills)   run_skills ;;
  closeout) run_closeout ;;
  checkpoint) run_checkpoint ;;
  runtime)  run_runtime ;;
  config)   run_config ;;
  hooks)    run_hooks ;;
  smoke)    run_smoke ;;
  release)  run_release ;;
    *) printf 'Unknown command: %s\nAvailable: all, agents, skills, closeout, checkpoint, runtime, config, hooks, smoke, release\n' "$command" >&2; exit 2 ;;
esac

printf '\n── Result: %d error(s) ──\n' "$errors"
[ "$errors" -eq 0 ] && printf 'All checks passed.\n' || printf 'Some checks failed.\n' >&2
exit $errors
