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

echo "=== Test 8: Flag Targeting Rejected Option Does Not Block Candidate Option ==="
# Both prefer Option_0, but codex flags Option_B as over-architected
cp "$TEMP_DIR/claude.json" "$TEMP_DIR/claude_target.json"
cp "$TEMP_DIR/codex.json" "$TEMP_DIR/codex_target.json"
jq '.preferred_option = "Option_0" | .stance = "ACCEPT" | .over_architecture_flags = [{"id": "YAGNI-1", "pattern": "PREMATURE_GENERALIZATION", "target_option": "Option_B", "critique": "Option B is too complex"}]' "$TEMP_DIR/codex_target.json" > "$TEMP_DIR/codex_target_mod.json"
mv "$TEMP_DIR/codex_target_mod.json" "$TEMP_DIR/codex_target.json"

bash "$TALLY_SH" "$TEMP_DIR/claude_target.json" "$TEMP_DIR/codex_target.json" "$TEMP_DIR/tally8.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally8.json")
CONSENSUS_OPT=$(jq -r .consensus_option "$TEMP_DIR/tally8.json")
if [ "$STATUS" != "CONVERGED" ] || [ "$CONSENSUS_OPT" != "Option_0" ]; then
  echo "FAIL: Expected CONVERGED on Option_0 when flag targets Option_B, got status=$STATUS, opt=$CONSENSUS_OPT" >&2
  exit 1
fi
echo "PASS: Flag targeting rejected option correctly did not block Option_0"

echo "=== Test 9: Per-peer YAGNI Floor Disqualifies Option even if Avg >= 3.5 ==="
# Claude YAGNI = 5, Codex YAGNI = 2 (Avg = 3.5, but Codex is below 3.0 floor)
cp "$TEMP_DIR/claude.json" "$TEMP_DIR/claude_floor.json"
cp "$TEMP_DIR/codex.json" "$TEMP_DIR/codex_floor.json"
jq '.metrics.yagni_and_parsimony.score = 5' "$TEMP_DIR/claude_floor.json" > "$TEMP_DIR/cf.json" && mv "$TEMP_DIR/cf.json" "$TEMP_DIR/claude_floor.json"
jq '.metrics.yagni_and_parsimony.score = 2' "$TEMP_DIR/codex_floor.json" > "$TEMP_DIR/xf.json" && mv "$TEMP_DIR/xf.json" "$TEMP_DIR/codex_floor.json"

bash "$TALLY_SH" "$TEMP_DIR/claude_floor.json" "$TEMP_DIR/codex_floor.json" "$TEMP_DIR/tally9.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally9.json")
if [ "$STATUS" == "CONVERGED" ]; then
  echo "FAIL: Expected non-convergence due to per-peer YAGNI floor < 3.0, got CONVERGED" >&2
  exit 1
fi
echo "PASS: Per-peer YAGNI floor verified"

echo "All tally tests passed successfully!"

