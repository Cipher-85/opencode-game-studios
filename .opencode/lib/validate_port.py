#!/usr/bin/env python3
"""
validate_port.py — Structural validator for OpenCode Game Studios.

Validates the port against expected counts, frontmatter requirements,
stale-reference rules, and permission parity. Designed for CI.

Usage:
    python3 tools/validate_port.py [--root PATH]
    python3 tools/validate_port.py --root PATH --json
"""
import argparse
import json
import os
import re
import sys
import yaml

TOOL_MAP = {
    "Read": "read", "Glob": "glob", "Grep": "grep",
    "Write": "edit", "Edit": "edit", "Bash": "bash",
    "WebSearch": "websearch", "WebFetch": "webfetch", "Task": "task",
}

EXPECTED = {
    "agents": 49,
    "skills": 77,
    "commands": 77,
    "hooks_min": 12,
    "rules_min": 15,
    "agent_memory": 17,
}


def parse_frontmatter(path):
    with open(path) as f:
        txt = f.read()
    m = re.match(r"^---\n(.*?)\n---", txt, re.S)
    if not m:
        return None, txt
    try:
        return yaml.safe_load(m.group(1)), txt
    except yaml.YAMLError:
        return None, txt


def validate_agents(root):
    errors, warnings = [], []
    agents_dir = os.path.join(root, ".opencode", "agents")
    files = sorted(f for f in os.listdir(agents_dir) if f.endswith(".md"))
    count = len(files)

    if count != EXPECTED["agents"]:
        errors.append(f"agents: expected {EXPECTED['agents']}, got {count}")

    for f in files:
        path = os.path.join(agents_dir, f)
        fm, _ = parse_frontmatter(path)
        if fm is None:
            errors.append(f"{f}: no frontmatter")
            continue
        for field in ("description", "mode", "steps", "permission"):
            if field not in fm:
                errors.append(f"{f}: missing required field '{field}'")
        if fm.get("mode") != "subagent":
            errors.append(f"{f}: mode != subagent")
        meta = fm.get("metadata", {})
        if "ccgs_tier" not in meta:
            warnings.append(f"{f}: missing metadata.ccgs_tier")
        perm = fm.get("permission", {})
        if "'*'" not in str(perm) and "*" not in str(perm):
            warnings.append(f"{f}: no '*': deny catch-all in permission")
        if perm.get("question") != "allow":
            warnings.append(f"{f}: question not set to allow")
        if perm.get("todowrite") != "allow":
            warnings.append(f"{f}: todowrite not set to allow")

    return errors, warnings, {"agents": count}


def validate_skills(root):
    errors, warnings = [], []
    skills_dir = os.path.join(root, ".opencode", "skills")
    dirs = sorted(d for d in os.listdir(skills_dir)
                  if os.path.isdir(os.path.join(skills_dir, d)))
    count = len(dirs)

    if count < EXPECTED["skills"]:
        errors.append(f"skills: expected >={EXPECTED['skills']}, got {count}")

    for d in dirs:
        path = os.path.join(skills_dir, d, "SKILL.md")
        if not os.path.isfile(path):
            errors.append(f"skills/{d}: missing SKILL.md")
            continue
        fm, _ = parse_frontmatter(path)
        if fm is None:
            errors.append(f"skills/{d}: no frontmatter")
            continue
        if fm.get("name") != d:
            errors.append(f"skills/{d}: name '{fm.get('name')}' != dir name")
        if not fm.get("description"):
            errors.append(f"skills/{d}: missing description")

    return errors, warnings, {"skills": count}


def validate_commands(root):
    errors, warnings = [], []
    cmd_dir = os.path.join(root, ".opencode", "commands")
    files = sorted(f for f in os.listdir(cmd_dir) if f.endswith(".md"))
    count = len(files)
    if count < EXPECTED["commands"]:
        errors.append(f"commands: expected >={EXPECTED['commands']}, got {count}")
    return errors, warnings, {"commands": count}


def validate_stale_refs(root):
    errors, warnings = [], []
    patterns = [
        (r"\.claude/", "stale .claude/ path reference"),
        (r"\bCLAUDE\.md\b", "stale CLAUDE.md reference"),
        (r"\bClaude Code\b", "stale 'Claude Code' prose reference"),
    ]
    search_dirs = [
        os.path.join(root, ".opencode", "agents"),
        os.path.join(root, ".opencode", "skills"),
        os.path.join(root, ".opencode", "hooks"),
        os.path.join(root, ".opencode", "docs"),
    ]
    for search_dir in search_dirs:
        if not os.path.isdir(search_dir):
            continue
        for dirpath, _, files in os.walk(search_dir):
            if "node_modules" in dirpath:
                continue
            for fn in files:
                if not fn.endswith((".md", ".sh", ".yaml")):
                    continue
                fpath = os.path.join(dirpath, fn)
                with open(fpath) as f:
                    txt = f.read()
                # Skip metadata sections
                for pattern, msg in patterns:
                    matches = re.findall(pattern, txt)
                    if matches:
                        # Check if it's only in metadata
                        body_match = re.match(r"^---\n.*?\n---\n?(.*)", txt, re.S)
                        body = body_match.group(1) if body_match else txt
                        body_hits = re.findall(pattern, body)
                        if body_hits:
                            errors.append(f"{fn}: {msg} ({len(body_hits)} in body)")
    return errors, warnings, {}


def validate_config(root):
    errors, warnings = [], []
    config_path = os.path.join(root, "opencode.json")
    if not os.path.isfile(config_path):
        errors.append("opencode.json: missing")
        return errors, warnings, {}
    with open(config_path) as f:
        try:
            cfg = json.load(f)
        except json.JSONDecodeError as e:
            errors.append(f"opencode.json: invalid JSON ({e})")
            return errors, warnings, {}
    for field in ("$schema", "permission", "instructions", "plugin"):
        if field not in cfg:
            warnings.append(f"opencode.json: missing recommended field '{field}'")
    # Check instruction files exist
    for instr in cfg.get("instructions", []):
        full = os.path.join(root, instr)
        if not os.path.isfile(full):
            errors.append(f"instruction file missing: {instr}")
    return errors, warnings, {}


def validate_counts(root):
    errors, warnings = [], []
    hooks = len([f for f in os.listdir(os.path.join(root, ".opencode", "hooks"))
                 if f.endswith(".sh")])
    rules = len([f for f in os.listdir(os.path.join(root, ".opencode", "rules"))
                 if f.endswith(".md")])
    mem = sum(1 for _ in os.walk(os.path.join(root, ".opencode", "agent-memory")))
    mem_files = sum(len(files) for _, _, files in os.walk(
        os.path.join(root, ".opencode", "agent-memory")))

    if hooks < EXPECTED["hooks_min"]:
        errors.append(f"hooks: expected >={EXPECTED['hooks_min']}, got {hooks}")
    if rules < EXPECTED["rules_min"]:
        errors.append(f"rules: expected >={EXPECTED['rules_min']}, got {rules}")
    if mem_files < EXPECTED["agent_memory"]:
        errors.append(f"agent-memory: expected >={EXPECTED['agent_memory']}, got {mem_files}")

    return errors, warnings, {"hooks": hooks, "rules": rules, "agent_memory_files": mem_files}


def main():
    parser = argparse.ArgumentParser(description="Validate OpenCode Game Studios port")
    parser.add_argument("--root", default=".", help="Project root path")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    root = os.path.abspath(args.root)
    all_errors = []
    all_warnings = []
    counts = {}

    validators = [
        ("agents", validate_agents),
        ("skills", validate_skills),
        ("commands", validate_commands),
        ("stale_refs", validate_stale_refs),
        ("config", validate_config),
        ("counts", validate_counts),
    ]

    for name, validator in validators:
        e, w, c = validator(root)
        all_errors.extend(e)
        all_warnings.extend(w)
        counts.update(c)

    if args.json:
        print(json.dumps({
            "errors": all_errors,
            "warnings": all_warnings,
            "counts": counts,
            "passed": len(all_errors) == 0,
        }, indent=2))
    else:
        if all_errors:
            print(f"\n✗ {len(all_errors)} ERROR(S):")
            for e in all_errors:
                print(f"  ✗ {e}")
        else:
            print("\n✓ All validation checks passed")

        if all_warnings:
            print(f"\n⚠ {len(all_warnings)} WARNING(S):")
            for w in all_warnings:
                print(f"  ⚠ {w}")

        print(f"\nCounts: {counts}")

    sys.exit(1 if all_errors else 0)


if __name__ == "__main__":
    main()
