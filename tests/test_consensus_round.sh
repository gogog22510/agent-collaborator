#!/usr/bin/env bash
# Unit & Integration Test for Single-Round Concurrent Driver (consensus_round.sh)
# Tests isolated directory execution, concurrent execution, ballot extraction,
# tally invocation, and anonymized digest generation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROUND_SCRIPT="$REPO_ROOT/skills/agent-collaborator/scripts/consensus_round.sh"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

MOCK_BIN="$TEMP_DIR/bin"
mkdir -p "$MOCK_BIN"

echo "=== Setting up Mock CLI Binaries ==="

# Mock claude script
cat <<'EOF' > "$MOCK_BIN/claude"
#!/usr/bin/env bash
set -euo pipefail

# Record working directory and args for checks
pwd > "$MOCK_LOG_DIR/claude_cwd.txt"
echo "$@" > "$MOCK_LOG_DIR/claude_args.txt"

# Record stdin for prompt content check
cat > "$MOCK_LOG_DIR/claude_prompt.txt"

MODE="${MOCK_CLAUDE_MODE:-ACCEPT_OPTION_0}"
if [ "$MODE" = "FAIL_126" ]; then
  echo "Operation not permitted" >&2
  exit 126
elif [ "$MODE" = "FAIL_100" ]; then
  echo "Rate limit reached" >&2
  exit 100
elif [ "$MODE" = "LADDER_TEST" ]; then
  CURRENT_ARGS="$*"
  if [[ "$CURRENT_ARGS" =~ "--model haiku" ]]; then
    # Fallback model succeeds
    MODE="ACCEPT_OPTION_0"
  else
    echo "Rate limit exceeded (429)" >&2
    exit 1
  fi
elif [ "$MODE" = "COUNTER_PROPOSAL" ]; then
  cat <<'INNER'
```json
{
  "deliberation_id": "test-dlb-09",
  "round": 1,
  "agent": "claude",
  "model": "sonnet",
  "preferred_option": "Option_0",
  "stance": "BLOCK",
  "metrics": {
    "technical_feasibility": {"score": 2, "confidence": 0.9, "rationale": "Option 0 POSIX primitives cannot integrate into Flutter."},
    "architectural_simplicity": {"score": 4, "confidence": 0.8, "rationale": "Simple but incompatible."},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.9, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Standard baseline."},
    "robustness_failure_modes": {"score": 2, "confidence": 0.8, "rationale": "Discards existing consistency guarantees."},
    "maintainability_testability": {"score": 3, "confidence": 0.8, "rationale": "Requires rewrite."}
  },
  "over_architecture_flags": [],
  "blocking_objections": [
    {
      "id": "OBJ-1",
      "type": "factual",
      "metric_target": "technical_feasibility",
      "claim": "Option 0 cannot preserve existing Flutter UI and state lifecycle.",
      "resolution_condition": "Define an incremental repair option within Dart architecture."
    }
  ],
  "counter_proposal": {
    "title": "Targeted Consistency Repair",
    "description": "Incremental reducer fixes for event idempotency, scene anchoring, and volume pruning without rewriting Riverpod/Hive.",
    "resolves_objections": ["OBJ-1"]
  },
  "position_changes": []
}
```

## Executive Summary & Rationale
Option 0 breaks the Flutter app; proposing targeted consistency repair instead.
INNER
fi

# Simulate concurrent work
touch "$MOCK_LOG_DIR/claude_running"
sleep 0.2
rm -f "$MOCK_LOG_DIR/claude_running"

if [ "$MODE" = "ACCEPT_OPTION_0" ]; then
  cat <<'INNER'
```json
{
  "deliberation_id": "test-dlb-01",
  "round": 1,
  "agent": "claude",
  "model": "sonnet",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.9, "rationale": "Standard POSIX utilities."},
    "architectural_simplicity": {"score": 5, "confidence": 0.95, "rationale": "Single layer implementation."},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.95, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Direct file writes."},
    "robustness_failure_modes": {"score": 4, "confidence": 0.85, "rationale": "Handles basic errors cleanly."},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Easily tested with static fixtures."}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": []
}
```

## Executive Summary & Preferred Option Rationale
Claude recommends Option 0 because it achieves the goal with zero dependencies.
INNER
fi
EOF
chmod +x "$MOCK_BIN/claude"

# Mock codex script
cat <<'EOF' > "$MOCK_BIN/codex"
#!/usr/bin/env bash
set -euo pipefail

# Record working directory and args for checks
pwd > "$MOCK_LOG_DIR/codex_cwd.txt"
echo "$@" > "$MOCK_LOG_DIR/codex_args.txt"

# Record stdin for prompt content check
cat > "$MOCK_LOG_DIR/codex_prompt.txt"

MODE="${MOCK_CODEX_MODE:-BLOCK_OPTION_B}"
if [ "$MODE" = "FAIL_126" ]; then
  echo "Operation not permitted" >&2
  exit 126
elif [ "$MODE" = "FAIL_100" ]; then
  echo "Rate limit reached" >&2
  exit 100
elif [ "$MODE" = "LADDER_TEST" ]; then
  CURRENT_ARGS="$*"
  if [[ "$CURRENT_ARGS" =~ "--model gpt-5.6-terra" ]] || [[ "$CURRENT_ARGS" =~ "--model gpt-4o" ]] || [[ ! "$CURRENT_ARGS" =~ "--model" ]]; then
    # Fallback model succeeds
    MODE="CONVERGE_OPTION_0"
  else
    echo "ERROR: 400 Invalid model" >&2
    exit 1
  fi
fi

# Simulate concurrent work
touch "$MOCK_LOG_DIR/codex_running"
sleep 0.2
rm -f "$MOCK_LOG_DIR/codex_running"

if [ "$MODE" = "BLOCK_OPTION_B" ]; then
  cat <<'INNER'
```json
{
  "deliberation_id": "test-dlb-01",
  "round": 1,
  "agent": "codex",
  "model": "o3-mini",
  "preferred_option": "Option_B",
  "stance": "BLOCK",
  "metrics": {
    "technical_feasibility": {"score": 4, "confidence": 0.8, "rationale": "Works but complex setup."},
    "architectural_simplicity": {"score": 2, "confidence": 0.9, "rationale": "Too many abstraction layers."},
    "yagni_and_parsimony": {"score": 2, "confidence": 0.9, "cognitive_overhead": "HIGH", "indirection_layers": 4, "rationale": "Introduces unnecessary message broker."},
    "robustness_failure_modes": {"score": 3, "confidence": 0.7, "rationale": "Daemon crash vulnerability."},
    "maintainability_testability": {"score": 2, "confidence": 0.8, "rationale": "Hard to unit test without mock broker."}
  },
  "over_architecture_flags": [
    {
      "pattern": "PREMATURE_GENERALIZATION",
      "critique": "Option B introduces an asynchronous message queue when a simple file pipe suffices.",
      "simplification_remedy": "Use standard filesystem I/O."
    }
  ],
  "blocking_objections": [
    {
      "id": "OBJ-1",
      "type": "tradeoff",
      "metric_target": "yagni_and_parsimony",
      "claim": "Message queue overhead exceeds requirement.",
      "resolution_condition": "Remove queue daemon."
    }
  ],
  "position_changes": []
}
```

## Executive Summary & Preferred Option Rationale
Codex considers Option B functionally rich but places a block due to unjustified queue infrastructure.
INNER
elif [ "$MODE" = "CONVERGE_OPTION_0" ]; then
  cat <<'INNER'
```json
{
  "deliberation_id": "test-dlb-01",
  "round": 1,
  "agent": "codex",
  "model": "o3-mini",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.9, "rationale": "Standard POSIX utilities."},
    "architectural_simplicity": {"score": 5, "confidence": 0.9, "rationale": "Single layer implementation."},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.95, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Direct file writes."},
    "robustness_failure_modes": {"score": 4, "confidence": 0.8, "rationale": "Handles basic errors cleanly."},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Easily tested with static fixtures."}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": []
}
```

## Executive Summary & Preferred Option Rationale
Codex agrees with Option 0 baseline.
INNER
fi
EOF
chmod +x "$MOCK_BIN/codex"

echo "=== Test 1: In-Debate Round (Option divergence + YAGNI veto) ==="
DELIB_DIR="$TEMP_DIR/delib_test1"
MOCK_LOG_DIR="$TEMP_DIR/logs1"
mkdir -p "$DELIB_DIR" "$MOCK_LOG_DIR"

cat <<'EOF' > "$DELIB_DIR/manifest.json"
{
  "deliberation_id": "test-dlb-01",
  "topic": "Batch Log Ingestion Architecture",
  "options": [
    {"id": "Option_0", "description": "Direct file append with standard POSIX utils"},
    {"id": "Option_B", "description": "Distributed message broker with pub/sub queue"}
  ],
  "max_rounds": 3
}
EOF

export PATH="$MOCK_BIN:$PATH"
export MOCK_LOG_DIR="$MOCK_LOG_DIR"
export MOCK_CLAUDE_MODE="ACCEPT_OPTION_0"
export MOCK_CODEX_MODE="BLOCK_OPTION_B"

bash "$ROUND_SCRIPT" "$DELIB_DIR" 1

echo "Verifying exit code and round output files..."
[ -f "$DELIB_DIR/round-1/claude_ballot.json" ] || { echo "FAIL: claude_ballot.json missing" >&2; exit 1; }
[ -f "$DELIB_DIR/round-1/claude_ballot.md" ] || { echo "FAIL: claude_ballot.md missing" >&2; exit 1; }
[ -f "$DELIB_DIR/round-1/codex_ballot.json" ] || { echo "FAIL: codex_ballot.json missing" >&2; exit 1; }
[ -f "$DELIB_DIR/round-1/codex_ballot.md" ] || { echo "FAIL: codex_ballot.md missing" >&2; exit 1; }
[ -f "$DELIB_DIR/round-1/tally.json" ] || { echo "FAIL: tally.json missing" >&2; exit 1; }
[ -f "$DELIB_DIR/round-1/digest.md" ] || { echo "FAIL: digest.md missing" >&2; exit 1; }

echo "Verifying isolated working directories..."
CLAUDE_CWD=$(cat "$MOCK_LOG_DIR/claude_cwd.txt")
CODEX_CWD=$(cat "$MOCK_LOG_DIR/codex_cwd.txt")

if [[ "$CLAUDE_CWD" != *".sessions/claude"* ]]; then
  echo "FAIL: Claude did not run in isolated directory, got: $CLAUDE_CWD" >&2
  exit 1
fi
if [[ "$CODEX_CWD" != *".sessions/codex"* ]]; then
  echo "FAIL: Codex did not run in isolated directory, got: $CODEX_CWD" >&2
  exit 1
fi
echo "PASS: Isolated working directories verified."

echo "Verifying tally status..."
TALLY_STATUS=$(jq -r .status "$DELIB_DIR/round-1/tally.json")
if [ "$TALLY_STATUS" != "IN_DEBATE" ]; then
  echo "FAIL: Expected IN_DEBATE status, got: $TALLY_STATUS" >&2
  exit 1
fi
echo "PASS: Tally status is IN_DEBATE."

echo "Verifying anonymized digest content..."
DIGEST_CONTENT=$(cat "$DELIB_DIR/round-1/digest.md")
if ! echo "$DIGEST_CONTENT" | grep -q "Agent A"; then
  echo "FAIL: digest.md does not mention Agent A" >&2
  exit 1
fi
if ! echo "$DIGEST_CONTENT" | grep -q "Agent B"; then
  echo "FAIL: digest.md does not mention Agent B" >&2
  exit 1
fi
if echo "$DIGEST_CONTENT" | grep -iE "(claude|codex)"; then
  echo "FAIL: digest.md leaked peer identity (claude/codex)" >&2
  exit 1
fi
if ! echo "$DIGEST_CONTENT" | grep -q "OBJ-1"; then
  echo "FAIL: digest.md missing blocking objection OBJ-1" >&2
  exit 1
fi
if ! echo "$DIGEST_CONTENT" | grep -q "PREMATURE_GENERALIZATION"; then
  echo "FAIL: digest.md missing over-architecture flag PREMATURE_GENERALIZATION" >&2
  exit 1
fi
echo "PASS: Anonymized digest verified."

echo "=== Test 2: Full Convergence Round ==="
DELIB_DIR2="$TEMP_DIR/delib_test2"
MOCK_LOG_DIR2="$TEMP_DIR/logs2"
mkdir -p "$DELIB_DIR2" "$MOCK_LOG_DIR2"

cat <<'EOF' > "$DELIB_DIR2/manifest.json"
{
  "deliberation_id": "test-dlb-02",
  "topic": "Converged Architecture Requirement",
  "options": [
    {"id": "Option_0", "description": "Minimal Viable Architecture"}
  ],
  "max_rounds": 3
}
EOF

export MOCK_LOG_DIR="$MOCK_LOG_DIR2"
export MOCK_CLAUDE_MODE="ACCEPT_OPTION_0"
export MOCK_CODEX_MODE="CONVERGE_OPTION_0"

bash "$ROUND_SCRIPT" "$DELIB_DIR2" 1

CONV_STATUS=$(jq -r .status "$DELIB_DIR2/round-1/tally.json")
CONV_OPTION=$(jq -r .consensus_option "$DELIB_DIR2/round-1/tally.json")

if [ "$CONV_STATUS" != "CONVERGED" ]; then
  echo "FAIL: Expected CONVERGED status, got: $CONV_STATUS" >&2
  exit 1
fi
if [ "$CONV_OPTION" != "Option_0" ]; then
  echo "FAIL: Expected consensus_option Option_0, got: $CONV_OPTION" >&2
  exit 1
fi
echo "PASS: Full convergence round verified."

echo "=== Test 3: Round 2 Digest & Prior Ballot Injection ==="
DELIB_DIR3="$TEMP_DIR/delib_test3"
MOCK_LOG_DIR3="$TEMP_DIR/logs3"
mkdir -p "$DELIB_DIR3/round-1" "$MOCK_LOG_DIR3"

cat <<'EOF' > "$DELIB_DIR3/manifest.json"
{
  "deliberation_id": "test-dlb-03",
  "topic": "Multi-round Deliberation",
  "options": [
    {"id": "Option_0", "description": "Option 0"},
    {"id": "Option_A", "description": "Option A"}
  ],
  "max_rounds": 3
}
EOF

cat <<'EOF' > "$DELIB_DIR3/round-1/digest.md"
# Previous Round Digest
Summary: Agent A and Agent B disputed OBJ-99.
EOF

cat <<'EOF' > "$DELIB_DIR3/round-1/claude_ballot.json"
{"deliberation_id": "test-dlb-03", "round": 1, "preferred_option": "Option_0"}
EOF

cat <<'EOF' > "$DELIB_DIR3/round-1/codex_ballot.json"
{"deliberation_id": "test-dlb-03", "round": 1, "preferred_option": "Option_A"}
EOF

export MOCK_LOG_DIR="$MOCK_LOG_DIR3"
export MOCK_CLAUDE_MODE="ACCEPT_OPTION_0"
export MOCK_CODEX_MODE="CONVERGE_OPTION_0"

bash "$ROUND_SCRIPT" "$DELIB_DIR3" 2

CLAUDE_PROMPT=$(cat "$MOCK_LOG_DIR3/claude_prompt.txt")
if ! echo "$CLAUDE_PROMPT" | grep -q "OBJ-99"; then
  echo "FAIL: Round 2 did not inject prior round digest into Claude prompt" >&2
  exit 1
fi
echo "PASS: Round 2 digest injection verified."

echo "=== Test 4: Sandbox Blocking (Exit 126) ==="
DELIB_DIR4="$TEMP_DIR/delib_test4"
MOCK_LOG_DIR4="$TEMP_DIR/logs4"
mkdir -p "$DELIB_DIR4" "$MOCK_LOG_DIR4"

cat <<'EOF' > "$DELIB_DIR4/manifest.json"
{
  "deliberation_id": "test-dlb-04",
  "topic": "Sandbox Block Test",
  "options": [{"id": "Option_0", "description": "Option 0"}]
}
EOF

export MOCK_LOG_DIR="$MOCK_LOG_DIR4"
export MOCK_CLAUDE_MODE="FAIL_126"
export MOCK_CODEX_MODE="CONVERGE_OPTION_0"

SET_E_STATE=$(set +o | grep errexit)
set +e
OUTPUT_126=$(bash "$ROUND_SCRIPT" "$DELIB_DIR4" 1 2>&1)
EXIT_126=$?
eval "$SET_E_STATE"

if [ "$EXIT_126" -ne 126 ]; then
  echo "FAIL: Expected exit 126 on sandbox block, got $EXIT_126" >&2
  exit 1
fi
if ! echo "$OUTPUT_126" | grep -q "SANDBOX_BLOCKED"; then
  echo "FAIL: Output missing SANDBOX_BLOCKED message" >&2
  exit 1
fi
echo "PASS: Sandbox blocking (Exit 126) verified."

echo "=== Test 5: Total Peer Outage (Exit 100) ==="
DELIB_DIR5="$TEMP_DIR/delib_test5"
MOCK_LOG_DIR5="$TEMP_DIR/logs5"
mkdir -p "$DELIB_DIR5" "$MOCK_LOG_DIR5"

cat <<'EOF' > "$DELIB_DIR5/manifest.json"
{
  "deliberation_id": "test-dlb-05",
  "topic": "Outage Test",
  "options": [{"id": "Option_0", "description": "Option 0"}]
}
EOF

export MOCK_LOG_DIR="$MOCK_LOG_DIR5"
export MOCK_CLAUDE_MODE="FAIL_100"
export MOCK_CODEX_MODE="FAIL_100"

set +e
OUTPUT_100=$(bash "$ROUND_SCRIPT" "$DELIB_DIR5" 1 2>&1)
EXIT_100=$?
eval "$SET_E_STATE"

if [ "$EXIT_100" -ne 100 ]; then
  echo "FAIL: Expected exit 100 on peer outage, got $EXIT_100" >&2
  exit 1
fi
if ! echo "$OUTPUT_100" | grep -q "FALLBACK_TRIGGERED"; then
  echo "FAIL: Output missing FALLBACK_TRIGGERED message" >&2
  exit 1
fi
echo "PASS: Total peer outage (Exit 100) verified."

echo "=== Test 6: CLI Flags (--max-rounds, --model-claude, --model-codex) ==="
DELIB_DIR6="$TEMP_DIR/delib_test6"
MOCK_LOG_DIR6="$TEMP_DIR/logs6"
mkdir -p "$DELIB_DIR6" "$MOCK_LOG_DIR6"

cat <<'EOF' > "$DELIB_DIR6/manifest.json"
{
  "deliberation_id": "test-dlb-06",
  "topic": "CLI Flags Test",
  "options": [{"id": "Option_0", "description": "Option 0"}]
}
EOF

export MOCK_LOG_DIR="$MOCK_LOG_DIR6"
export MOCK_CLAUDE_MODE="ACCEPT_OPTION_0"
export MOCK_CODEX_MODE="CONVERGE_OPTION_0"

bash "$ROUND_SCRIPT" --max-rounds 5 --model-claude custom-sonnet --model-codex custom-o3 "$DELIB_DIR6" 1

CLAUDE_ARGS_RECORDED=$(cat "$MOCK_LOG_DIR6/claude_args.txt")
CODEX_ARGS_RECORDED=$(cat "$MOCK_LOG_DIR6/codex_args.txt")

if ! echo "$CLAUDE_ARGS_RECORDED" | grep -q "custom-sonnet"; then
  echo "FAIL: Claude did not receive --model custom-sonnet, args: $CLAUDE_ARGS_RECORDED" >&2
  exit 1
fi
if ! echo "$CODEX_ARGS_RECORDED" | grep -q "custom-o3"; then
  echo "FAIL: Codex did not receive --model custom-o3, args: $CODEX_ARGS_RECORDED" >&2
  exit 1
fi

TALLY_MAX_ROUNDS=$(jq -r .max_rounds "$DELIB_DIR6/round-1/tally.json")
if [ "$TALLY_MAX_ROUNDS" -ne 5 ]; then
  echo "FAIL: Expected tally max_rounds 5, got: $TALLY_MAX_ROUNDS" >&2
  exit 1
fi
echo "PASS: CLI flags verified."

echo "=== Test 7: Missing manifest (Exit 1) ==="
DELIB_DIR7="$TEMP_DIR/delib_test7_empty"
mkdir -p "$DELIB_DIR7"

set +e
bash "$ROUND_SCRIPT" "$DELIB_DIR7" 1 >/dev/null 2>&1
EXIT_MISSING_MANIFEST=$?
eval "$SET_E_STATE"

if [ "$EXIT_MISSING_MANIFEST" -ne 1 ]; then
  echo "FAIL: Expected exit 1 on missing manifest, got $EXIT_MISSING_MANIFEST" >&2
  exit 1
fi
echo "PASS: Missing manifest failure verified."

echo "=== Test 8: Model Fallback Ladder (Retry on 429/400 and succeed on fallback rung) ==="
DELIB_DIR8="$TEMP_DIR/delib_test8"
MOCK_LOG_DIR8="$TEMP_DIR/logs8"
mkdir -p "$DELIB_DIR8" "$MOCK_LOG_DIR8"

cat <<'EOF' > "$DELIB_DIR8/manifest.json"
{
  "deliberation_id": "test-dlb-08",
  "topic": "Fallback Ladder Test",
  "options": [{"id": "Option_0", "description": "Option 0"}]
}
EOF

export MOCK_LOG_DIR="$MOCK_LOG_DIR8"
export MOCK_CLAUDE_MODE="LADDER_TEST"
export MOCK_CODEX_MODE="LADDER_TEST"

bash "$ROUND_SCRIPT" "$DELIB_DIR8" 1

if [ ! -s "$DELIB_DIR8/round-1/claude_ballot.json" ]; then
  echo "FAIL: Claude ballot missing after fallback ladder" >&2
  exit 1
fi
if [ ! -s "$DELIB_DIR8/round-1/codex_ballot.json" ]; then
  echo "FAIL: Codex ballot missing after fallback ladder" >&2
  exit 1
fi

META_FILE="$DELIB_DIR8/round-1/meta.json"
if [ ! -f "$META_FILE" ]; then
  echo "FAIL: round-1/meta.json missing" >&2
  exit 1
fi

CLAUDE_MODEL_USED=$(jq -r '.claude.model_used' "$META_FILE")
CODEX_MODEL_USED=$(jq -r '.codex.model_used' "$META_FILE")

if [ "$CLAUDE_MODEL_USED" != "haiku" ]; then
  echo "FAIL: Expected Claude to fallback to haiku, got $CLAUDE_MODEL_USED" >&2
  exit 1
fi
if [ "$CODEX_MODEL_USED" != "gpt-5.6-terra" ] && [ "$CODEX_MODEL_USED" != "gpt-4o" ] && [ "$CODEX_MODEL_USED" != "default" ]; then
  echo "FAIL: Expected Codex to fallback to gpt-5.6-terra, gpt-4o, or default, got $CODEX_MODEL_USED" >&2
  exit 1
fi

echo "PASS: Model fallback ladder verified."

echo "=== Test 9: Counter-Proposal Synthesis into Manifest Options ==="
DELIB_DIR9="$TEMP_DIR/delib_test9"
MOCK_LOG_DIR9="$TEMP_DIR/logs9"
mkdir -p "$DELIB_DIR9" "$MOCK_LOG_DIR9"

cat <<'EOF' > "$DELIB_DIR9/manifest.json"
{
  "deliberation_id": "test-dlb-09",
  "topic": "Synthesis Test",
  "options": [{"id": "Option_0", "description": "Option 0"}]
}
EOF

export MOCK_LOG_DIR="$MOCK_LOG_DIR9"
export MOCK_CLAUDE_MODE="COUNTER_PROPOSAL"
export MOCK_CODEX_MODE="BLOCK_OPTION_B"

bash "$ROUND_SCRIPT" "$DELIB_DIR9" 1

MANIFEST_OPTIONS=$(jq -c '.options' "$DELIB_DIR9/manifest.json")
HAS_OPTION_A=$(echo "$MANIFEST_OPTIONS" | jq -e 'map(select(.id == "Option_A")) | length')

if [ "$HAS_OPTION_A" -lt 1 ]; then
  echo "FAIL: Expected Option_A to be synthesized into manifest.json, options: $MANIFEST_OPTIONS" >&2
  exit 1
fi

DIGEST_FILE9="$DELIB_DIR9/round-1/digest.md"
if ! grep -q "Synthesized Candidate Options" "$DIGEST_FILE9"; then
  echo "FAIL: Expected digest to list synthesized candidate options" >&2
  exit 1
fi
echo "PASS: Counter-proposal synthesis verified."

echo "All consensus_round tests passed successfully!"
