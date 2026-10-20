# Deliberation Continuation, Resilience & Option Synthesis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `agent-deliberate` with model fallback ladders, session continuation (`--continue` / `--guidance`), and adaptive counter-proposal synthesis to eliminate false deadlocks and ensure deliberation survival.

**Architecture:** Model calls execute with a tiered fallback ladder (`sonnet -> haiku`, `o3-mini -> gpt-4o -> default`). Deliberation sessions can be resumed idempotently from the last valid round with human guidance injected. Ballots with BLOCK require a `counter_proposal` that is dynamically registered in `manifest.json` as candidate options for subsequent rounds.

**Tech Stack:** Bash (macOS/POSIX compatible, `set -uo pipefail`), Python 3 (inline JSON/regex processors), `jq`.

**Spec:** `docs/superpowers/specs/2026-10-20-deliberation-continuation-and-resilience-design.md`

## Global Constraints

- Exit code contract must remain intact: 0 = CONVERGED, 1 = caller input error, 2 = DEADLOCK, 100 = external peers unavailable (triggers fallback), 126 = sandbox blocked.
- macOS standard tools compatibility: do not depend on GNU-specific coreutils (`timeout` / `sed -i` flags).
- All tests in `tests/run_all_tests.sh` must remain 100% green at every task checkpoint.
- Strict TDD: Write failing tests first, verify failure, then write minimal code to pass.

---

### Task 1: Prompt Template & Ballot Schema Update for Counter-Proposals & Guidance

**Files:**
- Modify: `templates/deliberation_prompt.md`
- Create: `tests/fixtures/counter_proposal_ballot.json`

**Interfaces:**
- Consumes: Deliberation schema from `specs/2026-10-20-deliberation-continuation-and-resilience-design.md`
- Produces: `counter_proposal` ballot schema field and `{{#IF_GUIDANCE}}` template block

- [ ] **Step 1: Create test fixture for counter proposal ballot**
  Write `tests/fixtures/counter_proposal_ballot.json` with a valid ballot containing `counter_proposal: {title, description, resolves_objections}`.
- [ ] **Step 2: Update `templates/deliberation_prompt.md`**
  Add `{{#IF_GUIDANCE}}` block and update the JSON schema instructions: when stance is `BLOCK` or when only `Option_0` is present, `counter_proposal` is mandatory.
- [ ] **Step 3: Verify template syntax & JSON validation**
  Verify `jq . tests/fixtures/counter_proposal_ballot.json` succeeds.
- [ ] **Step 4: Commit changes**
  `git add templates/deliberation_prompt.md tests/fixtures/counter_proposal_ballot.json`
  `git commit -m "feat(deliberation): add counter_proposal schema and guidance template block"`

---

### Task 2: Model Fallback Ladder in `consensus_round.sh`

**Files:**
- Modify: `skills/agent-collaborator/scripts/consensus_round.sh`
- Test: `tests/test_consensus_round.sh`

**Interfaces:**
- Consumes: Environment variables `CLAUDE_MODEL_LADDER`, `CODEX_MODEL_LADDER`, `--model-claude`, `--model-codex`
- Produces: Isolated peer execution with ladder fallback, writes `round-N/meta.json` with attempt records

- [ ] **Step 1: Write failing test in `tests/test_consensus_round.sh`**
  Add mock test where the primary model fails with a 429 / 400 error, but the secondary ladder model succeeds. Verify round produces a valid ballot and records the used model. Run test to verify failure.
- [ ] **Step 2: Implement ladder execution function in `consensus_round.sh`**
  Implement `run_peer_with_ladder` inside the concurrent subshells:
  - Claude ladder: `${MODEL_CLAUDE:-sonnet},haiku`
  - Codex ladder: `${MODEL_CODEX:-o3-mini},gpt-4o,default`
  - Classify exit codes: Exit 126 is fatal (return 126 immediately); 429/400/529 retries next rung; all rungs fail returns 100.
  - Re-render prompt per rung with current model.
  - Write `round-N/meta.json` containing `{peer, model_used, attempts}`.
- [ ] **Step 3: Run `tests/test_consensus_round.sh` and verify pass**
- [ ] **Step 4: Commit changes**
  `git add skills/agent-collaborator/scripts/consensus_round.sh tests/test_consensus_round.sh`
  `git commit -m "feat(deliberation): implement autonomous model fallback ladder"`

---

### Task 3: Dynamic Option Synthesis & Registration

**Files:**
- Modify: `skills/agent-collaborator/scripts/consensus_round.sh`
- Modify: `skills/agent-collaborator/scripts/consensus_tally.sh`
- Test: `tests/test_consensus_tally.sh`
- Test: `tests/test_consensus_round.sh`

**Interfaces:**
- Consumes: `claude_ballot.json` and `codex_ballot.json` `counter_proposal` field
- Produces: Newly registered options in `manifest.json` (`Option_A`, `Option_B`), validated by `consensus_tally.sh`

- [ ] **Step 1: Write failing test for option synthesis and validation**
  Add test verifying:
  - Two peers voting for an unregistered option ID cannot converge.
  - When a peer submits a ballot with a `counter_proposal`, `consensus_round.sh` extracts it and registers it in `manifest.json`.
  Run test to verify failure.
- [ ] **Step 2: Update `consensus_tally.sh` to validate candidate options**
  Check that `consensus_option` must belong to the registered options in `manifest.json`.
- [ ] **Step 3: Implement counter-proposal extraction and registration in `consensus_round.sh`**
  When round status is not `CONVERGED`, parse ballots for `counter_proposal`, assign neutral IDs (`Option_A`, etc.), link resolved objections, and append to `manifest.json.options` (capped at max 2 options).
- [ ] **Step 4: Run tests and verify all pass**
- [ ] **Step 5: Commit changes**
  `git add skills/agent-collaborator/scripts/consensus_round.sh skills/agent-collaborator/scripts/consensus_tally.sh tests/test_consensus_tally.sh tests/test_consensus_round.sh`
  `git commit -m "feat(deliberation): add adaptive counter-proposal synthesis into manifest options"`

---

### Task 4: Session Continuation (`--continue` / `-c`) & Human Guidance Injection

**Files:**
- Modify: `skills/agent-collaborator/scripts/agent_deliberate.sh`
- Test: `tests/test_agent_deliberate.sh`

**Interfaces:**
- Consumes: Flags `-c / --continue`, `--guidance "<text>"`, `--guidance-file <path>`, `--add-option "<opt>"`
- Produces: Idempotent continuation from latest incomplete round, budget extension, guidance injection into rendered prompt

- [ ] **Step 1: Write failing test in `tests/test_agent_deliberate.sh`**
  Add tests for:
  - Resuming an existing deliberation that ended in DEADLOCK.
  - Passing `--guidance "Use optimistic locking"` and verifying Round 4 prompt contains `Human Moderator Guidance`.
  - Verifying Round 1-3 files are never overwritten.
  Run test to verify failure.
- [ ] **Step 2: Implement CLI argument parsing in `agent_deliberate.sh`**
  Support `-c, --continue`, `--guidance`, `--guidance-file`, `--add-option`.
- [ ] **Step 3: Implement idempotent round detection & budget extension**
  Find highest existing round with valid `tally.json`. If continuing, set start round to `highest + 1` and extend `max_rounds`. Write `round-<START>/guidance.md` and update `manifest.json`.
- [ ] **Step 4: Run `tests/test_agent_deliberate.sh` and verify pass**
- [ ] **Step 5: Commit changes**
  `git add skills/agent-collaborator/scripts/agent_deliberate.sh tests/test_agent_deliberate.sh`
  `git commit -m "feat(deliberation): add session continuation and human guidance arbitration"`

---

### Task 5: End-to-End Verification & Verification Before Completion

**Files:**
- Modify: `tests/run_all_tests.sh`
- Test: Full test suite + real test on `dlb-memory-system-v2`
- Sync: Update `CelestialBrush` and global installation (`install.sh --antigravity-global`)

- [ ] **Step 1: Run complete test suite**
  Run `bash tests/run_all_tests.sh` and verify all tests pass with zero failures.
- [ ] **Step 2: Test continuation on real ledger `dlb-memory-system-v2`**
  Run `agent-deliberate -c --dir /Users/pcmanager/projects/CelestialBrush/.agent/deliberations/dlb-memory-system-v2 --guidance "針對性修復：不進行全面重寫，採用增量修復方案修復事件冪等與場景錨定"` and verify it resumes at Round 4 and evaluates the guidance.
- [ ] **Step 3: Sync changes to `CelestialBrush` and global environment**
  Run `./install.sh --antigravity-global` and sync to `/Users/pcmanager/projects/CelestialBrush`.
- [ ] **Step 4: Pre-flight review via `claude-review HEAD`**
- [ ] **Step 5: Commit and push**
