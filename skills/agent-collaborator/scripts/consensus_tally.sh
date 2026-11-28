#!/usr/bin/env bash
# Deterministic Consensus Tally & Gate Evaluator
# Evaluates 2-peer (Claude + Codex) or 3-peer (Claude + Codex + Gemini)
# deliberation ballots using jq to compute consensus, quorum, YAGNI compliance,
# metric score spreads, and dispute statuses.
#
# Usage: ./consensus_tally.sh [--gemini <GEMINI_BALLOT_JSON>] <CLAUDE_BALLOT_JSON> <CODEX_BALLOT_JSON> <OUTPUT_TALLY_JSON> [ROUND_NUM] [MAX_ROUNDS] [MANIFEST]

set -euo pipefail

THREE_PEER_MODE=false
GEMINI_BALLOT=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gemini)
      if [[ $# -lt 2 ]]; then
        echo "Error: --gemini requires a file path argument." >&2
        exit 1
      fi
      THREE_PEER_MODE=true
      GEMINI_BALLOT="$2"
      shift 2
      ;;
    --gemini=*)
      THREE_PEER_MODE=true
      GEMINI_BALLOT="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--gemini <GEMINI_BALLOT_JSON>] <CLAUDE_BALLOT_JSON> <CODEX_BALLOT_JSON> <OUTPUT_TALLY_JSON> [ROUND_NUM] [MAX_ROUNDS] [MANIFEST]"
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL+=("$1")
        shift
      done
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 [--gemini <GEMINI_BALLOT_JSON>] <CLAUDE_BALLOT_JSON> <CODEX_BALLOT_JSON> <OUTPUT_TALLY_JSON> [ROUND_NUM] [MAX_ROUNDS] [MANIFEST]" >&2
  exit 1
fi

CLAUDE_BALLOT="$1"
CODEX_BALLOT="$2"
OUTPUT_TALLY="$3"
ROUND_NUM="${4:-1}"
MAX_ROUNDS="${5:-3}"
MANIFEST_ARG="${6:-}"

# Parse registered options from manifest argument or default location
REGISTERED_OPTIONS="[]"
if [ -n "$MANIFEST_ARG" ]; then
  if [ -f "$MANIFEST_ARG" ]; then
    REGISTERED_OPTIONS=$(jq -c '[.options[]? | if type == "object" then (.id // .name) elif type == "string" then . else empty end]' "$MANIFEST_ARG" 2>/dev/null || echo "[]")
  elif echo "$MANIFEST_ARG" | jq -e . >/dev/null 2>&1; then
    REGISTERED_OPTIONS=$(echo "$MANIFEST_ARG" | jq -c 'if type == "array" then . elif type == "object" and .options then [.options[]? | if type == "object" then (.id // .name) else . end] else [] end')
  fi
elif [ -f "$(dirname "$OUTPUT_TALLY")/../manifest.json" ]; then
  REGISTERED_OPTIONS=$(jq -c '[.options[]? | if type == "object" then (.id // .name) elif type == "string" then . else empty end]' "$(dirname "$OUTPUT_TALLY")/../manifest.json" 2>/dev/null || echo "[]")
fi

# Ensure numeric round values (strip leading zeros so jq --argjson never fails)
if ! [[ "$ROUND_NUM" =~ ^[0-9]+$ ]]; then
  ROUND_NUM=1
else
  ROUND_NUM="$((10#$ROUND_NUM))"
  [ "$ROUND_NUM" -lt 1 ] && ROUND_NUM=1
fi
if ! [[ "$MAX_ROUNDS" =~ ^[0-9]+$ ]]; then
  MAX_ROUNDS=3
else
  MAX_ROUNDS="$((10#$MAX_ROUNDS))"
  [ "$MAX_ROUNDS" -lt 1 ] && MAX_ROUNDS=3
fi

# Ensure output directory exists
OUT_DIR="$(dirname "$OUTPUT_TALLY")"
mkdir -p "$OUT_DIR"
TMP_TALLY="$OUT_DIR/.tally.tmp.$$"
trap 'rm -f "$TMP_TALLY"' EXIT

# Strict pre-scoring ballot classification: ABSENT | INVALID | VALID
# Uses jq -s to guarantee exactly ONE top-level JSON object per file.
classify_ballot() {
  local f="$1"
  if [ -z "$f" ] || [ ! -s "$f" ]; then
    echo "ABSENT"
    return 0
  fi
  if jq -s -e '
    length == 1 and
    (.[0] as $root |
      ($root | type == "object") and
      ($root.preferred_option | type == "string" and length > 0) and
      ($root.stance | type == "string" and (. == "ACCEPT" or . == "ACCEPT_WITH_RESERVATIONS" or . == "BLOCK")) and
      ($root.metrics | type == "object") and
      (["technical_feasibility", "architectural_simplicity", "yagni_and_parsimony", "robustness_failure_modes", "maintainability_testability"]
        | all(. as $k | ($root.metrics[$k] | type == "object") and ($root.metrics[$k].score | type == "number" and . >= 1 and . <= 5))) and
      ($root.blocking_objections == null or ($root.blocking_objections | type == "array" and all(
        type == "object" and
        (.id == null or (.id | type == "string")) and
        (.type == null or (.type | type == "string")) and
        (.metric_target == null or (.metric_target | type == "string")) and
        (.claim == null or (.claim | type == "string")) and
        (.resolution_condition == null or (.resolution_condition | type == "string")) and
        (.target_option == null or (.target_option | type == "string"))
      ))) and
      ($root.over_architecture_flags == null or ($root.over_architecture_flags | type == "array" and all(
        type == "object" and
        (.pattern == null or (.pattern | type == "string")) and
        (.critique == null or (.critique | type == "string")) and
        (.simplification_remedy == null or (.simplification_remedy | type == "string")) and
        (.target_option == null or (.target_option | type == "string"))
      )))
    )
  ' "$f" >/dev/null 2>&1; then
    echo "VALID"
  else
    echo "INVALID"
  fi
}

PEER_NAMES=("claude" "codex")
PEER_FILES=("$CLAUDE_BALLOT" "$CODEX_BALLOT")
if [ "$THREE_PEER_MODE" = true ]; then
  PEER_NAMES+=("gemini")
  PEER_FILES+=("$GEMINI_BALLOT")
fi

EXPECTED_COUNT="${#PEER_NAMES[@]}"
PARTICIPATING_PEERS=()
ABSENT_PEERS=()
INVALID_PEERS=()
NON_PARTICIPATING_PEERS=()
VALID_FILES=()

for i in "${!PEER_NAMES[@]}"; do
  pname="${PEER_NAMES[$i]}"
  pfile="${PEER_FILES[$i]}"
  state="$(classify_ballot "$pfile")"
  case "$state" in
    VALID)
      PARTICIPATING_PEERS+=("$pname")
      VALID_FILES+=("$pfile")
      ;;
    ABSENT)
      ABSENT_PEERS+=("$pname")
      NON_PARTICIPATING_PEERS+=("$pname")
      ;;
    INVALID)
      INVALID_PEERS+=("$pname")
      NON_PARTICIPATING_PEERS+=("$pname")
      ;;
  esac
done

to_json_array() {
  if [ "$#" -eq 0 ]; then
    echo "[]"
  else
    printf '%s\n' "$@" | jq -R . | jq -s .
  fi
}

PARTICIPATING_JSON="$(to_json_array "${PARTICIPATING_PEERS[@]+"${PARTICIPATING_PEERS[@]}"}")"
ABSENT_JSON="$(to_json_array "${ABSENT_PEERS[@]+"${ABSENT_PEERS[@]}"}")"
INVALID_JSON="$(to_json_array "${INVALID_PEERS[@]+"${INVALID_PEERS[@]}"}")"
VALID_COUNT="${#VALID_FILES[@]}"

# Quorum requires at least 2 valid ballots
if [ "$VALID_COUNT" -lt 2 ]; then
  if [ "$VALID_COUNT" -eq 0 ]; then
    if [ "$THREE_PEER_MODE" = true ]; then
      DEGRADED_PEER="all"
    else
      DEGRADED_PEER="both"
    fi
    jq -n \
      --argjson round "$ROUND_NUM" \
      --argjson max_rounds "$MAX_ROUNDS" \
      --arg degraded_peer "$DEGRADED_PEER" \
      --argjson participating "$PARTICIPATING_JSON" \
      --argjson absent "$ABSENT_JSON" \
      --argjson invalid "$INVALID_JSON" \
      '{
        "deliberation_id": null,
        "round": $round,
        "max_rounds": $max_rounds,
        "status": "DEGRADED",
        "degraded_peer": $degraded_peer,
        "consensus_option": null,
        "yagni_score_avg": 0,
        "score_spreads": {
          "technical_feasibility": 0,
          "architectural_simplicity": 0,
          "yagni_and_parsimony": 0,
          "robustness_failure_modes": 0,
          "maintainability_testability": 0
        },
        "blocking_objections": [],
        "over_architecture_flags": [],
        "participating_peers": $participating,
        "absent_peers": $absent,
        "invalid_peers": $invalid,
        "quorum_met": false,
        "reduced_quorum": false
      }' > "$TMP_TALLY"
  else
    # Exactly 1 valid ballot
    DEGRADED_PEER="$(IFS=,; echo "${NON_PARTICIPATING_PEERS[*]}")"
    jq \
      --argjson round "$ROUND_NUM" \
      --argjson max_rounds "$MAX_ROUNDS" \
      --arg degraded_peer "$DEGRADED_PEER" \
      --argjson participating "$PARTICIPATING_JSON" \
      --argjson absent "$ABSENT_JSON" \
      --argjson invalid "$INVALID_JSON" \
      '. as $b |
      ($b.metrics.yagni_and_parsimony.score // 0) as $yagni |
      {
        "deliberation_id": ($b.deliberation_id // null),
        "round": $round,
        "max_rounds": $max_rounds,
        "status": "DEGRADED",
        "degraded_peer": $degraded_peer,
        "consensus_option": ($b.preferred_option // null),
        "yagni_score_avg": $yagni,
        "score_spreads": {
          "technical_feasibility": 0,
          "architectural_simplicity": 0,
          "yagni_and_parsimony": 0,
          "robustness_failure_modes": 0,
          "maintainability_testability": 0
        },
        "blocking_objections": ($b.blocking_objections // []),
        "over_architecture_flags": ($b.over_architecture_flags // []),
        "participating_peers": $participating,
        "absent_peers": $absent,
        "invalid_peers": $invalid,
        "quorum_met": false,
        "reduced_quorum": false
      }' "${VALID_FILES[0]}" > "$TMP_TALLY"
  fi
  mv "$TMP_TALLY" "$OUTPUT_TALLY"
  exit 0
fi

# Quorum met (>= 2 valid ballots): compute deterministic N-peer tally
REDUCED_QUORUM=false
if [ "$VALID_COUNT" -lt "$EXPECTED_COUNT" ]; then
  REDUCED_QUORUM=true
fi

jq -s \
  --argjson round "$ROUND_NUM" \
  --argjson max_rounds "$MAX_ROUNDS" \
  --argjson reg_opts "$REGISTERED_OPTIONS" \
  --argjson participating "$PARTICIPATING_JSON" \
  --argjson absent "$ABSENT_JSON" \
  --argjson invalid "$INVALID_JSON" \
  --argjson reduced_quorum "$REDUCED_QUORUM" \
  '
  . as $ballots |

  def spread($k):
    ([$ballots[].metrics[$k].score]) as $scores |
    (($scores | max) - ($scores | min));

  {
    "technical_feasibility": spread("technical_feasibility"),
    "architectural_simplicity": spread("architectural_simplicity"),
    "yagni_and_parsimony": spread("yagni_and_parsimony"),
    "robustness_failure_modes": spread("robustness_failure_modes"),
    "maintainability_testability": spread("maintainability_testability")
  } as $spreads |

  ([$ballots[].metrics.yagni_and_parsimony.score]) as $yagni_scores |
  (($yagni_scores | add) / ($yagni_scores | length)) as $yagni_avg |

  ([$ballots[] | (.blocking_objections // [])[]]) as $raw_blocking_objections |
  ([$ballots[] | (.over_architecture_flags // [])[]]) as $over_architecture_flags |

  ([$ballots[].preferred_option] | unique) as $unique_opts |
  (($unique_opts | length == 1) and ($unique_opts[0] != null) and ($unique_opts[0] != "")) as $preferred_matches |
  (if $preferred_matches then $unique_opts[0] else null end) as $candidate_option |

  ($reg_opts | length == 0 or ($candidate_option != null and ($reg_opts | index($candidate_option) != null))) as $option_is_registered |

  (if ($preferred_matches | not) or $option_is_registered then $raw_blocking_objections else $raw_blocking_objections + [{
    "id": "UNREGISTERED_OPTION",
    "type": "factual",
    "metric_target": "technical_feasibility",
    "claim": "The preferred option \($candidate_option) is not registered in manifest options.",
    "resolution_condition": "Register the option in manifest.json before consensus can be certified."
  }] end) as $blocking_objections |

  # Filter active flags and objections targeting the candidate option
  ($blocking_objections | map(select(
    (.target_option == null or .target_option == "" or .target_option == $candidate_option)
  ))) as $active_objections |

  ($over_architecture_flags | map(select(
    (.target_option == null or .target_option == "" or .target_option == $candidate_option)
  ))) as $active_flags |

  # Per-peer YAGNI floor >= 3.0 and average >= 3.5
  (($yagni_scores | all(. >= 3.0)) and ($yagni_avg >= 3.5)) as $yagni_pass |

  (([$ballots[].stance] | any(. == "BLOCK")) or ($active_objections | length > 0) or ($active_flags | length > 0) or ($preferred_matches and ($option_is_registered | not))) as $has_block |

  ([$spreads[]] | all(. <= 1)) as $all_spreads_lte_1 |

  (
    if $preferred_matches and $option_is_registered and ($has_block | not) and $yagni_pass and $all_spreads_lte_1 then
      "CONVERGED"
    elif $preferred_matches and $option_is_registered and ($has_block | not) and $yagni_pass and ($all_spreads_lte_1 | not) then
      "CONVERGED_WITH_DISSENT"
    elif $round >= $max_rounds then
      "DEADLOCK"
    else
      "IN_DEBATE"
    end
  ) as $status |

  (([ $ballots[] | .deliberation_id // empty ] | first) // null) as $delib_id |

  {
    "deliberation_id": $delib_id,
    "round": $round,
    "max_rounds": $max_rounds,
    "status": $status,
    "consensus_option": (if ($status == "CONVERGED" or $status == "CONVERGED_WITH_DISSENT") then $candidate_option else null end),
    "yagni_score_avg": $yagni_avg,
    "score_spreads": $spreads,
    "blocking_objections": $blocking_objections,
    "over_architecture_flags": $over_architecture_flags,
    "participating_peers": $participating,
    "absent_peers": $absent,
    "invalid_peers": $invalid,
    "quorum_met": true,
    "reduced_quorum": $reduced_quorum
  }
  ' "${VALID_FILES[@]}" > "$TMP_TALLY"

mv "$TMP_TALLY" "$OUTPUT_TALLY"
