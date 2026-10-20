#!/usr/bin/env bash
# Deterministic Consensus Tally & Gate Evaluator
# Evaluates multi-agent deliberation ballots using jq to compute consensus,
# YAGNI compliance, metric score spreads, and dispute statuses.
#
# Usage: ./consensus_tally.sh <CLAUDE_BALLOT_JSON> <CODEX_BALLOT_JSON> <OUTPUT_TALLY_JSON> [ROUND_NUM] [MAX_ROUNDS]

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <CLAUDE_BALLOT_JSON> <CODEX_BALLOT_JSON> <OUTPUT_TALLY_JSON> [ROUND_NUM] [MAX_ROUNDS]" >&2
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

# Ensure numeric round values
if ! [[ "$ROUND_NUM" =~ ^[0-9]+$ ]]; then
  ROUND_NUM=1
fi
if ! [[ "$MAX_ROUNDS" =~ ^[0-9]+$ ]]; then
  MAX_ROUNDS=3
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_TALLY")"

# Validate input files
claude_valid=true
codex_valid=true

if [ ! -s "$CLAUDE_BALLOT" ] || ! jq -e . "$CLAUDE_BALLOT" >/dev/null 2>&1; then
  claude_valid=false
fi

if [ ! -s "$CODEX_BALLOT" ] || ! jq -e . "$CODEX_BALLOT" >/dev/null 2>&1; then
  codex_valid=false
fi

# Handle degraded scenarios
if [ "$claude_valid" = false ] && [ "$codex_valid" = false ]; then
  jq -n \
    --argjson round "$ROUND_NUM" \
    --argjson max_rounds "$MAX_ROUNDS" \
    '{
      "deliberation_id": null,
      "round": $round,
      "max_rounds": $max_rounds,
      "status": "DEGRADED",
      "degraded_peer": "both",
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
      "over_architecture_flags": []
    }' > "$OUTPUT_TALLY"
  exit 0
elif [ "$claude_valid" = true ] && [ "$codex_valid" = false ]; then
  jq \
    --argjson round "$ROUND_NUM" \
    --argjson max_rounds "$MAX_ROUNDS" \
    --arg degraded_peer "codex" \
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
      "over_architecture_flags": ($b.over_architecture_flags // [])
    }' "$CLAUDE_BALLOT" > "$OUTPUT_TALLY"
  exit 0
elif [ "$claude_valid" = false ] && [ "$codex_valid" = true ]; then
  jq \
    --argjson round "$ROUND_NUM" \
    --argjson max_rounds "$MAX_ROUNDS" \
    --arg degraded_peer "claude" \
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
      "over_architecture_flags": ($b.over_architecture_flags // [])
    }' "$CODEX_BALLOT" > "$OUTPUT_TALLY"
  exit 0
fi

# Both ballots are valid; compute deterministic tally
jq -s \
  --argjson round "$ROUND_NUM" \
  --argjson max_rounds "$MAX_ROUNDS" \
  --argjson reg_opts "$REGISTERED_OPTIONS" \
  '
  def abs: if . < 0 then -. else . end;

  .[0] as $c | .[1] as $x |

  ($c.metrics.technical_feasibility.score // 0) as $c_tf |
  ($x.metrics.technical_feasibility.score // 0) as $x_tf |
  ($c.metrics.architectural_simplicity.score // 0) as $c_as |
  ($x.metrics.architectural_simplicity.score // 0) as $x_as |
  ($c.metrics.yagni_and_parsimony.score // 0) as $c_yp |
  ($x.metrics.yagni_and_parsimony.score // 0) as $x_yp |
  ($c.metrics.robustness_failure_modes.score // 0) as $c_rf |
  ($x.metrics.robustness_failure_modes.score // 0) as $x_rf |
  ($c.metrics.maintainability_testability.score // 0) as $c_mt |
  ($x.metrics.maintainability_testability.score // 0) as $x_mt |

  {
    "technical_feasibility": (($c_tf - $x_tf) | abs),
    "architectural_simplicity": (($c_as - $x_as) | abs),
    "yagni_and_parsimony": (($c_yp - $x_yp) | abs),
    "robustness_failure_modes": (($c_rf - $x_rf) | abs),
    "maintainability_testability": (($c_mt - $x_mt) | abs)
  } as $spreads |

  (($c_yp + $x_yp) / 2.0) as $yagni_avg |

  (($c.blocking_objections // []) + ($x.blocking_objections // [])) as $raw_blocking_objections |
  (($c.over_architecture_flags // []) + ($x.over_architecture_flags // [])) as $over_architecture_flags |

  ($c.preferred_option != null and $c.preferred_option == $x.preferred_option) as $preferred_matches |
  $c.preferred_option as $candidate_option |

  ($reg_opts | length == 0 or ($candidate_option != null and ($reg_opts | index($candidate_option) != null))) as $option_is_registered |

  (if $option_is_registered then $raw_blocking_objections else $raw_blocking_objections + [{
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
  ($c_yp >= 3.0 and $x_yp >= 3.0 and $yagni_avg >= 3.5) as $yagni_pass |

  ($c.stance == "BLOCK" or $x.stance == "BLOCK" or ($active_objections | length > 0) or ($active_flags | length > 0) or ($option_is_registered | not)) as $has_block |

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

  {
    "deliberation_id": ($c.deliberation_id // $x.deliberation_id // null),
    "round": $round,
    "max_rounds": $max_rounds,
    "status": $status,
    "consensus_option": (if ($status == "CONVERGED" or $status == "CONVERGED_WITH_DISSENT") then $c.preferred_option else null end),
    "yagni_score_avg": $yagni_avg,
    "score_spreads": $spreads,
    "blocking_objections": $blocking_objections,
    "over_architecture_flags": $over_architecture_flags
  }
  ' "$CLAUDE_BALLOT" "$CODEX_BALLOT" > "$OUTPUT_TALLY"
