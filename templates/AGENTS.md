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
    - *Ideation & Approach Trade-offs*: `claude-brainstorm [--model <model>] [-c] "<requirement>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_brainstorm.sh`)
    - *System Architecture & State Machines*: `claude-design [--model <model>] [-c] "<requirement>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_design.sh`)
    - *Spec, Schema & Prompt Refinement*: `claude-refine [--model <model>] [-c] "<target_file>" "<goal>" [ref_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_refine.sh`)
    - *Pre-flight Git Diff Code Review*: `claude-review [--model <model>] [-c] [BASE_REF] "<task_description>"` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_review.sh`)
    - *Session Follow-up & Iteration*: `claude-followup [--model <model>] "<followup_prompt>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_followup.sh`)
  - **OpenAI Codex (`agent-collaborator`)**:
    - *Engineering Feasibility & Contrarian Ideation*: `codex-brainstorm [--model <model>] [-c] "<requirement>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_brainstorm.sh`)
    - *Algorithmic, Performance & Terminal/CI Automation*: `codex-optimize [--model <model>] [-c] "<task_or_requirement>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_optimize.sh`)
    - *Session Follow-up & Iteration*: `codex-followup [--model <model>] "<followup_prompt>" [context_files...]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_followup.sh`)
    - *Cross-Model Second Opinion*: Consult Codex when architecture or review trade-offs from Claude require a contrasting perspective.
    - *Computer Use (GUI verification)*: Codex's screen-driven mouse/keyboard control is only available via the **Codex desktop/ChatGPT app**, not this headless CLI script. If a task needs actual GUI interaction (verifying a UI in a browser/Figma/Xcode/Slack), say so explicitly and route it to a human or the Codex app — do not assume `codex-optimize` can do it.
  - **Model Selection & Sizing**:
    - All peer agent commands support dynamic model specification via `--model <name>` / `-m <name>` or environment variables (`CLAUDE_MODEL`, `CODEX_MODEL`, `AGENT_MODEL`).
    - The Orchestrator (Antigravity) can select faster/cost-effective models (e.g. `haiku`, `o3-mini`) for lightweight tasks or top-tier models (e.g. `opus`, `sonnet`, `o3`) for critical architectural design and security reviews.
  - **Other Specialized Peer Agents (Extensible)**: see Section 5 below.

> **Execution Notes by Driver Platform**:
> 1. **Antigravity (Gemini as Central Orchestrator)**:
>    - **Sandbox Bypass**: External peer agent tools (`claude-brainstorm`, `claude-design`, `claude-refine`, `claude-review`, `claude-followup`, `codex-brainstorm`, `codex-optimize`, `codex-followup`, `agent-deliberate`, `consensus-round`) execute host binaries (`~/.local/bin/claude`, `~/.local/bin/codex`) and require internet access. You **MUST** execute them using `run_command` with `BypassSandbox: true`. Do NOT execute in standard sandbox mode.
>    - **Direct Invocation**: Directly invoke `claude-brainstorm`, `codex-brainstorm`, `claude-design`, `claude-refine`, `claude-review`, `claude-followup`, `codex-followup`, `codex-optimize`, `agent-deliberate`, or `consensus-round` (in `~/.local/bin` on PATH) or use the explicit absolute path `bash ~/.gemini/config/skills/agent-collaborator/scripts/<script>.sh`. Do NOT spend turns running `which` or searching for scripts.
>    - **Sandbox Error Handling**: If an execution ever fails with Exit 126, "Operation not permitted", or outputs `❌ [SANDBOX_BLOCKED]`, it indicates standard sandbox mode blocked the host binary. Immediately re-run with `BypassSandbox: true`. DO NOT trigger fallback for sandbox errors.
> 2. **Claude Code CLI (`claude` as Central Orchestrator)**:
>    - When running directly in Claude Code CLI, Claude is the primary orchestrator! It executes Superpowers skills directly (`superpowers:brainstorming`, `superpowers:systematic-debugging`, etc.).
>    - Claude CLI does **NOT** call `claude-brainstorm`, `claude-design` or `claude-review` on itself (avoiding nested recursive sessions). Instead, it can consult `codex-brainstorm` / `codex-optimize` for engineering feasibility, algorithmic/terminal tasks, or perform native verification.

---

## 2. Mandatory Lifecycle Dispatch Points

At each engineering milestone, the Orchestrator MUST consult external peer agents:

1. **Brainstorming & Ideation Phase**:
   - When exploring new features or major designs, run `claude-brainstorm` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_brainstorm.sh`) to explore 2-3 distinct approaches, architectural trade-offs, and critical risks.
   - For technical feasibility, ecosystem/standard-library alternatives, or a contrarian perspective, run `codex-brainstorm` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_brainstorm.sh`).
2. **Architecture & State Machine Phase**:
   - Before finalizing design docs or making non-trivial architectural decisions, run `claude-design` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_design.sh`) to validate state-machine transitions, component boundaries, and failure modes.
3. **Specification & Schema Phase**:
   - When writing complex JSON schemas, prompt templates, or API contracts, run `claude-refine` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_refine.sh`) to optimize clarity and remove ambiguity.
4. **Pre-flight Code Review Phase (Before Task Completion)**:
   - Before claiming any feature or major bugfix is complete, run `claude-review HEAD` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_review.sh HEAD`) to check for regressions, memory leaks, missing edge cases, and test gaps.
5. **Performance / Algorithmic / Automation Phase**:
   - Before finalizing a hot-path implementation, or when a task is heavy shell/CI/terminal automation, run `codex-optimize` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_optimize.sh`) to get Codex's optimization pass instead of Claude's.
6. **Multi-Agent Consensus Deliberation Phase**:
   - When facing architectural disputes, complex design trade-offs, or high-stakes system designs, run `agent-deliberate` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/agent_deliberate.sh`) to conduct a multi-turn, ring-structured deliberation among Claude, Codex, and Jetski against the structured metric table.

---

## 3. Asynchronous Coordination & Anti-Premature Completion Protocol

Because external peer agent CLIs perform deep LLM reasoning, commands typically take 15–30 seconds and will execute as **background tasks** in Antigravity.

1. **Strictly Prohibit Premature Milestone Completion**:
   - While `claude-brainstorm`, `codex-brainstorm`, `claude-design`, `claude-review`, or `agent-deliberate` is running in the background, the milestone is **IN PROGRESS, NOT COMPLETE**.
   - You **MUST NOT** finalize `implementation_plan.md`, declare "設計已完成" (design completed) or "審查已通過" (review passed), or prompt the user for execution approval while the task is still executing.
2. **Turn Yielding & Reactive Wake-Up**:
   - When `run_command` moves to the background: output a brief status update (e.g., *"已啟動 `claude-brainstorm` 進行發散思維與方案評估，等待 Claude 分析完成以整合至計畫中..."*) and **STOP calling tools immediately** to end your turn.
   - Do NOT poll or busy-wait. The Antigravity reactive messaging system will automatically wake you up when the peer agent finishes.
3. **Mandatory Synthesis**:
   - Upon wake-up with peer output, thoroughly examine recommendations, incorporate identified edge cases and failure modes into `implementation_plan.md`, and only then present the synthesized plan to the user.

---

## 4. Multi-Turn Collaboration & Memory Anti-Hallucination Protocol

External peer agent CLIs are **stateless by default**. The Orchestrator MUST NOT invoke raw stateless commands referencing phantom context (e.g. `claude -p "Based on the earlier review findings..."`) without passing continuity or context files!

1. **In-Agent Continuity (Same Agent)**:
   - When iterating with the same model across multiple turns in the current directory, use `claude-followup` / `codex-followup` or add `-c` / `--continue` to continue the most recent session.
   - *Note on Concurrency*: Session continuation targets the most recently modified session in the working directory; avoid running concurrent tasks in the same cwd if relying on `-c`.
2. **Cross-Agent Synthesis (Codex findings + Claude review -> Final Document)**:
   - Different models do NOT share session storage. Claude cannot access Codex sessions and vice-versa.
   - For cross-model workflows, always use **Explicit Context Piping**: save review/brainstorm output or pass reference files directly into `claude-refine <target> "<goal>" [ref_files...]` or context files to `claude-design`.

---

## 5. Extensibility: Adding New Peer Agents (e.g., Custom/Local CLIs)

To extend this workflow with additional external models beyond Claude CLI and Codex (e.g. local LLMs, other vendor CLIs):

1. Place the non-interactive wrapper script under `.agent/skills/<agent-name>/scripts/` or `~/.local/bin/` (e.g., `codex_review.sh`).
2. Follow the standard I/O convention:
   - Accept arguments: `<TASK_DESCRIPTION>` and optional `[CONTEXT_FILES...]` or `[BASE_GIT_REF]`.
   - On rate limits / quota failure: output `⚠️ [FALLBACK_TRIGGERED: <REASON>]` and exit with code `100`.
3. Reference the new agent command in this `AGENTS.md` protocol.

---

## 6. Graceful Self-Healing Fallback Protocol

- **Sandbox Block vs. API Exhaustion vs. Input Error Distinction**:
  - If a script exits with `126`, outputs `Operation not permitted`, or outputs `❌ [SANDBOX_BLOCKED]`: Re-run once with `BypassSandbox: true`. If 126 persists after one re-run, switch to internal reasoning fallback to prevent infinite retry loops.
  - If a script exits with `1` (missing arguments, missing files, or no recorded session to resume): This is a caller input error, NOT an API outage. Fix arguments or invoke without `-c`. Do NOT trigger fallback.
  - Only when an external peer agent CLI encounters API exhaustion, rate limits (429), or connectivity timeouts (exit code 100):
    1. The script will emit `⚠️ [FALLBACK_TRIGGERED: ...]` and exit with code `100`.
    2. The Orchestrator (Antigravity) will output a non-blocking log:
       *"External peer agent [AgentName] unavailable. Seamlessly switching to internal reasoning."*
    3. The Orchestrator immediately performs the review, design, or refinement internally.
    4. **The workflow must NEVER crash, hang, or halt due to external API limits.**

---

## 7. Multi-Agent Consensus Deliberation Protocol (`agent-deliberate`)

When facing major architectural trade-offs, conflicting implementation designs, or contentious technical decisions, the Orchestrator initiates a structured consensus deliberation using `agent-deliberate`.

### 1. Ring Topology & Role Division
- **Antigravity (Gemini Main Agent / Discussion Moderator)**:
  - **Neutral Host**: Frames the topic and candidate options, defines the mandatory **Option 0** baseline, generates anonymized round digests (`digest.md`), deterministically tallies ballots with `jq`, and synthesizes the final blueprint (`final_blueprint.md`). Does not cast a subjective vote in peer rounds to prevent confirmation bias.
- **Claude Agent (`claude` CLI - Architect & Edge-Case Hunter)**:
  - **Independent Voting Peer**: Focuses on high-level system topology, module boundaries, formal state machines, failure modes, and regression prevention. Evaluates proposals and registers blocking objections or architectural flags.
- **Codex Agent (`codex` CLI - Pragmatic Red Team & YAGNI Watchdog)**:
  - **Independent Voting Peer / Red Team**: Focuses on codebase simplicity, standard-library alternatives, performance/resource efficiency, terminal/CI automation, and over-architecture audits. Challenges speculative abstractions and enforces YAGNI.
- **Jetski Agent (Antigravity Native Subagent - Empirical Spike Probe)**:
  - **Empirical Evidence Collector**: Gathers ground truth when factual claims, benchmark performance, or API behaviors are disputed. Runs throwaway spikes, tests, or profiling scripts. Does not cast a subjective vote (preventing Gemini double-voting).

### 2. Structured Metric Table & Ballot Schema
All voting peers score proposals against five core metrics (scale 1-5):
1. `technical_feasibility`: Does the solution work within current OS, CLI, runtime, and API limits without undocumented assumptions?
2. `architectural_simplicity`: Are components decoupled, understandable in isolation, and free of circular dependencies?
3. `yagni_and_parsimony` (The Anti-Overarchitecture Metric): Strict economy of design; every line of abstraction must serve an active requirement.
4. `robustness_failure_modes`: Are timeout, partial failure, rate limits, exit codes (0/1/100/126), and state corruptions handled cleanly?
5. `maintainability_testability`: Can this design be verified with automated unit/integration tests without complex test harnesses?

Each ballot also registers:
- `preferred_option`: Selected architectural candidate (`Option_0`, `Option_A`, `Option_B`, etc.).
- `stance`: `ACCEPT`, `ACCEPT_WITH_RESERVATIONS`, or `BLOCK`.
- `over_architecture_flags`: Flags for `PREMATURE_GENERALIZATION`, `UNNECESSARY_PERSISTENCE`, `EXCESSIVE_INDIRECTION`, or `SPECULATIVE_CONFIG`.
- `blocking_objections`: Identified objections categorized as `factual`, `tradeoff`, or `ambiguity`.
- `position_changes`: Explicit citations of peer arguments justifying any stance change across rounds (guards against unreasoned sycophancy).

### 3. Anti-Overarchitecture & Parsimony Veto
- **Mandatory Option 0 MVA Baseline**: Round 1 requires defining `Option_0` (Minimal Viable Architecture using native/OS primitives with zero speculative abstractions). Any alternative option bears a complexity tax and must justify why Option 0 is insufficient.
- **Parsimony Veto**: Any proposal whose average `yagni_and_parsimony` score is below `3.5`, or has unaddressed `over_architecture_flags`, is disqualified from consensus. Proponents must either simplify the design in the next round or prove strict necessity.

### 4. Deterministic Convergence & Bounded Termination
- **Deterministic Convergence Gate (`CONVERGED`)**:
  - Unanimous `preferred_option` across all voting peers.
  - Zero open `BLOCK` stances.
  - Score spread $\le 1.0$ across all core metrics.
  - Average `yagni_and_parsimony` $\ge 3.5$.
- **Bounded Termination (`MAX_ROUNDS=3` -> `DEADLOCK`)**:
  - Deliberation is strictly bounded to `MAX_ROUNDS` (default: 3 rounds).
  - Round 1 is blind (eliminates anchoring bias).
  - Subsequent rounds distribute an anonymized digest (`digest.md`) addressing specific objection IDs.
  - If unconverged after `MAX_ROUNDS`, the process terminates with status `DEADLOCK`, outputs `dissent_register.md` capturing irreconcilable trade-offs and empirical data, and escalates to the human operator for tie-breaking.

### 5. CLI Usage & Commands
```bash
# Full multi-round deliberation runner:
agent-deliberate [--rounds 3] [--model-claude <model>] [--model-codex <model>] "<TOPIC_OR_REQUIREMENT>" [CONTEXT_FILES...]
# Example:
agent-deliberate --rounds 3 "Design an in-memory cache strategy with TTL eviction for CLI tools"

# Single-round concurrent driver (executes Claude and Codex concurrently):
consensus-round [--max-rounds 3] [--model-claude <model>] [--model-codex <model>] <DELIBERATION_DIR> <ROUND_NUM>
```
```
