# Gemini Native Subagent Peer & 3-Peer Consensus Deliberation Design

- **Date**: 2026-11-28
- **Status**: Draft for User Review
- **Scope**: Collaboration protocols (`templates/AGENTS.md`, `AGENTS.md`, `skills/agent-collaborator/SKILL.md`, `templates/antigravity_superpowers.md`, `README.md`, `README_zh.md`) and Consensus Deliberation scripts (`consensus_tally.sh`, `consensus_round.sh`, `agent_deliberate.sh`, `tests/`)

---

## 1. Motivation & Goals

Historically, `agent-collaborator` treated Antigravity (Gemini) solely as the orchestrator/implementer and relied exclusively on external CLIs (Claude CLI, OpenAI Codex CLI) for independent brainstorming, architecture design, spec refinement, code review, and consensus voting.

With stronger Gemini models and Antigravity's native `invoke_subagent` capability, Antigravity can dispatch an isolated, fresh-context **Gemini Peer Subagent** concurrently alongside Claude CLI and/or Codex CLI:

1. **Advisory Milestones (Brainstorm / Design / Refine / Review / Optimize)**:
   - Antigravity always dispatches a read-only `research` Gemini Peer Subagent in the same turn alongside available external CLIs (`claude-*` / `codex-*`).
   - All peers run asynchronously in parallel with zero extra wall-clock latency; Antigravity yields the turn until all return, then synthesizes consensus, disagreements, and edge cases across models.
   - If Claude/Codex are unavailable or hit rate limits (exit 100), the Gemini Peer Subagent still provides an independent, clean-context second opinion rather than falling back to single-thread self-review.
2. **Multi-Agent Consensus Deliberation (`agent-deliberate`)**:
   - Gemini Peer Subagent participates as an equal **3rd voting peer** alongside Claude and Codex.
   - Preserves **100% backward compatibility** with existing 2-peer CLI-only usage and tests.
   - Introduces **2-of-3 survival quorum**: if either Claude or Codex fails/is unavailable while Gemini + the other CLI succeed, deliberation proceeds as a valid quorum (`quorum_met: true`, `reduced_quorum: true`) instead of immediately degrading.
   - Maintains **unanimous convergence** across all participating valid peers (same registered `preferred_option`, zero `BLOCK` / active objections / active over-architecture flags, per-peer YAGNI ≥ 3.0, average YAGNI ≥ 3.5, per-metric `max - min ≤ 1`).

### Non-Goals
- No standalone `gemini` CLI wrapper inside Bash (native `invoke_subagent` is the primary mechanism).
- No generic N-agent plugin registry (`peers.json`), polling loops, or local daemon/HTTP bridges (avoiding `PREMATURE_GENERALIZATION` and `UNNECESSARY_PERSISTENCE`).

---

## 2. Architecture Overview

Bash scripts cannot directly invoke Antigravity's native `invoke_subagent` tool. Therefore, responsibilities are cleanly separated across the tool/shell boundary:

- **Antigravity Main Agent (Orchestrator & Neutral Moderator)** owns native `invoke_subagent` dispatch, result validation, atomic ballot file handoff (`round-N/gemini_ballot.json`), and cross-model synthesis. It does **not** cast a subjective vote.
- **Gemini Peer Subagent (`invoke_subagent`, `TypeName: "research"`)** runs in a fresh, isolated, read-only conversation context. It receives only the raw requirement, options, context files, and (for Round > 1) the anonymized `digest.md` — never the Orchestrator's personal leaning.
- **External CLIs (`claude`, `codex`)** continue running via Bash wrappers / `consensus_round.sh`.
- **Jetski Subagent** remains a distinct, non-voting empirical spike prober invoked only when `factual` blocking objections require benchmark/code verification.
- **Bash + `jq` (`consensus_tally.sh`, `consensus_round.sh`, `agent_deliberate.sh`)** remain the single deterministic gate for ballot validation, quorum calculation, spread/YAGNI checks, anonymized digest generation, and blueprint/dissent rendering.

---

## 3. Part 1: Collaboration Protocol & Advisory Milestones

### 3.1 Role Definitions (`templates/AGENTS.md`, `AGENTS.md`, `SKILL.md`, `templates/antigravity_superpowers.md`)

Update Section 1 ("Roles & Architecture Division of Labor") to define the **Tri-Model Peer Advisory Council**:

- **Central Orchestrator & Implementer (Antigravity / Gemini Main)**: Global context assembly, toolchain/test/git execution, cross-model synthesis, and neutral deliberation moderator (non-voting).
- **Gemini Peer Subagent (Antigravity Native `invoke_subagent`)**:
  - Dispatched with `TypeName: "research"` (read-only sandbox, zero risk of unintended file edits) and `Model: "inherit"` (unless the user explicitly requests `pro` or another model).
  - Assigned task-specific `Role` labels: `Gemini Brainstormer`, `Gemini Architect`, `Gemini Spec Reviewer`, `Gemini Code Reviewer`, or `Gemini Deliberation Peer`.
  - For Code Review (`git diff HEAD`), since `research` subagents cannot run shell commands, the Orchestrator includes the git diff (or changed file paths + diff summary) directly in the subagent prompt.
- **Claude CLI (`agent-collaborator`)**: Deep architecture, state machines, spec refinement, pre-flight code review.
- **OpenAI Codex CLI (`agent-collaborator`)**: Engineering feasibility, YAGNI/contrarian red-team perspective, algorithmic/performance and terminal/CI automation.
- **Jetski Subagent (Empirical Spike Probe, non-voting)**: Dispatched only to resolve `factual` disputes in `agent-deliberate` with throwaway benchmarks/spikes.

### 3.2 Mandatory Concurrent Dispatch Rules (Section 2)

For every engineering milestone when running in Antigravity:

| Milestone | Gemini Native Subagent (Always) | External CLIs (Concurrent when available) |
|---|---|---|
| **Brainstorming & Ideation** | `invoke_subagent` (`research`, `Role: "Gemini Brainstormer"`) | `claude-brainstorm` and/or `codex-brainstorm` |
| **Architecture & State Machine** | `invoke_subagent` (`research`, `Role: "Gemini Architect"`) | `claude-design` |
| **Spec & Schema Refinement** | `invoke_subagent` (`research`, `Role: "Gemini Spec Reviewer"`) | `claude-refine` |
| **Pre-flight Code Review** | `invoke_subagent` (`research`, `Role: "Gemini Code Reviewer"`, with diff context) | `claude-review HEAD` |
| **Performance / Algorithmic** | `invoke_subagent` (`research`, `Role: "Gemini Performance Reviewer"`) | `codex-optimize` |
| **Consensus Deliberation** | `invoke_subagent` (`research`, `Role: "Gemini Deliberation Peer"`) | `consensus-round --no-tally` (Claude + Codex) |

### 3.3 Asynchronous Turn Yielding & Synthesis (Section 3)

1. Launch the Gemini Peer Subagent (`invoke_subagent`) and available external CLI commands (`run_command`) **in the same turn**.
2. Output a brief status update and **stop calling tools** to yield the turn.
3. Do not finalize `implementation_plan.md` or declare a milestone complete until **all** dispatched peers (both native subagent and background CLI tasks) have returned.
4. Synthesize all returned perspectives, noting agreements, conflicting trade-offs, and unique edge cases caught by each model.
5. **Graceful Degradation**: If external CLIs are not installed or fail with exit code `100`, log the fallback notice and proceed using the Gemini Peer Subagent's independent review.
6. **Driver Platform Guard**: Only Antigravity uses `invoke_subagent` for Gemini Peer dispatch. When Claude Code CLI is the primary orchestrator, existing non-recursive rules remain unchanged.

---

## 4. Part 2: 3-Peer Consensus Deliberation (`agent-deliberate`)

### 4.1 `consensus_tally.sh` — Generalized N-Peer Deterministic Gate

#### CLI Signature (Backward Compatible)
```bash
consensus_tally.sh [--gemini <GEMINI_BALLOT_JSON>] <CLAUDE_BALLOT_JSON> <CODEX_BALLOT_JSON> <OUTPUT_TALLY_JSON> [ROUND_NUM] [MAX_ROUNDS] [MANIFEST]
```
- When `--gemini` is omitted: **2-peer mode** (`expected_peers = ["claude", "codex"]`). Behavior and legacy fields match existing 2-peer contracts identically.
- When `--gemini <file>` is provided: **3-peer mode** (`expected_peers = ["claude", "codex", "gemini"]`).

#### Strict Pre-Scoring Ballot Validation
For each expected peer's ballot file:
1. **Absent**: File does not exist or has size 0 → add peer name to `absent_peers`.
2. **Invalid**: File exists and is non-empty, but fails any of:
   - Valid JSON object (`type == "object"`).
   - Non-empty string `preferred_option`.
   - `stance` is one of `"ACCEPT"`, `"ACCEPT_WITH_RESERVATIONS"`, `"BLOCK"`.
   - All 5 core metrics (`technical_feasibility`, `architectural_simplicity`, `yagni_and_parsimony`, `robustness_failure_modes`, `maintainability_testability`) exist with numeric `score` where `1 <= score <= 5`.
   → add peer name to `invalid_peers` (never coerce missing scores to `0`).
3. **Valid**: Otherwise → add peer name to `participating_peers`.

#### Quorum & Convergence Gate
- `quorum_met = (participating_peers.length >= 2)`
- `reduced_quorum = (quorum_met && participating_peers.length < expected_peers.length)`
- **If `!quorum_met` (0 or 1 valid ballot)**:
  - `status = "DEGRADED"`
  - `degraded_peer`:
    - In 2-peer mode: `"both"` (0 valid), `"codex"` (only claude valid), or `"claude"` (only codex valid) — preserving exact legacy values.
    - In 3-peer mode: `"all"` (0 valid) or comma-joined list of non-participating peers (e.g. `"claude,codex"` when only gemini is valid).
  - `consensus_option`: `null` if 0 valid, or the single valid ballot's `preferred_option` (preserving legacy behavior for 1-ballot degraded inspection).
- **If `quorum_met` (2 or 3 valid ballots)**:
  - For each of the 5 core metrics: `spread = max(scores) - min(scores)` over `participating_peers`.
  - `yagni_score_avg = sum(yagni_scores) / participating_peers.length`.
  - `yagni_pass = (all participating yagni_score >= 3.0) && (yagni_score_avg >= 3.5)`.
  - `preferred_matches = (unique(participating preferred_options).length == 1)`.
  - `candidate_option = participating[0].preferred_option` (when `preferred_matches`).
  - `option_is_registered`: `manifest.options` is empty OR `candidate_option` is in `manifest.options`.
  - `blocking_objections` & `over_architecture_flags`: union across all participating ballots (plus synthetic `UNREGISTERED_OPTION` if `!option_is_registered`).
  - Active filter: objections/flags where `target_option` is `null`, `""`, or equals `candidate_option`.
  - `has_block = any(stance == "BLOCK") || active_objections.length > 0 || active_flags.length > 0 || !option_is_registered`.
  - `all_spreads_lte_1 = all(spread <= 1)`.
  - **Status**:
    - `CONVERGED`: `preferred_matches && option_is_registered && !has_block && yagni_pass && all_spreads_lte_1`
    - `CONVERGED_WITH_DISSENT`: `preferred_matches && option_is_registered && !has_block && yagni_pass && !all_spreads_lte_1`
    - `DEADLOCK`: `round >= max_rounds`
    - `IN_DEBATE`: otherwise

#### Output Schema (`tally.json`)
Preserves all existing fields (`deliberation_id`, `round`, `max_rounds`, `status`, `consensus_option`, `yagni_score_avg`, `score_spreads`, `blocking_objections`, `over_architecture_flags`, and `degraded_peer` when degraded) and adds:
```json
{
  "participating_peers": ["claude", "codex", "gemini"],
  "absent_peers": [],
  "invalid_peers": [],
  "quorum_met": true,
  "reduced_quorum": false
}
```
Output is written atomically via temp file + `mv` in the same directory.

---

### 4.2 `consensus_round.sh` — Parallel Native-Subagent Friendly Driver

Add three optional flags while keeping default invocation 100% unchanged:

```bash
consensus_round.sh [--no-tally | --tally-only] [--gemini-ballot <FILE>] [--max-rounds <N>] [--model-claude <M>] [--model-codex <M>] [--guidance <TEXT>] <DELIBERATION_DIR> <ROUND_NUM>
```

1. **`--no-tally`**:
   - Runs Claude and Codex CLIs concurrently in isolated session dirs and writes `claude_ballot.json`/`.md`, `codex_ballot.json`/`.md`, and `meta.json`.
   - Also writes `$ROUND_DIR/gemini_prompt.md` using `render_prompt "gemini" ...` for auditability/replay.
   - Stops before tallying (exits `126` immediately on sandbox block; exits `0` otherwise so `--tally-only` can evaluate full quorum once Gemini's ballot lands).
   - Never deletes an already-present `gemini_ballot.json` (since Antigravity's parallel subagent may finish before the CLIs).
2. **`--tally-only`**:
   - Skips invoking Claude and Codex CLIs.
   - Resolves Gemini ballot path from `--gemini-ballot <FILE>` if supplied, otherwise auto-detects `$ROUND_DIR/gemini_ballot.json` if present.
   - If zero valid ballots exist across all peers (Claude, Codex, Gemini), emits `⚠️ [FALLBACK_TRIGGERED: PEERS_UNAVAILABLE]` and exits `100`.
   - Invokes `consensus_tally.sh` (passing `--gemini "$GEMINI_BALLOT_PATH"` whenever 3-peer mode is active, i.e., `--gemini-ballot` was passed or `$ROUND_DIR/gemini_ballot.json` exists).
   - If status is not `CONVERGED`:
     - Synthesizes `counter_proposal` entries from **all** participating peers (Claude, Codex, and Gemini) into `manifest.json`.
     - Generates anonymized `digest.md` listing peer positions as `Peer 1`, `Peer 2`, `Peer 3` (deterministic order without leaking model names).
3. **Default mode (neither `--no-tally` nor `--tally-only`)**:
   - Identical to today, except if `--gemini-ballot <FILE>` is passed or `$ROUND_DIR/gemini_ballot.json` exists, it is automatically included in tallying, counter-proposal synthesis, and anonymized digest generation.

---

### 4.3 `agent_deliberate.sh` — Init, Finalize, and Dynamic 2/3-Peer Reporting

1. **`--init`**:
   - Creates/validates the deliberation directory, `manifest.json`, `option_0_baseline.md`, and optional `--add-option` / `--guidance` files, prints the resolved `DELIBERATION_DIR`, and exits `0` without running rounds.
2. **`--finalize <ROUND_NUM>`** (combined with `-d <DIR>` or `--id <ID>`):
   - Reads `$DELIBERATION_DIR/round-$ROUND_NUM/tally.json` and updates `manifest.json` (`CONVERGED` / `DEADLOCK`).
   - Calls `generate_final_blueprint "$ROUND_NUM"` or `generate_dissent_register "$ROUND_NUM"` and prints the terminal executive summary table.
   - Exits `0` on convergence, `2` on deadlock, `1` if `tally.json` is missing or still `IN_DEBATE`.
3. **Dynamic 2/3-Peer Rendering**:
   - `generate_final_blueprint`, `generate_dissent_register`, and the terminal summary table inspect which of `claude_ballot.json`, `codex_ballot.json`, `gemini_ballot.json` exist in `$ROUND_DIR` and render columns/sections dynamically (preserving 2-column output when only Claude + Codex exist, and rendering 3 columns `Claude | Codex | Gemini` when Gemini participated).
   - When `tally.reduced_quorum == true`, display an explicit `Quorum: 2/3 (reduced quorum — absent/invalid: ...)` notice in both the Markdown report and terminal summary.
4. **Antigravity 3-Peer Orchestration Flow (documented in `AGENTS.md` Section 7)**:
   1. Run `agent-deliberate --init "<TOPIC>" [CONTEXT_FILES...]` to initialize `<DIR>`.
   2. For each round `N = 1..MAX_ROUNDS`:
      - In a **single turn**, launch concurrently:
        - `run_command`: `consensus-round --no-tally <DIR> <N>`
        - `invoke_subagent` (`TypeName: "research"`, `Role: "Gemini Deliberation Peer"`): pass `<TOPIC>`, `<DIR>/option_0_baseline.md`, `<DIR>/manifest.json`, context files, `templates/deliberation_prompt.md`, and (for `N > 1`) `<DIR>/round-(N-1)/digest.md` + `<DIR>/round-(N-1)/gemini_ballot.json`.
      - Yield turn until both return.
      - Validate Gemini's returned fenced JSON ballot with `jq` and atomically write `<DIR>/round-<N>/gemini_ballot.json` and `<DIR>/round-<N>/gemini_ballot.md`.
      - Run `consensus-round --tally-only --gemini-ballot <DIR>/round-<N>/gemini_ballot.json <DIR> <N>`.
      - Inspect `<DIR>/round-<N>/tally.json`:
        - `CONVERGED` / `CONVERGED_WITH_DISSENT` / `DEADLOCK` → run `agent-deliberate --finalize <N> -d <DIR>`.
        - `IN_DEBATE` → if `factual` objections exist, dispatch Jetski probe to write `round-<N>/jetski_evidence.md` and append to `digest.md`; proceed to round `N+1`.

---

## 5. Error Handling & Edge Cases

1. **Read-only subagent cannot write files**: Gemini Peer returns fenced JSON + Markdown rationale as text; Antigravity extracts, validates with `jq`, and writes `gemini_ballot.json` atomically (`tmp` + `mv`).
2. **Malformed Gemini response**: If extraction or schema validation fails, Antigravity still passes `--gemini-ballot` (pointing to the invalid file or empty path) so `tally.json` accurately records `gemini` in `invalid_peers` or `absent_peers`, while Claude + Codex still form a valid `reduced_quorum: true` tally.
3. **One CLI down + Gemini up**: `--no-tally` succeeds even if Claude or Codex fails; `--tally-only` combines Gemini + the surviving CLI into a valid 2-of-3 quorum (`reduced_quorum: true`).
4. **Both CLIs down + Gemini up**: Only 1 valid ballot → `tally.json` records `status: "DEGRADED"`, `quorum_met: false`, `degraded_peer: "claude,codex"`. Single-agent output is never certified as consensus.
5. **Anonymization in `digest.md`**: Peer rationales and positions use anonymous labels (`Peer 1`, `Peer 2`, `Peer 3`) so Round > 1 remains free of model-name anchoring bias.
6. **Stale files on `-c` continuation**: Each round is strictly isolated in `round-<N>/`; `consensus_tally.sh` never globs across round directories.

---

## 6. Testing & Verification Strategy

All tests live under `tests/` and run via `bash tests/run_all_tests.sh`:

1. **Backward Compatibility**: All existing tests in `test_consensus_tally.sh`, `test_consensus_round.sh`, `test_agent_deliberate.sh`, and `test_wrapper_error_details.sh` must pass unmodified.
2. **New `test_consensus_tally.sh` cases**:
   - 3-peer unanimous `CONVERGED` (`quorum_met: true`, `reduced_quorum: false`, `participating_peers: ["claude","codex","gemini"]`).
   - 3-peer spread > 1 → `CONVERGED_WITH_DISSENT`.
   - 3-peer 2v1 split `preferred_option` → `IN_DEBATE` (round < max) / `DEADLOCK` (round == max).
   - 3-peer single peer YAGNI `< 3.0` fails even if average ≥ 3.5.
   - All three 2-of-3 survival quorums (Claude+Gemini, Codex+Gemini, Claude+Codex) → valid convergence with `quorum_met: true`, `reduced_quorum: true`, and accurate `absent_peers`.
   - 1-of-3 and 0-of-3 → `DEGRADED` (`quorum_met: false`).
   - Malformed JSON or missing metric score → peer recorded in `invalid_peers` (not coerced to `0`).
3. **New `test_consensus_round.sh` cases**:
   - `--no-tally` + write `gemini_ballot.json` + `--tally-only` end-to-end flow.
   - Anonymized `digest.md` contains no raw model names (`claude`, `codex`, `gemini`) in peer headers.
   - Gemini `counter_proposal` synthesized into `manifest.json`.
   - One mock CLI failing during `--no-tally` + valid `gemini_ballot.json` succeeds in `--tally-only` with `reduced_quorum: true`.
4. **New `test_agent_deliberate.sh` cases**:
   - `--init` creates manifest and `option_0_baseline.md` cleanly.
   - `--finalize` on 3-peer `CONVERGED` generates 3-column `final_blueprint.md` (and `reduced_quorum` notice when 2/3).
   - `--finalize` on 3-peer `DEADLOCK` generates `dissent_register.md` listing all 3 peers' preferences.
5. **Installer Sync Verification**: Run `./install.sh --antigravity-global` (or verify `templates/AGENTS.md` ↔ `AGENTS.md` sync) so updated protocol blocks stay in lockstep.
