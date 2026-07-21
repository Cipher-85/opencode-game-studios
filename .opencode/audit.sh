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
#   handoff-review Check handoff review-gate, explicit authorization, capacity,
#                  scope-baseline, fresh-context reviewer, and resume-index contracts
#   resume-contract Check resume lane-selection, bounded-read, precedence, and
#                  readback contracts on resume-from-handoff
#   hook-behavior  Run behavioral fixtures against session-start/pre/post-compact hooks
#   fixtures       Run negative contract fixtures (must be detected as invalid)
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
    all|agents|skills|runtime|config|hooks|smoke|release|closeout|checkpoint|playtest|bug-lifecycle|handoff-review|resume-contract|hook-behavior|fixtures|install-safety|coexistence|smoke-headless) command="$1"; shift ;;
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
  if python3 - "$root" <<'PY'
import os, re, sys
root = sys.argv[1]
fails = 0

SKILL = ".opencode/skills/handoff/SKILL.md"
AGENTS = "AGENTS.md"

def read_raw(rel):
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as fh:
        return fh.read()

def norm(rel):
    raw = read_raw(rel)
    return re.sub(r"\s+", " ", raw) if raw is not None else None

skill_raw = read_raw(SKILL)
skill = re.sub(r"\s+", " ", skill_raw) if skill_raw is not None else None
agents = norm(AGENTS)

CORE_PHRASES = (
    "## Round 1",
    "## Round 2",
    "`STANDARD`",
    "`ADVERSARIAL`",
    "Foundation ADR cluster closure",
    "pure design/process-document",
    "self-review is sufficient and the fresh-context reviewer is skipped",
    "Mixed code-and-document changes are not exempt",
    "built-in `explore`",
    "fresh context",
    "`HIGH`, `MEDIUM`, or `LOW`",
    "`CLEAN`",
    "`path:line`",
    "If uncertain whether the work meets a major trigger, use `STANDARD`",
    "quoted verbatim",
    "stop before Phase 1",
    "another fresh reviewer pass",
    "`HIGH` finding",
    "cross-cutting executable behavior",
    "Trivial and confidently intent-preserving only",
    "Any non-trivial fix",
    "Do not run a third pass",
    "three reviewer invocations",
    "fourth reviewer invocation",
    "active reported context percentage",
    "review audit trail",
    "every finding",
    "Only then proceed to Phase 1",
)

AUTH_PHRASES = {
    SKILL: (
        "equally explicit instruction to commit and push this handoff",
        "Generic requests to pause, stop, checkpoint",
        "they are not commit or push authority",
    ),
    AGENTS: (
        "equally explicit instruction to commit and push the handoff",
        "Generic pause/stop wording does not",
    ),
}

CAPACITY_PHRASES = (
    "## Context Capacity Gate",
    "active reported context percentage",
    "estimated additional percentage cost",
    "hardcoded percentage threshold",
    "If the active percentage is unavailable",
)

SCOPE_PHRASES = (
    "production/session-logs/session-baseline.json",
    "starting HEAD",
    "git merge-base --is-ancestor <starting-head> HEAD",
    "git diff --name-only <starting-head>..HEAD",
    "git diff --cached --name-only",
    "git ls-files --others --exclude-standard",
    "files it records as touched or in progress",
    "filesystem file count",
    "tracked count",
    "staged count",
    "git check-ignore -v -- <path>",
)

FRESH_REVIEWER_PHRASES = (
    "## Fresh-Context Reviewer Contract",
    "exact deduplicated review path list",
    "starting HEAD",
    "current HEAD",
    "user-approved behavioral contract and acceptance criteria",
    "Applicable project rules, ADRs, GDDs",
    "Verification evidence already produced",
    "Do not pass authoring conclusions",
    "instruction-read-only",
    "must not edit or write files",
    "git status --porcelain=v2 --untracked-files=all",
    "git diff --binary --no-ext-diff",
    "git diff --cached --binary --no-ext-diff",
    "SHA-256 content hash",
    "before and after results exactly",
    "Any unexplained mutation blocks the gate",
    "unavailable delegation tool",
    "absent built-in `explore` agent",
    "inability to spawn the reviewer with a fresh context",
    "do not simulate or silently replace the reviewer",
    "explicitly waive the independent reviewer",
    "another fresh reviewer pass",
    "do not reuse the first reviewer",
    "no authoring conclusions or narrative defending the fix",
    "reviewer type",
    "mutation snapshot outcome",
)

INDEX_PHRASES = (
    "production/resume-index.md",
    "derived, disposable accelerator",
    "Generated date and source HEAD",
    "SHA-256 content hash",
    "Last reported or verified boot/playtest with provenance",
    "Owed verification",
    "two alternative lanes",
    "Blockers/gates",
    "at most 10 KB",
)

AGENTS_PHRASES = (
    "files already created or materially modified during the session",
    "intent-preserving review fixes",
    "built-in `explore`",
    "fresh context",
    "before-and-after repository mutation snapshot",
    "Round-two non-trivial findings",
    "external data-egress approval",
    "new intent, architecture, game-feel, balance, or scope decisions",
)

FRESH_REVIEWER_SURFACES = {
    ".opencode/docs/coordination-rules.md": (
        "## Handoff Integrity Reviewer",
        "built-in `explore`",
        "fresh context",
        "not a custom role agent, director gate, or lead gate",
        "Do not simulate a reviewer or silently substitute a same-session pass",
    ),
    ".opencode/docs/context-management.md": (
        "fresh context",
        "fresh integrity reviewer",
        "omits the author's conclusions",
    ),
    ".opencode/docs/session-continuity.md": (
        "fresh built-in `explore` integrity review",
        "fresh context",
        "before-and-after mutation snapshot",
        "explicit user waiver",
    ),
}

FORBIDDEN_PATTERNS = (
    (re.compile(r"(?i)fresh same-session reasoning pass,\s*not an independent reviewer"),
     "same-session reviewer substitution"),
    (re.compile(r"(?i)\btask_id\s*[:=]"),
     "reviewer history fork via task_id"),
    (re.compile(r"(?i)if the (?:reviewer|delegation)[^.\n]{0,80}(?:unavailable|blocked|fails?)[^.\n]{0,80}(?:continue|proceed)[^.\n]{0,80}same-session"),
     "silent reviewer fallback"),
)

def check(label, text, phrases):
    global fails
    missing = [p for p in phrases if p not in text]
    if missing:
        print(f"  ! {label}: missing phrase(s): " + ", ".join(missing))
        fails += 1

if skill is None:
    print(f"  ! {SKILL}: missing file")
    fails += 1
else:
    check(f"{SKILL} (review gate)", skill, CORE_PHRASES)
    check(f"{SKILL} (context capacity gate)", skill, CAPACITY_PHRASES)
    check(f"{SKILL} (review scope baseline contract)", skill, SCOPE_PHRASES)
    check(f"{SKILL} (fresh-context reviewer contract)", skill, FRESH_REVIEWER_PHRASES)
    check(f"{SKILL} (compact resume-index contract)", skill, INDEX_PHRASES)
    m = re.match(r"^---\n(.*?)\n---", skill_raw, re.S)
    desc = ""
    if m:
        d = re.search(r"description:\s*[\"']?(.*?)[\"']?\s*$", m.group(1), re.M)
        desc = (d.group(1) if d else "").lower()
    if any(w in desc for w in ("pause", "stop", "checkpoint", "resume later")):
        print(f"  ! {SKILL}: explicit invocation boundary is ambiguous in frontmatter description")
        fails += 1
    for rx, msg in FORBIDDEN_PATTERNS:
        for match in rx.finditer(skill_raw):
            line_no = skill_raw.count("\n", 0, match.start()) + 1
            print(f"  ! {SKILL}:{line_no}: {msg}")
            fails += 1

for rel, phrases in AUTH_PHRASES.items():
    text = skill if rel == SKILL else agents
    if text is None:
        print(f"  ! {rel}: missing explicit invocation boundary surface")
        fails += 1
    else:
        check(f"{rel} (explicit invocation boundary)", text, phrases)

if agents is None:
    print(f"  ! {AGENTS}: missing file")
    fails += 1
else:
    check(f"{AGENTS} (handoff review exception)", agents, AGENTS_PHRASES)

for rel, phrases in FRESH_REVIEWER_SURFACES.items():
    text = norm(rel)
    if text is None:
        print(f"  ! {rel}: missing fresh-context reviewer contract surface")
        fails += 1
    else:
        check(f"{rel} (fresh-context reviewer contract)", text, phrases)

print(f"  handoff review contract checked, {fails} violation(s)")
sys.exit(1 if fails else 0)
PY
  then
    pass "handoff review contract satisfied"
  else
    fail "handoff review contract violations"
  fi
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

BOUNDED_PHRASES = (
    "/resume-from-handoff deep [focus]",
    "bounded current section",
    "at most 200 lines or 32 KiB",
    "Default resume must not read the entire slice source",
    "Missing or stale index state never activates deep mode automatically",
    "production/resume-index.md",
    "Mark an oversized index `oversized`",
    "SHA-256 content hash",
    "Compute the hash locally without loading the whole source into model context",
    "stale-hash",
)

READBACK_PHRASES = (
    "read `production/session-state/active.md` back in full",
    "## Source Freshness",
    "## Owed Before Starting",
    "recommended `## Session Worklist` lane",
    "Do not claim the session cache was updated until this readback passes",
)

PRECEDENCE_PHRASES = (
    "Use this source precedence",
    "durable narrative, decisions, blockers",
    "for current stage",
    "for story status",
    "fresh bounded current section",
    "derived accelerator",
    "lowest-priority same-session cache",
    "Surface conflicts; never silently normalize them",
)

fails = 0
for label, phrases in (
    ("lane-selection contract", required),
    ("bounded default slice-read contract", BOUNDED_PHRASES),
    ("cache readback contract", READBACK_PHRASES),
    ("source precedence contract", PRECEDENCE_PHRASES),
):
    missing = [p for p in phrases if p not in norm]
    if missing:
        print(f"  ! {rel}: missing {label} phrase(s): " + ", ".join(missing))
        fails += len(missing)

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
    reads_full_slice = (
        re.search(r"\bread\b.*\b(?:entire|full|all)\b.*\b(?:slice|playable)[ -]?(?:source|history)?\b", lower)
        or re.search(r"\bread\b.*\b(?:slice|playable)[ -]?(?:source|history)?\b.*\b(?:entire|full|all)\b", lower)
        or re.search(r"\b(?:entire|full|all)\b.*\b(?:slice|playable)[ -]?(?:source|history)?\b.*\bread\b", lower)
    )
    deep_only = "deep" in lower
    explicitly_bounded = any(
        phrase in lower for phrase in ("do not", "must not", "never", "only explicit", "only in")
    )
    if reads_full_slice and not deep_only and not explicitly_bounded:
        print(f"  ! {rel}:{i}: unbounded default slice read is forbidden; "
              "reserve the full slice history for explicit deep mode")
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

run_hook_behavior() {
  printf '\n── Hook Behavior Fixtures ────────────────────────────────\n'
  if python3 - "$root" <<'PY'
import json, os, subprocess, sys, tempfile
from pathlib import Path

root = Path(sys.argv[1])
errors = []

def run_hook(tmp_root, name):
    env = dict(os.environ)
    env.pop("CCGS_ROOT", None)
    return subprocess.run(
        ["bash", str(root / ".opencode" / "hooks" / name)],
        cwd=tmp_root, env=env, capture_output=True, text=True, timeout=60,
    )

def git(tmp_root, *args):
    return subprocess.run(["git", "-C", str(tmp_root), *args],
                          check=True, capture_output=True, text=True)

def git_init(tmp_root):
    git(tmp_root, "init", "-q")

def git_commit_fixture(tmp_root):
    git(tmp_root, "config", "user.name", "CCGS Fixture")
    git(tmp_root, "config", "user.email", "fixture@example.invalid")
    (tmp_root / ".fixture").write_text("fixture\n", encoding="utf-8")
    git(tmp_root, "add", ".fixture")
    git(tmp_root, "commit", "-qm", "fixture baseline")
    return git(tmp_root, "rev-parse", "HEAD").stdout.strip()

def write_handoff(tmp_root, marker="HANDOFF FIXTURE"):
    p = tmp_root / "production" / "session-handoff.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(f"# Session Handoff\n\nCurrent Stage: production\nNext Action: {marker}\n",
                 encoding="utf-8")

def write_active(tmp_root, marker="ACTIVE FIXTURE", pointer_only=False):
    p = tmp_root / "production" / "session-state" / "active.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    if pointer_only:
        text = "# Active Session State\n\nSource: production/session-handoff.md\n"
    else:
        text = ("# Active Session State\n\nSource: production/session-handoff.md\n\n"
                "## Current Focus\n"
                f"- Task: {marker}\n\n"
                "## Session Worklist\n"
                "1. (Recommended) Fixture lane\n")
    p.write_text(text, encoding="utf-8")

def assert_order(label, out, first, second):
    a, b = out.find(first), out.find(second)
    if a < 0 or b < 0 or a >= b:
        errors.append(f"{label}: expected {first!r} before {second!r}")

scenarios = 0

with tempfile.TemporaryDirectory(prefix="ccgs-hook-behavior-") as t:
    scenarios += 1
    tr = Path(t); git_init(tr); head = git_commit_fixture(tr)
    write_handoff(tr); write_active(tr)
    r = run_hook(tr, "session-start.sh")
    if r.returncode != 0:
        errors.append(f"session-start rc={r.returncode}: {r.stderr!r}")
    if "ACTIVE SESSION STATE DETECTED" not in r.stdout:
        errors.append("session-start missing substantive active banner")
    assert_order("session-start handoff precedence", r.stdout, "HANDOFF FIXTURE", "ACTIVE FIXTURE")
    if "/resume-from-handoff" not in r.stdout:
        errors.append("session-start did not recommend /resume-from-handoff")
    try:
        baseline = json.loads((tr / "production" / "session-logs" / "session-baseline.json").read_text(encoding="utf-8"))
        if baseline.get("start_head") != head or not baseline.get("branch") or not baseline.get("started_at"):
            errors.append(f"session-start baseline contents wrong: {baseline!r}")
    except Exception as exc:
        errors.append(f"session-start baseline missing/invalid: {exc}")

with tempfile.TemporaryDirectory(prefix="ccgs-hook-behavior-") as t:
    scenarios += 1
    tr = Path(t); git_init(tr); git_commit_fixture(tr)
    write_handoff(tr, "HANDOFF ONLY")
    r = run_hook(tr, "session-start.sh")
    if "HANDOFF ONLY" not in r.stdout:
        errors.append("session-start handoff-only missing handoff preview")
    if "ACTIVE SESSION STATE DETECTED" in r.stdout:
        errors.append("session-start handoff-only invented substantive active state")

with tempfile.TemporaryDirectory(prefix="ccgs-hook-behavior-") as t:
    scenarios += 1
    tr = Path(t); git_init(tr); git_commit_fixture(tr)
    write_handoff(tr, "HANDOFF POINTER PRIMARY"); write_active(tr, pointer_only=True)
    r = run_hook(tr, "session-start.sh")
    if "POINTER-ONLY ACTIVE STATE DETECTED" not in r.stdout:
        errors.append("session-start missing pointer-only banner")
    assert_order("session-start pointer precedence", r.stdout,
                 "HANDOFF POINTER PRIMARY", "POINTER-ONLY ACTIVE STATE DETECTED")

with tempfile.TemporaryDirectory(prefix="ccgs-hook-behavior-") as t:
    scenarios += 1
    tr = Path(t); git_init(tr)
    write_handoff(tr, "COMPACT HANDOFF FALLBACK"); write_active(tr, "COMPACT ACTIVE PRIMARY")
    r = run_hook(tr, "pre-compact.sh")
    if "SESSION STATE BEFORE COMPACTION" not in r.stdout:
        errors.append("pre-compact missing header")
    assert_order("pre-compact active precedence", r.stdout,
                 "COMPACT ACTIVE PRIMARY", "COMPACT HANDOFF FALLBACK")
    r = run_hook(tr, "post-compact.sh")
    if "Context Restored After Compaction" not in r.stdout:
        errors.append("post-compact missing header")
    assert_order("post-compact active precedence", r.stdout,
                 "COMPACT ACTIVE PRIMARY", "COMPACT HANDOFF FALLBACK")

with tempfile.TemporaryDirectory(prefix="ccgs-hook-behavior-") as t:
    scenarios += 1
    tr = Path(t); git_init(tr)
    write_handoff(tr, "COMPACT HANDOFF ELEVATED"); write_active(tr, pointer_only=True)
    r = run_hook(tr, "pre-compact.sh")
    if "Canonical Handoff Recovery (elevated)" not in r.stdout:
        errors.append("pre-compact missing elevated handoff")
    assert_order("pre-compact pointer precedence", r.stdout,
                 "COMPACT HANDOFF ELEVATED", "Pointer-Only Active State")
    r = run_hook(tr, "post-compact.sh")
    if "Canonical Handoff Recovery (elevated)" not in r.stdout:
        errors.append("post-compact missing elevated handoff")
    assert_order("post-compact pointer precedence", r.stdout,
                 "COMPACT HANDOFF ELEVATED", "Pointer-Only Active State")

for e in errors:
    print(f"  ! {e}")
print(f"  hook behavior fixtures: {len(errors)} error(s) across {scenarios} scenario(s)")
sys.exit(1 if errors else 0)
PY
  then
    pass "hook behavior fixtures satisfied"
  else
    fail "hook behavior fixture violations"
  fi
}

run_negative_fixtures() {
  printf '\n── Negative Contract Fixtures ────────────────────────────\n'
  if python3 - "$root" <<'PY'
import os, re, sys
root = sys.argv[1]
base = os.path.join(root, ".opencode", "tests", "fixtures")
errors = []

def read(rel):
    path = os.path.join(base, rel)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as fh:
        return fh.read()

h = read("invalid-handoff-contract/.opencode/skills/handoff/SKILL.md")
if h is None:
    errors.append("invalid-handoff-contract fixture missing")
else:
    norm = re.sub(r"\s+", " ", h)
    m = re.match(r"^---\n(.*?)\n---", h, re.S)
    desc = ""
    if m:
        d = re.search(r"description:\s*[\"']?(.*?)[\"']?\s*$", m.group(1), re.M)
        desc = (d.group(1) if d else "").lower()
    if not any(w in desc for w in ("pause", "stop", "checkpoint", "resume later")):
        errors.append("handoff fixture: description must trip the invocation-boundary check")
    for phrase in ("## Context Capacity Gate",
                   "production/session-logs/session-baseline.json",
                   "## Fresh-Context Reviewer Contract",
                   "production/resume-index.md"):
        if phrase in norm:
            errors.append(f"handoff fixture: must lack contract phrase {phrase!r}")
    forbidden = {
        "same-session reviewer substitution": r"(?i)fresh same-session reasoning pass,\s*not an independent reviewer",
        "reviewer history fork via task_id": r"(?i)\btask_id\s*[:=]",
        "silent reviewer fallback": r"(?i)if the (?:reviewer|delegation)[^.\n]{0,80}(?:unavailable|blocked|fails?)[^.\n]{0,80}(?:continue|proceed)[^.\n]{0,80}same-session",
    }
    for label, pat in forbidden.items():
        if not re.search(pat, h):
            errors.append(f"handoff fixture: must trip forbidden pattern {label!r}")

r = read("invalid-resume-contract/.opencode/skills/resume-from-handoff/SKILL.md")
if r is None:
    errors.append("invalid-resume-contract fixture missing")
else:
    norm = re.sub(r"\s+", " ", r)
    for phrase in ("## Source Freshness",
                   "at most 200 lines or 32 KiB",
                   "production/resume-index.md"):
        if phrase in norm:
            errors.append(f"resume fixture: must lack contract phrase {phrase!r}")
    trips_unbounded = False
    trips_startup = False
    for line in r.splitlines():
        lower = line.lower()
        reads_full_slice = (
            re.search(r"\bread\b.*\b(?:entire|full|all)\b.*\b(?:slice|playable)[ -]?(?:source|history)?\b", lower)
            or re.search(r"\bread\b.*\b(?:slice|playable)[ -]?(?:source|history)?\b.*\b(?:entire|full|all)\b", lower)
            or re.search(r"\b(?:entire|full|all)\b.*\b(?:slice|playable)[ -]?(?:source|history)?\b.*\bread\b", lower)
        )
        if reads_full_slice and "deep" not in lower and not any(
            p in lower for p in ("do not", "must not", "never", "only explicit", "only in")
        ):
            trips_unbounded = True
        starts_lane = re.search(r"\b(?:start|begin|enter)\b", lower)
        bypasses = any(w in lower for w in ("automatically", "immediately", "without waiting", "without selection"))
        allowed = any(w in lower for w in ("do not", "don't", "never", "must not", "cannot"))
        if starts_lane and bypasses and not allowed:
            trips_startup = True
    if not trips_unbounded:
        errors.append("resume fixture: must trip the unbounded default slice-read check")
    if not trips_startup:
        errors.append("resume fixture: must trip the automatic lane startup check")

for e in errors:
    print(f"  ! {e}")
print(f"  negative fixtures: {len(errors)} error(s) across 2 fixture(s)")
sys.exit(1 if errors else 0)
PY
  then
    pass "negative fixtures detected as invalid"
  else
    fail "negative fixture detection gaps"
  fi
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

  # S8 project-created resume-index survives uninstall
  T="$base/s8"; mkdir -p "$T"
  bash "$inst" $MF "$T" >/dev/null 2>&1 || true
  mkdir -p "$T/production"
  printf '# Project-owned resume index\n' > "$T/production/resume-index.md"
  rc=0; out="$(bash "$uninst" "$T" 2>&1)" || rc=$?
  if [ -f "$T/production/resume-index.md" ]; then pass "S8 resume-index survives uninstall"; else fail "S8 uninstall removed project-created resume-index"; fi

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
    run_hook_behavior
    run_negative_fixtures
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
  hook-behavior) run_hook_behavior ;;
  fixtures)  run_negative_fixtures ;;
  runtime)  run_runtime ;;
  config)   run_config ;;
  install-safety) run_install_safety ;;
  coexistence) run_coexistence ;;
  smoke-headless) run_smoke_headless ;;
  hooks)    run_hooks ;;
  smoke)    run_smoke ;;
  release)  run_release ;;
    *) printf 'Unknown command: %s\nAvailable: all, agents, skills, closeout, checkpoint, playtest, bug-lifecycle, handoff-review, resume-contract, hook-behavior, fixtures, runtime, config, install-safety, coexistence, smoke-headless, hooks, smoke, release\n' "$command" >&2; exit 2 ;;
esac

printf '\n── Result: %d error(s) ──\n' "$errors"
[ "$errors" -eq 0 ] && printf 'All checks passed.\n' || printf 'Some checks failed.\n' >&2
exit $errors
