#!/usr/bin/env bash
# Universal OpenAI Codex Algorithmic / Performance / Terminal-Automation Script with Graceful Fallback
# Plays to Codex's real strengths: leading Terminal-Bench agentic shell automation,
# algorithmic & performance optimization, and lower cost-per-token on high-volume tasks.
# Usage: ./codex_optimize.sh "<TASK_OR_REQUIREMENT>" [FILE_PATHS...]

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

PROMPT="You are a Principal Performance Engineer specializing in algorithmic complexity analysis, shell/terminal automation, and CLI tooling.
Provide a rigorous, actionable optimization pass for the specified task.

$PROJECT_HINT

[Task & Requirement]
$REQUIREMENT

[Relevant Context Files]
$FILE_CONTEXT

Please output a structured, production-grade report covering:
1. Algorithmic complexity / hot-path bottlenecks and concrete Big-O improvements.
2. Terminal, shell, or CI pipeline automation opportunities (scriptable, non-interactive).
3. Concrete before/after code or command snippets.
4. Any trade-offs (memory vs. speed, portability, readability) worth flagging.
"

# Execute Codex CLI non-interactively (read-only sandbox: this is an advisory
# consultation, not a workspace-modifying run) and capture stdout / stderr.
TEMP_OUTPUT=$(mktemp)
TEMP_ERR=$(mktemp)

echo "$PROMPT" | codex exec --sandbox read-only --skip-git-repo-check - > "$TEMP_OUTPUT" 2> "$TEMP_ERR"
EXIT_CODE=$?

OUTPUT_STR=$(cat "$TEMP_OUTPUT")
ERR_STR=$(cat "$TEMP_ERR")
rm -f "$TEMP_OUTPUT" "$TEMP_ERR"

# Check for usage limits, rate limits, quota exhaustion, or connection failures
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT_STR $ERR_STR" | grep -qiE "(rate limit|usage limit|quota|exceeded|credit balance|overloaded|429|529|authentication|sign in)"; then
  echo "⚠️ [FALLBACK_TRIGGERED: CODEX_UNAVAILABLE]"
  if [ $EXIT_CODE -eq 126 ] || echo "$ERR_STR" | grep -qiE "(operation not permitted|permission denied)"; then
    echo "Reason: Sandbox execution blocked or permission denied (Exit: $EXIT_CODE). Requires an appropriate --sandbox mode."
  elif [ $EXIT_CODE -eq 127 ] || echo "$ERR_STR" | grep -qiE "(command not found|not found)"; then
    echo "Reason: Codex CLI binary not found (Exit: $EXIT_CODE). Ensure codex is installed and on PATH."
  else
    echo "Reason: Codex CLI usage limit, connection, or execution error (Exit: $EXIT_CODE)."
  fi
  if [ -n "$ERR_STR" ]; then
    echo "Detail: $ERR_STR"
  fi
  exit 100
fi

echo "$OUTPUT_STR"
exit 0
