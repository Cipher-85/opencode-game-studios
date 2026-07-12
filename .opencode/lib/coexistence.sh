#!/usr/bin/env bash
# lib/coexistence.sh — Coexistence detection, guards, backup, and tracking
#
# Detects foreign Game Studios runtimes (Claude Code, Codex), protects their
# paths, preserves shared content, backs up before overwrite, and manages the
# .gitignore allowlist. Sourced by install.sh, uninstall.sh, and release.sh.

# ── Markers ──────────────────────────────────────────────────────

ccgs_marker_start="<!-- BEGIN CCGS OPENCODE PORT -->"
ccgs_marker_end="<!-- END CCGS OPENCODE PORT -->"
ccgs_gitignore_start="# BEGIN CCGS OPENCODE PORT GITIGNORE"
ccgs_gitignore_end="# END CCGS OPENCODE PORT GITIGNORE"
ccgs_install_state_rel=".opencode/install-state.json"
ccgs_state_schema=2

# ── Root resolution ──────────────────────────────────────────────

ccgs_find_root() {
  if [ -n "${CCGS_ROOT:-}" ]; then
    printf '%s\n' "$CCGS_ROOT"
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

# ── Runtime detection ────────────────────────────────────────────

ccgs_has_claude() {
  [ -f "${target_root:-$PWD}/CLAUDE.md" ] && return 0
  [ -f "${target_root:-$PWD}/claude.md" ] && return 0
  [ -d "${target_root:-$PWD}/.claude" ] && return 0
  return 1
}

ccgs_has_claude_ccgs() {
  [ -f "${target_root:-$PWD}/.claude/agents/creative-director.md" ] && return 0
  [ -f "${target_root:-$PWD}/.claude/skills/start/SKILL.md" ] && return 0
  [ -f "${target_root:-$PWD}/.claude/docs/workflow-catalog.yaml" ] && return 0
  return 1
}

ccgs_has_codex() {
  [ -d "${target_root:-$PWD}/.codex" ] && return 0
  [ -d "${target_root:-$PWD}/.agents" ] && return 0
  return 1
}

ccgs_has_codex_ccgs() {
  [ -f "${target_root:-$PWD}/.codex/agents/creative-director.toml" ] && return 0
  [ -f "${target_root:-$PWD}/.codex/VERSION" ] && return 0
  [ -f "${target_root:-$PWD}/.agents/skills/start/SKILL.md" ] && return 0
  return 1
}

ccgs_has_opencode_prior() {
  [ -f "${target_root:-$PWD}/.opencode/install-state.json" ] && return 0
  [ -f "${target_root:-$PWD}/.opencode/VERSION" ] && return 0
  [ -f "${target_root:-$PWD}/.opencode/agents/creative-director.md" ] && return 0
  return 1
}

ccgs_detect_mode() {
  local claude=0 claude_ccgs=0 codex=0 codex_ccgs=0 prior=0 runtimes=0

  ccgs_has_claude && claude=1
  ccgs_has_claude_ccgs && claude_ccgs=1
  ccgs_has_codex && codex=1
  ccgs_has_codex_ccgs && codex_ccgs=1
  ccgs_has_opencode_prior && prior=1

  runtimes=$((claude + codex))

  if [ "$runtimes" -gt 1 ]; then
    printf 'multi_runtime\n'
  elif [ "$claude_ccgs" -eq 1 ]; then
    printf 'claude_ccgs_coexist\n'
  elif [ "$codex_ccgs" -eq 1 ]; then
    printf 'codex_ccgs_coexist\n'
  elif [ "$claude" -eq 1 ]; then
    printf 'claude_present\n'
  elif [ "$codex" -eq 1 ]; then
    printf 'codex_present\n'
  elif [ "$prior" -eq 1 ]; then
    printf 'opencode_prior\n'
  else
    printf 'opencode_clean\n'
  fi
}

ccgs_detect_runtimes() {
  local found=""
  ccgs_has_claude_ccgs && found="${found}claude_ccgs "
  ccgs_has_codex_ccgs && found="${found}codex_ccgs "
  ccgs_has_claude && { echo "$found" | grep -q "claude_" || found="${found}claude "; }
  ccgs_has_codex && { echo "$found" | grep -q "codex_" || found="${found}codex "; }
  ccgs_has_opencode_prior && found="${found}opencode_prior "
  echo "$found" | xargs
}

ccgs_print_mode_summary() {
  local mode="$1"
  local runtimes
  runtimes="$(ccgs_detect_runtimes)"
  printf 'Detected mode: %s\n' "$mode"
  if [ -n "$runtimes" ]; then
    printf 'Runtimes: %s\n' "$runtimes"
  fi
}

# ── Foreign path refusal (hard guard) ────────────────────────────

ccgs_is_foreign_path() {
  local path="$1"
  case "$path" in
    .claude/*|CLAUDE.md|*/.claude/*|*/CLAUDE.md) return 0 ;;
    .codex/*|*/.codex/*) return 0 ;;
    .agents/*|*/.agents/*) return 0 ;;
    *) return 1 ;;
  esac
}

ccgs_refuse_foreign_path() {
  local path="$1"
  if ccgs_is_foreign_path "$path"; then
    printf 'ERROR: refusing to modify foreign-runtime path: %s\n' "$path" >&2
    exit 1
  fi
}

# ── Shared path detection ────────────────────────────────────────

ccgs_is_shared_path() {
  local path="$1"
  case "$path" in
    "CCGS Skill Testing Framework"/*) return 0 ;;
    docs/WORKFLOW-GUIDE.md) return 0 ;;
    docs/COLLABORATIVE-DESIGN-PRINCIPLE.md) return 0 ;;
    docs/engine-reference/*) return 0 ;;
    docs/architecture/*) return 0 ;;
    docs/examples/*) return 0 ;;
    docs/registry/*) return 0 ;;
    design/registry/*) return 0 ;;
    design/AGENTS.md) return 0 ;;
    design/gdd/systems-index.md) return 0 ;;
    production/session-state/*) return 0 ;;
    production/sprints/*) return 0 ;;
    production/epics/*) return 0 ;;
    src/.gitkeep) return 0 ;;
    *) return 1 ;;
  esac
}

ccgs_should_preserve_shared() {
  # Returns 0 if the path should be preserved in coexistence mode.
  # Args: path target_root mode
  local path="$1" root="$2" mode="$3"
  case "$mode" in
    claude_ccgs_coexist|codex_ccgs_coexist|multi_runtime)
      ccgs_is_shared_path "$path" && [ -e "$root/$path" ] && return 0
      ;;
  esac
  return 1
}

# ── Backup ───────────────────────────────────────────────────────

ccgs_backup_file() {
  local path="$1" root="${2:-${target_root:-$PWD}}"
  local target_file="$root/$path"
  [ -f "$target_file" ] || return 0
  local stamp backup_dir
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_dir="$root/.opencode/backups/$stamp"
  mkdir -p "$backup_dir/$(dirname "$path")"
  cp "$target_file" "$backup_dir/$path"
}

ccgs_backup_if_differs() {
  local path="$1" source_root="${2:-${source_root:-}}" root="${3:-${target_root:-$PWD}}"
  local source_file="$source_root/$path"
  local target_file="$root/$path"
  [ -f "$target_file" ] || return 0
  [ -f "$source_file" ] || return 0
  if ! cmp -s "$source_file" "$target_file"; then
    ccgs_backup_file "$path" "$root"
  fi
}

# ── SHA256 hashing (for incremental patching) ────────────────────

ccgs_sha256_file() {
  local file="$1"
  [ -f "$file" ] || return 1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    python3 -c "
import hashlib, sys
with open('$file', 'rb') as f:
    print(hashlib.sha256(f.read()).hexdigest())
" 2>/dev/null
  fi
}

ccgs_incremental_unchanged() {
  # Returns 0 if the source file's SHA256 matches what was recorded in install-state.
  # Args: path source_root target_root
  local path="$1" source_root="$2" target_root="$3"
  local state_file="$target_root/$ccgs_install_state_rel"
  [ -f "$state_file" ] || return 1
  local source_file="$source_root/$path"
  [ -f "$source_file" ] || return 1
  local current_hash
  current_hash="$(ccgs_sha256_file "$source_file")" || return 1
  python3 -c "
import json, sys
try:
    with open('$state_file') as f:
        state = json.load(f)
    recorded = state.get('installed_file_hashes', {}).get('$path', '')
    sys.exit(0 if recorded == '$current_hash' else 1)
except:
    sys.exit(1)
" 2>/dev/null
}

# ── Marker-block management ──────────────────────────────────────

ccgs_extract_marker_block() {
  local source_file="$1"
  python3 - "$source_file" "$ccgs_marker_start" "$ccgs_marker_end" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
start, end = sys.argv[2], sys.argv[3]
si = text.find(start)
ei = text.find(end)
if si == -1 or ei == -1 or ei < si:
    raise SystemExit(f"missing marker block")
ei += len(end)
print(text[si:ei])
PY
}

ccgs_write_marker_block() {
  local target_file="$1" block="$2"
  python3 - "$target_file" "$ccgs_marker_start" "$ccgs_marker_end" "$block" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
start, end, block = sys.argv[2], sys.argv[3], sys.argv[4].rstrip() + "\n"
text = path.read_text(encoding="utf-8") if path.exists() else ""
si = text.find(start)
ei = text.find(end)
if si != -1 and ei != -1 and ei >= si:
    ei += len(end)
    updated = text[:si] + block.rstrip() + text[ei:]
else:
    sep = "" if not text or text.endswith("\n\n") else "\n\n"
    updated = text + sep + block
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(updated.rstrip() + "\n", encoding="utf-8")
PY
}

ccgs_remove_marker_block() {
  local target_file="$1"
  [ -f "$target_file" ] || return 0
  python3 - "$target_file" "$ccgs_marker_start" "$ccgs_marker_end" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
start, end = sys.argv[2], sys.argv[3]
text = path.read_text(encoding="utf-8")
si = text.find(start)
ei = text.find(end)
if si == -1 or ei == -1 or ei < si:
    raise SystemExit(3)  # not found
ei += len(end)
updated = (text[:si].rstrip() + "\n\n" + text[ei:].lstrip()).strip()
if updated:
    path.write_text(updated + "\n", encoding="utf-8")
else:
    path.unlink()
PY
}

# ── .gitignore allowlist management ──────────────────────────────

ccgs_update_gitignore_allowlist() {
  local root="${1:-${target_root:-$PWD}}"
  local gitignore="$root/.gitignore"
  [ -f "$gitignore" ] || return 0

  # Generate allowlist entries from manifest
  local manifest="$root/.opencode/manifest/installed-files.json"
  [ -f "$manifest" ] || return 0

  ccgs_backup_file ".gitignore" "$root"

  python3 - "$gitignore" "$manifest" "$ccgs_gitignore_start" "$ccgs_gitignore_end" <<'PY'
import json, sys
from pathlib import Path

gitignore = Path(sys.argv[1])
manifest = json.loads(Path(sys.argv[2]).read_text())
start, end = sys.argv[3], sys.argv[4]

paths = sorted({f["path"] for f in manifest.get("files", [])})
lines = [start, "# Added by OpenCode Game Studios so installed files remain trackable."]
for p in paths:
    lines.append("!" + p.replace(" ", "\\ "))
lines.append("# Keep the live session checkpoint local while preserving production/session-state/.gitkeep.")
lines.append("/production/session-state/active.md")
lines.append(end)
block = "\n".join(lines) + "\n"

text = gitignore.read_text() if gitignore.exists() else ""
si = text.find(start)
ei = text.find(end)
if si != -1 and ei != -1 and ei >= si:
    ei += len(end)
    updated = text[:si] + block.rstrip() + text[ei:]
else:
    sep = "\n\n" if text and not text.endswith("\n\n") else ""
    updated = text + sep + block
gitignore.write_text(updated.rstrip() + "\n", encoding="utf-8")
PY
}

ccgs_remove_gitignore_allowlist() {
  local root="${1:-${target_root:-$PWD}}"
  local gitignore="$root/.gitignore"
  [ -f "$gitignore" ] || return 0

  python3 - "$gitignore" "$ccgs_gitignore_start" "$ccgs_gitignore_end" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
start, end = sys.argv[2], sys.argv[3]
text = path.read_text(encoding="utf-8")
si = text.find(start)
ei = text.find(end)
if si == -1 or ei == -1 or ei < si:
    raise SystemExit(3)
ei += len(end)
updated = (text[:si].rstrip() + "\n\n" + text[ei:].lstrip()).strip()
if updated:
    path.write_text(updated + "\n", encoding="utf-8")
else:
    path.unlink()
PY
}

# ── Install-state read/write ─────────────────────────────────────

ccgs_install_state_file() {
  printf '%s/%s\n' "${target_root:-$PWD}" "$ccgs_install_state_rel"
}

ccgs_state_validate() {
  # Validate install-state.json. Returns: 0 valid, 1 invalid, 2 missing.
  # Prints a reason to stderr when invalid. Args: target_root (optional)
  local root="${1:-${target_root:-$PWD}}"
  local state_file="$root/$ccgs_install_state_rel"
  if [ ! -f "$state_file" ]; then
    printf 'install-state missing: %s\n' "$state_file" >&2
    return 2
  fi
  if [ -L "$state_file" ]; then
    printf 'install-state is a symlink (unsafe): %s\n' "$state_file" >&2
    return 1
  fi
  python3 - "$state_file" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    data = json.loads(p.read_text(encoding="utf-8"))
except Exception as e:
    print(f"malformed install-state JSON: {e}", file=sys.stderr); sys.exit(1)
if data.get("schema_version") != 2:
    print(f"unsupported schema_version: {data.get('schema_version')}", file=sys.stderr); sys.exit(1)
for key in ("installed_file_hashes", "shared_paths_created", "shared_paths_preserved"):
    val = data.get(key, {})
    items = val.keys() if isinstance(val, dict) else val
    for rel in items:
        s = str(rel)
        if s.startswith("/") or ".." in s.split("/"):
            print(f"unsafe path in {key}: {s}", file=sys.stderr); sys.exit(1)
sys.exit(0)
PY
}

ccgs_state_owned_paths() {
  # Emit package-owned paths from install-state, one per line.
  # Caller MUST validate state first. Args: target_root (optional)
  local root="${1:-${target_root:-$PWD}}"
  local state_file="$root/$ccgs_install_state_rel"
  python3 - "$state_file" <<'PY'
import json, sys
from pathlib import Path
try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception:
    sys.exit(1)
items = data.get("installed_file_hashes", {})
paths = items.keys() if isinstance(items, dict) else items
for rel in sorted(paths):
    print(rel)
PY
}

ccgs_write_install_state() {
  # Args: target_root source_root mode patch_mode opus_model sonnet_model haiku_model primary_model
  #       opus_variant sonnet_variant haiku_variant preserved_file created_file
  local target_root="$1" source_root="$2" mode="$3" patch_mode="$4"
  local opus_model="$5" sonnet_model="$6" haiku_model="$7" primary_model="$8"
  local opus_var="$9" sonnet_var="${10}" haiku_var="${11}"
  local preserved_file="${12}" created_file="${13}"
  local manifest="$source_root/.opencode/manifest/installed-files.json"

  python3 - "$target_root" "$source_root" "$mode" "$patch_mode" \
    "$opus_model" "$sonnet_model" "$haiku_model" "$primary_model" \
    "$opus_var" "$sonnet_var" "$haiku_var" \
    "$preserved_file" "$created_file" "$manifest" \
    "$ccgs_marker_start" "$ccgs_marker_end" <<'PY'
import hashlib, json, sys
from datetime import datetime, timezone
from pathlib import Path

target = Path(sys.argv[1])
source_root = Path(sys.argv[2])
mode, patch_mode = sys.argv[3], sys.argv[4]
opus_m, sonnet_m, haiku_m, primary_m = sys.argv[5:9]
opus_v, sonnet_v, haiku_v = sys.argv[9:12]
preserved_file, created_file = sys.argv[12], sys.argv[13]
manifest_path = sys.argv[14]
marker_start, marker_end = sys.argv[15], sys.argv[16]

def lines(path):
    p = Path(path)
    return [l for l in p.read_text().splitlines() if l] if p.exists() else []

def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()

# Build file hashes from manifest
manifest = json.loads(Path(manifest_path).read_text())
file_hashes = {}
marker_hashes = {}
for entry in manifest.get("files", []):
    rel = entry["path"]
    src = source_root / rel
    if not src.is_file():
        continue
    data = src.read_bytes()
    file_hashes[rel] = sha256_bytes(data)
    if rel == "AGENTS.md" or rel.endswith("/AGENTS.md"):
        text = data.decode("utf-8")
        si = text.find(marker_start)
        ei = text.find(marker_end)
        if si != -1 and ei != -1 and ei >= si:
            ei += len(marker_end)
            marker_hashes[rel] = sha256_bytes(text[si:ei].encode("utf-8"))

now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

# Detect runtimes for the state record
runtimes = []
for signal, name in [
    (target / ".claude" / "agents" / "creative-director.md", "claude_ccgs"),
    (target / "CLAUDE.md", "claude"),
    (target / ".codex" / "VERSION", "codex_ccgs"),
    (target / ".codex", "codex"),
]:
    if signal.exists():
        runtimes.append(name)

state = {
    "schema_version": 2,
    "installed_at": now,
    "detected_mode": mode,
    "patch_mode": patch_mode,
    "ccgs_version": (source_root / ".opencode" / "VERSION").read_text().strip()
        if (source_root / ".opencode" / "VERSION").exists() else "unknown",
    "foreign_runtimes": runtimes,
    "shared_paths_preserved": lines(preserved_file),
    "shared_paths_created": lines(created_file),
    "installed_file_hashes": file_hashes,
    "marker_block_hashes": marker_hashes,
    "models": {
        "opus": opus_m, "sonnet": sonnet_m, "haiku": haiku_m, "primary": primary_m
    },
    "variants": {
        "opus": opus_v, "sonnet": sonnet_v, "haiku": haiku_v
    },
}

state_path = target / ".opencode" / "install-state.json"
state_path.parent.mkdir(parents=True, exist_ok=True)
state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}
