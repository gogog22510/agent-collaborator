#!/usr/bin/env bash
# .agent/skills/claude-collaborator/scripts/claude_prompt_tune.sh
# Usage: ./claude_prompt_tune.sh "<PROMPT_FILE>" "<OPTIMIZATION_GOAL>"

set -euo pipefail

PROMPT_FILE="${1:-}"
GOAL="${2:-}"

if [ -z "$PROMPT_FILE" ] || [ -z "$GOAL" ]; then
  echo "Error: Missing arguments." >&2
  echo "Usage: $0 <PROMPT_FILE> \"<OPTIMIZATION_GOAL>\"" >&2
  exit 1
fi

CONTENT=""
if [ -f "$PROMPT_FILE" ]; then
  CONTENT="$(cat "$PROMPT_FILE")"
else
  echo "Error: File $PROMPT_FILE not found." >&2
  exit 1
fi

PROMPT="你是一位頂級中文武俠/仙俠小說作家與 Prompt Engineering 專家。
請優化以下 Prompt 檔案內容，以達到指定的優化目標。
語言要求：請永遠使用繁體中文回覆。

【目標 Prompt 檔案】
$PROMPT_FILE

【目前內容】
$CONTENT

【優化目標】
$GOAL

請輸出：
1. 分析目前 Prompt 的優缺點與瓶頸。
2. 修改後的完整優化 Prompt 內容（可直接取代原檔）。
3. 關鍵改動原因說明。
"

claude -p "$PROMPT" < /dev/null
