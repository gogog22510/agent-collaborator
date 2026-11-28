# Multi-Agent Peer Collaboration Contract (`AGENTS.md`)

`./install.sh --project <path>` automatically injects the ````markdown ... ```` block below into `<path>/AGENTS.md` for you (idempotently — pass `--no-agents-md` to skip it). This file is the source `install.sh` extracts from; the manual steps below are for reference or for injecting into a different location (`.agent/AGENTS.md`, system instructions, etc.) by hand:

````markdown
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

- **Peer Advisory Council (Tri-Model: Gemini Native Subagent + External Specialized Agents)**:
  - **Gemini Peer Subagent (Antigravity Native `invoke_subagent`)**:
    - *Isolated Fresh-Context Peer*: In Antigravity, ALWAYS dispatch a read-only `research` subagent (`invoke_subagent`, `TypeName: "research"`, `Model: "inherit"`) concurrently alongside available external CLIs so Gemini contributes an independent perspective free of main-thread confirmation bias.
    - *Task Roles*: Assign a clear role (`Gemini Brainstormer`, `Gemini Architect`, `Gemini Spec Reviewer`, `Gemini Code Reviewer`, `Gemini Performance Reviewer`, or `Gemini Deliberation Peer`).
    - *Code Review Input*: Because `research` subagents run in a read-only sandbox, pass the `git diff` (or changed file paths + diff summary) directly in the subagent prompt.
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
    - All peer agent commands support dynamic model specification via `--model <name>` / `-m <name>` or environment variables (`CLAUDE_MODEL`, `CODEX_MODEL`, `AGENT_MODEL`). Claude wrappers also support `--effort <low|medium|high>` (env fallback: `CLAUDE_EFFORT`) to tune reasoning depth vs. latency.
    - The Orchestrator (Antigravity) can select faster/cost-effective models (e.g. `haiku`, `o3-mini`) for lightweight tasks or top-tier models (e.g. `opus`, `sonnet`, `o3`) for critical architectural design and security reviews. For large multi-file context (>30 KB) on Claude, consider passing `--effort medium` (or `--model sonnet`) to keep latency bounded within 1–3 minutes.
  - **Other Specialized Peer Agents (Extensible)**: see Section 5 below.

> **Execution Notes by Driver Platform**:
> 1. **Antigravity (Gemini as Central Orchestrator)**:
>    - **Sandbox Bypass**: External peer agent tools (`claude-brainstorm`, `claude-design`, `claude-refine`, `claude-review`, `claude-followup`, `codex-brainstorm`, `codex-optimize`, `codex-followup`, `agent-deliberate`, `consensus-round`) execute host binaries (`~/.local/bin/claude`, `~/.local/bin/codex`) and require internet access. You **MUST** execute them using `run_command` with `BypassSandbox: true`. Do NOT execute in standard sandbox mode.
>    - **Direct Invocation**: Directly invoke `claude-brainstorm`, `codex-brainstorm`, `claude-design`, `claude-refine`, `claude-review`, `claude-followup`, `codex-followup`, `codex-optimize`, `agent-deliberate`, or `consensus-round` (in `~/.local/bin` on PATH) or use the explicit absolute path `bash ~/.gemini/config/skills/agent-collaborator/scripts/<script>.sh`. Do NOT spend turns running `which` or searching for scripts.
>    - **Sandbox Error Handling**: If an execution ever fails with Exit 126, "Operation not permitted", or outputs `❌ [SANDBOX_BLOCKED]`, it indicates standard sandbox mode blocked the host binary. Immediately re-run with `BypassSandbox: true`. DO NOT trigger fallback for sandbox errors.
> 2. **Claude Code CLI (`claude` as Central Orchestrator)**:
>    - When running directly in Claude Code CLI, Claude is the primary orchestrator! It executes Superpowers skills directly (`superpowers:brainstorming`, `superpowers:systematic-debugging`, etc.).
>    - Claude CLI does **NOT** call `claude-brainstorm`, `claude-design` or `claude-review` on itself (avoiding nested recursive sessions), and does NOT use Antigravity's `invoke_subagent`. Instead, it can consult `codex-brainstorm` / `codex-optimize` for engineering feasibility, algorithmic/terminal tasks, or perform native verification.

---

## 2. Mandatory Lifecycle Dispatch Points

At each engineering milestone (when running in Antigravity), dispatch **Gemini Peer Subagent (`invoke_subagent`, `TypeName: "research"`) concurrently in the same turn alongside available external CLIs (`claude-*` / `codex-*`)**, then wait for all peers to return and synthesize their perspectives together:

1. **Brainstorming & Ideation Phase**:
   - Dispatch `invoke_subagent` (`TypeName: "research"`, `Role: "Gemini Brainstormer"`) for an independent fresh-context exploration of approaches, trade-offs, and risks.
   - Concurrently (when available), run `claude-brainstorm` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_brainstorm.sh`) for divergent ideation and `codex-brainstorm` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_brainstorm.sh`) for engineering feasibility, standard-library alternatives, or a contrarian perspective.
2. **Architecture & State Machine Phase**:
   - Dispatch `invoke_subagent` (`TypeName: "research"`, `Role: "Gemini Architect"`) concurrently with `claude-design` (when available) to validate state-machine transitions, component boundaries, and failure modes.
3. **Specification & Schema Phase**:
   - Dispatch `invoke_subagent` (`TypeName: "research"`, `Role: "Gemini Spec Reviewer"`) concurrently with `claude-refine` (when available) to optimize clarity, schema rigor, and remove ambiguity.
4. **Pre-flight Code Review Phase (Before Task Completion)**:
   - Dispatch `invoke_subagent` (`TypeName: "research"`, `Role: "Gemini Code Reviewer"`, including `git diff HEAD` / changed file paths in the prompt) concurrently with `claude-review HEAD` (when available) to check for regressions, memory leaks, missing edge cases, and test gaps.
5. **Performance / Algorithmic / Automation Phase**:
   - Dispatch `invoke_subagent` (`TypeName: "research"`, `Role: "Gemini Performance Reviewer"`) concurrently with `codex-optimize` (when available) for hot-path analysis or heavy shell/CI/terminal automation.
6. **Multi-Agent Consensus Deliberation Phase**:
   - When facing architectural disputes, complex design trade-offs, or high-stakes system designs, run a 3-peer ring-structured deliberation among **Gemini Peer Subagent**, **Claude CLI**, and **Codex CLI** (with **Jetski** as non-voting empirical spike probe) using `agent-deliberate` / `consensus-round` (see Section 7).

---

## 3. Asynchronous Coordination & Anti-Premature Completion Protocol

Because native Gemini subagents (`invoke_subagent`) and external peer agent CLIs perform deep LLM reasoning, they run asynchronously in the background.

1. **Strictly Prohibit Premature Milestone Completion**:
   - While any dispatched **Gemini Peer Subagent** (`invoke_subagent`) or external CLI (`claude-brainstorm`, `codex-brainstorm`, `claude-design`, `claude-review`, `agent-deliberate`, `consensus-round`) is still running, the milestone is **IN PROGRESS, NOT COMPLETE**.
   - You **MUST NOT** finalize `implementation_plan.md`, declare "設計已完成" (design completed) or "審查已通過" (review passed), or prompt the user for execution approval while any peer is still executing.
2. **Turn Yielding & Reactive Wake-Up**:
   - Launch the Gemini Peer Subagent and available external CLI commands **in the same turn**, output a brief status update (e.g., *"已併發啟動 Gemini Subagent 與 `claude-design` 進行架構諮詢，等待所有回報完成後整合至計畫中..."*), and **STOP calling tools immediately** to end your turn.
   - Do NOT poll or busy-wait. The Antigravity reactive messaging system will automatically wake you up as each peer finishes. Wait until ALL dispatched peers have returned before synthesizing.
   - **Heartbeat & Long-Running Opus Calls**: Claude wrappers emit a startup metadata line (`model`, `effort`, `prompt_bytes`) and a 30s stderr heartbeat (`still waiting for Claude CLI (Xs elapsed)...`). If a notification fires while `claude-design` / `claude-brainstorm` is running on Opus with large multi-file context (which can legitimately take 3–8 minutes), check the task log: **active heartbeats mean the process is healthy and waiting on the API — do NOT prematurely kill it as hung**. If faster turnaround is needed, pass `--effort medium` or `--model sonnet` on invocation.
3. **Mandatory Cross-Model Synthesis**:
   - Upon wake-up with all peer outputs, compare agreements, conflicting trade-offs, and unique edge cases caught by Gemini Peer, Claude, and Codex; incorporate them into `implementation_plan.md`, and only then present the synthesized plan to the user.

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
    3. The Orchestrator proceeds using the **Gemini Peer Subagent's** independent review (if dispatched) or performs the review, design, or refinement internally.
    4. **The workflow must NEVER crash, hang, or halt due to external API limits.**

---

## 7. Multi-Agent Consensus Deliberation Protocol (`agent-deliberate`)

When facing major architectural trade-offs, conflicting implementation designs, or contentious technical decisions, the Orchestrator initiates a structured 3-peer consensus deliberation using `agent-deliberate` and `consensus-round`.

### 1. Ring Topology & Role Division
- **Antigravity Main Agent (Discussion Moderator — Non-Voting)**:
  - **Neutral Host**: Frames the topic and candidate options, defines the mandatory **Option 0** baseline, dispatches peers concurrently, validates and atomically writes `gemini_ballot.json`, runs deterministic `jq` tallying, and synthesizes the final blueprint (`final_blueprint.md`). Does **not** cast a subjective vote.
- **Gemini Peer Subagent (`invoke_subagent`, `TypeName: "research"` — Independent Voting Peer)**:
  - **Fresh-Context Voting Peer**: Runs in an isolated, read-only context receiving only the raw topic, options, context files, and (for Round > 1) the anonymized `digest.md` — never the Moderator's personal leanings. Casts an equal structured ballot (`gemini_ballot.json`).
- **Claude Agent (`claude` CLI — Architect & Edge-Case Hunter)**:
  - **Independent Voting Peer**: Focuses on high-level system topology, module boundaries, formal state machines, failure modes, and regression prevention. Evaluates proposals and registers blocking objections or architectural flags.
- **Codex Agent (`codex` CLI — Pragmatic Red Team & YAGNI Watchdog)**:
  - **Independent Voting Peer / Red Team**: Focuses on codebase simplicity, standard-library alternatives, performance/resource efficiency, terminal/CI automation, and over-architecture audits. Challenges speculative abstractions and enforces YAGNI.
- **Jetski Agent (Antigravity Native Subagent — Empirical Spike Probe, Non-Voting)**:
  - **Empirical Evidence Collector**: Gathers ground truth only when `factual` blocking objections are disputed. Runs throwaway spikes, tests, or profiling scripts. Does **not** cast a subjective vote.

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
- **Parsimony Veto**: Any proposal with a per-peer `yagni_and_parsimony` score below `3.0`, average `yagni_and_parsimony` below `3.5`, or unaddressed `over_architecture_flags` is disqualified from consensus. Proponents must either simplify the design in the next round or prove strict necessity.

### 4. Deterministic Convergence, 2-of-3 Survival Quorum & Bounded Termination
- **Quorum Rule**: At least **2 valid ballots** are required (`quorum_met: true`). In 3-peer mode (tracked via `manifest.json` `"voters"`), if one external CLI fails or is unavailable while Gemini Peer + the surviving CLI succeed, deliberation proceeds as a valid **reduced quorum** (`reduced_quorum: true`, with `absent_peers` / `invalid_peers` recorded in `tally.json`). Only 0 or 1 valid ballots produce `DEGRADED` in `tally.json` and `NO_QUORUM` (exit `3`) in `agent-deliberate` — never falsely reported as `DEADLOCK`.
- **Deterministic Convergence Gate (`CONVERGED` / `CONVERGED_WITH_DISSENT`)**:
  - Unanimous `preferred_option` across all participating valid voting peers.
  - Zero open `BLOCK` stances, active blocking objections, or active over-architecture flags.
  - Per-peer `yagni_and_parsimony` $\ge 3.0$ and average `yagni_and_parsimony` $\ge 3.5$.
  - Score spread (`max - min`) $\le 1.0$ across all 5 core metrics yields `CONVERGED`; if all other gates pass but any metric spread $> 1.0$, yields `CONVERGED_WITH_DISSENT` (recorded in both `manifest.json` and `final_blueprint.md`).
- **Bounded Termination (`MAX_ROUNDS=3` -> `DEADLOCK`)**:
  - Deliberation is strictly bounded to `MAX_ROUNDS` (default: 3 rounds).
  - Round 1 is blind (eliminates anchoring bias).
  - Subsequent rounds distribute an anonymized digest (`digest.md` using `Agent A` / `Agent B` / `Agent C`) addressing specific objection IDs.
  - If unconverged after `MAX_ROUNDS` with quorum met, the process terminates with status `DEADLOCK` (exit `2`), outputs `dissent_register.md` capturing irreconcilable trade-offs and empirical data, and escalates to the human operator for tie-breaking.

### 5. CLI Usage & Antigravity 3-Peer Orchestration Flow
```bash
# Antigravity 3-Peer Flow (Gemini Native Subagent + Claude + Codex in parallel):
# 1. Initialize ledger directory (records 3-peer voters in manifest.json):
agent-deliberate --init [--rounds 3] [--add-option "..."] "<TOPIC_OR_REQUIREMENT>" [CONTEXT_FILES...]

# 2. For each round N (in the SAME turn):
#    - Run external CLIs without tallying:
consensus-round --no-tally [--model-claude <M>] [--model-codex <M>] <DELIBERATION_DIR> <N>
#    - Concurrently call invoke_subagent (TypeName: "research", Role: "Gemini Deliberation Peer")
#      with topic, option_0_baseline.md, manifest.json, context files, templates/deliberation_prompt.md,
#      and (for N > 1) round-(N-1)/digest.md + round-(N-1)/gemini_ballot.json.
# 3. Yield turn until both return; validate Gemini's JSON ballot with jq and write
#    <DELIBERATION_DIR>/round-<N>/gemini_ballot.json (and .md) atomically.
#    (If Gemini fails or returns invalid JSON, still pass --gemini-ballot to --tally-only so
#     tally.json records reduced_quorum: true and absent_peers/invalid_peers accurately.)
# 4. Run deterministic 3-peer tally + anonymized digest:
consensus-round --tally-only --gemini-ballot <DELIBERATION_DIR>/round-<N>/gemini_ballot.json <DELIBERATION_DIR> <N>
# 5. If IN_DEBATE with factual blocking objections, dispatch Jetski probe to write round-<N>/jetski_evidence.md
#    and append findings to round-<N>/digest.md before Round N+1.
#    Once tally.json reaches CONVERGED, CONVERGED_WITH_DISSENT, DEADLOCK, or DEGRADED:
agent-deliberate --finalize <N> --dir <DELIBERATION_DIR>

# Standalone 2-Peer CLI-Only Runner (backward-compatible):
agent-deliberate [--rounds 3] [--model-claude <model>] [--model-codex <model>] "<TOPIC_OR_REQUIREMENT>" [CONTEXT_FILES...]
agent-deliberate -c [--dir <DIR> | --id <ID>] [--guidance "<guidance_text>"] [--add-option "<json_or_title>"]
```
````
