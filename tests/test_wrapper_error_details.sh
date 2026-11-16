#!/usr/bin/env bash
# ==============================================================================
# Unit & Integration Tests for Wrapper & Consensus Round stdout Error Details
# ==============================================================================

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required for test_wrapper_error_details.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/skills/agent-collaborator/scripts"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

MOCK_BIN="$TEMP_DIR/bin"
WORK_DIR="$TEMP_DIR/work"
mkdir -p "$MOCK_BIN" "$WORK_DIR"

# Prepare a minimal git repo and file for claude_review.sh / claude_refine.sh
cat <<'EOF' > "$WORK_DIR/dummy.md"
# Sample Doc
Initial line
EOF

(
  cd "$WORK_DIR"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"
  git add dummy.md
  git commit -qm "init"
  echo "Modified line" >> dummy.md
)

cat <<'EOF' > "$MOCK_BIN/claude"
#!/usr/bin/env bash
case "${MOCK_MODE:-AUTH_STDOUT}" in
  AUTH_STDOUT)
    echo "Failed to authenticate: OAuth session expired and could not be refreshed"
    exit 1
    ;;
  RATE_STDOUT)
    echo "Error: HTTP 429 rate limit reached"
    exit 1
    ;;
  BENIGN_4012)
    echo "You can sign in later; no session needed in this text (id 4012)"
    echo "Execution failed for request id 4012" >&2
    exit 1
    ;;
  NO_SESSION_STDOUT)
    echo "No conversation found with session ID: abc123"
    exit 1
    ;;
  AUTH_ROUND)
    echo "Failed to authenticate: OAuth expired"
    exit 1
    ;;
  *)
    echo "Unknown MOCK_MODE in claude mock: ${MOCK_MODE:-}" >&2
    exit 2
    ;;
esac
EOF

cat <<'EOF' > "$MOCK_BIN/codex"
#!/usr/bin/env bash
case "${MOCK_MODE:-AUTH_STDOUT}" in
  AUTH_STDOUT)
    echo "Failed to authenticate: OAuth session expired and could not be refreshed"
    exit 1
    ;;
  RATE_STDOUT)
    echo "Error: HTTP 429 rate limit reached"
    exit 1
    ;;
  BENIGN_4012)
    echo "You can sign in later; no session needed in this text (id 4012)"
    echo "Execution failed for request id 4012" >&2
    exit 1
    ;;
  NO_SESSION_STDOUT)
    echo "No session found to resume"
    exit 1
    ;;
  AUTH_ROUND)
    echo "Failed to authenticate: OAuth expired"
    exit 1
    ;;
  *)
    echo "Unknown MOCK_MODE in codex mock: ${MOCK_MODE:-}" >&2
    exit 2
    ;;
esac
EOF

chmod +x "$MOCK_BIN/claude" "$MOCK_BIN/codex"
export PATH="$MOCK_BIN:$PATH"

run_case() {
  local label="$1"
  local expected_rc="$2"
  shift 2

  local out=""
  local rc=0
  set +e
  out=$(cd "$WORK_DIR" && "$@" 2>&1)
  rc=$?
  set -e

  if [ "$rc" -ne "$expected_rc" ]; then
    echo "FAIL [$label]: expected exit $expected_rc, got $rc" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  printf '%s\n' "$out"
}

check_auth_wrapper() {
  local label="$1"
  local expected_detail="$2"
  shift 2
  local out
  out=$(run_case "$label" 100 "$@")
  if ! grep -q "FALLBACK_TRIGGERED" <<<"$out"; then
    echo "FAIL [$label]: missing FALLBACK_TRIGGERED" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  if ! grep -qi "authentication error" <<<"$out"; then
    echo "FAIL [$label]: missing 'authentication error' in Reason:" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  if ! grep -qF "Detail: $expected_detail" <<<"$out"; then
    echo "FAIL [$label]: missing 'Detail: $expected_detail'" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  echo "PASS: $label"
}

check_resume_stdout() {
  local label="$1"
  local expected_detail="$2"
  shift 2
  local out
  out=$(run_case "$label" 1 "$@")
  if ! grep -qF "Detail: $expected_detail" <<<"$out"; then
    echo "FAIL [$label]: missing 'Detail: $expected_detail'" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  echo "PASS: $label"
}

echo "=== Test 1: All 8 wrappers surface stdout-only auth error (exit 100) ==="
export MOCK_MODE="AUTH_STDOUT"
AUTH_MSG="Failed to authenticate: OAuth session expired and could not be refreshed"

check_auth_wrapper "claude_brainstorm" "$AUTH_MSG" bash "$SCRIPTS_DIR/claude_brainstorm.sh" "topic"
check_auth_wrapper "claude_design"     "$AUTH_MSG" bash "$SCRIPTS_DIR/claude_design.sh" "topic"
check_auth_wrapper "claude_review"     "$AUTH_MSG" bash "$SCRIPTS_DIR/claude_review.sh" HEAD "topic"
check_auth_wrapper "claude_refine"     "$AUTH_MSG" bash "$SCRIPTS_DIR/claude_refine.sh" dummy.md "goal"
check_auth_wrapper "claude_followup"   "$AUTH_MSG" bash "$SCRIPTS_DIR/claude_followup.sh" "followup"
check_auth_wrapper "codex_brainstorm"  "$AUTH_MSG" bash "$SCRIPTS_DIR/codex_brainstorm.sh" "topic"
check_auth_wrapper "codex_optimize"    "$AUTH_MSG" bash "$SCRIPTS_DIR/codex_optimize.sh" "topic"
check_auth_wrapper "codex_followup"    "$AUTH_MSG" bash "$SCRIPTS_DIR/codex_followup.sh" "followup"

echo "=== Test 2: Claude & Codex -c / followup stdout-only session resume error (exit 1) ==="
export MOCK_MODE="NO_SESSION_STDOUT"
check_resume_stdout "claude_brainstorm_continue" "No conversation found with session ID: abc123" bash "$SCRIPTS_DIR/claude_brainstorm.sh" -c "topic"
check_resume_stdout "claude_followup_resume"     "No conversation found with session ID: abc123" bash "$SCRIPTS_DIR/claude_followup.sh" "followup"
check_resume_stdout "codex_brainstorm_continue"  "No session found to resume" bash "$SCRIPTS_DIR/codex_brainstorm.sh" -c "topic"
check_resume_stdout "codex_followup_resume"      "No session found to resume" bash "$SCRIPTS_DIR/codex_followup.sh" "followup"

echo "=== Test 3: Stdout-only rate limit & benign-4012 negative check ==="
export MOCK_MODE="RATE_STDOUT"
rate_out=$(run_case "claude_rate_stdout" 100 bash "$SCRIPTS_DIR/claude_design.sh" "topic")
if ! grep -qi "rate limit" <<<"$rate_out" || ! grep -qF "Detail: Error: HTTP 429 rate limit reached" <<<"$rate_out"; then
  echo "FAIL [claude_rate_stdout]: unexpected output:" >&2
  printf '%s\n' "$rate_out" >&2
  exit 1
fi
echo "PASS: claude_rate_stdout"

export MOCK_MODE="BENIGN_4012"
for item in "claude|claude_brainstorm.sh" "codex|codex_brainstorm.sh"; do
  name="${item%%|*}"
  script="${item##*|}"
  neg_out=$(run_case "neg_$name" 100 bash "$SCRIPTS_DIR/$script" "topic")
  if grep -qi "authentication error" <<<"$neg_out"; then
    echo "FAIL [neg_$name]: misclassified request id 4012 / stdout prose as auth error:" >&2
    printf '%s\n' "$neg_out" >&2
    exit 1
  fi
  if ! grep -qF "Detail: Execution failed for request id 4012" <<<"$neg_out"; then
    echo "FAIL [neg_$name]: stderr should take precedence without stdout pollution:" >&2
    printf '%s\n' "$neg_out" >&2
    exit 1
  fi
  echo "PASS: neg_$name"
done

echo "=== Test 4: consensus_round.sh captures stdout-only error in attempt metadata ==="
export MOCK_MODE="AUTH_ROUND"
DELIB_DIR="$TEMP_DIR/delib"
mkdir -p "$DELIB_DIR"
cat <<'EOF' > "$DELIB_DIR/manifest.json"
{
  "deliberation_id": "test-dlb-err",
  "topic": "Stdout Error Capture Test",
  "options": [{"id": "Option_0", "description": "Option 0"}]
}
EOF

set +e
ROUND_OUT=$(bash "$SCRIPTS_DIR/consensus_round.sh" "$DELIB_DIR" 1 2>&1)
ROUND_RC=$?
set -e

if [ "$ROUND_RC" -ne 100 ]; then
  echo "FAIL [consensus_round]: expected exit 100, got $ROUND_RC" >&2
  printf '%s\n' "$ROUND_OUT" >&2
  exit 1
fi

META_FILE="$DELIB_DIR/round-1/meta.json"
if [ ! -f "$META_FILE" ]; then
  echo "FAIL [consensus_round]: missing $META_FILE" >&2
  exit 1
fi
for peer in claude codex; do
  err_val=$(jq -r ".$peer.attempts[0].error // \"\"" "$META_FILE")
  if ! grep -qF "Failed to authenticate" <<<"$err_val"; then
    echo "FAIL [$META_FILE:$peer]: expected 'Failed to authenticate' in $peer.attempts[0].error, got '$err_val'" >&2
    exit 1
  fi
done
echo "PASS: consensus_round stdout error metadata verified."
echo "All wrapper error detail tests passed!"
