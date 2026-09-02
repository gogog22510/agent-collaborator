#!/usr/bin/env bash
# Universal Claude Content / Prompt / Spec Refiner Script with Graceful Fallback
# Usage: ./claude_refine.sh "<TARGET_FILE>" "<OPTIMIZATION_GOAL>"

set -uo pipefail

TARGET_FILE="${1:-}"
GOAL="${2:-}"

if [ -z "$TARGET_FILE" ] || [ -z "$GOAL" ]; then
  echo "Error: Missing arguments." >&2
  echo "Usage: $0 <TARGET_FILE> \"<OPTIMIZATION_GOAL>\"" >&2
  exit 1
fi

CONTENT=""
if [ -f "$TARGET_FILE" ]; then
  CONTENT="$(cat "$TARGET_FILE")"
else
  echo "Error: File $TARGET_FILE not found." >&2
  exit 1
fi

PROMPT="You are a Principal Engineering Lead specializing in technical specifications, JSON schemas, API contracts, and prompt engineering.
Refine the provided target file content to achieve the specified optimization goal.

[Target File]
$TARGET_FILE

[Current Content]
$CONTENT

[Optimization Goal]
$GOAL

Please output:
1. Analysis of current ambiguities, bottlenecks, or edge-case gaps.
2. The complete, production-ready refined content (ready as a direct drop-in replacement).
3. Rationale and key improvements explained.
"

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
  echo "Reason: Claude CLI usage limit or connection error detected (Exit: $EXIT_CODE)."
  if [ -n "$ERR_STR" ]; then
    echo "Detail: $ERR_STR"
  fi
  exit 100
fi

echo "$OUTPUT_STR"
exit 0
