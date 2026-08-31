# Multi-Agent Peer Collaboration Contract (`AGENTS.md`)

Add the following configuration into your project's `.agent/AGENTS.md`, `AGENTS.md`, or system instructions to enforce disciplined multi-agent cross-verification:

```markdown
# 🤝 Multi-Agent Peer Collaboration & Verification Protocol

## 1. Roles & Architecture Division of Labor

- **Central Orchestrator & Implementer (Antigravity / Gemini)**:
  - **Global Context Assembly**: Analyzes whole-project topology and pinpoints relevant files/slices.
  - **Toolchain & Execution**: Runs build commands, automated tests, git operations, and code modifications.
  - **Workflow Supervision & Fallback**: Coordinates milestones and seamlessly takes over when external peers are unavailable.

- **Peer Advisory Council (External Specialized Agents)**:
  - **Claude CLI (`claude-collaborator`)**:
    - *System Architecture & State Machines*: `claude_design.sh "<requirement>" [context_files...]`
    - *Spec, Schema & Prompt Refinement*: `claude_refine.sh "<target_file>" "<goal>"`
    - *Pre-flight Git Diff Code Review*: `claude_review.sh [BASE_REF] "<task_description>"`
  - **OpenAI Codex / Specialized Peer Agents (Extensible)**:
    - *Algorithmic & Performance Optimization*: Dispatch specialized code synthesis or language-specific verifications.
    - *Cross-Model Second Opinion*: Consult secondary model when architecture trade-offs require contrasting perspectives.

---

## 2. Mandatory Lifecycle Dispatch Points

At each engineering milestone, the Orchestrator MUST consult external peer agents:

1. **Brainstorming & Architecture Phase**:
   - Before finalizing design docs or making non-trivial decisions, run `claude-design` to validate state-machine transitions, component boundaries, and failure modes.
2. **Specification & Schema Phase**:
   - When writing complex JSON schemas, prompt templates, or API contracts, run `claude-refine` to optimize clarity and remove ambiguity.
3. **Pre-flight Code Review Phase (Before Task Completion)**:
   - Before claiming any feature or major bugfix is complete, run `claude-review HEAD` (or diff against base branch) to check for regressions, memory leaks, missing edge cases, and test gaps.

---

## 3. Extensibility: Adding New Peer Agents (e.g., Codex, Custom CLI)

To extend this workflow with additional external models (such as OpenAI Codex or local LLMs):

1. Place the non-interactive wrapper script under `.agent/skills/<agent-name>/scripts/` or `~/.local/bin/` (e.g., `codex_review.sh`).
2. Follow the standard I/O convention:
   - Accept arguments: `<TASK_DESCRIPTION>` and optional `[CONTEXT_FILES...]` or `[BASE_GIT_REF]`.
   - On rate limits / quota failure: output `⚠️ [FALLBACK_TRIGGERED: <REASON>]` and exit with code `100`.
3. Reference the new agent command in this `AGENTS.md` protocol.

---

## 4. Graceful Self-Healing Fallback Protocol

- When any external peer agent CLI encounters API exhaustion, rate limits (429), or connectivity timeouts:
  1. The script will emit `⚠️ [FALLBACK_TRIGGERED: ...]` and exit with code `100`.
  2. The Orchestrator (Antigravity) will output a non-blocking log:
     *"External peer agent [AgentName] unavailable. Seamlessly switching to internal reasoning."*
  3. The Orchestrator immediately performs the review, design, or refinement internally.
  4. **The workflow must NEVER crash, hang, or halt due to external API limits.**
```
