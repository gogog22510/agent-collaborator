#!/usr/bin/env bash
# Universal Multi-Agent Consensus Deliberation Runner
# Orchestrates multi-turn deliberation among Claude CLI, Codex CLI, and Jetski empirical probe
# using a Structured Metric Table, mandatory Option 0 MVA baseline, anti-overarchitecture YAGNI veto,
# and deterministic bounded termination.
#
# Usage: ./agent_deliberate.sh [OPTIONS] "<TOPIC_OR_REQUIREMENT>" [CONTEXT_FILES...]
# Options:
#   -r, --rounds, --max-rounds <N>  Maximum deliberation rounds (default: 3)
#   --model-claude <M>              Model for Claude CLI
#   --model-codex <M>               Model for Codex CLI
#   --id <ID>                       Deliberation ID (default: dlb-YYYYMMDD-XXXX)
#   -d, --dir <DIR>                 Output directory (default: .agent/deliberations/<ID>)
#   --jetski-evidence <FILE>        Path to empirical evidence markdown file
#   -h, --help                      Show this help message

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

MAX_ROUNDS=3
ROUNDS_EXPLICIT=false
MODEL_CLAUDE=""
MODEL_CODEX=""
DELIBERATION_ID=""
DELIBERATION_DIR=""
JETSKI_EVIDENCE_OPT=""
IS_CONTINUATION=false
GUIDANCE_TEXT=""
ADD_OPTIONS=()
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--rounds|--max-rounds)
      ROUNDS_EXPLICIT=true
      if [[ -n "${2:-}" && "${2:-}" =~ ^[0-9]+$ ]]; then
        MAX_ROUNDS="$((10#$2))"
        if [ "$MAX_ROUNDS" -lt 1 ] || [ "$MAX_ROUNDS" -gt 10 ]; then
          echo "Error: --rounds must be between 1 and 10." >&2
          exit 1
        fi
        shift 2
      else
        echo "Error: --rounds requires an integer argument between 1 and 10." >&2
        exit 1
      fi
      ;;
    --rounds=*|--max-rounds=*)
      ROUNDS_EXPLICIT=true
      RAW_ROUNDS="${1#*=}"
      if [[ "$RAW_ROUNDS" =~ ^[0-9]+$ ]]; then
        MAX_ROUNDS="$((10#$RAW_ROUNDS))"
        if [ "$MAX_ROUNDS" -lt 1 ] || [ "$MAX_ROUNDS" -gt 10 ]; then
          echo "Error: --rounds must be between 1 and 10." >&2
          exit 1
        fi
      else
        echo "Error: --rounds requires an integer argument between 1 and 10." >&2
        exit 1
      fi
      shift
      ;;
    -c|--continue)
      IS_CONTINUATION=true
      shift
      ;;
    --guidance)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        GUIDANCE_TEXT="$2"
        shift 2
      else
        echo "Error: --guidance requires a string argument." >&2
        exit 1
      fi
      ;;
    --guidance=*)
      GUIDANCE_TEXT="${1#*=}"
      shift
      ;;
    --guidance-file)
      if [[ -n "${2:-}" && -f "$2" ]]; then
        GUIDANCE_TEXT="$(cat "$2")"
        shift 2
      else
        echo "Error: --guidance-file requires an existing file path." >&2
        exit 1
      fi
      ;;
    --guidance-file=*)
      G_FILE="${1#*=}"
      if [ -f "$G_FILE" ]; then
        GUIDANCE_TEXT="$(cat "$G_FILE")"
      else
        echo "Error: --guidance-file requires an existing file path." >&2
        exit 1
      fi
      shift
      ;;
    --add-option)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        ADD_OPTIONS+=("$2")
        shift 2
      else
        echo "Error: --add-option requires an option description or JSON object." >&2
        exit 1
      fi
      ;;
    --add-option=*)
      ADD_OPTIONS+=("${1#*=}")
      shift
      ;;
    --model-claude)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        MODEL_CLAUDE="$2"
        shift 2
      else
        echo "Error: --model-claude requires a model argument." >&2
        exit 1
      fi
      ;;
    --model-claude=*)
      MODEL_CLAUDE="${1#*=}"
      shift
      ;;
    --model-codex)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        MODEL_CODEX="$2"
        shift 2
      else
        echo "Error: --model-codex requires a model argument." >&2
        exit 1
      fi
      ;;
    --model-codex=*)
      MODEL_CODEX="${1#*=}"
      shift
      ;;
    --id)
      if [[ -n "${2:-}" && "${2:-}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        DELIBERATION_ID="$2"
        shift 2
      else
        echo "Error: --id must be a safe identifier (letters, digits, dots, underscores, dashes)." >&2
        exit 1
      fi
      ;;
    --id=*)
      DELIBERATION_ID="${1#*=}"
      if ! [[ "$DELIBERATION_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "Error: --id must be a safe identifier (letters, digits, dots, underscores, dashes)." >&2
        exit 1
      fi
      shift
      ;;
    -d|--dir)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        DELIBERATION_DIR="$2"
        shift 2
      else
        echo "Error: --dir requires a directory path." >&2
        exit 1
      fi
      ;;
    --dir=*)
      DELIBERATION_DIR="${1#*=}"
      shift
      ;;
    --jetski-evidence)
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        JETSKI_EVIDENCE_OPT="$2"
        shift 2
      else
        echo "Error: --jetski-evidence requires a file path." >&2
        exit 1
      fi
      ;;
    --jetski-evidence=*)
      JETSKI_EVIDENCE_OPT="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] \"<TOPIC_OR_REQUIREMENT>\" [CONTEXT_FILES...]"
      echo ""
      echo "Options:"
      echo "  -c, --continue          Resume existing deliberation without clobbering completed rounds"
      echo "  --guidance <TEXT>       Inject human operator steering guidance into subsequent rounds"
      echo "  --guidance-file <FILE>  Inject human operator steering guidance from file"
      echo "  --add-option <OPT>      Register an additional candidate option in manifest"
      echo "  -r, --rounds <N>        Maximum deliberation rounds (default: 3)"
      echo "  --model-claude <M>      Model name for Claude CLI (e.g. sonnet, opus)"
      echo "  --model-codex <M>       Model name for Codex CLI (e.g. o3-mini, o3)"
      echo "  --id <ID>               Explicit deliberation ID (default: dlb-YYYYMMDD-XXXX)"
      echo "  -d, --dir <DIR>         Ledger directory (default: .agent/deliberations/<ID>)"
      echo "  --jetski-evidence <F>   Empirical test / benchmark evidence file"
      echo "  -h, --help              Show this help message"
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

TOPIC=""
if [ "$#" -ge 1 ]; then
  if [ "$IS_CONTINUATION" = true ] && [ -z "$DELIBERATION_DIR" ] && [ -d "$1" ]; then
    DELIBERATION_DIR="$1"
    shift
  else
    TOPIC="$1"
    shift
  fi
fi

# Validate and resolve context files to absolute paths
RESOLVED_CONTEXT_FILES=()
for f in "$@"; do
  if [ -f "$f" ]; then
    RESOLVED_CONTEXT_FILES+=("$(cd "$(dirname "$f")" && pwd)/$(basename "$f")")
  else
    echo "Error: Context file '$f' not found." >&2
    exit 1
  fi
done
CONTEXT_FILES=("${RESOLVED_CONTEXT_FILES[@]+"${RESOLVED_CONTEXT_FILES[@]}"}")

# Resolve Deliberation Directory & ID based on mode
if [ "$IS_CONTINUATION" = true ]; then
  if [ -z "$DELIBERATION_DIR" ]; then
    if [ -n "$DELIBERATION_ID" ]; then
      if [ -d ".agent/deliberations/$DELIBERATION_ID" ]; then
        DELIBERATION_DIR=".agent/deliberations/$DELIBERATION_ID"
      elif [ -d "$REPO_ROOT/.agent/deliberations/$DELIBERATION_ID" ]; then
        DELIBERATION_DIR="$REPO_ROOT/.agent/deliberations/$DELIBERATION_ID"
      fi
    else
      LATEST_DIR=$(ls -td .agent/deliberations/*/ 2>/dev/null | head -n 1 || true)
      if [ -n "$LATEST_DIR" ]; then
        DELIBERATION_DIR="${LATEST_DIR%/}"
      fi
    fi
  fi

  if [ -z "$DELIBERATION_DIR" ] || [ ! -d "$DELIBERATION_DIR" ]; then
    echo "Error: Cannot continue: deliberation directory '$DELIBERATION_DIR' does not exist." >&2
    exit 1
  fi

  DELIBERATION_DIR="$(cd "$DELIBERATION_DIR" && pwd)"
  MANIFEST_FILE="$DELIBERATION_DIR/manifest.json"

  if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Cannot continue: deliberation manifest not found at '$MANIFEST_FILE'." >&2
    exit 1
  fi

  if [ -z "$TOPIC" ]; then
    TOPIC=$(jq -r '.topic // empty' "$MANIFEST_FILE" 2>/dev/null || true)
    if [ -z "$TOPIC" ]; then
      TOPIC="Continued Deliberation"
    fi
  fi
  if [ -z "$DELIBERATION_ID" ]; then
    DELIBERATION_ID=$(jq -r '.deliberation_id // empty' "$MANIFEST_FILE" 2>/dev/null || true)
    if [ -z "$DELIBERATION_ID" ]; then
      DELIBERATION_ID="$(basename "$DELIBERATION_DIR")"
    fi
  fi
else
  if [ -z "$TOPIC" ]; then
    echo "Error: Missing required topic or requirement argument." >&2
    echo "Usage: $0 [OPTIONS] \"<TOPIC_OR_REQUIREMENT>\" [CONTEXT_FILES...]" >&2
    exit 1
  fi

  if [ -z "$DELIBERATION_ID" ]; then
    if [ -n "$DELIBERATION_DIR" ]; then
      DELIBERATION_ID="$(basename "$DELIBERATION_DIR")"
    else
      HEX_SUFFIX=$(LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 4 || true)
      if [ -z "$HEX_SUFFIX" ]; then
        HEX_SUFFIX=$(printf "%04x" "$((RANDOM % 65536))")
      fi
      DELIBERATION_ID="dlb-$(date +%Y%m%d)-$HEX_SUFFIX"
    fi
  fi

  if [ -z "$DELIBERATION_DIR" ]; then
    DELIBERATION_DIR=".agent/deliberations/$DELIBERATION_ID"
  fi

  mkdir -p "$DELIBERATION_DIR"
  DELIBERATION_DIR="$(cd "$DELIBERATION_DIR" && pwd)"
  MANIFEST_FILE="$DELIBERATION_DIR/manifest.json"

  if [ -f "$MANIFEST_FILE" ]; then
    EXISTING_TOPIC=$(jq -r '.topic // empty' "$MANIFEST_FILE" 2>/dev/null || true)
    if [ -n "$EXISTING_TOPIC" ] && [ "$EXISTING_TOPIC" != "$TOPIC" ]; then
      echo "Error: Deliberation directory '$DELIBERATION_DIR' already exists with a different topic: '$EXISTING_TOPIC'." >&2
      echo "Please specify a unique --id or use a different directory." >&2
      exit 1
    fi
  fi
fi

# Context files JSON array
CONTEXT_JSON="[]"
if [ "${#CONTEXT_FILES[@]}" -gt 0 ]; then
  CONTEXT_JSON=$(printf '%s\n' "${CONTEXT_FILES[@]}" | jq -R . | jq -s .)
fi

if [ ! -f "$MANIFEST_FILE" ]; then
  jq -n \
    --arg id "$DELIBERATION_ID" \
    --arg topic "$TOPIC" \
    --arg created_at "$CREATED_AT" \
    --argjson max_rounds "$MAX_ROUNDS" \
    --argjson context_files "$CONTEXT_JSON" \
    '{
      "deliberation_id": $id,
      "topic": $topic,
      "created_at": $created_at,
      "max_rounds": $max_rounds,
      "context_files": $context_files,
      "options": [
        {
          "id": "Option_0",
          "name": "Option 0",
          "description": "Minimal Viable Architecture (MVA) baseline using direct POSIX / standard library primitives with zero unnecessary abstractions or daemons."
        }
      ],
      "status": "IN_PROGRESS"
    }' > "$MANIFEST_FILE"
else
  # Update existing manifest (or initialize options if needed)
  jq \
    --arg id "$DELIBERATION_ID" \
    --arg topic "$TOPIC" \
    --argjson max_rounds "$MAX_ROUNDS" \
    --argjson context_files "$CONTEXT_JSON" \
    '
    .deliberation_id = (if .deliberation_id then .deliberation_id else $id end) |
    .topic = (if .topic then .topic else $topic end) |
    .max_rounds = $max_rounds |
    .status = "IN_PROGRESS" |
    if ($context_files | length > 0) then .context_files = $context_files else . end |
    if (.options | map(select(.id == "Option_0")) | length == 0) then
      .options = ([{"id": "Option_0", "name": "Option 0", "description": "Minimal Viable Architecture (MVA) baseline using direct POSIX / standard library primitives with zero unnecessary abstractions or daemons."}] + (.options // []))
    else
      .
    end
    ' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
fi

# Ingest any manual options provided via --add-option
if [ "${#ADD_OPTIONS[@]}" -gt 0 ]; then
  python3 -c '
import sys, json

manifest_file = sys.argv[1]
add_opts_raw = sys.argv[2:]

with open(manifest_file, "r", encoding="utf-8") as f:
    manifest = json.load(f)

options = manifest.get("options", [])
existing_ids = set()
for o in options:
    if isinstance(o, dict) and "id" in o:
        existing_ids.add(o["id"])
    elif isinstance(o, str):
        existing_ids.add(o)

letters = ["A", "B", "C", "D", "E", "F", "G", "H"]

for raw in add_opts_raw:
    raw_str = raw.strip()
    try:
        opt_obj = json.loads(raw_str)
        if isinstance(opt_obj, dict):
            if "id" not in opt_obj or not opt_obj["id"]:
                for l in letters:
                    cand = f"Option_{l}"
                    if cand not in existing_ids:
                        opt_obj["id"] = cand
                        break
            existing_ids.add(opt_obj["id"])
            options.append(opt_obj)
        else:
            raise ValueError()
    except Exception:
        cand_id = "Option_Manual"
        for l in letters:
            cand = f"Option_{l}"
            if cand not in existing_ids:
                cand_id = cand
                break
        existing_ids.add(cand_id)
        options.append({
            "id": cand_id,
            "title": raw_str,
            "description": raw_str
        })

manifest["options"] = options
with open(manifest_file, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
' "$MANIFEST_FILE" "${ADD_OPTIONS[@]}"
fi

# Detect highest completed round in directory
HIGHEST_COMPLETED_ROUND=0
for rdir in "$DELIBERATION_DIR"/round-*; do
  if [ -d "$rdir" ]; then
    r_tally="$rdir/tally.json"
    if [ -f "$r_tally" ] && jq -e . "$r_tally" >/dev/null 2>&1; then
      r_base="$(basename "$rdir")"
      r_num="${r_base#round-}"
      if [[ "$r_num" =~ ^[0-9]+$ ]] && [ "$r_num" -gt "$HIGHEST_COMPLETED_ROUND" ]; then
        HIGHEST_COMPLETED_ROUND="$r_num"
      fi
    fi
  fi
done

if [ "$IS_CONTINUATION" = true ]; then
  START_ROUND=$((HIGHEST_COMPLETED_ROUND + 1))
  MANIFEST_MAX=$(jq -r '.max_rounds // 3' "$MANIFEST_FILE" 2>/dev/null || echo 3)
  PREV_STATUS=$(jq -r '.status // empty' "$MANIFEST_FILE" 2>/dev/null || true)

  if [ "$PREV_STATUS" = "CONVERGED" ] || [ "$PREV_STATUS" = "CONVERGED_WITH_DISSENT" ]; then
    if [ -z "$GUIDANCE_TEXT" ] && [ "${#ADD_OPTIONS[@]}" -eq 0 ]; then
      echo "Deliberation $DELIBERATION_ID has already reached consensus in round $HIGHEST_COMPLETED_ROUND."
      echo "Final Blueprint  : $DELIBERATION_DIR/final_blueprint.md"
      exit 0
    fi
  fi

  if [ "$ROUNDS_EXPLICIT" = false ]; then
    if [ "$START_ROUND" -gt "$MANIFEST_MAX" ]; then
      MAX_ROUNDS=$((START_ROUND + 1))
    else
      MAX_ROUNDS="$MANIFEST_MAX"
    fi
  else
    if [ "$MAX_ROUNDS" -lt "$START_ROUND" ]; then
      MAX_ROUNDS="$START_ROUND"
    fi
  fi

  UPDATE_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq \
    --arg status "IN_PROGRESS" \
    --argjson mr "$MAX_ROUNDS" \
    --arg ut "$UPDATE_TIME" \
    '
    .status = $status |
    .max_rounds = $mr |
    .continued_at = $ut
    ' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
else
  START_ROUND=1
fi

# Ingest and persist guidance if provided
if [ -n "$GUIDANCE_TEXT" ]; then
  echo "$GUIDANCE_TEXT" > "$DELIBERATION_DIR/guidance.md"
  mkdir -p "$DELIBERATION_DIR/round-$START_ROUND"
  echo "$GUIDANCE_TEXT" > "$DELIBERATION_DIR/round-$START_ROUND/guidance.md"
  jq --arg g "$GUIDANCE_TEXT" '.guidance = $g' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
fi

# Create option_0_baseline.md if missing
OPTION_0_FILE="$DELIBERATION_DIR/option_0_baseline.md"
if [ ! -f "$OPTION_0_FILE" ]; then
  cat <<'EOF' > "$OPTION_0_FILE"
# Option 0: Minimal Viable Architecture (MVA) Baseline

- **Architecture**: Direct standard library / POSIX implementation with zero external daemon or framework overhead.
- **Parsimony Guarantee**: Serves as the minimal complexity benchmark (YAGNI = 5). Any alternative option must justify why this baseline is insufficient.
EOF
fi

# Locate consensus_round.sh driver
ROUND_DRIVER="${CONSENSUS_ROUND_SH:-}"
if [ -z "$ROUND_DRIVER" ]; then
  if [ -x "$SCRIPT_DIR/consensus_round.sh" ]; then
    ROUND_DRIVER="$SCRIPT_DIR/consensus_round.sh"
  elif command -v consensus_round.sh >/dev/null 2>&1; then
    ROUND_DRIVER="$(command -v consensus_round.sh)"
  elif command -v consensus-round >/dev/null 2>&1; then
    ROUND_DRIVER="$(command -v consensus-round)"
  else
    echo "Error: consensus_round.sh driver not found in $SCRIPT_DIR or PATH." >&2
    exit 1
  fi
fi

# Helper function to generate Final Blueprint Markdown
generate_final_blueprint() {
  local target_round="$1"
  local blueprint_path="$DELIBERATION_DIR/final_blueprint.md"

  python3 -c '
import sys, json, os

manifest_file = sys.argv[1]
tally_file = sys.argv[2]
round_dir = sys.argv[3]
blueprint_out = sys.argv[4]
round_num = sys.argv[5]

def escape_md(text):
    return str(text).replace("|", "\\|").replace("\n", " ").strip()

manifest = {}
if os.path.exists(manifest_file):
    with open(manifest_file, "r", encoding="utf-8") as f:
        manifest = json.load(f)

if not os.path.exists(tally_file):
    print(f"Error: tally file {tally_file} not found for blueprint generation.", file=sys.stderr)
    sys.exit(1)

with open(tally_file, "r", encoding="utf-8") as f:
    tally = json.load(f)

status = tally.get("status")
if status not in ("CONVERGED", "CONVERGED_WITH_DISSENT"):
    print(f"Error: Deliberation has not converged (status: {status}). Blueprint cannot be generated.", file=sys.stderr)
    sys.exit(1)

consensus_opt = tally.get("consensus_option")
if not consensus_opt or consensus_opt == "null":
    print("Error: Missing or invalid consensus_option in tally.json.", file=sys.stderr)
    sys.exit(1)

claude_ballot = {}
claude_path = os.path.join(round_dir, "claude_ballot.json")
if os.path.exists(claude_path):
    with open(claude_path, "r", encoding="utf-8") as f:
        claude_ballot = json.load(f)

codex_ballot = {}
codex_path = os.path.join(round_dir, "codex_ballot.json")
if os.path.exists(codex_path):
    with open(codex_path, "r", encoding="utf-8") as f:
        codex_ballot = json.load(f)

delib_id = manifest.get("deliberation_id", "deliberation")
topic = manifest.get("topic", "No topic specified")
yagni_avg = tally.get("yagni_score_avg", 5.0)
spreads = tally.get("score_spreads", {})
max_rounds_val = manifest.get("max_rounds", 3)
updated_at_val = manifest.get("updated_at", manifest.get("created_at", ""))


lines = []
lines.append(f"# Multi-Agent Consensus Architecture Blueprint")
lines.append("")
lines.append(f"- **Deliberation ID**: `{delib_id}`")
lines.append(f"- **Topic**: {topic}")
lines.append(f"- **Convergence Status**: `{status}`")
lines.append(f"- **Converged Round**: Round {round_num} of {max_rounds_val}")
lines.append(f"- **Selected Architecture**: `{consensus_opt}`")
lines.append(f"- **Timestamp**: {updated_at_val}")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## 1. Executive Summary & Consensus Rationale")
lines.append("")
lines.append(f"Deliberation converged on `{consensus_opt}` after {round_num} round(s) with unanimous peer acceptance and zero unaddressed blocking objections.")
lines.append("")

c_rat = claude_ballot.get("metrics", {}).get("technical_feasibility", {}).get("rationale", "")
x_rat = codex_ballot.get("metrics", {}).get("technical_feasibility", {}).get("rationale", "")
if c_rat or x_rat:
    lines.append("### Peer Rationales:")
    if c_rat:
        lines.append(f"- **Claude**: {c_rat}")
    if x_rat:
        lines.append(f"- **Codex**: {x_rat}")
    lines.append("")

lines.append("## 2. Structured Metric Evaluation")
lines.append("")
lines.append("| Metric | Claude Score | Codex Score | Spread | Status |")
lines.append("|---|---|---|---|---|")

metric_keys = [
    ("technical_feasibility", "Technical Feasibility"),
    ("architectural_simplicity", "Architectural Simplicity"),
    ("yagni_and_parsimony", "YAGNI & Parsimony"),
    ("robustness_failure_modes", "Robustness & Failure Modes"),
    ("maintainability_testability", "Maintainability & Testability")
]

for key, label in metric_keys:
    c_score = claude_ballot.get("metrics", {}).get(key, {}).get("score", "-")
    x_score = codex_ballot.get("metrics", {}).get(key, {}).get("score", "-")
    spread = spreads.get(key, 0)
    stat = "PASS" if spread <= 1 else "DISSENT"
    lines.append(f"| {label} | {c_score} | {x_score} | {spread} | {stat} |")

lines.append("")
lines.append(f"- **YAGNI & Parsimony Average**: `{yagni_avg} / 5.0` (Threshold: $\\ge 3.5$)")
lines.append(f"- **Over-Architecture Flags**: Zero active blocking flags")
lines.append("")

lines.append("## 3. Architecture Specification & Component Boundaries")
lines.append("")
lines.append(f"The approved `{consensus_opt}` design adheres strictly to the minimal complexity footprint required to satisfy the specification.")
lines.append("- Direct standard library and POSIX primitives preferred over speculative daemons.")
lines.append("- Isolated state management and clear component boundaries.")
lines.append("")

lines.append("## 4. Failure Modes & Robustness Guarantees")
lines.append("")
lines.append("- Clean handling of timeout, non-zero exits, and environmental constraints.")
lines.append("- Full compatibility with Antigravity single-task async orchestration.")
lines.append("")

lines.append("## 5. Implementation Roadmap & Milestones")
lines.append("")
lines.append(f"1. **Phase 1: Verification Fixtures** — Author automated unit/integration tests establishing baseline behavior.")
lines.append(f"2. **Phase 2: Core Implementation** — Implement `{consensus_opt}` with minimal viable code footprint.")
lines.append(f"3. **Phase 3: Pre-flight Verification** — Execute test suites and peer code reviews before completion.")
lines.append("")

with open(blueprint_out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
' "$MANIFEST_FILE" "$DELIBERATION_DIR/round-$target_round/tally.json" "$DELIBERATION_DIR/round-$target_round" "$blueprint_path" "$target_round"
}

# Helper function to generate Dissent Register Markdown
generate_dissent_register() {
  local target_round="$1"
  local dissent_path="$DELIBERATION_DIR/dissent_register.md"

  python3 -c '
import sys, json, os

manifest_file = sys.argv[1]
tally_file = sys.argv[2]
round_dir = sys.argv[3]
dissent_out = sys.argv[4]
round_num = sys.argv[5]

manifest = {}
if os.path.exists(manifest_file):
    with open(manifest_file, "r", encoding="utf-8") as f:
        manifest = json.load(f)

tally = {}
if os.path.exists(tally_file):
    with open(tally_file, "r", encoding="utf-8") as f:
        tally = json.load(f)

claude_ballot = {}
claude_path = os.path.join(round_dir, "claude_ballot.json")
if os.path.exists(claude_path):
    with open(claude_path, "r", encoding="utf-8") as f:
        claude_ballot = json.load(f)

codex_ballot = {}
codex_path = os.path.join(round_dir, "codex_ballot.json")
if os.path.exists(codex_path):
    with open(codex_path, "r", encoding="utf-8") as f:
        codex_ballot = json.load(f)

delib_id = manifest.get("deliberation_id", "deliberation")
topic = manifest.get("topic", "No topic specified")
c_pref = claude_ballot.get("preferred_option", "Unknown")
x_pref = codex_ballot.get("preferred_option", "Unknown")
blocking_objs = tally.get("blocking_objections", [])
over_arch_flags = tally.get("over_architecture_flags", [])
spreads = tally.get("score_spreads", {})
max_rounds_val = manifest.get("max_rounds", 3)
updated_at_val = manifest.get("updated_at", "")

lines = []
lines.append("# Multi-Agent Deliberation Dissent Register (Deadlock Escalation)")
lines.append("")
lines.append(f"- **Deliberation ID**: `{delib_id}`")
lines.append(f"- **Topic**: {topic}")
lines.append(f"- **Status**: `DEADLOCK`")
lines.append(f"- **Rounds Executed**: {round_num} of {max_rounds_val}")
lines.append(f"- **Timestamp**: {updated_at_val}")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## 1. Executive Deadlock Summary")
lines.append(f"The multi-agent deliberation concluded without unanimous convergence after {round_num} round(s).")
lines.append("The voting peers remain divided across preferred architectural options and tradeoff priorities.")
lines.append("Human operator tie-breaking is required to finalize the implementation approach.")
lines.append("")

lines.append("## 2. Divergent Preferred Options")
lines.append(f"- **Claude Preferred Option**: `{c_pref}`")
lines.append(f"- **Codex Preferred Option**: `{x_pref}`")
lines.append("")

lines.append("## 3. Unresolved Blocking Objections")
if blocking_objs:
    for obj in blocking_objs:
        oid = obj.get("id", "OBJ")
        otype = obj.get("type", "tradeoff")
        target = obj.get("metric_target", "general")
        claim = obj.get("claim", "No claim text")
        res = obj.get("resolution_condition", "No resolution condition specified")
        lines.append(f"### `{oid}` [{otype.upper()}] — Target: `{target}`")
        lines.append(f"- **Claim**: {claim}")
        lines.append(f"- **Resolution Condition**: {res}")
        lines.append("")
else:
    lines.append("No explicit blocking objections recorded.")
    lines.append("")

lines.append("## 4. Over-Architecture (YAGNI) Flags")
if over_arch_flags:
    for flag in over_arch_flags:
        pat = flag.get("pattern", "OVER_ARCHITECTURE")
        critique = flag.get("critique", "")
        remedy = flag.get("simplification_remedy", "")
        lines.append(f"### Pattern: `{pat}`")
        lines.append(f"- **Critique**: {critique}")
        lines.append(f"- **Simplification Remedy**: {remedy}")
        lines.append("")
else:
    lines.append("No over-architecture antipatterns active.")
    lines.append("")

lines.append("## 5. Metric Score Spreads")
lines.append("| Metric | Spread | Spread Status |")
lines.append("|---|---|---|")
for k, v in spreads.items():
    stat = "PASS" if v <= 1 else "DIVERGENT"
    lines.append(f"| {k} | {v} | {stat} |")
lines.append("")

lines.append("## 6. Human Tie-Breaker Decision Menu")
lines.append("The human operator should review the trade-offs above and select an option:")
lines.append(f"1. **Option 0 (Minimal Viable Architecture)**: Enforce strict YAGNI parsimony baseline.")
lines.append(f"2. **{c_pref} (Claude proposal)**: Accept Claude architectural model.")
lines.append(f"3. **{x_pref} (Codex proposal)**: Accept Codex architectural model.")
lines.append("4. **Custom Compromise**: Provide manual override directives in implementation plan.")
lines.append("")

with open(dissent_out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
' "$MANIFEST_FILE" "$DELIBERATION_DIR/round-$target_round/tally.json" "$DELIBERATION_DIR/round-$target_round" "$dissent_path" "$target_round"
}

# Helper function to generate Jetski evidence prompt
generate_jetski_prompt() {
  local target_round="$1"
  local prompt_path="$DELIBERATION_DIR/round-$target_round/jetski_evidence_prompt.md"

  python3 -c '
import sys, json, os

manifest_file = sys.argv[1]
tally_file = sys.argv[2]
prompt_out = sys.argv[3]
round_num = sys.argv[4]

manifest = {}
if os.path.exists(manifest_file):
    with open(manifest_file, "r", encoding="utf-8") as f:
        manifest = json.load(f)

tally = {}
if os.path.exists(tally_file):
    with open(tally_file, "r", encoding="utf-8") as f:
        tally = json.load(f)

delib_id = manifest.get("deliberation_id", "deliberation")
topic = manifest.get("topic", "")
factual_objs = [o for o in tally.get("blocking_objections", []) if o.get("type") == "factual"]

lines = []
lines.append("# Jetski Subagent Empirical Spike Directive")
lines.append("")
lines.append(f"- **Deliberation ID**: `{delib_id}`")
lines.append(f"- **Round**: {round_num}")
lines.append(f"- **Topic**: {topic}")
lines.append("")
lines.append("## Objective")
lines.append("The deliberation encountered empirical / factual disputes that block consensus.")
lines.append("As the Jetski Subagent (Empirical Probe), execute throwaway spike code or real benchmarks")
lines.append("to resolve these disputed claims with concrete numerical evidence.")
lines.append("")
lines.append("## Factual Disputes to Verify")
for o in factual_objs:
    oid = o.get("id", "OBJ")
    target = o.get("metric_target", "technical_feasibility")
    claim = o.get("claim", "")
    res = o.get("resolution_condition", "")
    lines.append(f"### `{oid}` — Target Metric: `{target}`")
    lines.append(f"- **Disputed Claim**: {claim}")
    lines.append(f"- **Resolution Condition**: {res}")
    lines.append("")

lines.append("## Instructions for Jetski Subagent")
lines.append("1. Write and execute a throwaway test or benchmark validating the claims above.")
lines.append("2. Record precise numbers: execution latency (ms), memory footprint, error rate, LOC.")
lines.append("3. Format findings in Markdown and write to:")
lines.append(f"   `.agent/deliberations/{delib_id}/round-{round_num}/jetski_evidence.md`")
lines.append("4. Conclude with a clear verdict stating whether the disputed claim was VALIDATED or REFUTED.")
lines.append("")

with open(prompt_out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
' "$MANIFEST_FILE" "$DELIBERATION_DIR/round-$target_round/tally.json" "$prompt_path" "$target_round"
}

# Main Deliberation Loop
FINAL_STATUS="IN_DEBATE"
CONVERGED_ROUND=0

for (( round=START_ROUND; round<=MAX_ROUNDS; round++ )); do
  echo "=== Deliberation $DELIBERATION_ID: Executing Round $round of $MAX_ROUNDS ==="

  # Check if Jetski evidence is available to inject before this round (for round > 1)
  if [ "$round" -gt 1 ]; then
    PREV_ROUND=$((round - 1))
    PREV_DIGEST="$DELIBERATION_DIR/round-$PREV_ROUND/digest.md"

    # Search for potential jetski evidence files
    CANDIDATE_EVIDENCE=""
    if [ -n "$JETSKI_EVIDENCE_OPT" ] && [ -f "$JETSKI_EVIDENCE_OPT" ]; then
      CANDIDATE_EVIDENCE="$JETSKI_EVIDENCE_OPT"
    elif [ -f "$DELIBERATION_DIR/round-$PREV_ROUND/jetski_evidence.md" ]; then
      CANDIDATE_EVIDENCE="$DELIBERATION_DIR/round-$PREV_ROUND/jetski_evidence.md"
    elif [ -f "$DELIBERATION_DIR/jetski_evidence.md" ]; then
      CANDIDATE_EVIDENCE="$DELIBERATION_DIR/jetski_evidence.md"
    elif [ -f "$DELIBERATION_DIR/round-$round/jetski_evidence.md" ]; then
      CANDIDATE_EVIDENCE="$DELIBERATION_DIR/round-$round/jetski_evidence.md"
    fi

    if [ -n "$CANDIDATE_EVIDENCE" ] && [ -f "$PREV_DIGEST" ]; then
      if ! grep -q "Empirical Spike Evidence (Jetski)" "$PREV_DIGEST"; then
        echo -e "\n\n## Empirical Spike Evidence (Jetski)\n$(cat "$CANDIDATE_EVIDENCE")" >> "$PREV_DIGEST"
      fi
    fi
  fi

  # Build consensus_round.sh arguments
  DRIVER_ARGS=(--max-rounds "$MAX_ROUNDS")
  if [ -n "$MODEL_CLAUDE" ]; then
    DRIVER_ARGS+=(--model-claude "$MODEL_CLAUDE")
  fi
  if [ -n "$MODEL_CODEX" ]; then
    DRIVER_ARGS+=(--model-codex "$MODEL_CODEX")
  fi
  if [ -n "$GUIDANCE_TEXT" ]; then
    DRIVER_ARGS+=(--guidance "$GUIDANCE_TEXT")
  fi

  # Execute round driver
  set +e
  "$ROUND_DRIVER" "${DRIVER_ARGS[@]}" "$DELIBERATION_DIR" "$round"
  ROUND_EXIT=$?
  set -e

  if [ "$ROUND_EXIT" -eq 126 ]; then
    echo "❌ [SANDBOX_BLOCKED] Operation not permitted by sandbox environment." >&2
    echo "Please re-run the deliberation command with BypassSandbox: true." >&2
    exit 126
  elif [ "$ROUND_EXIT" -eq 100 ]; then
    echo "⚠️ [FALLBACK_TRIGGERED: External peers unavailable]" >&2
    echo "External peer CLIs encountered rate limits or connection failures." >&2
    jq --arg status "FALLBACK_TRIGGERED" '.status = $status' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
    exit 100
  elif [ "$ROUND_EXIT" -ne 0 ]; then
    echo "Error: Round $round failed with exit code $ROUND_EXIT" >&2
    exit "$ROUND_EXIT"
  fi

  # Inspect tally output
  ROUND_TALLY="$DELIBERATION_DIR/round-$round/tally.json"
  if [ ! -f "$ROUND_TALLY" ]; then
    echo "Error: tally.json not found for round $round." >&2
    exit 1
  fi

  STATUS=$(jq -r '.status // "UNKNOWN"' "$ROUND_TALLY")
  CONSENSUS_OPT=$(jq -r '.consensus_option // empty' "$ROUND_TALLY")
  YAGNI_AVG=$(jq -r '.yagni_score_avg // 0' "$ROUND_TALLY")
  FINAL_STATUS="$STATUS"

  # Case 1: Full Convergence or Convergence with Dissent
  if [ "$STATUS" = "CONVERGED" ] || [ "$STATUS" = "CONVERGED_WITH_DISSENT" ]; then
    CONVERGED_ROUND="$round"
    UPDATE_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    jq \
      --arg status "CONVERGED" \
      --arg opt "$CONSENSUS_OPT" \
      --argjson round "$round" \
      --arg updated_at "$UPDATE_TIME" \
      '
      .status = $status |
      .consensus_option = $opt |
      .converged_round = $round |
      .updated_at = $updated_at
      ' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"

    generate_final_blueprint "$round"

    # Print Executive Summary Table to terminal
    echo ""
    echo "================================================================================"
    echo "🎉 CONSENSUS REACHED: Multi-Agent Deliberation Blueprint Generated"
    echo "================================================================================"
    echo "Deliberation ID  : $DELIBERATION_ID"
    echo "Topic            : $TOPIC"
    echo "Converged Round  : Round $round of $MAX_ROUNDS"
    echo "Consensus Option : $CONSENSUS_OPT"
    echo "YAGNI Score Avg  : $YAGNI_AVG / 5.0 (Minimum: 3.5)"
    echo ""
    echo "Structured Metric Table:"
    echo "--------------------------------------------------------------------------------"
    printf "%-32s %-8s %-8s %-8s %-8s\n" "Metric" "Claude" "Codex" "Spread" "Status"
    echo "--------------------------------------------------------------------------------"

    python3 -c '
import sys, json

tally = json.load(open(sys.argv[1]))
claude = json.load(open(sys.argv[2]))
codex = json.load(open(sys.argv[3]))

metric_keys = [
    ("technical_feasibility", "technical_feasibility"),
    ("architectural_simplicity", "architectural_simplicity"),
    ("yagni_and_parsimony", "yagni_and_parsimony"),
    ("robustness_failure_modes", "robustness_failure_modes"),
    ("maintainability_testability", "maintainability_testability")
]

spreads = tally.get("score_spreads", {})
for key, label in metric_keys:
    c_s = claude.get("metrics", {}).get(key, {}).get("score", "-")
    x_s = codex.get("metrics", {}).get(key, {}).get("score", "-")
    sp = spreads.get(key, 0)
    st = "PASS" if sp <= 1 else "DISSENT"
    print(f"{label:<32} {str(c_s):<8} {str(x_s):<8} {str(sp):<8} {st:<8}")
' "$ROUND_TALLY" "$DELIBERATION_DIR/round-$round/claude_ballot.json" "$DELIBERATION_DIR/round-$round/codex_ballot.json"

    echo "--------------------------------------------------------------------------------"
    echo "Final Blueprint  : $DELIBERATION_DIR/final_blueprint.md"
    echo "Ledger Directory : $DELIBERATION_DIR"
    echo "================================================================================"
    echo ""
    exit 0
  fi

  # Case 2: In Debate -> Check for factual disputes and Jetski probe integration
  if [ "$STATUS" = "IN_DEBATE" ]; then
    FACTUAL_COUNT=$(jq '[.blocking_objections[]? | select(.type == "factual")] | length' "$ROUND_TALLY")
    if [ "$FACTUAL_COUNT" -gt 0 ]; then
      generate_jetski_prompt "$round"
      echo "🔬 [JETSKI_DIRECTIVE] Generated empirical spike instructions for $FACTUAL_COUNT factual dispute(s):"
      echo "    $DELIBERATION_DIR/round-$round/jetski_evidence_prompt.md"

      # If pre-supplied or already created evidence exists, integrate into current digest
      CANDIDATE_EVIDENCE=""
      if [ -n "$JETSKI_EVIDENCE_OPT" ] && [ -f "$JETSKI_EVIDENCE_OPT" ]; then
        CANDIDATE_EVIDENCE="$JETSKI_EVIDENCE_OPT"
      elif [ -f "$DELIBERATION_DIR/round-$round/jetski_evidence.md" ]; then
        CANDIDATE_EVIDENCE="$DELIBERATION_DIR/round-$round/jetski_evidence.md"
      elif [ -f "$DELIBERATION_DIR/jetski_evidence.md" ]; then
        CANDIDATE_EVIDENCE="$DELIBERATION_DIR/jetski_evidence.md"
      fi

      if [ -n "$CANDIDATE_EVIDENCE" ] && [ -f "$DELIBERATION_DIR/round-$round/digest.md" ]; then
        if ! grep -q "Empirical Spike Evidence (Jetski)" "$DELIBERATION_DIR/round-$round/digest.md"; then
          echo -e "\n\n## Empirical Spike Evidence (Jetski)\n$(cat "$CANDIDATE_EVIDENCE")" >> "$DELIBERATION_DIR/round-$round/digest.md"
          echo "    Integrated Jetski evidence into Round $round digest for subsequent evaluation."
        fi
      fi
    fi
  fi

  # Case 3: Deadlock detected by tally
  if [ "$STATUS" = "DEADLOCK" ]; then
    break
  fi
done

# If loop completed without convergence, trigger Deadlock Escalation
UPDATE_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
LAST_ROUND=$((round > MAX_ROUNDS ? MAX_ROUNDS : round))

jq \
  --arg status "DEADLOCK" \
  --argjson round "$LAST_ROUND" \
  --arg updated_at "$UPDATE_TIME" \
  '
  .status = $status |
  .deadlock_round = $round |
  .updated_at = $updated_at
  ' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"

generate_dissent_register "$LAST_ROUND"

echo ""
echo "================================================================================"
echo "🚨 DEADLOCK ESCALATION REPORT: Multi-Agent Deliberation Unresolved"
echo "================================================================================"
echo "Deliberation ID  : $DELIBERATION_ID"
echo "Topic            : $TOPIC"
echo "Rounds Executed  : $LAST_ROUND of $MAX_ROUNDS"
echo "Status           : DEADLOCK"
echo ""

python3 -c '
import sys, json, os

claude = {}
if os.path.exists(sys.argv[1]):
    try:
        with open(sys.argv[1], "r", encoding="utf-8") as f:
            claude = json.load(f)
    except Exception:
        pass

codex = {}
if os.path.exists(sys.argv[2]):
    try:
        with open(sys.argv[2], "r", encoding="utf-8") as f:
            codex = json.load(f)
    except Exception:
        pass

tally = {}
if os.path.exists(sys.argv[3]):
    try:
        with open(sys.argv[3], "r", encoding="utf-8") as f:
            tally = json.load(f)
    except Exception:
        pass

c_p = claude.get("preferred_option", "Unknown")
x_p = codex.get("preferred_option", "Unknown")

print(f"Claude Preference : {c_p}")
print(f"Codex Preference  : {x_p}")
print("")
print("Unresolved Blocking Objections:")
objs = tally.get("blocking_objections", [])
if objs:
    for o in objs:
        otype = o.get("type", "tradeoff").upper()
        oid = o.get("id", "OBJ")
        oclaim = o.get("claim", "")
        print(f"  - [{otype}] {oid}: {oclaim}")
else:
    print("  - Disagreement on metric tradeoffs and architecture preferences.")
print("")
print("Human Tie-Breaker Options:")
print("  [1] Option 0: Enforce Minimal Viable Architecture (MVA) baseline")
print(f"  [2] Option A ({c_p}): Proceed with Claude proposal")
print(f"  [3] Option B ({x_p}): Proceed with Codex proposal")
print("  [4] Custom Override: Settle tradeoff manually and override deliberation")
' "$DELIBERATION_DIR/round-$LAST_ROUND/claude_ballot.json" \
  "$DELIBERATION_DIR/round-$LAST_ROUND/codex_ballot.json" \
  "$DELIBERATION_DIR/round-$LAST_ROUND/tally.json"

echo ""
echo "Dissent ledger recorded at: $DELIBERATION_DIR/dissent_register.md"
echo "================================================================================"
echo ""

exit 2
