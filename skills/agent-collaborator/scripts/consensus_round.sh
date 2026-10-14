#!/usr/bin/env bash
# Universal Multi-Agent Consensus Round Driver
# Concurrently evaluates architectural proposals using Claude and Codex in isolated sessions,
# parses structured JSON ballots, executes deterministic consensus tallying,
# and generates anonymized round digests.
#
# Usage: ./consensus_round.sh [OPTIONS] <DELIBERATION_DIR> <ROUND_NUM>
# Options:
#   --max-rounds, -r <N>      Maximum rounds allowed (default: from manifest or 3)
#   --model-claude <M>        Model for Claude CLI (default: $CLAUDE_MODEL or sonnet)
#   --model-codex <M>         Model for Codex CLI (default: $CODEX_MODEL or o3-mini)
#   -h, --help                Show this help message

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || pwd)"

MAX_ROUNDS_OPT=""
MODEL_CLAUDE_OPT=""
MODEL_CODEX_OPT=""
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-rounds|-r)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        MAX_ROUNDS_OPT="$2"
        shift 2
      else
        echo "Error: --max-rounds requires an integer argument." >&2
        exit 1
      fi
      ;;
    --max-rounds=*)
      MAX_ROUNDS_OPT="${1#*=}"
      shift
      ;;
    --model-claude)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        MODEL_CLAUDE_OPT="$2"
        shift 2
      else
        echo "Error: --model-claude requires a model argument." >&2
        exit 1
      fi
      ;;
    --model-claude=*)
      MODEL_CLAUDE_OPT="${1#*=}"
      shift
      ;;
    --model-codex)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        MODEL_CODEX_OPT="$2"
        shift 2
      else
        echo "Error: --model-codex requires a model argument." >&2
        exit 1
      fi
      ;;
    --model-codex=*)
      MODEL_CODEX_OPT="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] <DELIBERATION_DIR> <ROUND_NUM>"
      echo "Options:"
      echo "  -r, --max-rounds <N>    Maximum rounds allowed (default: 3)"
      echo "  --model-claude <M>      Model name for Claude CLI"
      echo "  --model-codex <M>       Model name for Codex CLI"
      exit 0
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]+"${POSITIONAL_ARGS[@]}"}"

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 [OPTIONS] <DELIBERATION_DIR> <ROUND_NUM>" >&2
  exit 1
fi

DELIBERATION_DIR="$1"
ROUND_NUM="$2"

# Resolve deliberation directory if relative or given as ID
if [ ! -d "$DELIBERATION_DIR" ]; then
  if [ -d ".agent/deliberations/$DELIBERATION_DIR" ]; then
    DELIBERATION_DIR=".agent/deliberations/$DELIBERATION_DIR"
  elif [ -d "$REPO_ROOT/.agent/deliberations/$DELIBERATION_DIR" ]; then
    DELIBERATION_DIR="$REPO_ROOT/.agent/deliberations/$DELIBERATION_DIR"
  else
    echo "Error: Deliberation directory '$DELIBERATION_DIR' does not exist." >&2
    exit 1
  fi
fi

# Convert to absolute path
DELIBERATION_DIR="$(cd "$DELIBERATION_DIR" && pwd)"

MANIFEST="$DELIBERATION_DIR/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  echo "Error: manifest.json not found in $DELIBERATION_DIR" >&2
  exit 1
fi

# Validate Round Number
if ! [[ "$ROUND_NUM" =~ ^[0-9]+$ ]] || [ "$ROUND_NUM" -lt 1 ]; then
  echo "Error: ROUND_NUM must be a positive integer, got '$ROUND_NUM'" >&2
  exit 1
fi

# Read metadata from manifest
DELIBERATION_ID=$(jq -r '.deliberation_id // empty' "$MANIFEST")
if [ -z "$DELIBERATION_ID" ]; then
  DELIBERATION_ID="$(basename "$DELIBERATION_DIR")"
fi

TOPIC=$(jq -r '.topic // .requirement // "No topic specified"' "$MANIFEST")

MAX_ROUNDS="$MAX_ROUNDS_OPT"
if [ -z "$MAX_ROUNDS" ]; then
  MAX_ROUNDS=$(jq -r '.max_rounds // empty' "$MANIFEST")
fi
if [ -z "$MAX_ROUNDS" ] || ! [[ "$MAX_ROUNDS" =~ ^[0-9]+$ ]]; then
  MAX_ROUNDS=3
fi

# Read Option 0 MVA Baseline
OPTION_0_BASELINE=""
if [ -f "$DELIBERATION_DIR/option_0_baseline.md" ]; then
  OPTION_0_BASELINE="$(cat "$DELIBERATION_DIR/option_0_baseline.md")"
else
  OPTION_0_BASELINE=$(jq -r '.option_0_baseline // empty' "$MANIFEST")
fi
if [ -z "$OPTION_0_BASELINE" ]; then
  OPTION_0_BASELINE="Option 0: Minimal Viable Architecture (direct POSIX / standard library implementation with zero external daemon dependencies)."
fi

# Read proposed options
PROPOSED_OPTIONS=$(jq -r '
  if .proposed_options then
    (if (.proposed_options | type) == "string" then .proposed_options else (.proposed_options | tostring) end)
  elif .options then
    (if (.options | type) == "string" then .options
     elif (.options | type) == "array" then
       (.options | map("- **" + (.id // .name // "Option") + "**: " + (.description // .desc // (. | tostring))) | join("\n"))
     elif (.options | type) == "object" then
       (.options | to_entries | map("- **" + .key + "**: " + (.value | tostring)) | join("\n"))
     else (.options | tostring)
     end)
  else
    "No alternative options declared."
  end' "$MANIFEST")

# Read context files
CONTEXT_FILES_STR=""
CONTEXT_FILES_LIST=$(jq -r '.context_files // [] | .[]' "$MANIFEST" 2>/dev/null || true)
if [ -n "$CONTEXT_FILES_LIST" ]; then
  while IFS= read -r f; do
    if [ -n "$f" ]; then
      TARGET_F="$f"
      if [ ! -f "$TARGET_F" ] && [ -f "$DELIBERATION_DIR/$f" ]; then
        TARGET_F="$DELIBERATION_DIR/$f"
      fi
      if [ -f "$TARGET_F" ]; then
        CONTEXT_FILES_STR+=$'\n\n'"--- File: $f ---"$'\n'
        CONTEXT_FILES_STR+="$(cat "$TARGET_F")"
      fi
    fi
  done <<< "$CONTEXT_FILES_LIST"
fi
if [ -z "$CONTEXT_FILES_STR" ]; then
  CONTEXT_FILES_STR="(No reference context files provided)"
fi

# Locate template
TEMPLATE_FILE=""
if [ -f "$REPO_ROOT/templates/deliberation_prompt.md" ]; then
  TEMPLATE_FILE="$REPO_ROOT/templates/deliberation_prompt.md"
elif [ -f "$SCRIPT_DIR/../../../templates/deliberation_prompt.md" ]; then
  TEMPLATE_FILE="$SCRIPT_DIR/../../../templates/deliberation_prompt.md"
elif [ -f "${HOME}/.gemini/config/skills/agent-collaborator/templates/deliberation_prompt.md" ]; then
  TEMPLATE_FILE="${HOME}/.gemini/config/skills/agent-collaborator/templates/deliberation_prompt.md"
fi

# Locate consensus_tally.sh
TALLY_SH="$SCRIPT_DIR/consensus_tally.sh"
if [ ! -f "$TALLY_SH" ]; then
  echo "Error: consensus_tally.sh not found in $SCRIPT_DIR" >&2
  exit 1
fi

# Setup directories for Round outputs and Isolated Sessions
ROUND_DIR="$DELIBERATION_DIR/round-$ROUND_NUM"
mkdir -p "$ROUND_DIR"

SESSION_CLAUDE="$DELIBERATION_DIR/.sessions/claude"
SESSION_CODEX="$DELIBERATION_DIR/.sessions/codex"
mkdir -p "$SESSION_CLAUDE" "$SESSION_CODEX"

# Model selection
MODEL_CLAUDE="${MODEL_CLAUDE_OPT:-${CLAUDE_MODEL:-${AGENT_MODEL:-sonnet}}}"
MODEL_CODEX="${MODEL_CODEX_OPT:-${CODEX_MODEL:-${AGENT_MODEL:-o3-mini}}}"

# Load prior round outputs if Round > 1
ROUND_DIGEST_CONTENT=""
PRIOR_CLAUDE_BALLOT_CONTENT="{}"
PRIOR_CODEX_BALLOT_CONTENT="{}"

if [ "$ROUND_NUM" -gt 1 ]; then
  PREV_ROUND=$((ROUND_NUM - 1))
  PREV_DIR="$DELIBERATION_DIR/round-$PREV_ROUND"
  if [ -f "$PREV_DIR/digest.md" ]; then
    ROUND_DIGEST_CONTENT="$(cat "$PREV_DIR/digest.md")"
  fi
  if [ -f "$PREV_DIR/claude_ballot.json" ]; then
    PRIOR_CLAUDE_BALLOT_CONTENT="$(cat "$PREV_DIR/claude_ballot.json")"
  fi
  if [ -f "$PREV_DIR/codex_ballot.json" ]; then
    PRIOR_CODEX_BALLOT_CONTENT="$(cat "$PREV_DIR/codex_ballot.json")"
  fi
fi

# Function to render prompt from template
render_prompt() {
  local agent_name="$1"
  local model_name="$2"
  local prev_ballot="$3"
  local out_file="$4"

  python3 -c '
import sys, json, re

template_path = sys.argv[1]
out_path = sys.argv[2]
agent_name = sys.argv[3]
model_name = sys.argv[4]
delib_id = sys.argv[5]
round_num = int(sys.argv[6])
req = sys.argv[7]
opt0 = sys.argv[8]
prop_opts = sys.argv[9]
ctx_files = sys.argv[10]
digest = sys.argv[11]
prev_ballot = sys.argv[12]

if template_path and template_path != "":
    with open(template_path, "r", encoding="utf-8") as f:
        content = f.read()
else:
    content = """# Deliberation Prompt
Deliberation ID: {{DELIBERATION_ID}}
Round: {{ROUND}}
Agent: {{AGENT_NAME}}
Model: {{MODEL}}

Topic:
{{REQUIREMENT}}

Option 0:
{{OPTION_0_BASELINE}}

Proposed Options:
{{PROPOSED_OPTIONS}}

Context Files:
{{CONTEXT_FILES}}

{{#IF_ROUND_GREATER_THAN_1}}
Prior Digest:
{{ROUND_DIGEST}}

Your Previous Ballot:
{{PREVIOUS_BALLOT}}
{{/IF_ROUND_GREATER_THAN_1}}
"""

if round_num > 1:
    content = re.sub(r"\{\{#IF_ROUND_GREATER_THAN_1\}\}([\s\S]*?)\{\{/IF_ROUND_GREATER_THAN_1\}\}", r"\1", content)
else:
    content = re.sub(r"\{\{#IF_ROUND_GREATER_THAN_1\}\}[\s\S]*?\{\{/IF_ROUND_GREATER_THAN_1\}\}", "", content)

subs = {
    "DELIBERATION_ID": delib_id,
    "ROUND": str(round_num),
    "AGENT_NAME": agent_name,
    "MODEL": model_name,
    "REQUIREMENT": req,
    "OPTION_0_BASELINE": opt0,
    "PROPOSED_OPTIONS": prop_opts,
    "CONTEXT_FILES": ctx_files,
    "ROUND_DIGEST": digest,
    "PREVIOUS_BALLOT": prev_ballot
}

for k, v in subs.items():
    content = content.replace("{{" + k + "}}", v)

with open(out_path, "w", encoding="utf-8") as f:
    f.write(content)
' "$TEMPLATE_FILE" "$out_file" "$agent_name" "$model_name" "$DELIBERATION_ID" "$ROUND_NUM" \
  "$TOPIC" "$OPTION_0_BASELINE" "$PROPOSED_OPTIONS" "$CONTEXT_FILES_STR" "$ROUND_DIGEST_CONTENT" "$prev_ballot"
}

PROMPT_CLAUDE_FILE=$(mktemp)
PROMPT_CODEX_FILE=$(mktemp)
render_prompt "claude" "$MODEL_CLAUDE" "$PRIOR_CLAUDE_BALLOT_CONTENT" "$PROMPT_CLAUDE_FILE"
render_prompt "codex" "$MODEL_CODEX" "$PRIOR_CODEX_BALLOT_CONTENT" "$PROMPT_CODEX_FILE"

# Prepare execution commands and arguments
CLAUDE_ARGS=()
if [ -n "$MODEL_CLAUDE" ]; then
  CLAUDE_ARGS=(--model "$MODEL_CLAUDE")
fi

CODEX_ARGS=()
if [ -n "$MODEL_CODEX" ]; then
  CODEX_ARGS=(--model "$MODEL_CODEX")
fi

TEMP_CLAUDE_OUT=$(mktemp)
TEMP_CLAUDE_ERR=$(mktemp)
TEMP_CODEX_OUT=$(mktemp)
TEMP_CODEX_ERR=$(mktemp)

cleanup_temps() {
  rm -f "$PROMPT_CLAUDE_FILE" "$PROMPT_CODEX_FILE" "$TEMP_CLAUDE_OUT" "$TEMP_CLAUDE_ERR" "$TEMP_CODEX_OUT" "$TEMP_CODEX_ERR"
}
trap cleanup_temps EXIT

# Concurrently dispatch Claude and Codex in isolated session directories
echo "Starting concurrent round $ROUND_NUM evaluations for deliberation $DELIBERATION_ID..."

(
  cd "$SESSION_CLAUDE"
  cat "$PROMPT_CLAUDE_FILE" | claude ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"} -p --tools "" > "$TEMP_CLAUDE_OUT" 2> "$TEMP_CLAUDE_ERR"
) &
PID_CLAUDE=$!

(
  cd "$SESSION_CODEX"
  cat "$PROMPT_CODEX_FILE" | codex exec --sandbox read-only ${CODEX_ARGS[@]+"${CODEX_ARGS[@]}"} --skip-git-repo-check - > "$TEMP_CODEX_OUT" 2> "$TEMP_CODEX_ERR"
) &
PID_CODEX=$!

EXIT_CLAUDE=0
wait "$PID_CLAUDE" || EXIT_CLAUDE=$?

EXIT_CODEX=0
wait "$PID_CODEX" || EXIT_CODEX=$?

# Check for sandbox blocking (Exit 126)
if [ "$EXIT_CLAUDE" -eq 126 ] || [ "$EXIT_CODEX" -eq 126 ]; then
  echo "❌ [SANDBOX_BLOCKED: BypassSandbox=true REQUIRED]" >&2
  echo "Reason: Sandbox execution blocked or permission denied (Exit: 126)." >&2
  exit 126
fi

# Save full markdown output
cat "$TEMP_CLAUDE_OUT" > "$ROUND_DIR/claude_ballot.md"
cat "$TEMP_CODEX_OUT" > "$ROUND_DIR/codex_ballot.md"

# Function to extract fenced JSON ballot
extract_json_ballot() {
  local input_file="$1"
  local output_file="$2"

  rm -f "$output_file"

  # 1. Direct JSON check
  if [ -s "$input_file" ] && jq -e . "$input_file" >/dev/null 2>&1; then
    cp "$input_file" "$output_file"
    return 0
  fi

  # 2. Extract ```json code blocks or embedded JSON objects
  python3 -c '
import sys, re, json

content = open(sys.argv[1], "r", encoding="utf-8", errors="replace").read()

matches = re.findall(r"```(?:json)?\s*([\s\S]*?)```", content)
found = False
for block in matches:
    block_str = block.strip()
    try:
        data = json.loads(block_str)
        if isinstance(data, dict) and ("preferred_option" in data or "deliberation_id" in data or "metrics" in data):
            with open(sys.argv[2], "w", encoding="utf-8") as out:
                json.dump(data, out, indent=2)
            found = True
            break
    except Exception:
        continue

if not found:
    start = content.find("{")
    while start != -1:
        depth = 0
        end = -1
        for i in range(start, len(content)):
            if content[i] == "{":
                depth += 1
            elif content[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        if end != -1:
            snippet = content[start:end]
            try:
                data = json.loads(snippet)
                if isinstance(data, dict) and ("preferred_option" in data or "deliberation_id" in data):
                    with open(sys.argv[2], "w", encoding="utf-8") as out:
                        json.dump(data, out, indent=2)
                    found = True
                    break
            except Exception:
                pass
            start = content.find("{", start + 1)
        else:
            break

if not found:
    sys.exit(1)
' "$input_file" "$output_file" 2>/dev/null && return 0

  # 3. Fallback to awk
  awk '/^```json/{flag=1; next} /^```/{if(flag){flag=0; exit}} flag' "$input_file" > "$output_file" 2>/dev/null || true
  if [ -s "$output_file" ] && jq -e . "$output_file" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

extract_json_ballot "$TEMP_CLAUDE_OUT" "$ROUND_DIR/claude_ballot.json" || true
extract_json_ballot "$TEMP_CODEX_OUT" "$ROUND_DIR/codex_ballot.json" || true

CLAUDE_BALLOT_EXISTS=false
CODEX_BALLOT_EXISTS=false

if [ -s "$ROUND_DIR/claude_ballot.json" ] && jq -e . "$ROUND_DIR/claude_ballot.json" >/dev/null 2>&1; then
  CLAUDE_BALLOT_EXISTS=true
fi
if [ -s "$ROUND_DIR/codex_ballot.json" ] && jq -e . "$ROUND_DIR/codex_ballot.json" >/dev/null 2>&1; then
  CODEX_BALLOT_EXISTS=true
fi

# Check for total peer outage
if [ "$CLAUDE_BALLOT_EXISTS" = false ] && [ "$CODEX_BALLOT_EXISTS" = false ]; then
  echo "⚠️ [FALLBACK_TRIGGERED: PEERS_UNAVAILABLE]" >&2
  echo "Reason: Both Claude and Codex peer agents failed or were unavailable (Exit Claude: $EXIT_CLAUDE, Exit Codex: $EXIT_CODEX)." >&2
  exit 100
fi

# Execute consensus_tally.sh to produce tally.json
bash "$TALLY_SH" "$ROUND_DIR/claude_ballot.json" "$ROUND_DIR/codex_ballot.json" "$ROUND_DIR/tally.json" "$ROUND_NUM" "$MAX_ROUNDS"

# Verify tally.json exists
if [ ! -f "$ROUND_DIR/tally.json" ]; then
  echo "Error: Failed to generate $ROUND_DIR/tally.json" >&2
  exit 1
fi

TALLY_STATUS=$(jq -r '.status // "IN_DEBATE"' "$ROUND_DIR/tally.json")

# If status is NOT "CONVERGED", generate digest.md
if [ "$TALLY_STATUS" != "CONVERGED" ]; then
  python3 -c '
import sys, json

tally_file = sys.argv[1]
claude_ballot_file = sys.argv[2]
codex_ballot_file = sys.argv[3]
digest_out = sys.argv[4]

with open(tally_file, "r", encoding="utf-8") as f:
    tally = json.load(f)

claude_ballot = {}
try:
    with open(claude_ballot_file, "r", encoding="utf-8") as f:
        claude_ballot = json.load(f)
except Exception:
    pass

codex_ballot = {}
try:
    with open(codex_ballot_file, "r", encoding="utf-8") as f:
        codex_ballot = json.load(f)
except Exception:
    pass

round_num = tally.get("round", 1)
max_rounds = tally.get("max_rounds", 3)
status = tally.get("status", "IN_DEBATE")
consensus_opt = tally.get("consensus_option")
yagni_avg = tally.get("yagni_score_avg", 0)

agent_a_opt = claude_ballot.get("preferred_option", "Unknown / Degraded")
agent_a_stance = claude_ballot.get("stance", "UNKNOWN")
agent_b_opt = codex_ballot.get("preferred_option", "Unknown / Degraded")
agent_b_stance = codex_ballot.get("stance", "UNKNOWN")

spreads = tally.get("score_spreads", {})
blocking_objs = tally.get("blocking_objections", [])
over_arch_flags = tally.get("over_architecture_flags", [])

lines = []
lines.append(f"# Deliberation Round {round_num} Disagreement Digest")
lines.append("")
lines.append(f"**Deliberation Status**: `{status}` (Round {round_num} of {max_rounds})")
if consensus_opt:
    lines.append(f"**Consensus Option**: `{consensus_opt}`")
lines.append(f"**Average YAGNI Score**: `{yagni_avg:.2f}` / 5.0 (Threshold: 3.5)")
lines.append("")

lines.append("## 1. Anonymized Agent Positions & Preferred Options")
lines.append(f"- **Agent A**: Preferred Option `{agent_a_opt}` | Stance: `{agent_a_stance}`")
lines.append(f"- **Agent B**: Preferred Option `{agent_b_opt}` | Stance: `{agent_b_stance}`")
lines.append("")

lines.append("## 2. Metric Score Comparison & Spreads")
lines.append("| Metric | Agent A Score | Agent B Score | Spread (|A - B|) | Status |")
lines.append("| :--- | :---: | :---: | :---: | :---: |")

metrics = [
    ("technical_feasibility", "Technical Feasibility"),
    ("architectural_simplicity", "Architectural Simplicity"),
    ("yagni_and_parsimony", "YAGNI & Parsimony"),
    ("robustness_failure_modes", "Robustness & Failure Modes"),
    ("maintainability_testability", "Maintainability & Testability")
]

for key, label in metrics:
    score_a = claude_ballot.get("metrics", {}).get(key, {}).get("score", "-")
    score_b = codex_ballot.get("metrics", {}).get(key, {}).get("score", "-")
    spread = spreads.get(key, "-")
    spread_status = "OK (<=1)" if isinstance(spread, (int, float)) and spread <= 1 else "**DISPUTE (>1)**"
    lines.append(f"| {label} | {score_a} | {score_b} | {spread} | {spread_status} |")
lines.append("")

lines.append("## 3. Active Blocking Objections")
if blocking_objs:
    for obj in blocking_objs:
        obj_id = obj.get("id", "OBJ")
        obj_type = obj.get("type", "general")
        target = obj.get("metric_target", "general")
        claim = obj.get("claim", "No claim provided")
        res = obj.get("resolution_condition", "None provided")
        lines.append(f"### `{obj_id}` [{obj_type.upper()}] — Target: `{target}`")
        lines.append(f"- **Claim**: {claim}")
        lines.append(f"- **Resolution Condition**: {res}")
        lines.append("")
else:
    lines.append("No active blocking objections raised.")
    lines.append("")

lines.append("## 4. Over-Architecture (YAGNI) Flags")
if over_arch_flags:
    for flag in over_arch_flags:
        pat = flag.get("pattern", "OVER_ARCHITECTURE")
        critique = flag.get("critique", "No critique provided")
        remedy = flag.get("simplification_remedy", "No remedy provided")
        lines.append(f"### Pattern: `{pat}`")
        lines.append(f"- **Critique**: {critique}")
        lines.append(f"- **Simplification Remedy**: {remedy}")
        lines.append("")
else:
    lines.append("No over-architecture antipatterns flagged.")
    lines.append("")

lines.append("## 5. Round Resolution Directives for Next Round")
factual_objs = [o for o in blocking_objs if o.get("type") == "factual"]
tradeoff_objs = [o for o in blocking_objs if o.get("type") == "tradeoff"]
ambiguity_objs = [o for o in blocking_objs if o.get("type") == "ambiguity"]

if factual_objs:
    lines.append("### Factual Disputes (Target for Empirical Spike / Verification)")
    for o in factual_objs:
        oid = o.get("id", "OBJ")
        oclaim = o.get("claim", "")
        lines.append(f"- **`{oid}`**: {oclaim} -> Resolve via empirical code spike or benchmark test.")
    lines.append("")

if tradeoff_objs:
    lines.append("### Tradeoff Disputes (Architectural & Operational Priorities)")
    for o in tradeoff_objs:
        oid = o.get("id", "OBJ")
        oclaim = o.get("claim", "")
        lines.append(f"- **`{oid}`**: {oclaim} -> Evaluating agents must weigh operational simplicity against proposed benefits.")
    lines.append("")

if ambiguity_objs:
    lines.append("### Specification Ambiguities")
    for o in ambiguity_objs:
        oid = o.get("id", "OBJ")
        oclaim = o.get("claim", "")
        lines.append(f"- **`{oid}`**: {oclaim} -> Clarification required from Moderator in manifest.")
    lines.append("")

if agent_a_opt != agent_b_opt:
    lines.append("### Option Divergence")
    lines.append(f"- Agent A prefers `{agent_a_opt}`, while Agent B prefers `{agent_b_opt}`.")
    lines.append("- In Round N+1, proponents of non-baseline options MUST prove what critical production failure occurs if the baseline Option 0 is selected.")
    lines.append("- If changing positions, agents must explicitly cite the objection ID that influenced their revision.")
    lines.append("")

with open(digest_out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
' "$ROUND_DIR/tally.json" "$ROUND_DIR/claude_ballot.json" "$ROUND_DIR/codex_ballot.json" "$ROUND_DIR/digest.md"
fi

echo "Round $ROUND_NUM completed successfully. Tally status: $TALLY_STATUS."
exit 0
