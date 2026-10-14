#!/usr/bin/env bash
# ==============================================================================
# Complete Multi-Agent Consensus Deliberation Test Suite Runner
# Executes all unit, integration, and lifecycle tests across the deliberation
# subsystem (tally calculation, concurrent round execution, agent deliberation).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================================="
echo "🚀 Running Multi-Agent Deliberation Test Suite"
echo "=================================================="

TEST_SCRIPTS=(
  "test_consensus_tally.sh"
  "test_consensus_round.sh"
  "test_agent_deliberate.sh"
)

TOTAL_START=$(date +%s)
PASSED=0
FAILED=0

for test_script in "${TEST_SCRIPTS[@]}"; do
  TEST_PATH="$SCRIPT_DIR/$test_script"
  echo ""
  echo "--------------------------------------------------"
  echo "▶ Running: $test_script"
  echo "--------------------------------------------------"

  if [ ! -f "$TEST_PATH" ]; then
    echo "❌ Error: Test script not found: $TEST_PATH" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  START_TIME=$(date +%s)
  if bash "$TEST_PATH"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "✅ $test_script PASSED (${DURATION}s)"
    PASSED=$((PASSED + 1))
  else
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "❌ $test_script FAILED (${DURATION}s)" >&2
    FAILED=$((FAILED + 1))
  fi
done

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))

echo ""
echo "=================================================="
echo "🏁 Deliberation Test Suite Summary"
echo "=================================================="
echo "Total Suites: $((PASSED + FAILED))"
echo "Passed:       $PASSED"
echo "Failed:       $FAILED"
echo "Total Time:   ${TOTAL_DURATION}s"
echo "=================================================="

if [ "$FAILED" -ne 0 ]; then
  echo "❌ One or more deliberation test suites failed!" >&2
  exit 1
fi

echo "🎉 All multi-agent deliberation test suites passed cleanly!"
exit 0
