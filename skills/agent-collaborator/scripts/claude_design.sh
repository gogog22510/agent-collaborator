#!/usr/bin/env bash
# Universal Claude Architecture & Design Script with Graceful Fallback
# Usage: ./claude_design.sh "<TASK_OR_REQUIREMENT>" [FILE_PATHS...]

set -uo pipefail

REQUIREMENT="${1:-}"
if [ -z "$REQUIREMENT" ]; then
  echo "Error: Missing requirement prompt." >&2
  echo "Usage: $0 \"<TASK_OR_REQUIREMENT>\" [FILE_PATHS...]" >&2
  exit 1
fi
shift

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

FILE_CONTEXT=""
for f in "$@"; do
  if [ -f "$f" ]; then
    FILE_CONTEXT+=$'\n\n'"--- File: $f ---"$'\n'
    FILE_CONTEXT+="$(cat "$f")"
  fi
done

PROMPT="You are a Principal Software Architect and Systems Engineer.
Provide a rigorous, actionable architectural design for the specified requirement.

$PROJECT_HINT

[Design Goal & Requirements]
$REQUIREMENT

[Relevant Context Files]
$FILE_CONTEXT

Please output a structured, production-grade architectural design proposal covering:
1. Core Architecture & Data Flow / State Management topology.
2. Boundary conditions, error handling strategies, concurrency safety, and failure modes.
3. Component/Interface definitions (APIs, Interfaces, Types) and key algorithm pseudocode.
4. Recommended implementation breakdown and unit testing plan.
"

# Execute Claude CLI and capture stdout / stderr
TEMP_OUTPUT=$(mktemp)
TEMP_ERR=$(mktemp)

echo "$PROMPT" | claude -p --tools "" > "$TEMP_OUTPUT" 2> "$TEMP_ERR"
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
