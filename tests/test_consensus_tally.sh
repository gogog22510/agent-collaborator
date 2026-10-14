#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TALLY_SH="$SCRIPT_DIR/../skills/agent-collaborator/scripts/consensus_tally.sh"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "=== Test 1: Full Convergence on Option_0 ==="
cp "$SCRIPT_DIR/fixtures/valid_ballot_claude.json" "$TEMP_DIR/claude.json"
cp "$SCRIPT_DIR/fixtures/valid_ballot_claude.json" "$TEMP_DIR/codex.json"
# Modify agent name for codex
jq '.agent = "codex"' "$TEMP_DIR/codex.json" > "$TEMP_DIR/codex_mod.json" && mv "$TEMP_DIR/codex_mod.json" "$TEMP_DIR/codex.json"

bash "$TALLY_SH" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally1.json" 1
STATUS=$(jq -r .status "$TEMP_DIR/tally1.json")
if [ "$STATUS" != "CONVERGED" ]; then
  echo "FAIL: Expected CONVERGED, got $STATUS" >&2
  exit 1
fi
echo "PASS: Full Convergence verified"

echo "=== Test 2: Over-Architecture Veto Triggered ==="
bash "$TALLY_SH" "$TEMP_DIR/claude.json" "$SCRIPT_DIR/fixtures/overarchitecture_ballot.json" "$TEMP_DIR/tally2.json" 1
STATUS=$(jq -r .status "$TEMP_DIR/tally2.json")
HAS_VETO=$(jq '.over_architecture_flags | length' "$TEMP_DIR/tally2.json")
if [ "$STATUS" != "IN_DEBATE" ] || [ "$HAS_VETO" -le 0 ]; then
  echo "FAIL: Expected IN_DEBATE with flags, got $STATUS, flags: $HAS_VETO" >&2
  exit 1
fi
echo "PASS: Over-Architecture Veto verified"

echo "=== Test 3: Convergence with Dissent (Spread > 1) ==="
# Same option Option_0, no block, yagni >= 3.5, but robustness spread is 2 (5 vs 3)
cp "$TEMP_DIR/claude.json" "$TEMP_DIR/claude_dissent.json"
cp "$TEMP_DIR/codex.json" "$TEMP_DIR/codex_dissent.json"
jq '.metrics.robustness_failure_modes.score = 2' "$TEMP_DIR/codex_dissent.json" > "$TEMP_DIR/codex_dissent_mod.json"
mv "$TEMP_DIR/codex_dissent_mod.json" "$TEMP_DIR/codex_dissent.json"

bash "$TALLY_SH" "$TEMP_DIR/claude_dissent.json" "$TEMP_DIR/codex_dissent.json" "$TEMP_DIR/tally3.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally3.json")
CONSENSUS_OPT=$(jq -r .consensus_option "$TEMP_DIR/tally3.json")
SPREAD=$(jq '.score_spreads.robustness_failure_modes' "$TEMP_DIR/tally3.json")
if [ "$STATUS" != "CONVERGED_WITH_DISSENT" ] || [ "$CONSENSUS_OPT" != "Option_0" ] || [ "$SPREAD" -le 1 ]; then
  echo "FAIL: Expected CONVERGED_WITH_DISSENT with Option_0 and spread > 1, got status=$STATUS, opt=$CONSENSUS_OPT, spread=$SPREAD" >&2
  exit 1
fi
echo "PASS: Convergence with Dissent verified"

echo "=== Test 4: Deadlock Reached at Max Rounds ==="
# In debate at round 3 with max_rounds 3 -> DEADLOCK
bash "$TALLY_SH" "$TEMP_DIR/claude.json" "$SCRIPT_DIR/fixtures/overarchitecture_ballot.json" "$TEMP_DIR/tally4.json" 3 3
STATUS=$(jq -r .status "$TEMP_DIR/tally4.json")
if [ "$STATUS" != "DEADLOCK" ]; then
  echo "FAIL: Expected DEADLOCK at round 3 of 3, got $STATUS" >&2
  exit 1
fi
echo "PASS: Deadlock verified"

echo "=== Test 5: Graceful Degradation (Single Peer Missing/Corrupted) ==="
bash "$TALLY_SH" "$TEMP_DIR/claude.json" "$TEMP_DIR/nonexistent_codex.json" "$TEMP_DIR/tally5.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally5.json")
DEGRADED_PEER=$(jq -r .degraded_peer "$TEMP_DIR/tally5.json")
if [ "$STATUS" != "DEGRADED" ] || [ "$DEGRADED_PEER" != "codex" ]; then
  echo "FAIL: Expected DEGRADED with degraded_peer=codex, got status=$STATUS, peer=$DEGRADED_PEER" >&2
  exit 1
fi
echo "PASS: Single peer degradation verified"

echo "=== Test 6: Graceful Degradation (Both Peers Missing) ==="
bash "$TALLY_SH" "$TEMP_DIR/nonexistent_claude.json" "$TEMP_DIR/nonexistent_codex.json" "$TEMP_DIR/tally6.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally6.json")
DEGRADED_PEER=$(jq -r .degraded_peer "$TEMP_DIR/tally6.json")
if [ "$STATUS" != "DEGRADED" ] || [ "$DEGRADED_PEER" != "both" ]; then
  echo "FAIL: Expected DEGRADED with degraded_peer=both, got status=$STATUS, peer=$DEGRADED_PEER" >&2
  exit 1
fi
echo "PASS: Both peers degradation verified"

echo "=== Test 7: Argument Validation ==="
if bash "$TALLY_SH" "$TEMP_DIR/claude.json" 2>/dev/null; then
  echo "FAIL: Expected non-zero exit code when missing arguments" >&2
  exit 1
fi
echo "PASS: Argument validation verified"

echo "All tally tests passed successfully!"
