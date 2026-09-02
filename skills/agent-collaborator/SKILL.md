---
name: agent-collaborator
description: Coordinate with external coding agents (Claude CLI, OpenAI Codex, etc.) on the local machine for architecture design, code review, spec optimization, and prompt engineering with automatic fallback.
---

# Universal Agent Collaborator Skill

This skill enables a universal, language-agnostic **Multi-Agent / Dual-Agent Workflow** between **Antigravity (Gemini)** and external peer agents (**Claude CLI, OpenAI Codex, etc.**), featuring **Automatic Graceful Fallback**.

## Roles & Division of Labor

- **External Peer Agents (Claude CLI / OpenAI Codex - Primary Architects & Reviewers)**:
  - Deep architecture & state-machine design (`claude_design.sh`)
  - Rigorous code review, vulnerability detection & regression prevention (`claude_review.sh`)
  - Spec / Prompt / Documentation refinement (`claude_refine.sh`)
- **Primary Agent (Antigravity / Gemini - The Orchestrator & Implementer)**:
  - Project discovery, codebase-wide search & context assembly
  - File generation & refactoring across any language stack
  - Toolchain execution (build tools, linters, test runners, git)
  - **Self-Healing Fallback**: When an external agent hits rate limits, credit limits, or errors (exit code 100 or `FALLBACK_TRIGGERED`), Antigravity seamlessly assumes the Design / Review role and continues without halting the task.

## Universal Helper Scripts

Scripts auto-detect the current project type (`pubspec.yaml`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, etc.) and run non-interactively without blocking stdin.

They are globally available at: `~/.gemini/config/skills/agent-collaborator/scripts/` (or locally at `.agent/skills/agent-collaborator/scripts/` or standalone in `~/.local/bin/`).

### 1. Architecture & Solution Design
```bash
claude-design "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_design.sh "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
```

### 2. Universal Code Review
```bash
claude-review [BASE_GIT_REF] "<TASK_DESCRIPTION>"
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_review.sh [BASE_GIT_REF] "<TASK_DESCRIPTION>"
```

### 3. Prompt & Spec Refinement
```bash
claude-refine "<FILE_PATH>" "<OPTIMIZATION_GOAL>"
# or: bash ~/.gemini/config/skills/agent-collaborator/scripts/claude_refine.sh "<FILE_PATH>" "<OPTIMIZATION_GOAL>"
```

## Graceful Fallback Protocol

When calling any of the peer agent scripts:
1. If the script outputs `⚠️ [FALLBACK_TRIGGERED: ...]` or exits with `100`:
   - Log a non-blocking notice: *"External peer agent unavailable. Seamlessly switching to internal reasoning for this phase."*
   - Antigravity immediately executes the Design, Review, or Prompt Refinement task itself using its own model reasoning.
   - The workflow never blocks or fails due to external API limits.
