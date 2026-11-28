# Gemini Native Subagent Peer & 3-Peer Consensus Deliberation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Antigravity (Gemini) to dispatch its own isolated, read-only native Gemini Peer Subagent (`invoke_subagent`) concurrently alongside Claude CLI and/or Codex CLI across all advisory milestones AND as an equal 3rd voting peer in `agent-deliberate` with 2-of-3 survival quorum.

**Architecture:** Because Bash scripts cannot call Antigravity's native `invoke_subagent` tool, Antigravity owns native subagent dispatch, JSON ballot validation, and atomic file handoff (`round-N/gemini_ballot.json`). Bash + `jq` (`consensus_tally.sh`, `consensus_round.sh`, `agent_deliberate.sh`) remain the single deterministic gate for N-peer tallying, anonymized digest generation (`Agent A` / `Agent B` / `Agent C`), counter-proposal synthesis, and dynamic 2/3-column blueprint/dissent rendering.

**Tech Stack:** Bash, `jq`, Python 3 (stdlib only), Markdown templates/protocols.

**Spec:** `docs/superpowers/specs/2026-11-28-gemini-native-subagent-peer-design.md`

## Global Constraints

- **100% Backward Compatibility**: Existing 2-peer positional invocations of `consensus_tally.sh`, `consensus_round.sh`, `agent_deliberate.sh`, and all existing tests in `tests/run_all_tests.sh` MUST pass without modification.
- **No New Daemons/Registries/External CLIs**: Do not introduce `peers.json`, polling loops, or a `gemini` CLI binary wrapper.
- **Anonymization**: `digest.md` MUST use `Agent A`, `Agent B`, `Agent C` labels and MUST NOT leak `claude`, `codex`, or `gemini` in peer headers or attribution.
- **Strict Validation**: Ballots with missing/non-numeric/out-of-range (`< 1` or `> 5`) metric scores, missing `preferred_option`, or invalid `stance` MUST be rejected into `invalid_peers` (never coerced to `0`).
- **Atomic File Writes**: `tally.json` and `gemini_ballot.json` writes use temp-file + `mv` in the same directory.
- **Protocol Sync**: `templates/AGENTS.md` and root `AGENTS.md` must stay identical inside `<!-- agent-collaborator:protocol:start/end -->` markers.

---

### Task 1: Generalize `consensus_tally.sh` for 2/3-Peer Voting & Strict Validation

**Files:**
- Modify: `skills/agent-collaborator/scripts/consensus_tally.sh`
- Test: `tests/test_consensus_tally.sh`

**Interfaces:**
- Consumes: Ballot JSON files conforming to `templates/deliberation_prompt.md` schema and optional `manifest.json`.
- Produces:
  - CLI: `consensus_tally.sh [--gemini <GEMINI_BALLOT_JSON>] <CLAUDE_BALLOT_JSON> <CODEX_BALLOT_JSON> <OUTPUT_TALLY_JSON> [ROUND_NUM] [MAX_ROUNDS] [MANIFEST]`
  - Output `tally.json`: all legacy fields (`deliberation_id`, `round`, `max_rounds`, `status`, `consensus_option`, `yagni_score_avg`, `score_spreads`, `blocking_objections`, `over_architecture_flags`, `degraded_peer` when degraded) PLUS `participating_peers`, `absent_peers`, `invalid_peers`, `quorum_met`, `reduced_quorum`.

- [ ] **Step 1: Add failing 3-peer, 2-of-3 survival quorum, and strict validation tests to `tests/test_consensus_tally.sh`**

Append the following tests to `tests/test_consensus_tally.sh` before the final `echo "All consensus_tally tests passed!"` line:

```bash
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
```

- [ ] **Step 2: Run `bash tests/test_consensus_tally.sh` to verify new tests fail**

Run: `bash tests/test_consensus_tally.sh`
Expected: FAIL on Test 11 (`--gemini` flag not supported yet).

- [ ] **Step 3: Implement N-peer tallying, `--gemini` parsing, strict validation, and atomic write in `skills/agent-collaborator/scripts/consensus_tally.sh`**

Key implementation details for `skills/agent-collaborator/scripts/consensus_tally.sh`:
- Parse optional `--gemini <FILE>` / `--gemini=<FILE>` before positional arguments, setting `THREE_PEER_MODE=true` and `GEMINI_BALLOT="<FILE>"`.
- Write a helper `classify_ballot <file>` that returns `"ABSENT"` (missing or 0-byte), `"INVALID"` (non-object JSON, missing/empty `preferred_option`, invalid `stance`, or any of the 5 core metrics missing a numeric score in `[1, 5]`), or `"VALID"`.
- Build JSON arrays for `participating_peers`, `absent_peers`, `invalid_peers`, and a JSON array of valid ballot objects.
- If `valid_count < 2`: output `DEGRADED` JSON (preserving exact legacy `degraded_peer` values `"both"` / `"claude"` / `"codex"` in 2-peer mode, and `"all"` / comma-joined non-participating peers in 3-peer mode) with `quorum_met: false`, `reduced_quorum: false`.
- If `valid_count >= 2`: compute `max - min` spread for each of the 5 metrics across all valid ballots, `yagni_score_avg = (map(.metrics.yagni_and_parsimony.score) | add / length)`, `yagni_pass = (all(.metrics.yagni_and_parsimony.score >= 3.0) and $yagni_avg >= 3.5)`, `preferred_matches = (map(.preferred_option) | unique | length == 1)`, aggregate `blocking_objections` and `over_architecture_flags` across all valid ballots, compute `reduced_quorum = ($valid_count < $expected_count)`, and emit the full `tally.json`.
- Write to `"$(dirname "$OUTPUT_TALLY")/.tally.tmp.$$"` and `mv` atomically to `"$OUTPUT_TALLY"`.

- [ ] **Step 4: Run `bash tests/test_consensus_tally.sh` to verify all 16 tests pass**

Run: `bash tests/test_consensus_tally.sh`
Expected: PASS (all legacy tests 1–10 and new tests 11–16 pass).

- [ ] **Step 5: Commit Task 1**

```bash
git add skills/agent-collaborator/scripts/consensus_tally.sh tests/test_consensus_tally.sh
git commit -m "feat(deliberate): generalize consensus_tally.sh for 2/3-peer quorum and strict ballot validation"
```

---

### Task 2: Extend `consensus_round.sh` with `--no-tally`, `--tally-only`, `--gemini-ballot`, and 3-Peer Anonymized Digest

**Files:**
- Modify: `skills/agent-collaborator/scripts/consensus_round.sh`
- Test: `tests/test_consensus_round.sh`

**Interfaces:**
- Consumes: `consensus_tally.sh --gemini <file> ...` from Task 1.
- Produces:
  - CLI: `consensus_round.sh [--no-tally | --tally-only] [--gemini-ballot <FILE>] [--max-rounds <N>] [--model-claude <M>] [--model-codex <M>] [--guidance <TEXT>] <DELIBERATION_DIR> <ROUND_NUM>`
  - Artifacts: `$ROUND_DIR/gemini_prompt.md` (written during `--no-tally` / full run), `$ROUND_DIR/tally.json`, anonymized `$ROUND_DIR/digest.md` (`Agent A`, `Agent B`, `Agent C` — zero raw model names), updated `manifest.json` with synthesized counter-proposals from all peers including Gemini.

- [ ] **Step 1: Add failing tests for `--no-tally` + `gemini_ballot.json` + `--tally-only`, anonymized 3-peer digest, Gemini counter-proposal synthesis, and 2-of-3 CLI-failure survival to `tests/test_consensus_round.sh`**

Append Tests 10–12 to `tests/test_consensus_round.sh`:
- **Test 10**: `--no-tally` runs Claude & Codex and writes `gemini_prompt.md` without creating `tally.json`; then write `round-1/gemini_ballot.json` (preferring `Option_A` with a `counter_proposal`) and run `--tally-only --gemini-ballot "$DELIB_DIR10/round-1/gemini_ballot.json"`. Verify:
  - `tally.json` has `participating_peers` length 3 and status `IN_DEBATE`.
  - `digest.md` mentions `Agent A`, `Agent B`, `Agent C` and `grep -iE "(claude|codex|gemini)"` returns NO match!
  - `manifest.json` contains the counter-proposal synthesized from Gemini.
- **Test 11**: One CLI fails (`MOCK_CODEX_MODE="FAIL_100"`) during `--no-tally` (exits 0, does not abort early), then drop a valid `gemini_ballot.json` matching Claude's `Option_0`, run `--tally-only`. Verify exit 0, `tally.json` status `CONVERGED`, `reduced_quorum: true`, `absent_peers: ["codex"]`.
- **Test 12**: Auto-detection of `$ROUND_DIR/gemini_ballot.json` during `--tally-only` even without explicit `--gemini-ballot` flag.

- [ ] **Step 2: Run `bash tests/test_consensus_round.sh` to verify new tests fail**

Run: `bash tests/test_consensus_round.sh`
Expected: FAIL on Test 10 (`--no-tally` unknown option).

- [ ] **Step 3: Implement `--no-tally`, `--tally-only`, `--gemini-ballot`, `gemini_prompt.md`, and 3-peer anonymized digest in `skills/agent-collaborator/scripts/consensus_round.sh`**

Key implementation details:
- Parse `--no-tally`, `--tally-only`, `--gemini-ballot <FILE>` / `--gemini-ballot=<FILE>`. Reject mutually exclusive `--no-tally` + `--tally-only` with exit 1.
- When `TALLY_ONLY=false`:
  - Render `$ROUND_DIR/gemini_prompt.md` using `render_prompt "gemini" "native-subagent" "$PRIOR_GEMINI_BALLOT_CONTENT" "$HUMAN_GUIDANCE_CONTENT" "$ROUND_DIR/gemini_prompt.md"` (also load `PRIOR_GEMINI_BALLOT_CONTENT` from `$PREV_DIR/gemini_ballot.json` when `ROUND_NUM > 1`).
  - Run Claude and Codex concurrently as before, write `meta.json`, propagate exit `126` on sandbox block.
  - If `NO_TALLY=true`, echo status and `exit 0` (leaving `gemini_ballot.json` untouched if already present).
- Resolve `GEMINI_BALLOT_PATH`: if `--gemini-ballot` was given, use it (`THREE_PEER_MODE=true`); else if `[ -f "$ROUND_DIR/gemini_ballot.json" ]`, use `$ROUND_DIR/gemini_ballot.json` (`THREE_PEER_MODE=true`).
- Peer outage check: exit `100` only if ALL expected ballots are missing/unparseable (`claude_valid=false && codex_valid=false && gemini_valid=false`).
- Invoke `bash "$TALLY_SH"` (with `--gemini "$GEMINI_BALLOT_PATH"` when `THREE_PEER_MODE=true`).
- Update digest & counter-proposal synthesis Python block to accept optional 6th argument (`$GEMINI_BALLOT_PATH`):
  - Collect `(anon_label, peer_name, ballot)` dynamically for present ballots: `Agent A`, `Agent B`, and (if 3-peer mode) `Agent C`.
  - Synthesize `counter_proposal` from all peers (Claude, Codex, Gemini) into `manifest.json`, and in `digest.md` render `Proposed by Agent A/B/C` (never raw model name!).
  - Render dynamic 2- or 3-column metric table (`| Metric | Agent A Score | Agent B Score | [Agent C Score |] Spread (max - min) | Status |`) and option divergence summary across all anonymized agents.

- [ ] **Step 4: Run `bash tests/test_consensus_round.sh` to verify all 12 tests pass**

Run: `bash tests/test_consensus_round.sh`
Expected: PASS (all legacy tests 1–9 and new tests 10–12 pass).

- [ ] **Step 5: Commit Task 2**

```bash
git add skills/agent-collaborator/scripts/consensus_round.sh tests/test_consensus_round.sh
git commit -m "feat(deliberate): add --no-tally, --tally-only, --gemini-ballot, and 3-peer anonymized digest to consensus_round.sh"
```

---

### Task 3: Extend `agent_deliberate.sh` with `--init`, `--finalize`, and Dynamic 2/3-Peer Reporting

**Files:**
- Modify: `skills/agent-collaborator/scripts/agent_deliberate.sh`
- Test: `tests/test_agent_deliberate.sh`

**Interfaces:**
- Consumes: `round-N/tally.json`, `round-N/claude_ballot.json`, `round-N/codex_ballot.json`, optional `round-N/gemini_ballot.json`.
- Produces:
  - CLI: `agent_deliberate.sh --init [OPTIONS] "<TOPIC>" [CONTEXT_FILES...]`
  - CLI: `agent_deliberate.sh --finalize <ROUND_NUM> -d <DIR>` (exits `0` on convergence, `2` on deadlock, `1` on invalid/in-debate tally)
  - Dynamic 2- or 3-column `final_blueprint.md`, `dissent_register.md`, and terminal summary table, plus explicit `reduced_quorum` notice when `tally.reduced_quorum == true`.

- [ ] **Step 1: Add failing tests for `--init`, `--finalize` (3-peer CONVERGED with 3 columns, 2/3 reduced quorum notice, and 3-peer DEADLOCK) to `tests/test_agent_deliberate.sh`**

Append Tests 11–13 to `tests/test_agent_deliberate.sh`:
- **Test 11**: `agent_deliberate.sh --init --id dlb-init-11 --dir "$TEST11_DIR" "Init Test Topic"` creates `manifest.json` + `option_0_baseline.md` and exits `0` without calling `consensus_round.sh`.
- **Test 12**: Populate `$TEST11_DIR/round-1/` with `claude_ballot.json`, `codex_ballot.json`, `gemini_ballot.json`, and 3-peer `CONVERGED` `tally.json`, then run `agent_deliberate.sh --finalize 1 --dir "$TEST11_DIR"`. Verify exit `0`, `final_blueprint.md` contains `Gemini Score` and `Gemini`, and stdout summary contains `Gemini`. Also test `reduced_quorum: true` notice appears when `reduced_quorum` is true.
- **Test 13**: Populate `$TEST13_DIR/round-2/` with 3 ballots and `DEADLOCK` `tally.json`, run `agent_deliberate.sh --finalize 2 --dir "$TEST13_DIR"`. Verify exit `2` and `dissent_register.md` lists `Gemini Preferred Option`.

- [ ] **Step 2: Run `bash tests/test_agent_deliberate.sh` to verify new tests fail**

Run: `bash tests/test_agent_deliberate.sh`
Expected: FAIL on Test 11 (`--init` unknown option).

- [ ] **Step 3: Implement `--init`, `--finalize`, and dynamic 2/3-peer blueprint/dissent/terminal rendering in `skills/agent-collaborator/scripts/agent_deliberate.sh`**

Key implementation details:
- Fix `CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"` initialization before manifest creation if not already set.
- Parse `--init` (`INIT_ONLY=true`) and `--finalize <ROUND_NUM>` / `--finalize=<ROUND_NUM>` (`FINALIZE_ROUND="$2"`).
- When `INIT_ONLY=true`: after creating/updating `manifest.json`, `option_0_baseline.md`, and any `--add-option` / `--guidance`, print `DELIBERATION_DIR=$DELIBERATION_DIR` and `exit 0`.
- Refactor convergence finalization and deadlock finalization into clean helper functions (`finalize_converged "$round"` and `finalize_deadlock "$round"`) used by BOTH the main loop and `--finalize <ROUND_NUM>`.
- Update `generate_final_blueprint`, `generate_dissent_register`, and terminal summary table Python blocks to check for `gemini_ballot.json`:
  - Dynamically build columns for present peers (`Claude`, `Codex`, and `Gemini` if `gemini_ballot.json` exists).
  - Include `Quorum` line (`2/3 (reduced quorum — absent/invalid: ...)` when `tally.reduced_quorum == true`).
  - In `dissent_register.md`, include `Gemini Preferred Option` and `Gemini proposal` in the Human Tie-Breaker Decision Menu when `gemini_ballot.json` exists.

- [ ] **Step 4: Run `bash tests/test_agent_deliberate.sh` to verify all 13 tests pass**

Run: `bash tests/test_agent_deliberate.sh`
Expected: PASS (all legacy tests 1–10 and new tests 11–13 pass).

- [ ] **Step 5: Commit Task 3**

```bash
git add skills/agent-collaborator/scripts/agent_deliberate.sh tests/test_agent_deliberate.sh
git commit -m "feat(deliberate): add --init, --finalize, and dynamic 2/3-peer reporting to agent_deliberate.sh"
```

---

### Task 4: Update Collaboration Protocols, Skill Docs, READMEs, and Sync Global Install

**Files:**
- Modify: `templates/AGENTS.md`
- Modify: `AGENTS.md`
- Modify: `skills/agent-collaborator/SKILL.md`
- Modify: `templates/antigravity_superpowers.md`
- Modify: `README.md`
- Modify: `README_zh.md`

**Interfaces:**
- Consumes: CLI flags and behaviors implemented in Tasks 1–3 (`--no-tally`, `--tally-only`, `--gemini-ballot`, `--init`, `--finalize`).
- Produces: Synchronized protocol documentation and updated global installation (`~/.gemini/config/AGENTS.md`, `~/.gemini/AGENTS.md`, `~/.gemini/config/skills/agent-collaborator/`).

- [ ] **Step 1: Update `templates/AGENTS.md` and sync `AGENTS.md`**

Update `templates/AGENTS.md` (and replicate the exact protocol block inside `<!-- agent-collaborator:protocol:start/end -->` in root `AGENTS.md`):
- **Section 1**: Add **Gemini Peer Subagent (Antigravity Native `invoke_subagent`)** to the Peer Advisory Council (`TypeName: "research"`, read-only, fresh context, `Model: "inherit"`, role-specific labels, diff passed in prompt for Code Review). Keep driver platform guard for Claude Code CLI.
- **Section 2**: Update all 6 lifecycle dispatch points so Antigravity always dispatches a Gemini Peer Subagent concurrently with available Claude / Codex CLIs in the same turn, then synthesizes all perspectives together.
- **Section 3**: Extend Anti-Premature Completion & Turn Yielding rules to cover both native `invoke_subagent` peers and background CLI tasks.
- **Section 6**: Note that when external CLIs are unavailable or hit exit `100`, the Gemini Peer Subagent's independent review still provides a clean-context second opinion.
- **Section 7**: Reconcile Ring Topology (Antigravity Main = Neutral non-voting Moderator; Gemini Peer Subagent = fresh-context voting peer; Claude CLI = Architect voter; Codex CLI = YAGNI/Red-Team voter; Jetski Subagent = non-voting empirical spike probe). Document 2-of-3 survival quorum (`reduced_quorum`), unanimous convergence, and the `--init` → concurrent `consensus-round --no-tally` + `invoke_subagent` → atomic `gemini_ballot.json` → `consensus-round --tally-only` → `agent-deliberate --finalize` workflow.

- [ ] **Step 2: Update `skills/agent-collaborator/SKILL.md`, `templates/antigravity_superpowers.md`, `README.md`, and `README_zh.md`**

Bring all 4 files into full alignment with `templates/AGENTS.md`:
- `SKILL.md`: Add Gemini Peer Subagent role, concurrent dispatch instructions, and 3-peer `agent-deliberate` CLI options (`--init`, `--finalize`, `--no-tally`, `--tally-only`, `--gemini-ballot`).
- `templates/antigravity_superpowers.md`: Update protocol reference block and Mermaid Golden Pipeline diagram to include Gemini Peer Subagent alongside Claude/Codex/Jetski.
- `README.md` & `README_zh.md`: Document the Tri-Model Peer Advisory Council (Gemini Native Subagent + Claude CLI + OpenAI Codex) and 3-peer consensus deliberation with 2-of-3 survival quorum.

- [ ] **Step 3: Run full test suite and sync installer**

Run:
```bash
bash tests/run_all_tests.sh && ./install.sh --antigravity-global
```
Expected: All 4 test suites pass (`Failed: 0`) and `~/.gemini/config/AGENTS.md` + `~/.gemini/config/skills/agent-collaborator/` are updated cleanly.

- [ ] **Step 4: Commit Task 4**

```bash
git add templates/AGENTS.md AGENTS.md skills/agent-collaborator/SKILL.md templates/antigravity_superpowers.md README.md README_zh.md
git commit -m "docs(protocol): add Gemini native subagent concurrent peer dispatch and 3-peer deliberation protocol"
```
