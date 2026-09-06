#!/usr/bin/env bash
# Universal OpenAI Codex Brainstorming & Engineering Feasibility Script with Graceful Fallback
# Explores engineering feasibility, standard library/ecosystem alternatives, pragmatic data structures, and contrarian perspectives.
# Usage: ./codex_brainstorm.sh "<TASK_OR_REQUIREMENT>" [FILE_PATHS...]

set -uo pipefail

REQUIREMENT="${1:-}"
if [ -z "$REQUIREMENT" ]; then
  echo "Error: Missing requirement prompt." >&2
  echo "Usage: $0 \"<TASK_OR_REQUIREMENT>\" [FILE_PATHS...]" >&2
  exit 1
fi
shift

PROJECT_HINT=""
if [ -f "pubspec.yaml" ]; then
  PROJECT_HINT="Project Technology Stack: Dart / Flutter"
elif [ -f "package.json" ]; then
  PROJECT_HINT="Project Technology Stack: Node.js / TypeScript / JavaScript"
elif [ -f "Cargo.toml" ]; then
  PROJECT_HINT="Project Technology Stack: Rust"
elif [ -f "go.mod" ]; then
  PROJECT_HINT="Project Technology Stack: Go"
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  PROJECT_HINT="Project Technology Stack: Python"
fi

FILE_CONTEXT=""
for f in "$@"; do
  if [ -f "$f" ]; then
    FILE_CONTEXT+=$'\n\n'"--- File: $f ---"$'\n'
    FILE_CONTEXT+="$(cat "$f")"
  fi
done

PROMPT="You are a Principal Systems Pragmatist and Engineering Feasibility Architect.
Provide a rigorous, pragmatic engineering brainstorming pass for the specified requirement.
Focus on concrete technical feasibility, minimal-complexity alternatives, data structures, and ecosystem realities.

$PROJECT_HINT

[Feature Requirement & Brainstorming Goal]
$REQUIREMENT

[Relevant Context Files]
$FILE_CONTEXT

Please output a structured, production-grade engineering brainstorming report covering:
1. Pragmatic Alternatives & Ecosystem Options:
   - What existing standard library utilities, language primitives, or battle-tested tools could solve this without adding custom complexity?
   - Compare 2 distinct implementation angles: (e.g. In-process / Embedded vs. Modular / External Service).
2. Algorithmic, Data Structure & Runtime Characteristics:
   - Recommended data structures, state representation, and memory/CPU footprint.
   - Concurrency models, serialization costs, and I/O efficiency.
3. Contrarian Engineering Perspective:
   - Challenge typical over-engineering traps: what can be safely simplified, delayed, or removed?
   - What are the hard production failure modes (network breaks, disk full, corrupted cache, lock contention)?
4. Recommended Minimal Viable Architecture:
   - The leanest, most verifiable technical design that delivers 100% of the requirement.
"

# Execute Codex CLI non-interactively (read-only sandbox for advisory safety)
TEMP_OUTPUT=$(mktemp)
TEMP_ERR=$(mktemp)

echo "$PROMPT" | codex exec --sandbox read-only --skip-git-repo-check - > "$TEMP_OUTPUT" 2> "$TEMP_ERR"
EXIT_CODE=$?

OUTPUT_STR=$(cat "$TEMP_OUTPUT")
ERR_STR=$(cat "$TEMP_ERR")
rm -f "$TEMP_OUTPUT" "$TEMP_ERR"

# Check for execution errors or binary missing
if [ $EXIT_CODE -ne 0 ]; then
  if [ $EXIT_CODE -eq 127 ] || echo "$ERR_STR" | grep -qiE "(command not found|not found)"; then
    echo "❌ [COMMAND_NOT_FOUND]"
    echo "Reason: Codex CLI binary not found (Exit: $EXIT_CODE). Ensure codex is installed in ~/.local/bin or on PATH."
    if [ -n "$ERR_STR" ]; then
      echo "Detail: $ERR_STR"
    fi
    exit 127
  fi

  echo "⚠️ [FALLBACK_TRIGGERED: CODEX_UNAVAILABLE]"
  if echo "$ERR_STR" | grep -qiE "(rate limit|usage limit|quota|exceeded|credit balance|overloaded|429|529|authentication)"; then
    echo "Reason: Codex CLI rate limit, quota exhaustion, or connection error (Exit: $EXIT_CODE)."
  else
    echo "Reason: Codex CLI execution error (Exit: $EXIT_CODE)."
  fi
  if [ -n "$ERR_STR" ]; then
    echo "Detail: $ERR_STR"
  fi
  exit 100
fi

if [ -z "$(echo "$OUTPUT_STR" | tr -d '[:space:]')" ]; then
  echo "⚠️ [FALLBACK_TRIGGERED: CODEX_UNAVAILABLE]"
  echo "Reason: Codex CLI returned empty response."
  exit 100
fi

echo "$OUTPUT_STR"
exit 0
