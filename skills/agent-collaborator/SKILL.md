---
name: agent-collaborator
description: Coordinate with external coding agents (Claude CLI, OpenAI Codex, etc.) on the local machine for architecture design, code review, spec optimization, and prompt engineering with automatic fallback.
---

# Universal Agent Collaborator Skill

This skill enables a universal, language-agnostic **Multi-Agent / Dual-Agent Workflow** between **Antigravity (Gemini)** and external peer agents (**Claude CLI, OpenAI Codex, etc.**), featuring **Automatic Graceful Fallback**.

## Roles & Division of Labor

- **Claude CLI (Primary Architect & Reviewer)**:
  - Divergent ideation & approach trade-offs (`claude_brainstorm.sh`)
  - Deep architecture & state-machine design (`claude_design.sh`)
  - Rigorous code review, vulnerability detection & regression prevention (`claude_review.sh`)
  - Spec / Prompt / Documentation refinement (`claude_refine.sh`)
- **OpenAI Codex (Performance & Automation Specialist)** — dispatch here when the task plays to Codex's actual strengths:
  - Engineering feasibility, ecosystem alternatives & contrarian perspectives (`codex_brainstorm.sh`)
  - Algorithmic complexity / performance-hotspot analysis and heavy shell/CLI/CI automation (`codex_optimize.sh`). Codex leads Terminal-Bench-style agentic shell tasks and typically uses far fewer tokens per task, making it the cheaper choice for high-volume, terminal-heavy consultations.
  - Second opinion / cross-model verification on architecture or review conclusions from Claude, when trade-offs are contentious.
  - **Computer Use (GUI-driven tasks)**: recent Codex (via the ChatGPT desktop/Codex app, not the headless CLI) can see the screen and drive the mouse/keyboard to operate real apps (browser, Figma, Xcode, Slack, etc.). This is genuinely useful for visually verifying a UI change, testing an external app's behavior, or interacting with tools that have no CLI/API — but it is **not scriptable non-interactively** the way `codex exec` is. When a task needs this, tell the user/operator to drive it manually from the Codex desktop app rather than expecting an automated script to do it; do not fabricate a headless "computer use" script.
- **Primary Agent (Antigravity / Gemini - The Orchestrator & Implementer)**:
  - Project discovery, codebase-wide search & context assembly
  - File generation & refactoring across any language stack
  - Toolchain execution (build tools, linters, test runners, git)
  - **Self-Healing Fallback**: When an external agent hits rate limits, credit limits, or errors (exit code 100 or `FALLBACK_TRIGGERED`), Antigravity seamlessly assumes the Design / Review / Optimization role and continues without halting the task.

## Universal Helper Scripts

Scripts auto-detect the current project type (`pubspec.yaml`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, etc.) and run non-interactively without blocking stdin.

They are globally available at: `~/.gemini/config/skills/agent-collaborator/scripts/` (or locally at `.agent/skills/agent-collaborator/scripts/` or standalone in `~/.local/bin/`).

> ⚠️ **Antigravity Sandbox Requirement**: External peer agent tools (`claude-brainstorm`, `claude-design`, `claude-refine`, `claude-review`) execute host binaries (`~/.local/bin/claude`) and require outbound internet access to the Claude API. In Antigravity, you **MUST** run them using `run_command` with `BypassSandbox: true`. Do NOT run them in standard sandbox mode.

### 1. Divergent Brainstorming & Ideation (Claude)
```bash
claude-brainstorm "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_brainstorm.sh "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
```

### 2. Engineering Feasibility & Contrarian Brainstorming (Codex)
```bash
codex-brainstorm "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_brainstorm.sh "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
```

### 3. Architecture & Solution Design
```bash
claude-design "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_design.sh "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
```

### 4. Universal Code Review
```bash
claude-review [BASE_GIT_REF] "<TASK_DESCRIPTION>"
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_review.sh [BASE_GIT_REF] "<TASK_DESCRIPTION>"
```

### 5. Prompt & Spec Refinement
```bash
claude-refine "<FILE_PATH>" "<OPTIMIZATION_GOAL>"
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_refine.sh "<FILE_PATH>" "<OPTIMIZATION_GOAL>"
```

### 6. Algorithmic / Performance / Terminal Automation (Codex)
```bash
codex-optimize "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_optimize.sh "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
```

## Asynchronous Execution & Anti-Premature Completion Protocol

Because Claude CLI and Codex perform deep LLM reasoning, commands typically take 15–30 seconds, exceeding Antigravity's maximum synchronous wait limit (10,000ms) and running as **background tasks**.

### 🛑 CRITICAL: Do NOT Prematurely Finalize Milestones
When a peer agent command (`claude-brainstorm`, `codex-brainstorm`, `claude-design`, `claude-review`, `claude-refine`, `codex-optimize`) is sent to the background:
1. **The milestone is NOT complete**: You **MUST NOT** write a final `implementation_plan.md`, declare "設計已完成" (design completed) or "審查通過" (review passed), or invite the user to proceed. Doing so invalidates the peer collaboration.
2. **End Your Turn & Wait**:
   - Briefly notify the user (e.g. *"已啟動 `claude-design` 進行架構諮詢，正在等待 Claude 分析反饋以整合至設計計畫中..."*).
   - **STOP calling tools immediately** to end your turn.
   - The Antigravity messaging system will automatically wake you up with the full output as soon as the background task completes.
3. **Synthesize Peer Feedback Upon Wake-Up**:
   - When the task completes and delivers peer recommendations, thoroughly review architecture boundaries, state machine edge cases, and failure modes.
   - Synthesize these insights directly into `implementation_plan.md` (under a dedicated section such as `### 🏛️ Peer Architecture Consultation`).
   - Present the integrated, production-grade plan to the user only AFTER synthesis.

## Sandbox Handling & Graceful Fallback Protocol

### 1. Sandbox Permissions (Exit 126 / "Operation not permitted")
- If a command fails with Exit 126, `Operation not permitted`, or outputs `❌ [SANDBOX_BLOCKED]`, this is a sandbox restriction error, **NOT** an API exhaustion or unavailable peer agent.
- **DO NOT** trigger fallback to internal reasoning.
- **ACTION**: Immediately re-run the command with `BypassSandbox: true` in `run_command`.

### 2. Graceful Fallback Protocol (Exit Code 100)
- Only when the script outputs `⚠️ [FALLBACK_TRIGGERED: ...]` or exits with `100` (due to actual API rate limits, quota exhaustion, or service outage):
  1. Log a non-blocking notice: *"External peer agent unavailable. Seamlessly switching to internal reasoning for this phase."*
  2. Antigravity immediately executes the Design, Review, Prompt Refinement, or Optimization task itself using its own model reasoning.
  3. The workflow never blocks or fails due to external API limits.
