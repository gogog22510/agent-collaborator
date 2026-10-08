# ⚡ Superpowers + Agent Collaborator Complete Integration Guide

## 1. What is Superpowers?

[Superpowers](https://github.com/obra/superpowers) is an open-source software engineering methodology framework for AI coding agents. It equips AI agents with:
* **Brainstorming & Spec First**: Guided exploration of user requirements decomposed into bite-sized specifications before writing code.
* **TDD & Implementation Planning**: Structured red/green unit testing with step-by-step implementation plans.
* **Single-Flow Execution & Verification**: Disciplined task execution with rigorous acceptance verification.

---

## 2. Installing Superpowers

Install Superpowers depending on your primary driver environment:

### 🌐 Antigravity
Run in your terminal:
```bash
agy plugin install https://github.com/obra/superpowers
```
*(If `agy` CLI is not installed, you can clone the repository directly into `~/.gemini/config/plugins/superpowers` or your project's `.agent/skills/` directory)*

### 🤖 Claude Code
In Claude Code chat:
```text
/plugin install superpowers@claude-plugins-official
```
Or add the community marketplace:
```text
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

---

## 3. Injecting Agent Collaborator into the Superpowers Workflow

After installing Superpowers, install `agent-collaborator` as your peer agent collaborator:

```bash
cd /path/to/your/project
/path/to/agent-collaborator/install.sh --project .
```

Since Superpowers/Antigravity are driven by your project's `AGENTS.md`, `--project` now **automatically injects** the collaboration protocol (from `templates/AGENTS.md`) into `AGENTS.md` at your project root for you — idempotently, and without touching any of your existing content. Pass `--no-agents-md` if you'd rather do it by hand, or want to review the exact block first: it is reproduced below for reference.

```markdown
# 🤝 Multi-Agent Peer Collaboration & Verification Protocol

## 1. Roles & Division of Labor
- **Central Orchestrator (Antigravity / Gemini)**: Full context awareness, toolchain execution, TDD implementation, and fallback.
- **Peer Advisory Council (Claude CLI / OpenAI Codex / Custom)**:
  - `claude-brainstorm [--model <model>] [-c]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_brainstorm.sh`): Ideation & approach trade-offs (2-3 distinct approaches)
  - `codex-brainstorm [--model <model>] [-c]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_brainstorm.sh`): Engineering feasibility, standard library alternatives & contrarian perspectives
  - `claude-design [--model <model>] [-c]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_design.sh`): Architectural design & state-machine exploration
  - `claude-refine [--model <model>] [-c]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_refine.sh`): Spec & prompt optimization (accepts reference files)
  - `claude-review [--model <model>] [-c]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_review.sh`): Pre-flight git diff code review
  - `claude-followup [--model <model>]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_followup.sh`): Multi-turn session continuation for Claude
  - `codex-followup [--model <model>]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_followup.sh`): Multi-turn session continuation for Codex
  - `codex-optimize [--model <model>] [-c]` (or `bash ~/.gemini/config/skills/agent-collaborator/scripts/codex_optimize.sh`): Algorithmic/performance analysis & terminal/CI automation, using Codex's actual strengths (Terminal-Bench-leading agentic shell tasks, cheaper per-task on high-volume work). Codex's **Computer Use** (GUI screen/mouse/keyboard control) only exists in the Codex desktop app, not this headless script — route GUI-verification needs there.
  - *Model Selection*: All commands support `--model <name>` / `-m <name>` or environment variables (`CLAUDE_MODEL`, `CODEX_MODEL`, `AGENT_MODEL`). Antigravity can choose fast models (`haiku`, `o3-mini`) for lightweight tasks or top models (`opus`, `sonnet`, `o3`) for deep architectures.
  - *(Extensible: Add other custom peer agent scripts under `.agent/skills/` or `~/.local/bin/`)*

> **Execution Note for Antigravity (Gemini)**:
> 1. **Sandbox Bypass**: External peer agent tools (`claude-brainstorm`, `claude-design`, `claude-refine`, `claude-review`, `claude-followup`, `codex-brainstorm`, `codex-optimize`, `codex-followup`) execute host binaries (`~/.local/bin/claude`, `~/.local/bin/codex`) and require internet access. You **MUST** execute them via `run_command` with `BypassSandbox: true`.
> 2. **Direct Invocation**: Directly invoke `claude-brainstorm`, `codex-brainstorm`, `claude-design`, `claude-refine`, `claude-review`, `claude-followup`, `codex-followup`, or `codex-optimize` (in `~/.local/bin` on PATH) or use `bash ~/.gemini/config/skills/agent-collaborator/scripts/<script>.sh`. Do NOT spend turns running `which` or searching for scripts.
> 3. **Sandbox Error Handling**: If exit 126 or "Operation not permitted" occurs, it means `BypassSandbox: true` was omitted. Immediately re-run with `BypassSandbox: true`. Do NOT switch to fallback.

## 2. Mandatory Rules
- **Brainstorming / Plan**: Proactively consult peer agents (`claude-brainstorm` / `codex-brainstorm` / `claude-design` / `claude-refine`) with `BypassSandbox: true` to cross-reference designs and explore edge cases.
- **Pre-flight Verification**: Run `claude-review` with `BypassSandbox: true` before finalizing plans or claiming task completion.
- **Background Execution Synchronization**: When peer agents run in background (~15-30s), **DO NOT** prematurely output "設計已完成" or finalize `implementation_plan.md`. Yield the turn (stop calling tools) and wait for the reactive wake-up message, then synthesize peer findings into the final plan.
- **Multi-Turn Continuity & Anti-Hallucination**: Peer agent CLIs are stateless by default. For multi-turn followups with the same agent, use `claude-followup`, `codex-followup` or `-c`. For cross-agent workflows (e.g. Codex notes + Claude review -> plan), use explicit context piping (`claude-refine <target> "<goal>" [ref_files...]`). Never run raw stateless commands expecting past context to be remembered.
- **Sandbox vs Fallback vs Input Error**:
  - Exit 126 / Sandbox Block: Re-run once with `BypassSandbox: true` (if 126 persists, fallback to internal reasoning).
  - Exit 1 / Input Error (missing arguments, missing files, or no recorded session): Fix input or run without `-c`. Do NOT trigger fallback.
  - Exit 100 / Rate limit / Quota failure: Antigravity seamlessly continues internally with its own reasoning.
```

---

## 4. Multi-Agent + Superpowers Golden Pipeline

When Superpowers is combined with Agent Collaborator, every engineering milestone is double-checked by peer models:

```mermaid
flowchart TD
    subgraph SuperpowersFlow["Superpowers Engineering Methodology"]
        B["1. Brainstorming (Requirement & Spec Exploration)"]
        P["2. Writing Plans (Structured Implementation Plan)"]
        T["3. TDD Execution (Red/Green Testing & Code Implementation)"]
        V["4. Verification (End-to-End Proof & Delivery)"]
    end

    subgraph PeerAdvisors["🏛️ Peer Advisory Council (Claude / Codex / Extensible)"]
        CB["claude-brainstorm<br/>(Divergent Ideation & Trade-offs)"]
        XB["codex-brainstorm<br/>(Engineering Feasibility & Minimal Design)"]
        CD["claude-design<br/>(Architecture Validation & Boundary Check)"]
        CR["claude-refine<br/>(Spec & Prompt Refinement)"]
        CW["claude-review<br/>(Strict Git Diff Code Review)"]
        CO["codex-optimize<br/>(Perf/Algorithmic & Terminal Automation)"]
        CF["claude-followup / codex-followup<br/>(Multi-Turn Session Continuation)"]
    end

    B -.-> CB
    B -.-> XB
    B -.-> CD
    P -.-> CR
    P -.-> CF
    T -.-> CW
    T -.-> CO
    T -.-> CF
    CW --> V
    CO --> V
```
