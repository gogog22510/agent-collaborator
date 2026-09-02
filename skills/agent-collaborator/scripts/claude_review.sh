#!/usr/bin/env bash
# Universal Claude Code Review Script with Graceful Fallback
# Usage: ./claude_review.sh [BASE_REF] [TASK_DESCRIPTION]

set -uo pipefail

BASE_REF="${1:-HEAD}"
TASK_DESC="${2:-No task description provided}"

PROJECT_HINT=""
if [ -f "pubspec.yaml" ]; then
  PROJECT_HINT="Project Technology Stack: Dart / Flutter"
elif [ -f "package.json" ]; then
  PROJECT_HINT="Project Technology Stack: Node.js / TypeScript / JavaScript"
elif [ -f "Cargo.toml" ]; then
  PROJECT_HINT="Project Technology Stack: Rust"
elif [ -f "go.mod" ]; then
  PROJECT_HINT="Project Technology Stack: Go"
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  PROJECT_HINT="Project Technology Stack: Python"
fi

DIFF_OUTPUT=$(git diff "$BASE_REF" 2>/dev/null || echo "")

if [ -z "$DIFF_OUTPUT" ]; then
  DIFF_OUTPUT=$(git diff HEAD~1 2>/dev/null || git show -p HEAD 2>/dev/null || echo "")
fi

DIFF_SNIPPET=$(echo "$DIFF_OUTPUT" | head -n 400)

PROMPT="You are a Principal Code Reviewer and Security Auditor.
Perform a strict, objective, and actionable code review of the following Git Diff changes.

$PROJECT_HINT

[Task Context & Objective]
$TASK_DESC

[Git Diff Changes]
$DIFF_SNIPPET

Please provide a structured code review report in the following format:
### 1. Overview & Architecture Alignment
- Does the change cleanly fulfill the objective? Are abstraction layers preserved?

### 2. Critical & Blocker Issues
- Any potential crashes, logic flaws, regressions, unhandled edge cases, state de-sync, race conditions, memory leaks, or security vulnerabilities. If none, state 'None'.

### 3. Key Improvements & Best Practices
- Performance optimizations, defensive guards, test coverage gaps, or idiomatic language patterns.

### 4. Verdict
- [PASS / PASS WITH MINOR REVISIONS / REQUEST REDESIGN]
"

TEMP_OUTPUT=$(mktemp)
TEMP_ERR=$(mktemp)

echo "$PROMPT" | claude --safe-mode -p --tools "" > "$TEMP_OUTPUT" 2> "$TEMP_ERR"
EXIT_CODE=$?

OUTPUT_STR=$(cat "$TEMP_OUTPUT")
ERR_STR=$(cat "$TEMP_ERR")
rm -f "$TEMP_OUTPUT" "$TEMP_ERR"

# Check for usage limits, rate limits, or connection failures
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT_STR $ERR_STR" | grep -qiE "(rate limit|usage limit|quota|exceeded|credit balance|overloaded|429|529|authentication)"; then
  echo "⚠️ [FALLBACK_TRIGGERED: CLAUDE_UNAVAILABLE]"
  if [ $EXIT_CODE -eq 126 ] || echo "$ERR_STR" | grep -qiE "(operation not permitted|permission denied)"; then
    echo "Reason: Sandbox execution blocked or permission denied (Exit: $EXIT_CODE). Requires BypassSandbox=true."
  elif [ $EXIT_CODE -eq 127 ] || echo "$ERR_STR" | grep -qiE "(command not found|not found)"; then
    echo "Reason: Claude CLI binary not found (Exit: $EXIT_CODE). Ensure claude is installed and on PATH."
  else
    echo "Reason: Claude CLI usage limit, connection, or execution error (Exit: $EXIT_CODE)."
  fi
  if [ -n "$ERR_STR" ]; then
    echo "Detail: $ERR_STR"
  fi
  exit 100
fi

echo "$OUTPUT_STR"
exit 0
