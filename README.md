# 🤝 Agent Collaborator

> **A Multi-Agent Peer Collaboration & Cross-Verification System orchestrated by Google Antigravity, dispatching specialized external peer agents (Claude CLI, OpenAI Codex, Cursor) with Automatic Graceful Fallback.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Orchestrator: Antigravity](https://img.shields.io/badge/Orchestrator-Antigravity-4285F4.svg)](#-architecture-antigravity-as-the-central-orchestrator)
[![Peer: Claude CLI](https://img.shields.io/badge/Peer%20Agent-Claude%20CLI-D97706.svg)](#-core-capabilities--cli-tools)
[![Workflow: Superpowers](https://img.shields.io/badge/Workflow-Superpowers-10B981.svg)](#-superpowers--antigravity-pipeline)

[繁體中文說明文件 (Traditional Chinese Document)](README_zh.md)

---

## 🌟 Architecture: Antigravity as the Central Orchestrator

In modern software engineering, a single LLM frequently struggles to balance massive codebase context assembly with rigorous localized logic deduction.

`agent-collaborator` establishes a **Multi-Agent Pair Programming Architecture** where **Google Antigravity (Gemini)** acts as the **Central Orchestrator & Implementer**, proactively consulting and dispatching **External Peer Agents (Claude CLI, OpenAI Codex, etc.)** at critical decision milestones:

```mermaid
flowchart TD
    subgraph Orchestrator["👑 Antigravity (Central Orchestrator & Implementer)"]
        direction TB
        Awareness["🧠 Global Context Assembly & Deep Awareness<br/>(Gemini Massive Context Window for Full-Project Topology)"]
        Engine["⚙️ Toolchain Execution & Automated Refactoring<br/>(Builds, Test Runners, Git Operations, Hot Reloads)"]
        Supervisor["🛡️ Workflow Progression, Task Management & Fallback<br/>(Task Tracker & Self-Healing Fallback Engine)"]
    end

    subgraph PeerCouncil["🏛️ External Peer Advisory Council"]
        direction TB
        Claude["🤖 Claude CLI<br/>• System Architecture & State Machine Design (claude-design)<br/>• Prompt & Specification Refinement (claude-refine)<br/>• Pre-flight Git Diff Code Review (claude-review)"]
        Codex["🧩 OpenAI Codex (Extensible)<br/>• Algorithmic & Language-Specific Optimizations"]
    end

    Awareness -->|1. Assemble pinpoint context & initiate consultation| Claude
    Claude -->|2. Return architectural decision / review feedback| Engine
    Engine -->|3. Implement code & run TDD test suite| Supervisor
    Supervisor -->|4. Trigger pre-flight review before completion| Claude
    Supervisor --> Done(["🏁 High-Standard Task Completion & Delivery"])
```

### Why Antigravity as the Orchestrator?
1. **Massive Context Capacity**: Antigravity leverages Gemini's industry-leading context window and whole-project search capabilities to assemble precise, comprehensive code slices for external advisors.
2. **Full Toolchain Authority**: Antigravity natively manages terminal command execution, test suite verification, file manipulation, and version control.
3. **Active Coordination & Fault Tolerance**: Antigravity maintains task trackers and execution state. When an external peer agent encounters rate limits, token exhaustion, or connection hiccups, Antigravity seamlessly assumes the role to ensure the workflow never blocks.

---

## ⚡ Core Capabilities & CLI Tools

Once installed, you can use these tools directly in any terminal or allow Antigravity to automatically orchestrate them:

| Command / Script | Purpose | Usage Example |
| :--- | :--- | :--- |
| **`claude-design`** | System architecture, state machines, trade-off analysis & research | `claude-design "<requirement>" [context_files...]` |
| **`claude-refine`** | Spec optimization, JSON Schema refinement & prompt tuning | `claude-refine "<target_file>" "<optimization_goal>"` |
| **`claude-review`** | Objective Git Diff code review, crash prevention & regression check | `claude-review HEAD "<task_context_description>"` |

---

## 🚀 1. Install Superpowers (Prerequisite Methodology)

If you want your agent to follow structured engineering discipline (Brainstorming, Spec First, Implementation Plans, Red/Green TDD):

* **Antigravity**:
  ```bash
  agy plugin install https://github.com/obra/superpowers
  ```
* **Claude Code**:
  ```text
  /plugin install superpowers@claude-plugins-official
  ```
* **Cursor**:
  ```text
  /add-plugin superpowers
  ```

---

## 🚀 2. Install Agent Collaborator

### Step 1: Clone Repository
```bash
git clone https://github.com/gogog22510/agent-collaborator.git
cd agent-collaborator
./install.sh
```

### Step 2: Choose Installation Mode

```text
======================================================
  🤝 Agent Collaborator Universal Installer
======================================================
Select an installation target:
  1) All (CLI Tools + Antigravity Global + Claude Code Global) [Recommended]
  2) Standalone CLI Tools only (~/.local/bin/claude-design, ...)
  3) Antigravity Global Skills (~/.gemini/...)
  4) Project-Local Skill (.agent/skills/ in current directory)
  5) Claude Code Global Skills (~/.claude/skills/)
```

### Non-Interactive Flags (CI / Automated Scripts)
* **Full Install**: `./install.sh --all`
* **CLI Only**: `./install.sh --cli` (Symlinks to `~/.local/bin/`)
* **Antigravity Global**: `./install.sh --antigravity-global` (Installs into `~/.gemini/skills/`)
* **Project Local**: `./install.sh --project /path/to/project` (Installs into `.agent/skills/`)

---

## 🌟 3. Superpowers + Antigravity Orchestration Pipeline

When combining Superpowers methodology with Antigravity and Agent Collaborator, every engineering milestone is double-checked by peer models:

```mermaid
flowchart TD
    subgraph AntigravitySuperpowers["👑 Antigravity Orchestrator + Superpowers Methodology"]
        B["1. Brainstorming<br/>(Requirement & Spec Exploration)"] --> P["2. Writing Plans<br/>(Structured Implementation Plan)"]
        P --> T["3. TDD Execution<br/>(Red/Green Tests & Implementation)"]
        T --> V["4. Verification<br/>(End-to-End Proof & Delivery)"]
    end

    subgraph PeerAdvisors["🏛️ External Peer Advisory (Agent Collaborator)"]
        CD["claude-design<br/>(Architecture Validation & State Topology)"]
        CR["claude-refine<br/>(Spec & Prompt Refinement)"]
        CW["claude-review<br/>(Strict Git Diff Code Review)"]
    end

    B -.->|Antigravity Dispatches Consultation| CD
    P -.->|Antigravity Dispatches Refinement| CR
    T -.->|Antigravity Dispatches Pre-flight Review| CW
    CW --> V
```

---

## 📖 Environment Integration Templates

Ready-to-use integration contracts are available in the `templates/` directory:
* ⚡ **Superpowers / Antigravity**: [`templates/antigravity_superpowers.md`](templates/antigravity_superpowers.md) (Add to `.agent/AGENTS.md`)
* 🖱️ **Cursor / Windsurf**: [`templates/cursor_rules.md`](templates/cursor_rules.md) (Add to `.cursorrules`)
* 🤖 **Claude Code**: [`templates/claude_code.md`](templates/claude_code.md) (Add to `CLAUDE.md`)

---

## 🛡️ Graceful Self-Healing Fallback

When an external peer agent encounters:
- Usage / Credit limits
- Rate limits (429)
- Server overload (529)

The helper scripts automatically catch the error, emit `⚠️ [FALLBACK_TRIGGERED: ...]`, and exit with code `100`. The Orchestrator (Antigravity) seamlessly takes over reasoning internally, **ensuring tasks never stall**.

---

## 🌐 Multi-Stack Auto Detection

The scripts automatically detect project configurations and tailor the prompt context:
* `pubspec.yaml` ➔ **Dart / Flutter**
* `package.json` ➔ **Node.js / TypeScript / JavaScript**
* `Cargo.toml` ➔ **Rust**
* `go.mod` ➔ **Go**
* `pyproject.toml` / `requirements.txt` ➔ **Python**

---

## 📄 License

Distributed under the [MIT License](LICENSE).
