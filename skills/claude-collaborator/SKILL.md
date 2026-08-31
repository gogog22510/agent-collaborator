---
name: claude-collaborator
description: Coordinate with Claude CLI on the local machine for architecture design, code review, spec optimization, and prompt engineering with automatic fallback to Antigravity.
---

# Universal Claude Collaborator Skill

This skill enables a universal, language-agnostic **Dual-Agent Workflow** between **Antigravity (Gemini)** and **Claude CLI** on this development machine, featuring **Automatic Graceful Fallback**.

## Roles & Division of Labor

- **Claude (CLI - The Primary Architect & Reviewer)**:
  - Deep architecture & state-machine design (`claude_design.sh`)
  - Rigorous code review, vulnerability detection & regression prevention (`claude_review.sh`)
  - Spec / Prompt / Documentation refinement (`claude_refine.sh`)
- **Antigravity (Gemini - The Orchestrator, Implementer & Automatic Fallback)**:
  - Project discovery, codebase-wide search & context assembly
  - File generation & refactoring across any language stack
  - Toolchain execution (build tools, linters, test runners, git)
  - **Self-Healing Fallback**: When Claude CLI hits rate limits, credit limits, or errors (exit code 100 or `FALLBACK_TRIGGERED`), Antigravity seamlessly assumes the Design / Review role and continues without halting the task.

## Universal Helper Scripts

Scripts auto-detect the current project type (`pubspec.yaml`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, etc.) and run non-interactively without blocking stdin.

They are globally available at: `~/.gemini/config/skills/claude-collaborator/scripts/` (or locally at `.agent/skills/claude-collaborator/scripts/`).

### 1. Architecture & Solution Design
```bash
bash ~/.gemini/config/skills/claude-collaborator/scripts/claude_design.sh "<TASK_OR_REQUIREMENT>" [CONTEXT_FILES...]
```

### 2. Universal Code Review
```bash
bash ~/.gemini/config/skills/claude-collaborator/scripts/claude_review.sh [BASE_GIT_REF] "<TASK_DESCRIPTION>"
```

### 3. Prompt & Spec Refinement
```bash
bash ~/.gemini/config/skills/claude-collaborator/scripts/claude_refine.sh "<FILE_PATH>" "<OPTIMIZATION_GOAL>"
```

## Graceful Fallback Protocol

When calling any of the above scripts:
1. If the script outputs `⚠️ [FALLBACK_TRIGGERED: CLAUDE_UNAVAILABLE]` or exits with `100`:
   - Log a non-blocking notice: *"Claude usage limit/quota reached. Seamlessly switching to Antigravity internal reasoning for this phase."*
   - Antigravity immediately executes the Design, Review, or Prompt Refinement task itself using its own model reasoning.
   - The workflow never blocks or fails due to external API limits.
