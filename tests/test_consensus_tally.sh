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

echo "=== Test 10: Unregistered Option cannot produce CONVERGED ==="
# Both prefer Option_X, but manifest only registers Option_0
cp "$TEMP_DIR/claude.json" "$TEMP_DIR/claude_unreg.json"
cp "$TEMP_DIR/codex.json" "$TEMP_DIR/codex_unreg.json"
jq '.preferred_option = "Option_X" | .stance = "ACCEPT"' "$TEMP_DIR/claude_unreg.json" > "$TEMP_DIR/cu.json" && mv "$TEMP_DIR/cu.json" "$TEMP_DIR/claude_unreg.json"
jq '.preferred_option = "Option_X" | .stance = "ACCEPT"' "$TEMP_DIR/codex_unreg.json" > "$TEMP_DIR/xu.json" && mv "$TEMP_DIR/xu.json" "$TEMP_DIR/codex_unreg.json"

cat <<'EOF' > "$TEMP_DIR/manifest_only_opt0.json"
{
  "deliberation_id": "test-tally-10",
  "options": [{"id": "Option_0", "description": "Option 0"}]
}
EOF

bash "$TALLY_SH" "$TEMP_DIR/claude_unreg.json" "$TEMP_DIR/codex_unreg.json" "$TEMP_DIR/tally10.json" 1 3 "$TEMP_DIR/manifest_only_opt0.json"
STATUS10=$(jq -r .status "$TEMP_DIR/tally10.json")
if [ "$STATUS10" == "CONVERGED" ] || [ "$STATUS10" == "CONVERGED_WITH_DISSENT" ]; then
  echo "FAIL: Expected non-convergence on unregistered option, got $STATUS10" >&2
  exit 1
fi
echo "PASS: Unregistered option rejection verified"

echo "=== Test 11: 3-Peer Full Convergence (Claude + Codex + Gemini) ==="
cp "$TEMP_DIR/claude.json" "$TEMP_DIR/gemini.json"
jq '.agent = "gemini" | .model = "gemini-pro"' "$TEMP_DIR/gemini.json" > "$TEMP_DIR/gemini_mod.json" && mv "$TEMP_DIR/gemini_mod.json" "$TEMP_DIR/gemini.json"

bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally11.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally11.json")
QUORUM=$(jq -r .quorum_met "$TEMP_DIR/tally11.json")
REDUCED=$(jq -r .reduced_quorum "$TEMP_DIR/tally11.json")
PEER_COUNT=$(jq '.participating_peers | length' "$TEMP_DIR/tally11.json")
if [ "$STATUS" != "CONVERGED" ] || [ "$QUORUM" != "true" ] || [ "$REDUCED" != "false" ] || [ "$PEER_COUNT" -ne 3 ]; then
  echo "FAIL: Expected 3-peer CONVERGED quorum_met=true reduced_quorum=false, got status=$STATUS quorum=$QUORUM reduced=$REDUCED count=$PEER_COUNT" >&2
  exit 1
fi
echo "PASS: 3-Peer Full Convergence verified"

echo "=== Test 12: 3-Peer 2v1 Split Vote -> IN_DEBATE (Round 1) & DEADLOCK (Round 3) ==="
cp "$TEMP_DIR/gemini.json" "$TEMP_DIR/gemini_optA.json"
jq '.preferred_option = "Option_A"' "$TEMP_DIR/gemini_optA.json" > "$TEMP_DIR/ga.json" && mv "$TEMP_DIR/ga.json" "$TEMP_DIR/gemini_optA.json"

bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini_optA.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally12a.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally12a.json")
if [ "$STATUS" != "IN_DEBATE" ]; then
  echo "FAIL: Expected IN_DEBATE on 2v1 split in round 1, got $STATUS" >&2
  exit 1
fi
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini_optA.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally12b.json" 3 3
STATUS=$(jq -r .status "$TEMP_DIR/tally12b.json")
if [ "$STATUS" != "DEADLOCK" ]; then
  echo "FAIL: Expected DEADLOCK on 2v1 split in round 3, got $STATUS" >&2
  exit 1
fi
echo "PASS: 3-Peer 2v1 split vote verified"

echo "=== Test 13: 3-Peer Spread > 1 -> CONVERGED_WITH_DISSENT ==="
cp "$TEMP_DIR/gemini.json" "$TEMP_DIR/gemini_spread.json"
jq '.metrics.robustness_failure_modes.score = 2' "$TEMP_DIR/gemini_spread.json" > "$TEMP_DIR/gs.json" && mv "$TEMP_DIR/gs.json" "$TEMP_DIR/gemini_spread.json"
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini_spread.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally13.json" 1 3
STATUS=$(jq -r .status "$TEMP_DIR/tally13.json")
SPREAD=$(jq '.score_spreads.robustness_failure_modes' "$TEMP_DIR/tally13.json")
if [ "$STATUS" != "CONVERGED_WITH_DISSENT" ] || [ "$SPREAD" -ne 2 ]; then
  echo "FAIL: Expected CONVERGED_WITH_DISSENT with spread=2, got status=$STATUS spread=$SPREAD" >&2
  exit 1
fi
echo "PASS: 3-Peer CONVERGED_WITH_DISSENT verified"

echo "=== Test 14: 2-of-3 Survival Quorum (All 3 combinations) ==="
# 14a: Claude + Gemini (Codex absent)
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/missing_codex.json" "$TEMP_DIR/tally14a.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally14a.json")" != "CONVERGED" ] || \
   [ "$(jq -r .reduced_quorum "$TEMP_DIR/tally14a.json")" != "true" ] || \
   [ "$(jq -r '.absent_peers | join(",")' "$TEMP_DIR/tally14a.json")" != "codex" ]; then
  echo "FAIL: Expected Claude+Gemini reduced quorum CONVERGED, got $(cat "$TEMP_DIR/tally14a.json")" >&2
  exit 1
fi
# 14b: Codex + Gemini (Claude absent)
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini.json" "$TEMP_DIR/missing_claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally14b.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally14b.json")" != "CONVERGED" ] || \
   [ "$(jq -r .reduced_quorum "$TEMP_DIR/tally14b.json")" != "true" ] || \
   [ "$(jq -r '.absent_peers | join(",")' "$TEMP_DIR/tally14b.json")" != "claude" ]; then
  echo "FAIL: Expected Codex+Gemini reduced quorum CONVERGED, got $(cat "$TEMP_DIR/tally14b.json")" >&2
  exit 1
fi
# 14c: Claude + Codex (Gemini absent)
bash "$TALLY_SH" --gemini "$TEMP_DIR/missing_gemini.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally14c.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally14c.json")" != "CONVERGED" ] || \
   [ "$(jq -r .reduced_quorum "$TEMP_DIR/tally14c.json")" != "true" ] || \
   [ "$(jq -r '.absent_peers | join(",")' "$TEMP_DIR/tally14c.json")" != "gemini" ]; then
  echo "FAIL: Expected Claude+Codex reduced quorum CONVERGED, got $(cat "$TEMP_DIR/tally14c.json")" >&2
  exit 1
fi
echo "PASS: All 3 2-of-3 survival quorum combinations verified"

echo "=== Test 15: 1-of-3 and 0-of-3 -> DEGRADED ==="
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini.json" "$TEMP_DIR/missing_c.json" "$TEMP_DIR/missing_x.json" "$TEMP_DIR/tally15a.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally15a.json")" != "DEGRADED" ] || [ "$(jq -r .quorum_met "$TEMP_DIR/tally15a.json")" != "false" ]; then
  echo "FAIL: Expected 1-of-3 DEGRADED, got $(cat "$TEMP_DIR/tally15a.json")" >&2
  exit 1
fi
bash "$TALLY_SH" --gemini "$TEMP_DIR/missing_g.json" "$TEMP_DIR/missing_c.json" "$TEMP_DIR/missing_x.json" "$TEMP_DIR/tally15b.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally15b.json")" != "DEGRADED" ] || [ "$(jq -r .quorum_met "$TEMP_DIR/tally15b.json")" != "false" ]; then
  echo "FAIL: Expected 0-of-3 DEGRADED, got $(cat "$TEMP_DIR/tally15b.json")" >&2
  exit 1
fi
echo "PASS: 1-of-3 and 0-of-3 DEGRADED verified"

echo "=== Test 16: Strict Validation Rejects Missing Metric Score into invalid_peers ==="
echo '{"preferred_option": "Option_0", "stance": "ACCEPT", "metrics": {"technical_feasibility": {"score": 5}}}' > "$TEMP_DIR/gemini_bad.json"
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini_bad.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally16.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally16.json")" != "CONVERGED" ] || \
   [ "$(jq -r '.invalid_peers | join(",")' "$TEMP_DIR/tally16.json")" != "gemini" ] || \
   [ "$(jq -r .reduced_quorum "$TEMP_DIR/tally16.json")" != "true" ]; then
  echo "FAIL: Expected gemini in invalid_peers and Claude+Codex reduced_quorum CONVERGED, got $(cat "$TEMP_DIR/tally16.json")" >&2
  exit 1
fi
echo "PASS: Strict ballot validation verified"

echo "=== Test 17: Malformed JSON & Invalid blocking_objections Type Classified as invalid_peers ==="
echo '{broken json' > "$TEMP_DIR/gemini_syntax_err.json"
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini_syntax_err.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally17a.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally17a.json")" != "CONVERGED" ] || \
   [ "$(jq -r '.invalid_peers | join(",")' "$TEMP_DIR/tally17a.json")" != "gemini" ]; then
  echo "FAIL: Expected malformed JSON gemini in invalid_peers, got $(cat "$TEMP_DIR/tally17a.json")" >&2
  exit 1
fi

jq '.blocking_objections = "not-an-array"' "$TEMP_DIR/gemini.json" > "$TEMP_DIR/gemini_bad_obj.json"
bash "$TALLY_SH" --gemini "$TEMP_DIR/gemini_bad_obj.json" "$TEMP_DIR/claude.json" "$TEMP_DIR/codex.json" "$TEMP_DIR/tally17b.json" 1 3
if [ "$(jq -r .status "$TEMP_DIR/tally17b.json")" != "CONVERGED" ] || \
   [ "$(jq -r '.invalid_peers | join(",")' "$TEMP_DIR/tally17b.json")" != "gemini" ]; then
  echo "FAIL: Expected non-array blocking_objections in invalid_peers, got $(cat "$TEMP_DIR/tally17b.json")" >&2
  exit 1
fi
echo "PASS: Malformed JSON & non-array blocking_objections validation verified"

echo "All tally tests passed successfully!"

