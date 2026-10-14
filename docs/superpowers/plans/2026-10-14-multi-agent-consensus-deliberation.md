# Multi-Agent Consensus Deliberation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a multi-agent consensus deliberation system (`agent-deliberate`) where Antigravity (Gemini) orchestrates structured debates among Claude CLI, Codex CLI, and Jetski (empirical spike subagent) using a Structured Metric Table, anti-overarchitecture YAGNI veto, and deterministic bounded termination.

**Architecture:** A lightweight filesystem-based ledger state machine (`.agent/deliberations/<id>/`) powered by a single-task background driver (`consensus_round.sh`) that fans out to Claude and Codex concurrently, captures structured JSON ballots, evaluates convergence with `jq`, routes factual disputes to Jetski probes, and stops at `MAX_ROUNDS=3` with deadlock human escalation.

**Tech Stack:** Bash (POSIX / macOS compatible), `jq` (JSON parsing and deterministic scoring), Claude CLI (`claude`), Codex CLI (`codex`), Markdown specification templates.

**Spec:** `docs/superpowers/specs/2026-10-14-multi-agent-consensus-deliberation-design.md`

## Global Constraints
- **Zero Race Conditions**: Each deliberation round must execute as exactly ONE background task yielding ONE reactive wake-up turn to Antigravity.
- **YAGNI & Parsimony Enforcement**: Average `yagni_and_parsimony` score must be $\ge 3.5$ and no `OVER_ARCHITECTURE` flags present for `CONVERGED` status.
- **Bounded Termination**: Hard ceiling at `MAX_ROUNDS=3`; any unreached consensus must transition to `DEADLOCK` and generate `dissent_register.md`.
- **Stateless Isolation**: Claude and Codex executions must run in isolated session working directories to prevent cross-deliberation pollution.
- **Exit Code Conventions**: Script must follow `0` (Success/Round completed), `1` (Input/Argument error), `100` (All external peers unavailable - fallback triggered), `126` (Sandbox blocked - retry with BypassSandbox).

---

### Task 1: Structured Deliberation Prompt Template & Schema Definitions

**Files:**
- Create: `templates/deliberation_prompt.md`
- Test: `tests/fixtures/valid_ballot_claude.json`
- Test: `tests/fixtures/valid_ballot_codex.json`
- Test: `tests/fixtures/overarchitecture_ballot.json`

**Interfaces:**
- Produces: Prompt template with strict fenced JSON ballot structure and Markdown evaluation rubric.
- Consumes: Deliberation ID, Round number, Option definitions (including Option 0 MVA baseline), and Context files.

- [ ] **Step 1: Create test fixtures for schema verification**

Create `tests/fixtures/valid_ballot_claude.json`:
```json
{
  "deliberation_id": "dlb-test-01",
  "round": 1,
  "agent": "claude",
  "model": "sonnet",
  "preferred_option": "Option_0",
  "stance": "ACCEPT",
  "metrics": {
    "technical_feasibility": {"score": 5, "confidence": 0.9, "rationale": "Feasible with POSIX utilities."},
    "architectural_simplicity": {"score": 5, "confidence": 0.9, "rationale": "Zero extra layers."},
    "yagni_and_parsimony": {"score": 5, "confidence": 0.9, "cognitive_overhead": "LOW", "indirection_layers": 0, "rationale": "Direct file writes."},
    "robustness_failure_modes": {"score": 4, "confidence": 0.8, "rationale": "Handles basic errors."},
    "maintainability_testability": {"score": 5, "confidence": 0.9, "rationale": "Easy to test."}
  },
  "over_architecture_flags": [],
  "blocking_objections": [],
  "position_changes": []
}
```

Create `tests/fixtures/overarchitecture_ballot.json`:
```json
{
  "deliberation_id": "dlb-test-01",
  "round": 1,
  "agent": "codex",
  "model": "o3-mini",
  "preferred_option": "Option_B",
  "stance": "BLOCK",
  "metrics": {
    "technical_feasibility": {"score": 4, "confidence": 0.8, "rationale": "Works but complex."},
    "architectural_simplicity": {"score": 2, "confidence": 0.9, "rationale": "Too many abstractions."},
    "yagni_and_parsimony": {"score": 2, "confidence": 0.9, "cognitive_overhead": "HIGH", "indirection_layers": 4, "rationale": "Introduces unnecessary message broker."},
    "robustness_failure_modes": {"score": 3, "confidence": 0.7, "rationale": "Daemon crash vulnerability."},
    "maintainability_testability": {"score": 2, "confidence": 0.8, "rationale": "Hard to unit test."}
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

- [ ] **Step 2: Verify `jq` parses the test fixtures cleanly**

Run:
```bash
jq .deliberation_id tests/fixtures/valid_ballot_claude.json && jq .deliberation_id tests/fixtures/overarchitecture_ballot.json
```
Expected: `"dlb-test-01"` for both.

- [ ] **Step 3: Create `templates/deliberation_prompt.md`**

Write the prompt template ensuring strict instructions for fenced JSON output, evaluation of Option 0 MVA baseline, anti-overarchitecture rubric, and structured blocking objections.

- [ ] **Step 4: Commit Task 1**

```bash
git add templates/deliberation_prompt.md tests/fixtures/
git commit -m "feat(deliberation): add prompt template and ballot test fixtures"
```

---

### Task 2: Deterministic Consensus Tally & Gate Evaluator (`consensus_tally.sh`)

**Files:**
- Create: `skills/agent-collaborator/scripts/consensus_tally.sh`
- Test: `tests/test_consensus_tally.sh`

**Interfaces:**
- Consumes: Paths to Claude ballot JSON and Codex ballot JSON (`$1`, `$2`), and output path for `tally.json` (`$3`).
- Produces: `tally.json` containing:
  - `status`: `CONVERGED | CONVERGED_WITH_DISSENT | IN_DEBATE | DEADLOCK | DEGRADED`
  - `consensus_option`: string or null
  - `yagni_score_avg`: float
  - `score_spreads`: object mapping each metric to its $(\max - \min)$ spread
  - `blocking_objections`: array of all active unresolved objections
  - `over_architecture_flags`: array of all active YAGNI flags

- [ ] **Step 1: Write failing test script for tally evaluation**

Create `tests/test_consensus_tally.sh`:
```bash
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

echo "All tally tests passed successfully!"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_consensus_tally.sh`
Expected: FAIL (script does not exist yet).

- [ ] **Step 3: Implement `skills/agent-collaborator/scripts/consensus_tally.sh`**

Implement deterministic `jq` calculation:
1. Extract preferred options and check for identity match.
2. Check if any ballot has `stance == "BLOCK"`.
3. Check average `yagni_and_parsimony` score (must be $\ge 3.5$).
4. Check metric score spread (must be $\le 1.0$ for all metrics).
5. Aggregate all `blocking_objections` and `over_architecture_flags`.
6. Output formatted JSON to destination.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_consensus_tally.sh`
Expected: PASS with "All tally tests passed successfully!".

- [ ] **Step 5: Commit Task 2**

```bash
git add skills/agent-collaborator/scripts/consensus_tally.sh tests/test_consensus_tally.sh
git commit -m "feat(deliberation): add deterministic consensus tally engine"
```

---

### Task 3: Single-Round Concurrent Driver Script (`consensus_round.sh`)

**Files:**
- Create: `skills/agent-collaborator/scripts/consensus_round.sh`
- Test: `tests/test_consensus_round.sh`

**Interfaces:**
- Consumes: `<DELIBERATION_DIR>` and `<ROUND_NUM>`. Reads `manifest.json` and `<DELIBERATION_DIR>/round-<N-1>/digest.md` (if Round > 1).
- Produces:
  - `<DELIBERATION_DIR>/round-<N>/claude_ballot.json`
  - `<DELIBERATION_DIR>/round-<N>/claude_ballot.md`
  - `<DELIBERATION_DIR>/round-<N>/codex_ballot.json`
  - `<DELIBERATION_DIR>/round-<N>/codex_ballot.md`
  - `<DELIBERATION_DIR>/round-<N>/tally.json`
  - `<DELIBERATION_DIR>/round-<N>/digest.md` (anonymized summary for next round)
- Concurrency: Spawns Claude and Codex in background subshells, executes in isolated session directories, waits for both, performs `jq` schema extraction and validation.

- [ ] **Step 1: Write test script for `consensus_round.sh`**

Create `tests/test_consensus_round.sh` with mocked CLI binaries (`mock_claude.sh` and `mock_codex.sh`) that output valid ballots, simulating concurrent execution and single-turn wake-up.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_consensus_round.sh`
Expected: FAIL (driver script does not exist).

- [ ] **Step 3: Implement `skills/agent-collaborator/scripts/consensus_round.sh`**

Features to implement:
- Load deliberation manifest and topic.
- In Round 1: blind prompt without peer history.
- In Round > 1: inject `digest.md` and previous ballot.
- Set up isolated session folders: `.agent/deliberations/<id>/.sessions/claude/` and `.../codex/`.
- Parallel execution:
  ```bash
  run_claude &
  PID_CLAUDE=$!
  run_codex &
  PID_CODEX=$!
  wait $PID_CLAUDE
  wait $PID_CODEX
  ```
- Extract JSON code fence using `sed`/`awk`/`jq`.
- Run `consensus_tally.sh` to generate `tally.json`.
- If not converged, synthesize an anonymized `digest.md` highlighting `blocking_objections` and `over_architecture_flags`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_consensus_round.sh`
Expected: PASS.

- [ ] **Step 5: Commit Task 3**

```bash
git add skills/agent-collaborator/scripts/consensus_round.sh tests/test_consensus_round.sh
git commit -m "feat(deliberation): implement concurrent single-task round driver"
```

---

### Task 4: High-Level Deliberation Runner & Jetski Integration (`agent_deliberate.sh`)

**Files:**
- Create: `skills/agent-collaborator/scripts/agent_deliberate.sh`
- Test: `tests/test_agent_deliberate.sh`

**Interfaces:**
- CLI Syntax: `agent-deliberate [--rounds 3] [--model-claude <m>] [--model-codex <m>] "<TOPIC_OR_REQUIREMENT>" [CONTEXT_FILES...]`
- Orchestrates:
  1. Initializes `.agent/deliberations/<deliberation_id>/manifest.json` and defines `Option_0` (Minimal Viable Architecture baseline).
  2. Executes `consensus_round.sh` for Round 1.
  3. Checks tally:
     - If `CONVERGED`: Generates `final_blueprint.md` and displays the consensus metric table. Exits 0.
     - If `IN_DEBATE`: Identifies `factual` objections. If present, outputs prompt instructions for Jetski Subagent spike to verify facts.
     - Loops up to `MAX_ROUNDS`.
  4. If `round == MAX_ROUNDS` and still not converged: Generates `dissent_register.md`, sets status `DEADLOCK`, outputs human tie-breaker menu. Exits 2.

- [ ] **Step 1: Write integration test for `agent_deliberate.sh`**

Create `tests/test_agent_deliberate.sh` validating lifecycle progression:
- Successful convergence within 2 rounds.
- Hard termination and `dissent_register.md` creation upon 3 rounds of deadlock.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_agent_deliberate.sh`
Expected: FAIL.

- [ ] **Step 3: Implement `skills/agent-collaborator/scripts/agent_deliberate.sh`**

Implement complete loop, Option 0 MVA baseline generation, round dispatching, Jetski factual evidence injection, and final blueprint synthesis.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_agent_deliberate.sh`
Expected: PASS.

- [ ] **Step 5: Commit Task 4**

```bash
git add skills/agent-collaborator/scripts/agent_deliberate.sh tests/test_agent_deliberate.sh
git commit -m "feat(deliberation): add high-level multi-agent deliberation runner"
```

---

### Task 5: Protocol Documentation, Skill Registration & Installer Links

**Files:**
- Modify: `templates/AGENTS.md` (Add Section 7: "Multi-Agent Consensus Deliberation Protocol")
- Modify: `skills/agent-collaborator/SKILL.md` (Document `agent-deliberate` and `consensus-round`)
- Modify: `install.sh` (Add symlinks for `agent-deliberate` and `consensus-round` to `~/.local/bin/`)

**Interfaces:**
- Produces: Complete integration with the global and project-level Agent Collaborator ecosystem.

- [ ] **Step 1: Update `templates/AGENTS.md`**

Add Section 7 documenting the Deliberation lifecycle, role definitions (Antigravity moderator, Jetski spike agent, Claude architect, Codex YAGNI red team), the Structured Metric Table, and the Parsimony Veto.

- [ ] **Step 2: Update `skills/agent-collaborator/SKILL.md`**

Add usage documentation, CLI flags, and architectural examples for `agent-deliberate`.

- [ ] **Step 3: Update `install.sh`**

Add symlinks:
```bash
ln -sf "$SKILL_SRC/scripts/agent_deliberate.sh" "$BIN_DIR/agent-deliberate"
ln -sf "$SKILL_SRC/scripts/consensus_round.sh" "$BIN_DIR/consensus-round"
chmod +x "$BIN_DIR/agent-deliberate" "$BIN_DIR/consensus-round"
```

- [ ] **Step 4: Verify installer executes cleanly**

Run: `./install.sh --project .`
Expected: All symlinks created in `~/.local/bin/` and project files updated.

- [ ] **Step 5: Commit Task 5**

```bash
git add templates/AGENTS.md skills/agent-collaborator/SKILL.md install.sh
git commit -m "feat(deliberation): register agent-deliberate in AGENTS.md, skill docs, and installer"
```

---

### Task 6: End-to-End Golden Deliberation Verification

**Files:**
- Verify: Full test suite (`bash tests/test_deliberation_suite.sh`)
- Live Trial: Run a test deliberation using `agent-deliberate` on a small architectural problem.

- [ ] **Step 1: Run complete test suite**

Run all unit and integration tests:
```bash
bash tests/test_consensus_tally.sh
bash tests/test_consensus_round.sh
bash tests/test_agent_deliberate.sh
```
Expected: All tests pass.

- [ ] **Step 2: Execute live trial deliberation**

Execute:
```bash
agent-deliberate --rounds 2 "Design an in-memory cache strategy with TTL eviction for CLI tools"
```
Expected: Generates `.agent/deliberations/<id>/`, produces valid ballots, evaluates YAGNI score, and outputs final consensus blueprint.

- [ ] **Step 3: Final commit and cleanup**

Ensure clean git status and commit any test assets.
```bash
git status
git commit -m "chore(deliberation): complete verification and test coverage"
```
