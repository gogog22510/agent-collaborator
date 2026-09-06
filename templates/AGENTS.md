# Multi-Agent Peer Collaboration Contract (`AGENTS.md`)

`./install.sh --project <path>` automatically injects the ```markdown ... ``` block below into `<path>/AGENTS.md` for you (idempotently — pass `--no-agents-md` to skip it). This file is the source `install.sh` extracts from; the manual steps below are for reference or for injecting into a different location (`.agent/AGENTS.md`, system instructions, etc.) by hand:

```markdown
# 🤝 Multi-Agent Peer Collaboration & Verification Protocol

## 1. Roles & Architecture Division of Labor

- **Central Orchestrator & Implementer (Antigravity / Gemini)**:
  - **Global Context Assembly**: Analyzes whole-project topology and pinpoints relevant files/slices.
  - **Toolchain & Execution**: Runs build commands, automated tests, git operations, and code modifications.
  - **Workflow Supervision & Fallback**: Coordinates milestones and seamlessly takes over when external peers are unavailable.
  - **Engineering Discipline (Adaptive Dual-Mode)**:
    - *When Superpowers is installed* (e.g. `brainstorming`, `systematic-debugging`, `test-driven-development`, `verification-before-completion` are available):
      - **New Features / Design**: MUST invoke `brainstorming` skill before writing implementation plans or touching code.
      - **Bugfix / Failure**: MUST invoke `systematic-debugging` skill to find root cause before modifying code.
      - **Code Implementation**: MUST strictly follow `test-driven-development` (write failing test first).
      - **Verification**: MUST invoke `verification-before-completion` before claiming completion.
    - *When Superpowers is NOT installed (Standalone Mode)*:
      - The Orchestrator proceeds with disciplined internal reasoning and standard planning, without requiring external skill calls or throwing errors.
    - *Informational Q&A Exemption (Both Modes)*:
      - Pure conceptual queries, codebase explanations, architecture walkthroughs, and syntax questions that do NOT modify code or fix bugs are EXEMPT from heavy engineering workflows and must be answered directly.

- **Peer Advisory Council (External Specialized Agents)**:
  - **Claude CLI (`agent-collaborator`)**:
    - *System Architecture & State Machines*: `claude-design "<requirement>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_design.sh`)
    - *Spec, Schema & Prompt Refinement*: `claude-refine "<target_file>" "<goal>"` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_refine.sh`)
    - *Pre-flight Git Diff Code Review*: `claude-review [BASE_REF] "<task_description>"` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_review.sh`)
  - **OpenAI Codex (`agent-collaborator`)**:
    - *Algorithmic, Performance & Terminal/CI Automation*: `codex-optimize "<task_or_requirement>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_optimize.sh`)
    - *Cross-Model Second Opinion*: Consult Codex when architecture or review trade-offs from Claude require a contrasting perspective.
    - *Computer Use (GUI verification)*: Codex's screen-driven mouse/keyboard control is only available via the **Codex desktop/ChatGPT app**, not this headless CLI script. If a task needs actual GUI interaction (verifying a UI in a browser/Figma/Xcode/Slack), say so explicitly and route it to a human or the Codex app — do not assume `codex-optimize` can do it.
  - **Other Specialized Peer Agents (Extensible)**: see Section 4 below.

> **Execution Note for Antigravity (Gemini)**:
> 1. **Sandbox Bypass**: External peer agent tools (`claude-design`, `claude-refine`, `claude-review`) execute host binaries (`~/.local/bin/claude`) and require internet access to Claude API. You **MUST** execute them using `run_command` with `BypassSandbox: true`. Do NOT execute in standard sandbox mode.
> 2. **Direct Invocation**: Directly invoke `claude-design`, `claude-refine`, or `claude-review` (in `~/.local/bin` on PATH) or use the explicit absolute path `bash ~/.gemini/config/skills/agent-collaborator/scripts/<script>.sh`. Do NOT spend turns running `which` or searching for scripts.
> 3. **Sandbox Error Handling**: If an execution ever fails with Exit 126, "Operation not permitted", or outputs `❌ [SANDBOX_BLOCKED]`, it indicates standard sandbox mode blocked the host binary. Immediately re-run with `BypassSandbox: true`. DO NOT trigger fallback for sandbox errors.

---

## 2. Mandatory Lifecycle Dispatch Points

At each engineering milestone, the Orchestrator MUST consult external peer agents:

1. **Brainstorming & Architecture Phase**:
   - Before finalizing design docs or making non-trivial decisions, run `claude-design` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_design.sh`) to validate state-machine transitions, component boundaries, and failure modes.
2. **Specification & Schema Phase**:
   - When writing complex JSON schemas, prompt templates, or API contracts, run `claude-refine` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_refine.sh`) to optimize clarity and remove ambiguity.
3. **Pre-flight Code Review Phase (Before Task Completion)**:
   - Before claiming any feature or major bugfix is complete, run `claude-review HEAD` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_review.sh HEAD`) to check for regressions, memory leaks, missing edge cases, and test gaps.
4. **Performance / Algorithmic / Automation Phase**:
   - Before finalizing a hot-path implementation, or when a task is heavy shell/CI/terminal automation, run `codex-optimize` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_optimize.sh`) to get Codex's optimization pass instead of Claude's.

---

## 3. Asynchronous Coordination & Anti-Premature Completion Protocol

Because external peer agent CLIs perform deep LLM reasoning, commands typically take 15–30 seconds and will execute as **background tasks** in Antigravity.

1. **Strictly Prohibit Premature Milestone Completion**:
   - While `claude-design` or `claude-review` is running in the background, the milestone is **IN PROGRESS, NOT COMPLETE**.
   - You **MUST NOT** finalize `implementation_plan.md`, declare "設計已完成" (design completed) or "審查已通過" (review passed), or prompt the user for execution approval while the task is still executing.
2. **Turn Yielding & Reactive Wake-Up**:
   - When `run_command` moves to the background: output a brief status update (e.g., *"已啟動 `claude-design` 進行架構諮詢，等待 Claude 分析完成以整合至計畫中..."*) and **STOP calling tools immediately** to end your turn.
   - Do NOT poll or busy-wait. The Antigravity reactive messaging system will automatically wake you up when the peer agent finishes.
3. **Mandatory Synthesis**:
   - Upon wake-up with Claude's output, thoroughly examine Claude's recommendations, incorporate identified edge cases and failure modes into `implementation_plan.md`, and only then present the synthesized plan to the user.

---

## 4. Extensibility: Adding New Peer Agents (e.g., Custom/Local CLIs)

To extend this workflow with additional external models beyond Claude CLI and Codex (e.g. local LLMs, other vendor CLIs):

1. Place the non-interactive wrapper script under `.agent/skills/<agent-name>/scripts/` or `~/.local/bin/` (e.g., `codex_review.sh`).
2. Follow the standard I/O convention:
   - Accept arguments: `<TASK_DESCRIPTION>` and optional `[CONTEXT_FILES...]` or `[BASE_GIT_REF]`.
   - On rate limits / quota failure: output `⚠️ [FALLBACK_TRIGGERED: <REASON>]` and exit with code `100`.
3. Reference the new agent command in this `AGENTS.md` protocol.

---

## 5. Graceful Self-Healing Fallback Protocol

- **Sandbox Block vs. API Exhaustion Distinction**:
  - If a script exits with `126`, outputs `Operation not permitted`, or outputs `❌ [SANDBOX_BLOCKED]`: Re-run immediately with `BypassSandbox: true`. Do NOT trigger fallback.
  - Only when an external peer agent CLI encounters API exhaustion, rate limits (429), or connectivity timeouts (exit code 100):
    1. The script will emit `⚠️ [FALLBACK_TRIGGERED: ...]` and exit with code `100`.
    2. The Orchestrator (Antigravity) will output a non-blocking log:
       *"External peer agent [AgentName] unavailable. Seamlessly switching to internal reasoning."*
    3. The Orchestrator immediately performs the review, design, or refinement internally.
    4. **The workflow must NEVER crash, hang, or halt due to external API limits.**
```
