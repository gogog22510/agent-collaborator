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

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
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

# Helper function to build deduplicated model ladder
build_model_ladder() {
  local specified="$1"
  local env_ladder="$2"
  local defaults="$3"
  local raw=""
  if [ -n "$env_ladder" ]; then
    raw="$env_ladder"
  elif [ -n "$specified" ]; then
    raw="$specified,$defaults"
  else
    raw="$defaults"
  fi
  python3 -c '
import sys
rungs = [r.strip() for r in sys.argv[1].split(",") if r.strip()]
seen = set()
deduped = []
for r in rungs:
    if r not in seen:
        seen.add(r)
        deduped.append(r)
print(",".join(deduped))
' "$raw"
}

LADDER_CLAUDE=$(build_model_ladder "${MODEL_CLAUDE_OPT:-${CLAUDE_MODEL:-}}" "${CLAUDE_MODEL_LADDER:-}" "sonnet,haiku")
LADDER_CODEX=$(build_model_ladder "${MODEL_CODEX_OPT:-${CODEX_MODEL:-}}" "${CODEX_MODEL_LADDER:-}" "o3-mini,gpt-4o,default")

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

# Load human guidance if provided for this round or deliberation
HUMAN_GUIDANCE_CONTENT=""
if [ -f "$ROUND_DIR/guidance.md" ]; then
  HUMAN_GUIDANCE_CONTENT="$(cat "$ROUND_DIR/guidance.md")"
elif [ -f "$DELIBERATION_DIR/guidance.md" ]; then
  HUMAN_GUIDANCE_CONTENT="$(cat "$DELIBERATION_DIR/guidance.md")"
fi

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

# Function to render prompt from template
render_prompt() {
  local agent_name="$1"
  local model_name="$2"
  local prev_ballot="$3"
  local guidance="$4"
  local out_file="$5"

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
guidance = sys.argv[13]

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

if guidance and guidance.strip() != "":
    content = re.sub(r"\{\{#IF_GUIDANCE\}\}([\s\S]*?)\{\{/IF_GUIDANCE\}\}", r"\1", content)
    content = content.replace("{{HUMAN_GUIDANCE}}", guidance)
else:
    content = re.sub(r"\{\{#IF_GUIDANCE\}\}[\s\S]*?\{\{/IF_GUIDANCE\}\}", "", content)

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
  "$TOPIC" "$OPTION_0_BASELINE" "$PROPOSED_OPTIONS" "$CONTEXT_FILES_STR" "$ROUND_DIGEST_CONTENT" "$prev_ballot" "$guidance"
}

META_CLAUDE_FILE=$(mktemp)
META_CODEX_FILE=$(mktemp)

cleanup_temps() {
  rm -f "$META_CLAUDE_FILE" "$META_CODEX_FILE"
}
trap cleanup_temps EXIT

# Concurrently dispatch Claude and Codex with fallback ladder in isolated session directories
echo "Starting concurrent round $ROUND_NUM evaluations for deliberation $DELIBERATION_ID..."

(
  cd "$SESSION_CLAUDE"
  IFS=',' read -ra rungs <<< "$LADDER_CLAUDE"
  attempts="[]"
  for m in "${rungs[@]}"; do
    prompt_file=$(mktemp)
    render_prompt "claude" "$m" "$PRIOR_CLAUDE_BALLOT_CONTENT" "$HUMAN_GUIDANCE_CONTENT" "$prompt_file"
    m_args=()
    if [ "$m" != "default" ]; then
      m_args=(--model "$m")
    fi
    out_file=$(mktemp)
    err_file=$(mktemp)
    rc=0
    cat "$prompt_file" | claude ${m_args[@]+"${m_args[@]}"} -p --tools "" > "$out_file" 2> "$err_file" || rc=$?
    rm -f "$prompt_file"

    if [ "$rc" -eq 126 ]; then
      echo "❌ [SANDBOX_BLOCKED: BypassSandbox=true REQUIRED]" >&2
      cat "$err_file" >&2
      rm -f "$out_file" "$err_file"
      exit 126
    fi

    extracted=false
    if [ "$rc" -eq 0 ] || [ -s "$out_file" ]; then
      if extract_json_ballot "$out_file" "$ROUND_DIR/claude_ballot.json"; then
        extracted=true
      fi
    fi

    if [ "$extracted" = true ]; then
      cat "$out_file" > "$ROUND_DIR/claude_ballot.md"
      attempts=$(python3 -c '
import sys, json
att = json.loads(sys.argv[1])
att.append({"model": sys.argv[2], "exit_code": int(sys.argv[3]), "status": "SUCCESS"})
print(json.dumps(att))
' "$attempts" "$m" "$rc")
      python3 -c '
import sys, json
meta = {"model_used": sys.argv[1], "attempts": json.loads(sys.argv[2])}
with open(sys.argv[3], "w") as f:
    json.dump(meta, f, indent=2)
' "$m" "$attempts" "$META_CLAUDE_FILE"
      rm -f "$out_file" "$err_file"
      exit 0
    else
      err_msg=$(head -n 5 "$err_file" | tr '\n' ' ' | head -c 200)
      attempts=$(python3 -c '
import sys, json
att = json.loads(sys.argv[1])
att.append({"model": sys.argv[2], "exit_code": int(sys.argv[3]), "status": "FAILED", "error": sys.argv[4]})
print(json.dumps(att))
' "$attempts" "$m" "$rc" "$err_msg")
    fi
    rm -f "$out_file" "$err_file"
  done

  python3 -c '
import sys, json
meta = {"model_used": None, "attempts": json.loads(sys.argv[1])}
with open(sys.argv[2], "w") as f:
    json.dump(meta, f, indent=2)
' "$attempts" "$META_CLAUDE_FILE"
  exit 1
) &
PID_CLAUDE=$!

(
  cd "$SESSION_CODEX"
  IFS=',' read -ra rungs <<< "$LADDER_CODEX"
  attempts="[]"
  for m in "${rungs[@]}"; do
    prompt_file=$(mktemp)
    render_prompt "codex" "$m" "$PRIOR_CODEX_BALLOT_CONTENT" "$HUMAN_GUIDANCE_CONTENT" "$prompt_file"
    m_args=()
    if [ "$m" != "default" ]; then
      m_args=(--model "$m")
    fi
    out_file=$(mktemp)
    err_file=$(mktemp)
    rc=0
    cat "$prompt_file" | codex exec --sandbox read-only ${m_args[@]+"${m_args[@]}"} --skip-git-repo-check - > "$out_file" 2> "$err_file" || rc=$?
    rm -f "$prompt_file"

    if [ "$rc" -eq 126 ]; then
      echo "❌ [SANDBOX_BLOCKED: BypassSandbox=true REQUIRED]" >&2
      cat "$err_file" >&2
      rm -f "$out_file" "$err_file"
      exit 126
    fi

    extracted=false
    if [ "$rc" -eq 0 ] || [ -s "$out_file" ]; then
      if extract_json_ballot "$out_file" "$ROUND_DIR/codex_ballot.json"; then
        extracted=true
      fi
    fi

    if [ "$extracted" = true ]; then
      cat "$out_file" > "$ROUND_DIR/codex_ballot.md"
      attempts=$(python3 -c '
import sys, json
att = json.loads(sys.argv[1])
att.append({"model": sys.argv[2], "exit_code": int(sys.argv[3]), "status": "SUCCESS"})
print(json.dumps(att))
' "$attempts" "$m" "$rc")
      python3 -c '
import sys, json
meta = {"model_used": sys.argv[1], "attempts": json.loads(sys.argv[2])}
with open(sys.argv[3], "w") as f:
    json.dump(meta, f, indent=2)
' "$m" "$attempts" "$META_CODEX_FILE"
      rm -f "$out_file" "$err_file"
      exit 0
    else
      err_msg=$(head -n 5 "$err_file" | tr '\n' ' ' | head -c 200)
      attempts=$(python3 -c '
import sys, json
att = json.loads(sys.argv[1])
att.append({"model": sys.argv[2], "exit_code": int(sys.argv[3]), "status": "FAILED", "error": sys.argv[4]})
print(json.dumps(att))
' "$attempts" "$m" "$rc" "$err_msg")
    fi
    rm -f "$out_file" "$err_file"
  done

  python3 -c '
import sys, json
meta = {"model_used": None, "attempts": json.loads(sys.argv[1])}
with open(sys.argv[2], "w") as f:
    json.dump(meta, f, indent=2)
' "$attempts" "$META_CODEX_FILE"
  exit 1
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

# Assemble meta.json
python3 -c '
import sys, json, os

delib_id = sys.argv[1]
round_num = int(sys.argv[2])
c_file = sys.argv[3]
x_file = sys.argv[4]
out_file = sys.argv[5]

claude_meta = {"model_used": None, "attempts": []}
if os.path.exists(c_file) and os.path.getsize(c_file) > 0:
    try:
        claude_meta = json.load(open(c_file))
    except Exception:
        pass

codex_meta = {"model_used": None, "attempts": []}
if os.path.exists(x_file) and os.path.getsize(x_file) > 0:
    try:
        codex_meta = json.load(open(x_file))
    except Exception:
        pass

meta = {
    "deliberation_id": delib_id,
    "round": round_num,
    "claude": claude_meta,
    "codex": codex_meta
}
with open(out_file, "w") as f:
    json.dump(meta, f, indent=2)
' "$DELIBERATION_ID" "$ROUND_NUM" "$META_CLAUDE_FILE" "$META_CODEX_FILE" "$ROUND_DIR/meta.json"

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
bash "$TALLY_SH" "$ROUND_DIR/claude_ballot.json" "$ROUND_DIR/codex_ballot.json" "$ROUND_DIR/tally.json" "$ROUND_NUM" "$MAX_ROUNDS" "$MANIFEST"

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
manifest_file = sys.argv[5] if len(sys.argv) > 5 else None

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

synthesized_options = []
if manifest_file:
    try:
        with open(manifest_file, "r", encoding="utf-8") as mf:
            manifest_data = json.load(mf)
        options = manifest_data.get("options", [])
        existing_ids = set()
        existing_titles = set()
        for o in options:
            if isinstance(o, dict):
                if "id" in o:
                    existing_ids.add(o["id"])
                if "title" in o and o["title"]:
                    existing_titles.add(o["title"].strip().lower())
            elif isinstance(o, str):
                existing_ids.add(o)

        letters = ["A", "B", "C", "D", "E", "F"]
        peers = [("claude", claude_ballot), ("codex", codex_ballot)]
        manifest_updated = False
        for peer_name, ballot in peers:
            cp = ballot.get("counter_proposal")
            if isinstance(cp, dict):
                title = cp.get("title", "").strip()
                desc = cp.get("description", "").strip()
                if (title or desc) and (not title or title.lower() not in existing_titles) and len(options) < 6:
                    next_letter = None
                    for l in letters:
                        cand_id = f"Option_{l}"
                        if cand_id not in existing_ids:
                            next_letter = l
                            break
                    if next_letter:
                        new_opt_id = f"Option_{next_letter}"
                        new_opt = {
                            "id": new_opt_id,
                            "title": title or f"Option {next_letter}",
                            "description": desc or title,
                            "proposed_by": peer_name,
                            "resolves_objections": cp.get("resolves_objections", [])
                        }
                        options.append(new_opt)
                        existing_ids.add(new_opt_id)
                        if title:
                            existing_titles.add(title.lower())
                        synthesized_options.append(new_opt)
                        manifest_updated = True

        if manifest_updated:
            manifest_data["options"] = options
            with open(manifest_file, "w", encoding="utf-8") as mf:
                json.dump(manifest_data, mf, indent=2)
    except Exception as e:
        sys.stderr.write(f"Warning: Failed to synthesize options into manifest: {e}\n")

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

if synthesized_options:
    lines.append("## 💡 Synthesized Candidate Options for Next Round")
    lines.append("The following candidate options were synthesized from peer counter-proposals and registered in manifest.json:")
    for opt in synthesized_options:
        opt_id = opt.get("id")
        opt_title = opt.get("title", "")
        opt_by = opt.get("proposed_by", "agent")
        opt_desc = opt.get("description", "")
        res_objs = ", ".join(f"`{x}`" for x in opt.get("resolves_objections", [])) or "None specified"
        lines.append(f"- **`{opt_id}`** — **Title**: {opt_title} (Proposed by `{opt_by}`)")
        lines.append(f"  - **Description**: {opt_desc}")
        lines.append(f"  - **Resolves Objections**: {res_objs}")
    lines.append("")
    lines.append("- In Round N+1, peers SHOULD evaluate these candidate options in addition to baseline Option 0.")
    lines.append("")

with open(digest_out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
' "$ROUND_DIR/tally.json" "$ROUND_DIR/claude_ballot.json" "$ROUND_DIR/codex_ballot.json" "$ROUND_DIR/digest.md" "$MANIFEST"
fi

echo "Round $ROUND_NUM completed successfully. Tally status: $TALLY_STATUS."
exit 0
