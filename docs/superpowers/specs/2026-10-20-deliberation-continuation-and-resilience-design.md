# Multi-Agent Deliberation Resilience & Continuation Design Specification

- **Date**: 2026-10-20
- **Status**: Approved / In Design
- **Authors**: Antigravity Orchestrator & Multi-Agent Architecture Council

---

## 1. Problem Statement & Motivation

During empirical testing of `agent-deliberate` in production (e.g. `dlb-memory-system-v2`), three structural failure modes were uncovered:

1. **Model Fragility & Single-Point Quota Exhaustion**:
   - If a peer agent CLI fails due to rate limits (429), server overload (529), or invalid/unsupported model configuration (400, e.g. `gpt-6-luna`), the round currently marks the peer as `DEGRADED` or aborts with Exit 100.
   - There is no autonomous fallback ladder (e.g. `sonnet -> haiku`, `o3-mini -> gpt-4o -> default`) to retry within the round.

2. **Non-Resumable Execution & Inability to Continue with Human Guidance**:
   - If a deliberation ends in `DEADLOCK` or is interrupted, the orchestrator has no `-c / --continue` command.
   - Re-running with `--id` clobbers previous rounds instead of resuming from the latest completed round.
   - The human operator cannot inject arbitration directives (`--guidance`) to steer peers toward a compromise.

3. **Static Option Trap & Artificial Deadlock**:
   - When a deliberation starts with only `Option_0` (the MVA baseline) and a peer registers a valid `BLOCK` (e.g. "Option 0 POSIX primitives cannot integrate into Flutter/Riverpod"), there are no alternative options in `manifest.json`.
   - Without dynamic option registration, subsequent rounds re-evaluate the exact same failing option, guaranteeing a Deadlock on round 3.
   - Counter-proposals articulated in ballots are lost because they are not promoted into candidate options.

4. **Synchronous Runaway Past Factual Probes**:
   - When `round-1` detects factual objections, it generates `jetski_evidence_prompt.md`, but the batch loop immediately proceeds to `round-2` without yielding for the empirical probe.

---

## 2. Architecture & Design Principles

### Invariants Preserved
- **Option 0 Primacy**: Every deliberation must still define and evaluate `Option_0` as the zero-complexity baseline.
- **Parsimony Veto**: Average `yagni_and_parsimony >= 3.5` remains mandatory for `CONVERGED`.
- **Anonymized Peer Deliberation**: Blind round 1, peer identities stripped in digests, neutral moderation by Gemini.
- **Bounded Execution**: Deliberations cannot loop indefinitely; maximum rounds are strictly enforced unless explicitly extended by human guidance.

---

## 3. Subsystem Specifications

### Subsystem 1: Model Fallback Ladder (Peer Resilience)

#### Ladder Defaults & Precedence
1. **Claude CLI Ladder**:
   - Default: `CLAUDE_MODEL_LADDER="${CLAUDE_MODEL_LADDER:-sonnet,haiku}"`
   - If `--model-claude <M>` is passed, it becomes the first rung: `<M>,sonnet,haiku`.
2. **Codex CLI Ladder**:
   - Default: `CODEX_MODEL_LADDER="${CODEX_MODEL_LADDER:-o3-mini,gpt-4o,default}"`
   - If `--model-codex <M>` is passed, it becomes the first rung: `<M>,o3-mini,gpt-4o,default`.

#### Execution & Classification
Each peer subshell iterates through its ladder:
```bash
run_peer_with_ladder() {
  local peer="$1" ladder="$2" ...
  IFS=',' read -ra rungs <<< "$ladder"
  for model in "${rungs[@]}"; do
    # 1. Render prompt with {{MODEL}} = $model
    # 2. Invoke peer with timeout
    # 3. Classify outcome:
    #    - SUCCESS (valid JSON ballot extracted) -> record meta and return 0
    #    - FATAL (Exit 126 sandbox, auth missing) -> return immediately
    #    - RETRYABLE (400 unsupported, 429 quota, 529 overload, empty/malformed) -> try next rung
  done
  return 100
}
```
- **Audit Metadata**: Write `round-N/meta.json` recording `{peer, attempts: [{model, exit_code, status, duration_s}], model_used}`.

---

### Subsystem 2: Session Continuation & Human Guidance (`-c / --continue`)

#### CLI Interface
```bash
agent-deliberate -c [--id <ID>] [--rounds <+N|N>] [--guidance "<directive>" | --guidance-file <path>] [--add-option "<id>: <desc>"]
```

#### Idempotency & Round Progression
1. **Target Directory Resolution**:
   - If `--id` is provided, use `.agent/deliberations/<ID>`.
   - If `--id` is omitted with `-c`, automatically resolve the deliberation directory with the newest `updated_at` in `manifest.json`.
2. **Resume Boundary**:
   - Scan existing `round-*` directories. Identify highest round $K$ with a valid `tally.json`.
   - Start execution at round $K + 1$.
   - **Never overwrite completed rounds**.
3. **Budget Extension**:
   - If the deliberation was at `DEADLOCK` ($K \ge \text{max\_rounds}$), extend the budget:
     - If `--rounds +N` or `--rounds N` is given: extend to $K + N$.
     - Default on `-c` with guidance: automatically extend by $+1$ round.
     - Record extension history in `manifest.json` under `.budget_extensions[]`.

#### Human Guidance Directive
- Save input to `round-<K+1>/guidance.md`.
- Append `{round: K+1, guidance: "<text>", timestamp: "..."}` to `manifest.json`.
- In `templates/deliberation_prompt.md`, add a dedicated section:
  ```markdown
  {{#IF_GUIDANCE}}
  ## 👤 Human Moderator Guidance & Arbitration
  The human operator has provided the following directive to unblock consensus:
  {{HUMAN_GUIDANCE}}

  You MUST address this guidance in your ballot evaluation, explain how your position respects it, and adjust your scores/stance accordingly.
  {{/IF_GUIDANCE}}
  ```

---

### Subsystem 3: Dynamic Option Synthesis & Registration

#### Ballot Schema Extension
In `templates/deliberation_prompt.md`:
```json
{
  "preferred_option": "Option_0",
  "stance": "BLOCK",
  "counter_proposal": {
    "title": "Targeted Consistency Repair",
    "description": "Incremental reducer fixes for event idempotency, scene anchoring, and volume pruning without rewriting Riverpod/Hive.",
    "resolves_objections": ["OBJ-1", "OBJ-2"]
  }
}
```
- **Constraint**: If a peer's stance is `BLOCK` or if only `Option_0` exists in the round, providing a `counter_proposal` is **mandatory**.

#### Inter-Round Registration Logic
Between rounds $R$ and $R+1$:
1. If `tally.status != CONVERGED`:
   - Inspect both ballots for valid `counter_proposal` objects.
   - If found:
     - Generate stable, neutral identifiers: `Option_A`, `Option_B` (or sequential letter).
     - Strip peer identities (origin agent is stored only in internal audit metadata, never shown in prompts).
     - Link to resolved objection IDs.
     - Append to `manifest.json` `options` array (capped at max 2 new options per round).
2. Human-Added Options:
   - If `--add-option "<Title>: <Description>"` was provided via CLI, register it directly in `manifest.json`.
3. In Round $R+1$, both peers evaluate the newly registered options.
4. **Tally Validation**: `consensus_tally.sh` verifies that `preferred_option` matches a registered option in `manifest.json`. When peers converge on `Option_A`, tally status transitions to `CONVERGED`.

---

### Subsystem 4: Step-by-Step & Empirical Probe Yielding

1. When factual objections produce `jetski_evidence_prompt.md`:
   - If `--step` or `--yield-on-evidence` is enabled (default in interactive agent mode):
     - Output `🔬 [JETSKI_DIRECTIVE]` instructions.
     - Yield control and exit with code 3 (`WAITING_EVIDENCE`).
     - Once Jetski subagent writes `round-N/jetski_evidence.md`, running `agent-deliberate -c` seamlessly incorporates the evidence and executes Round $N+1$.
   - In headless batch mode (default CI): if evidence already exists, inject it automatically.

---

## 4. Verification & Testing Strategy

1. **Unit Tests (`test_consensus_round.sh`)**:
   - Mock Claude/Codex returning 429 on first rung, succeeding on second rung.
   - Verify `meta.json` logs attempts and model used.
   - Mock Exit 126: verify zero retry and immediate Exit 126.
2. **Continuation Tests (`test_agent_deliberate.sh`)**:
   - Execute Round 1 and Round 2 with DEADLOCK.
   - Run `agent-deliberate -c --guidance "Focus on Option A"`.
   - Verify Round 1 & 2 files untouched, Round 3 created with guidance injected in prompt.
3. **Synthesis Tests (`test_consensus_tally.sh`)**:
   - Round 1 only has `Option_0`, peer blocks with `counter_proposal`.
   - Manifest gains `Option_A`.
   - Round 2 peers vote `Option_A` -> `CONVERGED`.
4. **Regression Run (`tests/run_all_tests.sh`)**:
   - All existing suites must stay 100% green.
