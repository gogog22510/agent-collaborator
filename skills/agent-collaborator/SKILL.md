---
name: agent-collaborator
description: Coordinate with external coding agents (Claude CLI, Codex, Cursor, etc.) on the local machine for architecture design, code review, spec optimization, and prompt engineering with automatic fallback.
---

# Universal Agent Collaborator Skill

This skill enables a universal, language-agnostic **Multi-Agent / Dual-Agent Workflow** between **Antigravity (Gemini)** and external peer agents (**Claude CLI, Codex, Cursor, etc.**), featuring **Automatic Graceful Fallback**.

## Roles & Division of Labor

- **External Peer Agents (Claude CLI / Codex - Primary Architect & Reviewer)**:
  - Deep architecture & state-machine design (`claude_design.sh`)
  - Rigorous code review, vulnerability detection & regression prevention (`claude_review.sh`)
  - Spec / Prompt / Documentation refinement (`claude_refine.sh`)
- **Primary Agent (Antigravity / Gemini - The Orchestrator & Implementer)**:
  - Project discovery, codebase-wide search & context assembly
  - File generation & refactoring across any language stack
  - Toolchain execution (build tools, linters, test runners, git)
  - **Self-Healing Fallback**: When an external agent hits rate limits, credit limits, or connection errors, the primary agent seamlessly assumes the role and continues without halting the task.

## Universal Helper Scripts

Scripts auto-detect the current project type (`pubspec.yaml`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, etc.) and run non-interactively without blocking stdin.

### 1. Architecture & Solution Design
```bash
claude_design.sh "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
```

### 2. Universal Code Review
```bash
claude_review.sh [BASE_GIT_REF] "<TASK_DESCRIPTION>"
```

### 3. Prompt & Spec Refinement
```bash
claude_refine.sh "<FILE_PATH>" "<OPTIMIZATION_GOAL>"
```

## Graceful Fallback Protocol

When calling any of the peer agent scripts:
1. If the script outputs `⚠️ [FALLBACK_TRIGGERED: ...]` or exits with `100`:
   - Log a non-blocking notice: *"External peer agent unavailable. Seamlessly switching to internal reasoning for this phase."*
   - The primary agent immediately executes the Design, Review, or Prompt Refinement task itself.
   - The workflow never blocks or fails due to external API limits.
