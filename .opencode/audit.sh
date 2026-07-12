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
#   playtest     Check playtest-focus contract on root/continuity/skill surfaces
#   bug-lifecycle Check bug lifecycle consolidation contract on bug-report/triage
#   handoff-review Check handoff two-round review-gate contract on handoff/AGENTS.md
#   resume-contract Check resume lane-selection boundary on resume-from-handoff
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
    all|agents|skills|runtime|config|hooks|smoke|release|closeout|checkpoint|playtest|bug-lifecycle|handoff-review|resume-contract|install-safety|coexistence|smoke-headless) command="$1"; shift ;;
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

run_playtest_focus() {
  printf '\n── Playtest Focus Contract ────────────────────────────────\n'
  local -a surfaces=(
    "AGENTS.md"
    ".opencode/docs/session-continuity.md"
    ".opencode/skills/playtest-report/SKILL.md"
  )
  local -a phrases=(
    "user-owned playtest"
    "Playtest focus:"
    "hypothesis"
    "setup/build"
    "2-4 observation"
    "verdict/evidence"
  )
  local checked=0
  local rel
  for rel in "${surfaces[@]}"; do
    local f="$root/$rel"
    checked=$((checked + 1))
    [ -f "$f" ] || { fail "$rel (missing file)"; continue; }
    local missing=() p
    for p in "${phrases[@]}"; do
      if ! grep -qiF "$p" "$f" 2>/dev/null; then missing+=("$p"); fi
    done
    # session-continuity also requires the Session Worklist reference
    if [ "$rel" = ".opencode/docs/session-continuity.md" ]; then
      if ! grep -qiF "Session Worklist" "$f" 2>/dev/null; then missing+=("Session Worklist"); fi
    fi
    if [ "${#missing[@]}" -eq 0 ]; then
      pass "$rel (playtest focus contract)"
    else
      fail "$rel missing: ${missing[*]}"
    fi
  done
  printf '  %d playtest-focus surfaces checked\n' "$checked"
}

run_bug_lifecycle() {
  printf '\n── Bug Lifecycle Contract ────────────────────────────────\n'
  local checked=0

  # --- bug-report required phrases ---
  local report="$root/.opencode/skills/bug-report/SKILL.md"
  checked=$((checked + 1))
  if [ ! -f "$report" ]; then fail "bug-report/SKILL.md (missing)"; else
    local report_norm; report_norm=$(tr -s '[:space:]' ' ' < "$report")
    local -a req=(
      "treat verification, closure, stale triage"
      "one deterministic bug lifecycle operation"
      "Do not stop after VERIFIED FIXED to offer"
      "refresh stale triage metadata under the same approval"
      "zero-open-bugs refresh"
      "derived checkpoint"
      'Do not ask a separate "May I write?" for'
      "Do not bundle and stop for user decision if triage would require assigning"
    )
    local missing=() p
    for p in "${req[@]}"; do
      grep -qiF "$p" <<< "$report_norm" 2>/dev/null || missing+=("$p")
    done
    # Forbidden old-language fragments
    local -a forbidden=(
      "is referenced in the triage report"
      "write the closure record and update status"
      "remove it from the active list"
    )
    local bad=()
    for p in "${forbidden[@]}"; do
      grep -qiF "$p" <<< "$report_norm" 2>/dev/null && bad+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ] && [ "${#bad[@]}" -eq 0 ]; then
      pass "bug-report/SKILL.md (lifecycle contract)"
    else
      local d=""
      [ "${#missing[@]}" -gt 0 ] && d+=" missing: ${missing[*]}"
      [ "${#bad[@]}" -gt 0 ] && d+=" forbidden-present: ${bad[*]}"
      fail "bug-report/SKILL.md (lifecycle contract)$d"
    fi
  fi

  # --- bug-triage required phrases ---
  local triage="$root/.opencode/skills/bug-triage/SKILL.md"
  checked=$((checked + 1))
  if [ ! -f "$triage" ]; then fail "bug-triage/SKILL.md (missing)"; else
    local triage_norm; triage_norm=$(tr -s '[:space:]' ' ' < "$triage")
    local -a req2=(
      "zero-open-bugs closure refresh"
      "Treat it as metadata cleanup"
      "non-blocking follow-up"
      "Exception for bundled bug lifecycle cleanup"
      "deterministic metadata cleanup"
      "It must be explicitly marked non-blocking if it cannot be completed safely"
      "Do not bundle if the triage work would require assigning priorities"
    )
    local missing2=() p2
    for p2 in "${req2[@]}"; do
      grep -qiF "$p2" <<< "$triage_norm" 2>/dev/null || missing2+=("$p2")
    done
    if [ "${#missing2[@]}" -eq 0 ]; then
      pass "bug-triage/SKILL.md (lifecycle contract)"
    else
      fail "bug-triage/SKILL.md missing: ${missing2[*]}"
    fi
  fi
  printf '  %d bug-lifecycle surfaces checked\n' "$checked"
}

run_handoff_review() {
  printf '\n── Handoff Review Gate Contract ──────────────────────────\n'
  local checked=0

  # --- handoff SKILL.md required phrases ---
  local skill="$root/.opencode/skills/handoff/SKILL.md"
  checked=$((checked + 1))
  if [ ! -f "$skill" ]; then fail "handoff/SKILL.md (missing)"; else
    local skill_norm; skill_norm=$(tr -s '[:space:]' ' ' < "$skill")
    local -a req=(
      "## Round 1"
      "## Round 2"
      "\`STANDARD\`"
      "\`ADVERSARIAL\`"
      "Foundation ADR cluster closure"
      "pure design/process-document"
      "self-review is sufficient and the native cross-check is skipped"
      "Mixed code-and-document changes are not exempt"
      "distinct native review pass"
      "current OpenCode session"
      "\`HIGH\`, \`MEDIUM\`, or \`LOW\`"
      "\`CLEAN\`"
      "\`path:line\`"
      "If uncertain whether the work meets a major trigger, use \`STANDARD\`"
      "quoted verbatim"
      "stop before Phase 1"
      "second native cross-check"
      "\`HIGH\` finding"
      "cross-cutting executable behavior"
      "Trivial and confidently intent-preserving only"
      "Any non-trivial fix"
      "Do not run a third pass"
      "three native review passes"
      "fourth native review pass"
      "active reported context percentage"
      "review audit trail"
      "every finding"
      "Only then proceed to Phase 1"
    )
    local missing=() p
    for p in "${req[@]}"; do
      grep -qF "$p" <<< "$skill_norm" 2>/dev/null || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
      pass "handoff/SKILL.md (review gate contract)"
    else
      fail "handoff/SKILL.md missing: ${missing[*]}"
    fi
  fi

  # --- AGENTS.md required phrases ---
  local agents="$root/AGENTS.md"
  checked=$((checked + 1))
  if [ ! -f "$agents" ]; then fail "AGENTS.md (missing)"; else
    local agents_norm; agents_norm=$(tr -s '[:space:]' ' ' < "$agents")
    local -a req2=(
      "files already created or materially modified during the session"
      "intent-preserving review fixes"
      "active OpenCode session"
      "Round-two non-trivial findings"
      "external data-egress approval"
      "new intent, architecture, game-feel, balance, or scope decisions"
    )
    local missing2=() p2
    for p2 in "${req2[@]}"; do
      grep -qF "$p2" <<< "$agents_norm" 2>/dev/null || missing2+=("$p2")
    done
    if [ "${#missing2[@]}" -eq 0 ]; then
      pass "AGENTS.md (handoff review exception)"
    else
      fail "AGENTS.md missing: ${missing2[*]}"
    fi
  fi
  printf '  %d handoff-review surfaces checked\n' "$checked"
}

run_resume_contract() {
  printf '\n── Resume Lane-Selection Contract ────────────────────────\n'
  if python3 - "$root" <<'PY'
import re, sys, os
root = sys.argv[1]
rel = ".opencode/skills/resume-from-handoff/SKILL.md"
path = os.path.join(root, rel)
if not os.path.isfile(path):
    print(f"  ! {rel}: missing file")
    sys.exit(1)
text = open(path, encoding="utf-8").read()
norm = re.sub(r"\s+", " ", text)

required = (
    "A focus argument biases ranking; it does not select a lane.",
    "Never start an unselected lane.",
    "recommendation as the first option",
    "wait for the user to reply `1`",
    "Resume selection authorizes entering only the selected workflow",
    "FIRST verification cannot be waived by choosing another lane",
    "Follow-up fork",
    "`question` tool",
    "Playable/Slice State Source",
    "production/stage.txt",
    ".opencode/docs/workflow-catalog.yaml",
    "production/session-state/active.md",
)
missing = [p for p in required if p not in norm]
if missing:
    print(f"  ! {rel}: missing phrase(s): " + ", ".join(missing))

fails = len(missing)
for i, line in enumerate(text.splitlines(), start=1):
    lower = line.lower()
    starts_lane = re.search(r"\b(?:start|begin|enter)\b", lower)
    bypasses = any(w in lower for w in (
        "automatically", "immediately", "without waiting", "without selection"
    ))
    forbidden = any(w in lower for w in (
        "do not", "don't", "never", "must not", "cannot"
    ))
    if starts_lane and bypasses and not forbidden:
        print(f"  ! {rel}:{i}: automatic lane startup forbidden; "
              "pause for selection boundary")
        fails += 1

print(f"  resume-from-handoff checked, {fails} violation(s)")
sys.exit(1 if fails else 0)
PY
  then
    pass "resume selection contract satisfied"
  else
    fail "resume selection contract violations"
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
perm = cfg.get('permission', {})
edit_rules = perm.get('edit', {})
if not isinstance(edit_rules, dict) or not any(v == 'deny' and '.env' in str(k) for k, v in edit_rules.items()):
    print('missing edit .env* deny'); sys.exit(1)
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

run_install_safety() {
  printf '\n── Installer Safety ────────────────────────────────────────\n'
  local coex="$root/.opencode/lib/coexistence.sh"
  local inst="$root/.opencode/install.sh"
  local uninst="$root/.opencode/uninstall.sh"
  local problems=0

  if grep -q 'ccgs_state_validate()' "$coex" 2>/dev/null; then
    pass "coexistence.sh defines ccgs_state_validate"
  else
    fail "coexistence.sh missing ccgs_state_validate (uninstall cannot fail closed)"
    problems=1
  fi

  if grep -q 'ccgs_state_validate' "$uninst" 2>/dev/null; then
    pass "uninstall.sh validates state (fail-closed)"
  else
    fail "uninstall.sh does not call ccgs_state_validate"
    problems=1
  fi

  if grep -q 'installed-files.json' "$uninst" 2>/dev/null; then
    fail "uninstall.sh references installed-files.json (ownership-by-manifest regression)"
    problems=1
  else
    pass "uninstall.sh does not infer ownership from source manifest"
  fi

  if grep -q -- '--replace-modified' "$inst" 2>/dev/null; then
    pass "install.sh supports --replace-modified"
  else
    fail "install.sh missing --replace-modified opt-in"
    problems=1
  fi

  if grep -q 'Preflight' "$inst" 2>/dev/null; then
    pass "install.sh runs a preflight pass"
  else
    fail "install.sh missing preflight conflict detection"
    problems=1
  fi

  return $problems
}

run_coexistence() {
  printf '\n── Coexistence / Installer Matrix ───────────────────────────\n'
  printf '   (advisory — runs a real install/uninstall matrix in a temp dir)\n'
  local inst="$root/.opencode/install.sh"
  local uninst="$root/.opencode/uninstall.sh"
  [ -f "$inst" ] && [ -f "$uninst" ] || { fail "install.sh/uninstall.sh not found"; return 1; }

  local model=""
  if command -v opencode >/dev/null 2>&1; then model="$(opencode models 2>/dev/null | head -1)"
  elif [ -x "$HOME/.opencode/bin/opencode" ]; then model="$("$HOME/.opencode/bin/opencode" models 2>/dev/null | head -1)"; fi
  [ -n "$model" ] || model="local/test"
  local MF="--tier-opus $model --tier-sonnet $model --tier-haiku $model --primary $model"

  local base T out rc
  base="$(mktemp -d "${TMPDIR:-/tmp}/ccgs-coex.XXXXXX")" || { fail "could not create temp dir"; return 1; }

  # S1 fresh install
  T="$base/s1"; mkdir -p "$T"
  rc=0; out="$(bash "$inst" $MF "$T" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ] && [ -f "$T/.opencode/install-state.json" ]; then pass "S1 fresh install + state"; else fail "S1 fresh install (rc=$rc)"; fi

  # S2 unowned collision -> preflight abort, no mutation
  T="$base/s2"; mkdir -p "$T/.github"; printf 'USER\n' > "$T/.github/CODEOWNERS"
  rc=0; out="$(printf 'y\n' | bash "$inst" $MF "$T" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'Preflight conflict'; then pass "S2 unowned collision abort"; else fail "S2 collision abort (rc=$rc)"; fi
  if [ -f "$T/.opencode/install-state.json" ]; then fail "S2 mutated target despite abort"; else pass "S2 no mutation"; fi

  # S3 modified-file -> preflight abort, then S4 --replace-modified
  T="$base/s3"; mkdir -p "$T"
  bash "$inst" $MF "$T" >/dev/null 2>&1 || true
  printf 'USER-EDIT\n' > "$T/.opencode/VERSION"
  rc=0; out="$(bash "$inst" $MF "$T" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'Locally-modified'; then pass "S3 modified-file abort"; else fail "S3 modified abort (rc=$rc)"; fi
  rc=0; out="$(bash "$inst" $MF --replace-modified "$T" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ] && [ "$(cat "$T/.opencode/VERSION" 2>/dev/null)" = "$(cat "$root/.opencode/VERSION")" ]; then pass "S4 --replace-modified restore"; else fail "S4 replace-modified (rc=$rc)"; fi

  # S5 uninstall missing-state -> abort, no removal
  T="$base/s5"; mkdir -p "$T"
  bash "$inst" $MF "$T" >/dev/null 2>&1 || true
  local agents_before
  agents_before="$(ls "$T/.opencode/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  rm -f "$T/.opencode/install-state.json"
  rc=0; out="$(bash "$uninst" "$T" 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'cannot uninstall safely'; then pass "S5 uninstall missing-state abort"; else fail "S5 missing-state abort (rc=$rc)"; fi
  if [ "$(ls "$T/.opencode/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')" = "$agents_before" ]; then pass "S5 no files removed"; else fail "S5 files removed despite abort"; fi

  # S6 uninstall valid-state -> clean removal
  T="$base/s6"; mkdir -p "$T"
  bash "$inst" $MF "$T" >/dev/null 2>&1 || true
  rc=0; out="$(bash "$uninst" "$T" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ] && [ ! -f "$T/.opencode/install-state.json" ] && [ ! -f "$T/.opencode/agents/creative-director.md" ]; then pass "S6 uninstall valid-state clean"; else fail "S6 valid-state uninstall (rc=$rc)"; fi

  # S7 transactional rollback on forced mid-deploy failure
  T="$base/s7"; mkdir -p "$T"
  bash "$inst" $MF "$T" >/dev/null 2>&1 || true
  printf 'MY-MOD\n' > "$T/.opencode/.gitignore"
  rm -f "$T/.opencode/README.md"
  if chmod 444 "$T/.opencode/uninstall.sh" 2>/dev/null; then
    local a_before a_after
    a_before="$(cat "$T/.opencode/.gitignore")"
    rc=0; out="$(bash "$inst" $MF --replace-modified "$T" 2>&1)" || rc=$?
    chmod 644 "$T/.opencode/uninstall.sh" 2>/dev/null || true
    a_after="$(cat "$T/.opencode/.gitignore" 2>/dev/null)"
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'rolling back' && [ "$a_after" = "$a_before" ] && [ ! -f "$T/.opencode/README.md" ]; then
      pass "S7 transactional rollback (restore + remove)"
    else
      fail "S7 rollback (rc=$rc)"
    fi
  else
    pass "S7 rollback: SKIP (chmod 444 unsupported)"
  fi

  rm -rf "$base" 2>/dev/null || true
  return 0
}

run_smoke_headless() {
  printf '\n── Headless Smoke (non-model) ──────────────────────────────\n'
  printf '   (advisory — command/skill graph integrity; model-driven smoke deferred)\n'
  local problems=0 cmds=0 broken=0

  # command -> skill graph integrity
  local c ref skill_path
  for c in "$root"/.opencode/commands/*.md; do
    [ -f "$c" ] || continue
    cmds=$((cmds + 1))
    ref="$(grep -oE '@\.opencode/skills/[^/]+/SKILL\.md' "$c" 2>/dev/null | head -1)"
    if [ -z "$ref" ]; then
      fail "$(basename "$c" .md): no @skill reference"
      broken=$((broken + 1)); problems=1
      continue
    fi
    skill_path="${ref#@}"
    if [ ! -f "$root/$skill_path" ]; then
      fail "$(basename "$c" .md): skill $ref missing"
      broken=$((broken + 1)); problems=1
    fi
  done
  [ "$broken" -eq 0 ] && pass "$cmds commands resolve to an existing skill"

  # model-driven boot is intentionally deferred (needs model + API access)
  pass "model-driven boot: DEFERRED (wire explicitly when a CI model runner exists)"
  return $problems
}

case "$command" in
  all)
    run_agents
    run_skills
    run_closeout
    run_checkpoint
    run_playtest_focus
    run_bug_lifecycle
    run_handoff_review
    run_resume_contract
    run_runtime
    run_config
    run_install_safety
    run_hooks
    run_smoke
    ;;
  agents)   run_agents ;;
  skills)   run_skills ;;
  closeout) run_closeout ;;
  checkpoint) run_checkpoint ;;
  playtest) run_playtest_focus ;;
  bug-lifecycle) run_bug_lifecycle ;;
  handoff-review) run_handoff_review ;;
  resume-contract) run_resume_contract ;;
  runtime)  run_runtime ;;
  config)   run_config ;;
  install-safety) run_install_safety ;;
  coexistence) run_coexistence ;;
  smoke-headless) run_smoke_headless ;;
  hooks)    run_hooks ;;
  smoke)    run_smoke ;;
  release)  run_release ;;
    *) printf 'Unknown command: %s\nAvailable: all, agents, skills, closeout, checkpoint, playtest, bug-lifecycle, handoff-review, resume-contract, runtime, config, install-safety, coexistence, smoke-headless, hooks, smoke, release\n' "$command" >&2; exit 2 ;;
esac

printf '\n── Result: %d error(s) ──\n' "$errors"
[ "$errors" -eq 0 ] && printf 'All checks passed.\n' || printf 'Some checks failed.\n' >&2
exit $errors
