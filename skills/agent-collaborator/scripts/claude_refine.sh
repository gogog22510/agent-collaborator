#!/usr/bin/env bash
# Universal Claude Content / Prompt / Spec Refiner Script with Graceful Fallback
# Usage: ./claude_refine.sh "<TARGET_FILE>" "<OPTIMIZATION_GOAL>"

set -uo pipefail

TARGET_FILE="${1:-}"
GOAL="${2:-}"

if [ -z "$TARGET_FILE" ] || [ -z "$GOAL" ]; then
  echo "Error: Missing arguments." >&2
  echo "Usage: $0 <TARGET_FILE> \"<OPTIMIZATION_GOAL>\"" >&2
  exit 1
fi

CONTENT=""
if [ -f "$TARGET_FILE" ]; then
  CONTENT="$(cat "$TARGET_FILE")"
else
  echo "Error: File $TARGET_FILE not found." >&2
  exit 1
fi

PROMPT="你是一位精通文本、Prompt Engineering、規範與規格設計的高級工程專家。
請優化以下檔案內容，以達到指定的優化目標。
語言要求：請永遠使用繁體中文回覆。

【目標檔案】
$TARGET_FILE

【目前內容】
$CONTENT

【優化目標】
$GOAL

請輸出：
1. 深入分析目前內容的痛點、模糊之處或潛在瓶頸。
2. 修改後的完整優化內容（可直接作為修改版）。
3. 關鍵改動理由與效益說明。
"

TEMP_OUTPUT=$(mktemp)
TEMP_ERR=$(mktemp)

echo "$PROMPT" | claude -p --tools "" > "$TEMP_OUTPUT" 2> "$TEMP_ERR"
EXIT_CODE=$?

OUTPUT_STR=$(cat "$TEMP_OUTPUT")
ERR_STR=$(cat "$TEMP_ERR")
rm -f "$TEMP_OUTPUT" "$TEMP_ERR"

# 偵測是否觸發 Usage Limit、Rate Limit 或連線失敗
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT_STR $ERR_STR" | grep -qiE "(rate limit|usage limit|quota|exceeded|credit balance|overloaded|429|529|authentication)"; then
  echo "⚠️ [FALLBACK_TRIGGERED: CLAUDE_UNAVAILABLE]"
  echo "Reason: Claude CLI usage limit or connection error detected (Exit: $EXIT_CODE)."
  if [ -n "$ERR_STR" ]; then
    echo "Detail: $ERR_STR"
  fi
  exit 100
fi

echo "$OUTPUT_STR"
exit 0
