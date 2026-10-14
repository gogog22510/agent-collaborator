#!/usr/bin/env bash
# Unit & Integration Test for High-Level Deliberation Runner (agent_deliberate.sh)
# Tests the full deliberation lifecycle, including Round 1 convergence,
# multi-round progression with Jetski empirical evidence integration,
# deadlock termination at MAX_ROUNDS with dissent register and human tie-breaker menu,
# and CLI options/argument parsing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DELIBERATE_SCRIPT="$REPO_ROOT/skills/agent-collaborator/scripts/agent_deliberate.sh"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

MOCK_BIN="$TEMP_DIR/bin"
mkdir -p "$MOCK_BIN"
MOCK_LOGS="$TEMP_DIR/logs"
mkdir -p "$MOCK_LOGS"

echo "=== Setting up Mock consensus_round.sh ==="

MOCK_ROUND_SH="$MOCK_BIN/consensus_round.sh"
cat <<'EOF' > "$MOCK_ROUND_SH"
#!/usr/bin/env bash
set -euo pipefail

# Log all arguments and current working directory
echo "$@" >> "$MOCK_LOGS/consensus_round_args.txt"
pwd >> "$MOCK_LOGS/consensus_round_cwd.txt"

# Parse args to get deliberation dir and round num
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-rounds|-r|--model-claude|--model-codex)
      shift 2
      ;;
    --max-rounds=*|--model-claude=*|--model-codex=*)
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

DELIB_DIR="${POSITIONAL[0]}"
ROUND_NUM="${POSITIONAL[1]}"

ROUND_DIR="$DELIB_DIR/round-$ROUND_NUM"
mkdir -p "$ROUND_DIR"

SCENARIO="${MOCK_SCENARIO:-CONVERGE_ROUND_1}"

if [ "$SCENARIO" = "FAIL_126" ]; then
  echo "❌ [SANDBOX_BLOCKED] Operation not permitted" >&2
  exit 126
elif [ "$SCENARIO" = "FAIL_100" ]; then
  echo "⚠️ [FALLBACK_TRIGGERED: External peers unavailable]" >&2
  exit 100
fi

if [ "$SCENARIO" = "CONVERGE_ROUND_1" ]; then
  cat <<INNER > "$ROUND_DIR/claude_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": $ROUND_NUM,
  "agent": "claude",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.9, "rationale": "Direct POSIX utils"},
    "architectural_simplicity": {"score": 5, "confidence": 0.95, "rationale": "No extra layers"},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.95, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Zero overhead"},
    "robustness_failure_modes": {"score": 4, "confidence": 0.85, "rationale": "Standard exits"},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Simple test harness"}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": []
}
INNER

  cat <<INNER > "$ROUND_DIR/codex_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": $ROUND_NUM,
  "agent": "codex",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.9, "rationale": "Direct POSIX utils"},
    "architectural_simplicity": {"score": 5, "confidence": 0.95, "rationale": "No extra layers"},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.95, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Zero overhead"},
    "robustness_failure_modes": {"score": 4, "confidence": 0.85, "rationale": "Standard exits"},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Simple test harness"}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": []
}
INNER

  cat <<INNER > "$ROUND_DIR/tally.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": $ROUND_NUM,
  "max_rounds": 3,
  "status": "CONVERGED",
  "consensus_option": "Option_0",
  "yagni_score_avg": 5.0,
  "score_spreads": {
    "technical_feasibility": 0,
    "architectural_simplicity": 0,
    "yagni_and_parsimony": 0,
    "robustness_failure_modes": 0,
    "maintainability_testability": 0
  },
  "blocking_objections": [],
  "over_architecture_flags": []
}
INNER

elif [ "$SCENARIO" = "FACTUAL_OBJ_TO_CONVERGED" ]; then
  if [ "$ROUND_NUM" -eq 1 ]; then
    cat <<INNER > "$ROUND_DIR/claude_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": 1,
  "agent": "claude",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.9, "rationale": "Direct POSIX utils"},
    "architectural_simplicity": {"score": 5, "confidence": 0.9, "rationale": "Simple"},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.9, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Direct"},
    "robustness_failure_modes": {"score": 4, "confidence": 0.8, "rationale": "Standard"},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Simple"}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": []
}
INNER

    cat <<INNER > "$ROUND_DIR/codex_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": 1,
  "agent": "codex",
  "preferred_option": "Option_B",
  "stance": "BLOCK",
  "metrics": {
    "technical_feasibility": {"score": 3, "confidence": 0.7, "rationale": "Claims disk latency exceeds 10ms"},
    "architectural_simplicity": {"score": 3, "confidence": 0.8, "rationale": "Buffer layer added"},
    "yagni_and_parsimony": {"score": 3, "confidence": 0.8, "cognitive_overhead": "MED", "indirection_layers": 1, "rationale": "Buffer"},
    "robustness_failure_modes": {"score": 4, "confidence": 0.8, "rationale": "Safe"},
    "maintainability_testability": {"score": 4, "confidence": 0.8, "rationale": "Moderate"}
  },
  "over_architecture_flags": [],
  "blocking_objections": [
    {
      "id": "OBJ-1",
      "type": "factual",
      "metric_target": "technical_feasibility",
      "claim": "Direct file writes cause disk latency exceeding 10ms under 1000 ops/s.",
      "resolution_condition": "Run empirical benchmark measuring direct write latency."
    }
  ],
  "position_changes": []
}
INNER

    cat <<INNER > "$ROUND_DIR/tally.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": 1,
  "max_rounds": 3,
  "status": "IN_DEBATE",
  "consensus_option": null,
  "yagni_score_avg": 4.0,
  "score_spreads": {
    "technical_feasibility": 2,
    "architectural_simplicity": 2,
    "yagni_and_parsimony": 2,
    "robustness_failure_modes": 0,
    "maintainability_testability": 1
  },
  "blocking_objections": [
    {
      "id": "OBJ-1",
      "type": "factual",
      "metric_target": "technical_feasibility",
      "claim": "Direct file writes cause disk latency exceeding 10ms under 1000 ops/s.",
      "resolution_condition": "Run empirical benchmark measuring direct write latency."
    }
  ],
  "over_architecture_flags": []
}
INNER

    cat <<INNER > "$ROUND_DIR/digest.md"
# Round 1 Anonymized Digest
Dispute on OBJ-1: Direct file writes cause disk latency exceeding 10ms.
INNER

  elif [ "$ROUND_NUM" -eq 2 ]; then
    # In Round 2, verify that digest.md was updated with Jetski evidence
    PREV_DIGEST="$DELIB_DIR/round-1/digest.md"
    if grep -q "Empirical Spike Evidence (Jetski)" "$PREV_DIGEST" 2>/dev/null; then
      echo "MOCK: Detected Jetski evidence in round-1 digest!" >> "$MOCK_LOGS/jetski_detected.txt"
    fi

    cat <<INNER > "$ROUND_DIR/claude_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": 2,
  "agent": "claude",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.95, "rationale": "Empirical spike confirmed latency < 2ms"},
    "architectural_simplicity": {"score": 5, "confidence": 0.95, "rationale": "Simple"},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.95, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Direct"},
    "robustness_failure_modes": {"score": 4, "confidence": 0.85, "rationale": "Standard"},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Simple"}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": []
}
INNER

    cat <<INNER > "$ROUND_DIR/codex_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": 2,
  "agent": "codex",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.95, "rationale": "Conceded after Jetski benchmark showed 1.2ms latency"},
    "architectural_simplicity": {"score": 5, "confidence": 0.95, "rationale": "Concurred"},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.95, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Direct"},
    "robustness_failure_modes": {"score": 4, "confidence": 0.85, "rationale": "Standard"},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Simple"}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": [
    {
      "from_option": "Option_B",
      "to_option": "Option_0",
      "cited_objection_ids": ["OBJ-1"],
      "justification": "Jetski empirical benchmark proved direct writes stay under 2ms, invalidating latency block."
    }
  ]
}
INNER

    cat <<INNER > "$ROUND_DIR/tally.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": 2,
  "max_rounds": 3,
  "status": "CONVERGED",
  "consensus_option": "Option_0",
  "yagni_score_avg": 5.0,
  "score_spreads": {
    "technical_feasibility": 0,
    "architectural_simplicity": 0,
    "yagni_and_parsimony": 0,
    "robustness_failure_modes": 0,
    "maintainability_testability": 0
  },
  "blocking_objections": [],
  "over_architecture_flags": []
}
INNER
  fi

elif [ "$SCENARIO" = "DEADLOCK" ]; then
  cat <<INNER > "$ROUND_DIR/claude_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": $ROUND_NUM,
  "agent": "claude",
  "preferred_option": "Option_A",
  "stance": "BLOCK",
  "metrics": {
    "technical_feasibility": {"score": 4, "confidence": 0.8, "rationale": "Layered framework"},
    "architectural_simplicity": {"score": 3, "confidence": 0.8, "rationale": "Clean boundaries"},
    "yagni_and_parsimony": {"score": 3, "confidence": 0.7, "cognitive_overhead": "MED", "indirection_layers": 2, "rationale": "Speculative interfaces"},
    "robustness_failure_modes": {"score": 4, "confidence": 0.8, "rationale": "Handles exceptions"},
    "maintainability_testability": {"score": 3, "confidence": 0.8, "rationale": "Requires mocks"}
  },
  "over_architecture_flags": [],
  "blocking_objections": [
    {
      "id": "OBJ-CL-1",
      "type": "tradeoff",
      "metric_target": "maintainability_testability",
      "claim": "Option B lacks pluggable abstraction boundaries.",
      "resolution_condition": "Introduce abstraction interface."
    }
  ],
  "position_changes": []
}
INNER

  cat <<INNER > "$ROUND_DIR/codex_ballot.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": $ROUND_NUM,
  "agent": "codex",
  "preferred_option": "Option_B",
  "stance": "BLOCK",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.9, "rationale": "High throughput"},
    "architectural_simplicity": {"score": 4, "confidence": 0.85, "rationale": "Raw primitives"},
    "yagni_and_parsimony": {"score": 4, "confidence": 0.85, "cognitive_overhead": "LOW", "indirection_layers": 1, "rationale": "No interfaces"},
    "robustness_failure_modes": {"score": 3, "confidence": 0.7, "rationale": "Raw signals"},
    "maintainability_testability": {"score": 4, "confidence": 0.85, "rationale": "Direct"}
  },
  "over_architecture_flags": [
    {
      "pattern": "EXCESSIVE_INDIRECTION",
      "critique": "Option A adds unnecessary interface indirection.",
      "simplification_remedy": "Remove adapter layer."
    }
  ],
  "blocking_objections": [
    {
      "id": "OBJ-CX-1",
      "type": "tradeoff",
      "metric_target": "yagni_and_parsimony",
      "claim": "Option A violates YAGNI with speculative interfaces.",
      "resolution_condition": "Remove abstraction interfaces."
    }
  ],
  "position_changes": []
}
INNER

  # In final round or max round, status is DEADLOCK
  cat <<INNER > "$ROUND_DIR/tally.json"
{
  "deliberation_id": "$(basename "$DELIB_DIR")",
  "round": $ROUND_NUM,
  "max_rounds": 2,
  "status": "DEADLOCK",
  "consensus_option": null,
  "yagni_score_avg": 3.5,
  "score_spreads": {
    "technical_feasibility": 1,
    "architectural_simplicity": 1,
    "yagni_and_parsimony": 1,
    "robustness_failure_modes": 1,
    "maintainability_testability": 1
  },
  "blocking_objections": [
    {
      "id": "OBJ-CL-1",
      "type": "tradeoff",
      "metric_target": "maintainability_testability",
      "claim": "Option B lacks pluggable abstraction boundaries.",
      "resolution_condition": "Introduce abstraction interface."
    },
    {
      "id": "OBJ-CX-1",
      "type": "tradeoff",
      "metric_target": "yagni_and_parsimony",
      "claim": "Option A violates YAGNI with speculative interfaces.",
      "resolution_condition": "Remove abstraction interfaces."
    }
  ],
  "over_architecture_flags": [
    {
      "pattern": "EXCESSIVE_INDIRECTION",
      "critique": "Option A adds unnecessary interface indirection.",
      "simplification_remedy": "Remove adapter layer."
    }
  ]
}
INNER
fi

echo "Mock round $ROUND_NUM completed."
exit 0
EOF
chmod +x "$MOCK_ROUND_SH"

export PATH="$MOCK_BIN:$PATH"
export CONSENSUS_ROUND_SH="$MOCK_ROUND_SH"
export MOCK_LOGS="$MOCK_LOGS"

echo "=== Test 1: Lifecycle 1 - Full Convergence in Round 1 ==="
TEST1_DIR="$TEMP_DIR/test1_delib"
export MOCK_SCENARIO="CONVERGE_ROUND_1"

OUTPUT1=$(bash "$DELIBERATE_SCRIPT" \
  --id "dlb-test-01" \
  --dir "$TEST1_DIR" \
  --rounds 3 \
  "Design a high-throughput event logging pipeline")
EXIT1=$?

[ "$EXIT1" -eq 0 ] || { echo "FAIL: Test 1 exited with $EXIT1, expected 0" >&2; exit 1; }

# Verify manifest.json
[ -f "$TEST1_DIR/manifest.json" ] || { echo "FAIL: manifest.json not found" >&2; exit 1; }
M_STATUS=$(jq -r .status "$TEST1_DIR/manifest.json")
M_ID=$(jq -r .deliberation_id "$TEST1_DIR/manifest.json")
M_OPT0=$(jq -r '.options[] | select(.id == "Option_0") | .id' "$TEST1_DIR/manifest.json")

[ "$M_STATUS" = "CONVERGED" ] || { echo "FAIL: manifest status is $M_STATUS, expected CONVERGED" >&2; exit 1; }
[ "$M_ID" = "dlb-test-01" ] || { echo "FAIL: manifest id is $M_ID, expected dlb-test-01" >&2; exit 1; }
[ "$M_OPT0" = "Option_0" ] || { echo "FAIL: Option_0 baseline missing from manifest" >&2; exit 1; }

# Verify option_0_baseline.md
[ -f "$TEST1_DIR/option_0_baseline.md" ] || { echo "FAIL: option_0_baseline.md missing" >&2; exit 1; }

# Verify final_blueprint.md
[ -f "$TEST1_DIR/final_blueprint.md" ] || { echo "FAIL: final_blueprint.md not found" >&2; exit 1; }
BLUEPRINT=$(cat "$TEST1_DIR/final_blueprint.md")
echo "$BLUEPRINT" | grep -q "Option_0" || { echo "FAIL: final_blueprint.md missing Option_0" >&2; exit 1; }
echo "$BLUEPRINT" | grep -q "Structured Metric Evaluation" || { echo "FAIL: final_blueprint.md missing metric table" >&2; exit 1; }

# Verify stdout summary table
echo "$OUTPUT1" | grep -q "CONSENSUS REACHED" || { echo "FAIL: terminal output missing consensus header" >&2; exit 1; }
echo "$OUTPUT1" | grep -q "Option_0" || { echo "FAIL: terminal output missing Option_0" >&2; exit 1; }

echo "PASS: Lifecycle 1 verified."

echo "=== Test 2: Lifecycle 2 - Multi-Round Progression & Jetski Evidence Integration ==="
TEST2_DIR="$TEMP_DIR/test2_delib"
export MOCK_SCENARIO="FACTUAL_OBJ_TO_CONVERGED"

# Create a pre-supplied jetski evidence file
EVIDENCE_FILE="$TEMP_DIR/mock_jetski_evidence.md"
cat <<'EOF' > "$EVIDENCE_FILE"
# Empirical Benchmark Results
Measured latency: direct write average is 1.2ms under 1000 ops/s.
Disk latency does not exceed 10ms threshold.
EOF

OUTPUT2=$(bash "$DELIBERATE_SCRIPT" \
  --id "dlb-test-02" \
  --dir "$TEST2_DIR" \
  --rounds 3 \
  --jetski-evidence "$EVIDENCE_FILE" \
  "Evaluate Disk I/O Performance for Log Engine")
EXIT2=$?

[ "$EXIT2" -eq 0 ] || { echo "FAIL: Test 2 exited with $EXIT2, expected 0" >&2; exit 1; }

# Verify jetski_evidence_prompt.md was generated in Round 1
[ -f "$TEST2_DIR/round-1/jetski_evidence_prompt.md" ] || { echo "FAIL: jetski_evidence_prompt.md not generated in round-1" >&2; exit 1; }
PROMPT_CONTENT=$(cat "$TEST2_DIR/round-1/jetski_evidence_prompt.md")
echo "$PROMPT_CONTENT" | grep -q "OBJ-1" || { echo "FAIL: prompt missing factual objection OBJ-1" >&2; exit 1; }

# Verify round-1 digest.md included the Jetski evidence
DIGEST_R1=$(cat "$TEST2_DIR/round-1/digest.md")
echo "$DIGEST_R1" | grep -q "Empirical Spike Evidence (Jetski)" || { echo "FAIL: round-1 digest did not integrate Jetski evidence" >&2; exit 1; }

# Verify mock detected evidence in Round 2
[ -f "$MOCK_LOGS/jetski_detected.txt" ] || { echo "FAIL: Mock round 2 did not detect Jetski evidence in digest" >&2; exit 1; }

# Verify convergence after round 2
[ -f "$TEST2_DIR/final_blueprint.md" ] || { echo "FAIL: final_blueprint.md not found in test 2" >&2; exit 1; }
M2_STATUS=$(jq -r .status "$TEST2_DIR/manifest.json")
[ "$M2_STATUS" = "CONVERGED" ] || { echo "FAIL: manifest status is $M2_STATUS, expected CONVERGED" >&2; exit 1; }

echo "PASS: Lifecycle 2 verified."

echo "=== Test 3: Lifecycle 3 - Deadlock Termination at MAX_ROUNDS ==="
TEST3_DIR="$TEMP_DIR/test3_delib"
export MOCK_SCENARIO="DEADLOCK"

SET_E=$(set +o | grep errexit)
set +e
OUTPUT3=$(bash "$DELIBERATE_SCRIPT" \
  --id "dlb-test-03" \
  --dir "$TEST3_DIR" \
  --rounds 2 \
  "Architectural Framework vs Raw Primitives Dispute" 2>&1)
EXIT3=$?
eval "$SET_E"

[ "$EXIT3" -eq 2 ] || { echo "FAIL: Test 3 exited with $EXIT3, expected 2 (Deadlock)" >&2; exit 1; }

# Verify dissent_register.md created
[ -f "$TEST3_DIR/dissent_register.md" ] || { echo "FAIL: dissent_register.md not found" >&2; exit 1; }
DISSENT=$(cat "$TEST3_DIR/dissent_register.md")
echo "$DISSENT" | grep -q "DEADLOCK" || { echo "FAIL: dissent register missing DEADLOCK header" >&2; exit 1; }
echo "$DISSENT" | grep -q "OBJ-CL-1" || { echo "FAIL: dissent register missing OBJ-CL-1" >&2; exit 1; }
echo "$DISSENT" | grep -q "OBJ-CX-1" || { echo "FAIL: dissent register missing OBJ-CX-1" >&2; exit 1; }
echo "$DISSENT" | grep -q "Human Tie-Breaker" || { echo "FAIL: dissent register missing Human Tie-Breaker section" >&2; exit 1; }

# Verify manifest updated to DEADLOCK
M3_STATUS=$(jq -r .status "$TEST3_DIR/manifest.json")
[ "$M3_STATUS" = "DEADLOCK" ] || { echo "FAIL: manifest status is $M3_STATUS, expected DEADLOCK" >&2; exit 1; }

# Verify stdout contains Deadlock Escalation Report
echo "$OUTPUT3" | grep -q "DEADLOCK ESCALATION REPORT" || { echo "FAIL: terminal missing Deadlock Escalation Report" >&2; exit 1; }
echo "$OUTPUT3" | grep -q "Human Tie-Breaker Options" || { echo "FAIL: terminal missing Human Tie-Breaker options" >&2; exit 1; }

echo "PASS: Lifecycle 3 verified."

echo "=== Test 4: Lifecycle 4 - Argument Parsing & Options ==="
TEST4_DIR="$TEMP_DIR/test4_delib"
rm -f "$MOCK_LOGS/consensus_round_args.txt"
export MOCK_SCENARIO="CONVERGE_ROUND_1"

# Create dummy context files
CTX1="$TEMP_DIR/ctx1.md"
CTX2="$TEMP_DIR/ctx2.md"
echo "Context 1 content" > "$CTX1"
echo "Context 2 content" > "$CTX2"

OUTPUT4=$(bash "$DELIBERATE_SCRIPT" \
  --rounds 4 \
  --model-claude "claude-3-5-sonnet" \
  --model-codex "o3-mini" \
  --id "dlb-custom-99" \
  --dir "$TEST4_DIR" \
  "Custom Topic with Context" \
  "$CTX1" "$CTX2")
EXIT4=$?

[ "$EXIT4" -eq 0 ] || { echo "FAIL: Test 4 exited with $EXIT4, expected 0" >&2; exit 1; }

# Check that CLI passed options to consensus_round.sh
ROUND_ARGS=$(cat "$MOCK_LOGS/consensus_round_args.txt")
echo "$ROUND_ARGS" | grep -q "claude-3-5-sonnet" || { echo "FAIL: --model-claude not forwarded" >&2; exit 1; }
echo "$ROUND_ARGS" | grep -q "o3-mini" || { echo "FAIL: --model-codex not forwarded" >&2; exit 1; }
echo "$ROUND_ARGS" | grep -q "\-\-max\-rounds 4" || { echo "FAIL: --max-rounds 4 not forwarded" >&2; exit 1; }

# Check manifest context files
M4_CTX=$(jq -r '.context_files | length' "$TEST4_DIR/manifest.json")
[ "$M4_CTX" -eq 2 ] || { echo "FAIL: context_files in manifest has length $M4_CTX, expected 2" >&2; exit 1; }

# Test --help
HELP_OUT=$(bash "$DELIBERATE_SCRIPT" --help)
echo "$HELP_OUT" | grep -q "Usage:" || { echo "FAIL: --help missing Usage" >&2; exit 1; }

# Test missing topic argument
set +e
ERR_OUT=$(bash "$DELIBERATE_SCRIPT" 2>&1)
ERR_EXIT=$?
eval "$SET_E"
[ "$ERR_EXIT" -eq 1 ] || { echo "FAIL: missing topic should exit 1, got $ERR_EXIT" >&2; exit 1; }

echo "PASS: Lifecycle 4 verified."

echo "=== Test 5: Sandbox Block (Exit 126) & Outage (Exit 100) Propagation ==="
TEST5_DIR="$TEMP_DIR/test5_delib"
export MOCK_SCENARIO="FAIL_126"

set +e
OUT_126=$(bash "$DELIBERATE_SCRIPT" --dir "$TEST5_DIR/126" "Sandbox Test" 2>&1)
CODE_126=$?

export MOCK_SCENARIO="FAIL_100"
OUT_100=$(bash "$DELIBERATE_SCRIPT" --dir "$TEST5_DIR/100" "Outage Test" 2>&1)
CODE_100=$?
eval "$SET_E"

[ "$CODE_126" -eq 126 ] || { echo "FAIL: Expected exit 126, got $CODE_126" >&2; exit 1; }
echo "$OUT_126" | grep -q "SANDBOX_BLOCKED" || { echo "FAIL: Sandbox output missing warning" >&2; exit 1; }

[ "$CODE_100" -eq 100 ] || { echo "FAIL: Expected exit 100, got $CODE_100" >&2; exit 1; }
echo "$OUT_100" | grep -q "FALLBACK_TRIGGERED" || { echo "FAIL: Outage output missing warning" >&2; exit 1; }

echo "PASS: Exit code propagation verified."

echo "All agent_deliberate tests passed successfully!"
