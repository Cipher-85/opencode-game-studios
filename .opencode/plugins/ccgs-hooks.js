/**
 * CCGS Hooks Plugin — OpenCode events → Claude-shaped shell scripts.
 *
 * Uses node:child_process.spawn for portable script execution (no Bun shell
 * dependency). Includes payload capture for Stage 2 runtime verification and
 * __test exports for unit testing normalization functions.
 *
 * Event map:
 *   session.created                  → session-start.sh, detect-gaps.sh
 *   tool.execute.before (bash)       → validate-commit.sh, validate-push.sh
 *   tool.execute.before (task)       → log-agent.sh
 *   tool.execute.after (write/edit)  → validate-assets.sh, validate-skill-change.sh
 *   tool.execute.after (task)        → log-agent-stop.sh
 *   experimental.session.compacting  → pre-compact.sh (injects output.context[])
 *   session.compacted                → post-compact.sh
 *   session.idle                     → session-stop.sh
 */

import { spawn } from "node:child_process"
import fs from "node:fs"
import path from "node:path"

// ── Constants ────────────────────────────────────────────────────

const HOOK_TIMEOUT_DEFAULT = 10000
const HOOK_TIMEOUT_COMMIT = 15000

const TOOL_NAME = {
  bash: "Bash",
  write: "Write",
  edit: "Edit",
  apply_patch: "Edit",
  patch: "Edit",
  task: "Task",
}

// ── Helpers ──────────────────────────────────────────────────────

function firstDefined(...values) {
  return values.find((v) => v !== undefined && v !== null && v !== "")
}

/**
 * Extract file path from an apply_patch / patch payload.
 * Handles both current JSON and legacy raw-patch formats.
 */
function extractApplyPatchPath(patchText = "") {
  const patterns = [
    /^\*\*\* (?:Add|Update|Delete) File: (.+)$/m,
    /^--- [ab]\/(.+)$/m,
    /^\+\+\+ [ab]\/(.+)$/m,
  ]
  for (const pattern of patterns) {
    const match = patchText.match(pattern)
    if (match) {
      const p = match[1].trim()
      if (p && p !== "/dev/null") return p
    }
  }
  return ""
}

/**
 * Normalize a tool.execute.before/after payload into Claude-shaped JSON
 * that the shell scripts expect on stdin.
 */
function normalizeToolExecution(input = {}, output = {}) {
  const tool = input.tool || input.tool_name || input.name || ""
  const args = { ...(input.args || {}), ...(input.tool_input || {}), ...(output.args || {}) }

  const payload = {
    tool_name: TOOL_NAME[tool] || tool,
    tool_input: {},
  }

  if (tool === "bash") {
    payload.tool_input.command = firstDefined(args.command, args.cmd, "")
  } else if (["write", "edit", "apply_patch", "patch"].includes(tool)) {
    const filePath = firstDefined(args.filePath, args.file_path, "")
    if (filePath) {
      payload.tool_input.file_path = filePath
    } else if (tool === "apply_patch" || tool === "patch") {
      const patchText = firstDefined(args.patch, args.diff, "")
      const extracted = extractApplyPatchPath(patchText)
      if (extracted) payload.tool_input.file_path = extracted
    }
  } else if (tool === "task") {
    payload.agent_type = firstDefined(args.subagent_type, args.type, "unknown")
  }

  return payload
}

/**
 * Normalize a session/event payload for hooks that read agent_type or message.
 */
function normalizeEventPayload(event = {}) {
  const type = event.type || event.name || ""
  const properties = event.properties || event
  if (type === "tui.toast.show") {
    return {
      message: firstDefined(properties.message, properties.text, properties.title, ""),
    }
  }
  return {
    event: type,
    session_id: firstDefined(properties.sessionID, properties.session_id, properties.id, ""),
    cwd: firstDefined(properties.cwd, properties.directory, ""),
  }
}

// ── Payload capture (Stage 2 runtime verification) ──────────────

function capturePayload(root, eventName, payload) {
  try {
    const dir = path.join(root, "porting-reports", "runtime-payload-captures")
    fs.mkdirSync(dir, { recursive: true })
    const file = path.join(dir, `${eventName}.jsonl`)
    fs.appendFileSync(
      file,
      JSON.stringify({ captured_at: new Date().toISOString(), payload }) + "\n"
    )
  } catch {
    // capture is best-effort
  }
}

// ── Script runner ───────────────────────────────────────────────

/**
 * Run a hook script with stdin payload. Returns { code, stdout, stderr }.
 * Throws on non-zero exit if options.blocking is true.
 */
async function runScript(root, scriptName, payload, options = {}) {
  const script = path.join(root, ".opencode", "hooks", scriptName)
  const child = spawn("bash", [script], {
    cwd: root,
    stdio: ["pipe", "pipe", "pipe"],
  })

  let stdout = ""
  let stderr = ""
  child.stdout.on("data", (chunk) => { stdout += chunk.toString() })
  child.stderr.on("data", (chunk) => { stderr += chunk.toString() })

  child.stdin.end(JSON.stringify(payload || {}))

  const code = await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      child.kill("SIGTERM")
      reject(new Error(`Hook ${scriptName} timed out`))
    }, options.timeoutMs || HOOK_TIMEOUT_DEFAULT)

    child.on("close", (exitCode) => {
      clearTimeout(timeout)
      resolve(exitCode)
    })
    child.on("error", reject)
  })

  const output = `${stdout}${stderr}`.trim()

  if (options.blocking && code !== 0) {
    throw new Error(output || `Hook ${scriptName} blocked with exit code ${code}`)
  }

  if (output) {
    // Advisory output — visible but non-blocking
    console.warn(output)
  }

  return { code, stdout, stderr }
}

// ── Root resolution ─────────────────────────────────────────────

function resolveRoot(directory, worktree) {
  const candidate = worktree || directory || process.cwd()
  return candidate && candidate !== "/" ? candidate : process.cwd()
}

// ── Plugin export ───────────────────────────────────────────────

export default async function CCGSHooks({ directory, worktree }) {
  const root = resolveRoot(directory, worktree)

  return {
    // ── Session events ──────────────────────────────────────────
    event: async ({ event }) => {
      const payload = normalizeEventPayload(event)
      capturePayload(root, event.type || "event", payload)

      if (event.type === "session.created") {
        await runScript(root, "session-start.sh", payload)
        await runScript(root, "detect-gaps.sh", payload)
      } else if (event.type === "session.compacted") {
        await runScript(root, "post-compact.sh", payload)
      } else if (event.type === "session.idle") {
        await runScript(root, "session-stop.sh", payload)
      }
    },

    // ── PreToolUse emulation ────────────────────────────────────
    "tool.execute.before": async (input, output) => {
      const payload = normalizeToolExecution(input, output)
      capturePayload(root, `tool.execute.before.${input.tool || "unknown"}`, payload)

      if (input.tool === "bash") {
        await runScript(root, "validate-commit.sh", payload, {
          blocking: true, timeoutMs: HOOK_TIMEOUT_COMMIT,
        })
        await runScript(root, "validate-push.sh", payload, {
          blocking: true, timeoutMs: HOOK_TIMEOUT_DEFAULT,
        })
      } else if (input.tool === "task") {
        await runScript(root, "log-agent.sh", payload)
      }
    },

    // ── PostToolUse emulation ───────────────────────────────────
    "tool.execute.after": async (input, output) => {
      const payload = normalizeToolExecution(input, output)
      capturePayload(root, `tool.execute.after.${input.tool || "unknown"}`, payload)

      if (["write", "edit", "apply_patch", "patch"].includes(input.tool)) {
        await runScript(root, "validate-assets.sh", payload, {
          blocking: true, timeoutMs: HOOK_TIMEOUT_DEFAULT,
        })
        await runScript(root, "validate-skill-change.sh", payload)
      } else if (input.tool === "task") {
        await runScript(root, "log-agent-stop.sh", payload)
      }
    },

    // ── PreCompact emulation ────────────────────────────────────
    "experimental.session.compacting": async (input, output) => {
      const payload = normalizeEventPayload({
        type: "experimental.session.compacting", ...input,
      })
      capturePayload(root, "experimental.session.compacting", payload)

      const result = await runScript(root, "pre-compact.sh", payload)
      output.context = output.context || []
      if (result.stdout.trim()) {
        output.context.push(result.stdout)
      }
    },
  }
}

// ── Test exports ────────────────────────────────────────────────

CCGSHooks.__test = {
  normalizeToolExecution,
  normalizeEventPayload,
  extractApplyPatchPath,
}
